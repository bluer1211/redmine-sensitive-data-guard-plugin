# frozen_string_literal: true

module SensitiveDataGuard
  class SensitiveDataDetector
    include Redmine::I18n

    # 風險等級定義
    RISK_LEVELS = {
      high: 'high',
      medium: 'medium',
      low: 'low'
    }.freeze

    # 偵測結果結構
    DetectionResult = Struct.new(:detected, :patterns, :risk_level, :content_preview, :suggestions)

    def initialize
      @rules = load_detection_rules
      @risk_level_settings = load_risk_level_settings
    end

    # 主要偵測方法
    def scan(content, content_type = 'text')
      return DetectionResult.new(false, [], nil, nil, []) if content.blank?

      detected_patterns = []
      content_preview = extract_content_preview(content)
      
      # 執行所有啟用的偵測規則
      @rules.each do |rule|
        next unless rule.enabled?
        
        matches = find_matches(content, rule)
        if matches.any?
          detected_patterns << {
            rule: rule,
            matches: matches,
            risk_level: rule.risk_level
          }
        end
      end

      # 檢查風險等級設定
      detected_patterns = filter_by_risk_level(detected_patterns)
      
      # 生成建議
      suggestions = generate_suggestions(detected_patterns)
      
      DetectionResult.new(
        detected_patterns.any?,
        detected_patterns,
        determine_overall_risk_level(detected_patterns),
        content_preview,
        suggestions
      )
    end

    # 檢查是否應該阻擋提交
    def should_block?(detection_result, user = nil, project = nil)
      return false unless detection_result.detected
      
      # 檢查使用者覆蓋權限
      return false if user_has_override_permission?(user, project)
      
      # 檢查白名單
      return false if whitelist_match?(detection_result, user, project)
      
      # 根據風險等級決定是否阻擋
      case detection_result.risk_level
      when 'high'
        true # 高風險項目一律阻擋
      when 'medium'
        Setting.plugin_redmine_sensitive_data_guard['block_medium_risk'] || false
      when 'low'
        Setting.plugin_redmine_sensitive_data_guard['block_low_risk'] || false
      else
        false
      end
    end

    # 生成錯誤訊息
    def generate_error_message(detection_result, locale = 'zh-TW')
      return nil unless detection_result.detected

      messages = []
      
      detection_result.patterns.each do |pattern_data|
        rule = pattern_data[:rule]
        matches = pattern_data[:matches]
        
        case rule.rule_type
        when 'id_card'
          messages << l(:error_id_card_detected, locale: locale)
        when 'credit_card'
          messages << l(:error_credit_card_detected, locale: locale)
        when 'api_key'
          messages << l(:error_api_key_detected, locale: locale)
        when 'credential'
          messages << l(:error_credential_detected, locale: locale)
        when 'phone'
          messages << l(:error_phone_detected, locale: locale)
        when 'email'
          messages << l(:error_email_detected, locale: locale)
        when 'ip_address'
          messages << l(:error_ip_address_detected, locale: locale)
        when 'password'
          messages << l(:error_password_detected, locale: locale)
        else
          messages << l(:error_sensitive_data_detected, locale: locale)
        end
      end

      messages.uniq.join('; ')
    end

    private

    # 載入偵測規則
    def load_detection_rules
      # 預設規則
      default_rules = [
        # 台灣身分證號
        DetectionRule.new(
          name: 'Taiwan ID Card',
          rule_type: 'id_card',
          pattern: '[A-Z][12]\\d{8}',
          risk_level: 'high',
          description: '台灣身分證號碼格式'
        ),
        
        # 信用卡號
        DetectionRule.new(
          name: 'Credit Card Number',
          rule_type: 'credit_card',
          pattern: '\\b\\d{4}[-\\s]?\\d{4}[-\\s]?\\d{4}[-\\s]?\\d{4}\\b',
          risk_level: 'high',
          description: '信用卡號碼格式'
        ),
        
        # API Key
        DetectionRule.new(
          name: 'API Key',
          rule_type: 'api_key',
          pattern: '(?i)(?:api[_-]?key|secret|token)\\s*[:=]\\s*[\'"]?[a-zA-Z0-9]{20,}[\'"]?',
          risk_level: 'high',
          description: 'API金鑰格式'
        ),
        
        # 帳號密碼組合
        DetectionRule.new(
          name: 'Username Password Combination',
          rule_type: 'credential',
          pattern: '(?i)(?:user(?:name|id)?|login|account)\\s*[:=]\\s*[\'"]?[^\'"\\s]+[\'"]?\\s*(?:password|pwd|pass)\\s*[:=]\\s*[\'"]?[^\'"\\s]{6,}[\'"]?',
          risk_level: 'high',
          description: '帳號密碼組合'
        ),
        
        # 單獨密碼
        DetectionRule.new(
          name: 'Password Only',
          rule_type: 'password',
          pattern: '(?i)(?:password|pwd|passwd)\\s*=\\s*[\'"]?[^\'"\\s]{6,}[\'"]?',
          risk_level: 'medium',
          description: '單獨密碼'
        ),
        
        # 台灣手機號碼
        DetectionRule.new(
          name: 'Taiwan Mobile Number',
          rule_type: 'phone',
          pattern: '09\\d{2}-?\\d{3}-?\\d{3}',
          risk_level: 'medium',
          description: '台灣手機號碼格式'
        ),
        
        # Email地址
        DetectionRule.new(
          name: 'Email Address',
          rule_type: 'email',
          pattern: '\\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Z|a-z]{2,}\\b',
          risk_level: 'medium',
          description: 'Email地址格式'
        ),
        
        # 內部IP位址
        DetectionRule.new(
          name: 'Internal IP Address',
          rule_type: 'ip_address',
          pattern: '\\b(?:192\\.168\\.|10\\.|172\\.(?:1[6-9]|2[0-9]|3[01])\\.)\\d{1,3}\\.\\d{1,3}\\b',
          risk_level: 'medium',
          description: '內部網路IP位址'
        ),
        
        # 外部IP位址
        DetectionRule.new(
          name: 'External IP Address',
          rule_type: 'ip_address',
          pattern: '\\b(?:[0-9]{1,3}\\.){3}[0-9]{1,3}\\b',
          risk_level: 'low',
          description: '外部IP位址'
        )
      ]

      # 從資料庫載入自訂規則（如果存在）
      if defined?(DetectionRule) && DetectionRule.respond_to?(:all)
        db_rules = DetectionRule.all
        default_rules + db_rules
      else
        default_rules
      end
    end

    # 載入風險等級設定
    def load_risk_level_settings
      settings = Setting.plugin_redmine_sensitive_data_guard || {}
      
      {
        high: {
          enabled: settings['enable_high_risk_detection'] != false,
          strategy: settings['high_risk_strategy'] || 'block'
        },
        medium: {
          enabled: settings['enable_medium_risk_detection'] != false,
          strategy: settings['medium_risk_strategy'] || 'warn'
        },
        low: {
          enabled: settings['enable_low_risk_detection'] != false,
          strategy: settings['low_risk_strategy'] || 'log'
        }
      }
    end

    # 尋找匹配內容
    def find_matches(content, rule)
      return [] unless rule.pattern.present?
      
      begin
        regex = Regexp.new(rule.pattern, Regexp::IGNORECASE)
        matches = content.scan(regex)
        matches.flatten.compact
      rescue RegexpError => e
        Rails.logger.error "Invalid regex pattern in rule #{rule.name}: #{e.message}"
        []
      end
    end

    # 根據風險等級過濾結果
    def filter_by_risk_level(detected_patterns)
      detected_patterns.select do |pattern_data|
        risk_level = pattern_data[:risk_level]
        @risk_level_settings[risk_level.to_sym]&.dig(:enabled) != false
      end
    end

    # 決定整體風險等級
    def determine_overall_risk_level(detected_patterns)
      return nil if detected_patterns.empty?
      
      risk_levels = detected_patterns.map { |p| p[:risk_level] }
      
      if risk_levels.include?('high')
        'high'
      elsif risk_levels.include?('medium')
        'medium'
      else
        'low'
      end
    end

    # 提取內容預覽
    def extract_content_preview(content, max_length = 200)
      return '' if content.blank?
      
      preview = content.to_s.strip
      if preview.length > max_length
        preview = preview[0, max_length] + '...'
      end
      
      # 遮蔽敏感內容
      preview = mask_sensitive_content(preview)
      
      preview
    end

    # 遮蔽敏感內容
    def mask_sensitive_content(content)
      # 遮蔽身分證號
      content = content.gsub(/([A-Z][12]\d{6})\d{2}/, '\1**')
      
      # 遮蔽信用卡號
      content = content.gsub(/(\d{4}[-\\s]?\d{4}[-\\s]?\d{4})[-\\s]?\d{4}/, '\1-****')
      
      # 遮蔽手機號碼
      content = content.gsub(/(09\d{2}-?\d{3})-?\d{3}/, '\1-***')
      
      content
    end

    # 生成建議
    def generate_suggestions(detected_patterns)
      suggestions = []
      
      detected_patterns.each do |pattern_data|
        rule = pattern_data[:rule]
        
        case rule.rule_type
        when 'id_card'
          suggestions << '請移除身分證號碼或使用替代識別碼'
        when 'credit_card'
          suggestions << '請移除信用卡號碼或使用遮蔽格式'
        when 'api_key'
          suggestions << '請移除API金鑰或使用環境變數'
        when 'credential'
          suggestions << '請移除帳號密碼資訊或使用安全配置'
        when 'password'
          suggestions << '請移除密碼資訊或使用安全配置'
        when 'phone'
          suggestions << '請移除手機號碼或使用替代聯絡方式'
        when 'email'
          suggestions << '請確認Email地址的必要性'
        when 'ip_address'
          suggestions << '請確認IP位址的必要性'
        end
      end
      
      suggestions.uniq
    end

    # 檢查使用者覆蓋權限
    def user_has_override_permission?(user, project)
      return false unless user
      
      # 系統管理員
      return true if user.admin?
      
      # 檢查專案權限
      if project
        return true if user.allowed_to?(:override_sensitive_detection, project)
      end
      
      false
    end

    # 檢查白名單匹配
    def whitelist_match?(detection_result, user, project)
      # TODO: 實作白名單檢查邏輯
      false
    end
  end

  # 偵測規則模型（簡化版本）
  class DetectionRule
    attr_accessor :name, :rule_type, :pattern, :risk_level, :description, :enabled

    def initialize(attributes = {})
      @name = attributes[:name]
      @rule_type = attributes[:rule_type]
      @pattern = attributes[:pattern]
      @risk_level = attributes[:risk_level]
      @description = attributes[:description]
      @enabled = attributes[:enabled] != false
    end

    def enabled?
      @enabled
    end
  end
end 