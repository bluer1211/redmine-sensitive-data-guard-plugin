# frozen_string_literal: true

module SensitiveDataGuard
  class Hooks < Redmine::Hook::ViewListener
    include Redmine::I18n

    # 在問題表單提交前檢查
    def controller_issues_new_before_save(context = {})
      check_sensitive_data(context)
    end

    def controller_issues_edit_before_save(context = {})
      check_sensitive_data(context)
    end

    # 在Wiki頁面保存前檢查
    def controller_wiki_edit_before_save(context = {})
      check_sensitive_data(context)
    end

    # 在檔案上傳前檢查
    def controller_attachments_before_save(context = {})
      check_file_upload(context)
    end

    # 在評論提交前檢查
    def controller_issues_edit_before_save_journals(context = {})
      check_sensitive_data(context)
    end

    # 在專案描述保存前檢查
    def controller_projects_settings_before_save(context = {})
      check_sensitive_data(context)
    end

    private

    def check_sensitive_data(context)
      return unless plugin_enabled?
      
      detector = SensitiveDataDetector.new
      user = User.current
      project = context[:project] || context[:issue]&.project
      
      # 檢查問題內容
      if context[:issue]
        content_fields = [
          context[:issue].subject,
          context[:issue].description,
          context[:issue].notes
        ].compact.join(' ')
        
        result = detector.scan(content_fields)
        handle_detection_result(result, user, project, context)
      end
      
      # 檢查Wiki內容
      if context[:page]
        result = detector.scan(context[:page].content&.text)
        handle_detection_result(result, user, project, context)
      end
      
      # 檢查專案描述
      if context[:project]
        result = detector.scan(context[:project].description)
        handle_detection_result(result, user, project, context)
      end
    end

    def check_file_upload(context)
      return unless plugin_enabled?
      return unless Setting.plugin_redmine_sensitive_data_guard['enable_file_scanning']
      
      attachment = context[:attachment]
      return unless attachment
      
      # 檢查檔案類型
      return unless office_document?(attachment.filename)
      
      # 檢查檔案大小
      max_size = Setting.plugin_redmine_sensitive_data_guard['max_file_size_mb'] || 50
      if attachment.filesize > max_size.megabytes
        raise SecurityError, "檔案大小超過限制 (#{max_size}MB)"
      end
      
      # TODO: 實作檔案內容掃描
      # 這裡需要實作 Office 文件解析器
    end

    def handle_detection_result(result, user, project, context)
      return unless result.detected
      
      if detector.should_block?(result, user, project)
        # 記錄操作日誌
        log_sensitive_operation(result, user, project, context)
        
        # 拋出錯誤阻止提交
        error_message = detector.generate_error_message(result)
        raise SecurityError, error_message
      else
        # 記錄警告日誌
        log_sensitive_warning(result, user, project, context)
      end
    end

    def log_sensitive_operation(result, user, project, context)
      return unless defined?(SensitiveOperationLog)
      
      SensitiveOperationLog.create(
        user: user,
        project: project,
        operation_type: 'blocked_submission',
        content_type: determine_content_type(context),
        detected_patterns: result.patterns.to_json,
        content_preview: result.content_preview,
        risk_level: result.risk_level,
        ip_address: request&.remote_ip,
        user_agent: request&.user_agent
      )
    rescue => e
      Rails.logger.error "Failed to log sensitive operation: #{e.message}"
    end

    def log_sensitive_warning(result, user, project, context)
      return unless defined?(SensitiveOperationLog)
      
      SensitiveOperationLog.create(
        user: user,
        project: project,
        operation_type: 'warning',
        content_type: determine_content_type(context),
        detected_patterns: result.patterns.to_json,
        content_preview: result.content_preview,
        risk_level: result.risk_level,
        ip_address: request&.remote_ip,
        user_agent: request&.user_agent
      )
    rescue => e
      Rails.logger.error "Failed to log sensitive warning: #{e.message}"
    end

    def determine_content_type(context)
      if context[:issue]
        'issue'
      elsif context[:page]
        'wiki'
      elsif context[:project]
        'project'
      else
        'unknown'
      end
    end

    def office_document?(filename)
      return false unless filename
      
      extension = File.extname(filename).downcase
      %w[.docx .xlsx .pptx .pdf .doc .xls .odt .ods .odp].include?(extension)
    end

    def plugin_enabled?
      Setting.plugin_redmine_sensitive_data_guard['enabled'] != false
    end

    def detector
      @detector ||= SensitiveDataDetector.new
    end
  end
end 