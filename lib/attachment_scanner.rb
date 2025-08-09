# frozen_string_literal: true

# 附件掃描器
# 負責攔截和掃描 Redmine 附件上傳
class AttachmentScanner
  include Redmine::I18n

  def initialize(settings = {})
    @settings = settings
    @file_scanner = FileScanner.new(settings)
    @enabled = settings['enable_file_scanning'] != false
  end

  # 掃描附件
  def scan_attachment(attachment)
    return scan_result(false, '附件掃描功能已停用') unless @enabled
    return scan_result(false, '附件不能為空') if attachment.blank?
    return scan_result(false, '附件檔案不存在') unless attachment.diskfile && File.exist?(attachment.diskfile)

    # 掃描檔案
    scan_result = @file_scanner.scan_file(attachment.diskfile, attachment.filename)
    
    if scan_result[:detected]
      # 記錄掃描結果
      log_attachment_scan(attachment, scan_result)
      
      # 根據風險等級決定處理方式
      handle_attachment_scan_result(attachment, scan_result)
    end

    scan_result
  end

  # 批量掃描附件
  def scan_attachments(attachments)
    return [] unless @enabled
    return [] if attachments.blank?

    results = []
    attachments.each do |attachment|
      result = scan_attachment(attachment)
      results << {
        attachment: attachment,
        scan_result: result
      }
    end

    results
  end

  # 檢查附件是否安全
  def attachment_safe?(attachment)
    return true unless @enabled
    return true if attachment.blank?

    result = scan_attachment(attachment)
    !result[:detected]
  end

  private

  def handle_attachment_scan_result(attachment, scan_result)
    risk_level = scan_result[:risk_level] || 'low'
    
    case risk_level
    when 'high'
      handle_high_risk(attachment, scan_result)
    when 'medium'
      handle_medium_risk(attachment, scan_result)
    when 'low'
      handle_low_risk(attachment, scan_result)
    end
  end

  def handle_high_risk(attachment, scan_result)
    # 高風險：根據設定決定處理方式
    strategy = @settings['high_risk_strategy'] || 'block'
    
    case strategy
    when 'block'
      raise SecurityError.new("檢測到高風險內容：#{scan_result[:message]}")
    when 'warn'
      Rails.logger.warn "高風險附件上傳：#{attachment.filename} - #{scan_result[:message]}"
    else
      Rails.logger.info "高風險附件記錄：#{attachment.filename} - #{scan_result[:message]}"
    end
  end

  def handle_medium_risk(attachment, scan_result)
    # 中風險：警告或記錄
    strategy = @settings['medium_risk_strategy'] || 'warn'
    
    case strategy
    when 'block'
      raise SecurityError.new("檢測到中風險內容：#{scan_result[:message]}")
    when 'warn'
      Rails.logger.warn "中風險附件上傳：#{attachment.filename} - #{scan_result[:message]}"
    else
      Rails.logger.info "中風險附件記錄：#{attachment.filename} - #{scan_result[:message]}"
    end
  end

  def handle_low_risk(attachment, scan_result)
    # 低風險：僅記錄
    strategy = @settings['low_risk_strategy'] || 'log'
    
    case strategy
    when 'block'
      raise SecurityError.new("檢測到低風險內容：#{scan_result[:message]}")
    when 'warn'
      Rails.logger.warn "低風險附件上傳：#{attachment.filename} - #{scan_result[:message]}"
    else
      Rails.logger.info "低風險附件記錄：#{attachment.filename} - #{scan_result[:message]}"
    end
  end

  def log_attachment_scan(attachment, scan_result)
    # 記錄到敏感操作日誌
    begin
      SensitiveOperationLog.create!(
        user: User.current,
        project: attachment.project,
        operation_type: 'attachment_scan',
        content_type: 'attachment',
        detected_patterns: scan_result[:patterns]&.join(','),
        content_preview: "檔案: #{attachment.filename}",
        file_type: File.extname(attachment.filename).downcase.gsub('.', ''),
        file_size: attachment.filesize,
        risk_level: scan_result[:risk_level] || 'medium',
        ip_address: get_user_ip_address,
        user_agent: get_user_agent
      )
    rescue => e
      Rails.logger.error "記錄附件掃描失敗: #{e.message}"
    end
  end

  def get_user_ip_address
    if defined?(request) && request.respond_to?(:remote_ip)
      request.remote_ip
    else
      'unknown'
    end
  end

  def get_user_agent
    if defined?(request) && request.respond_to?(:user_agent)
      request.user_agent
    else
      'unknown'
    end
  end

  def scan_result(detected, message, detection_result = nil)
    {
      detected: detected,
      message: message,
      risk_level: detection_result&.risk_level || (detected ? 'medium' : 'low'),
      patterns: detection_result&.detections&.map { |d| d[:type] } || [],
      detection_count: detection_result&.total_matches || 0,
      details: detection_result&.detections || [],
      preview: message
    }
  end
end
