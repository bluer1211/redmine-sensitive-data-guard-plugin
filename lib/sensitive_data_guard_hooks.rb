# frozen_string_literal: true

# Redmine Hooks 用於攔截表單提交並進行敏感資料偵測
class SensitiveDataGuardHooks < Redmine::Hook::ViewListener
  include ActionView::Helpers::JavaScriptHelper

  # 在控制器動作執行前攔截
  def controller_issues_new_before_save(context = {})
    detect_sensitive_data_in_issue(context)
  end

  def controller_issues_edit_before_save(context = {})
    detect_sensitive_data_in_issue(context)
  end

  def controller_wiki_edit_before_save(context = {})
    detect_sensitive_data_in_wiki(context)
  end

  def controller_messages_new_before_save(context = {})
    detect_sensitive_data_in_message(context)
  end

  def controller_messages_reply_before_save(context = {})
    detect_sensitive_data_in_message(context)
  end

  # 附件上傳攔截
  def controller_attachments_new_before_save(context = {})
    detect_sensitive_data_in_attachment(context)
  end

  def controller_attachments_edit_before_save(context = {})
    detect_sensitive_data_in_attachment(context)
  end

  # 在視圖中注入 JavaScript 驗證
  def view_layouts_base_html_head(context = {})
    return '' unless User.current&.logged?

    content = +''
    content << javascript_include_tag('sensitive_data_validation', plugin: 'redmine_sensitive_data_guard')
    content << stylesheet_link_tag('sensitive_data_guard', plugin: 'redmine_sensitive_data_guard')
    content.html_safe
  end

  # 在表單中添加驗證提示
  def view_issues_form_details_bottom(context = {})
    render_sensitive_data_warning
  end

  def view_wiki_form_bottom(context = {})
    render_sensitive_data_warning
  end

  def view_messages_form_bottom(context = {})
    render_sensitive_data_warning
  end

  # 在附件上傳表單中添加驗證提示
  def view_attachments_form_bottom(context = {})
    render_attachment_scanning_warning
  end

  private

  def detect_sensitive_data_in_issue(context)
    issue = context[:issue]
    return unless issue

    begin
      content_fields = [
        issue.subject,
        issue.description,
        issue.notes
      ].compact.join(' ')

      detector = SimpleSensitiveDataDetector.new
      result = detector.scan(content_fields)

      if result.detected?
        handle_detection_result(result, User.current, issue.project, 'issue', content_fields)
      end
    rescue => error
      ErrorHandler.handle_detection_error(error, { 
        content_type: 'issue', 
        issue_id: issue.id,
        user_id: User.current&.id 
      })
      Rails.logger.error "Issue 敏感資料偵測失敗: #{error.message}"
    end
  end

  def detect_sensitive_data_in_wiki(context)
    page = context[:page]
    return unless page

    begin
      content_fields = [
        page.title,
        page.content&.text
      ].compact.join(' ')

      detector = SimpleSensitiveDataDetector.new
      result = detector.scan(content_fields)

      if result.detected?
        handle_detection_result(result, User.current, page.project, 'wiki', content_fields)
      end
    rescue => error
      ErrorHandler.handle_detection_error(error, { 
        content_type: 'wiki', 
        page_id: page.id,
        user_id: User.current&.id 
      })
      Rails.logger.error "Wiki 敏感資料偵測失敗: #{error.message}"
    end
  end

  def detect_sensitive_data_in_message(context)
    message = context[:message]
    return unless message

    begin
      content_fields = [
        message.subject,
        message.content
      ].compact.join(' ')

      detector = SimpleSensitiveDataDetector.new
      result = detector.scan(content_fields)

      if result.detected?
        handle_detection_result(result, User.current, message.board&.project, 'message', content_fields)
      end
    rescue => error
      ErrorHandler.handle_detection_error(error, { 
        content_type: 'message', 
        message_id: message.id,
        user_id: User.current&.id 
      })
      Rails.logger.error "Message 敏感資料偵測失敗: #{error.message}"
    end
  end

  def detect_sensitive_data_in_attachment(context)
    attachment = context[:attachment]
    return unless attachment

    begin
      # 檢查檔案大小限制
      max_size = Setting.plugin_redmine_sensitive_data_guard&.dig('max_file_size_mb') || 50
      if attachment.filesize > max_size.megabytes
        Rails.logger.warn "檔案大小超過限制: #{attachment.filename} (#{attachment.filesize} bytes)"
        return
      end

      # 檢查是否為可掃描的檔案類型
      supported_types = %w[txt csv doc docx xls xlsx pdf]
      file_extension = File.extname(attachment.filename).downcase.gsub('.', '')
      
      unless supported_types.include?(file_extension)
        Rails.logger.info "不支援的檔案類型: #{file_extension}"
        return
      end

      # 掃描檔案內容
      scanner = FileScanner.new
      scan_result = scanner.scan_file(attachment.diskfile, attachment.filename)

      if scan_result[:detected]
        log_attachment_scan(attachment, scan_result)
        
        # 檢查是否需要阻擋上傳
        if should_block_attachment_upload?(scan_result, User.current, attachment.project)
          raise SecurityError.new("附件包含敏感資料，上傳被阻擋")
        end
      end
    rescue => error
      ErrorHandler.handle_file_error(error, { 
        filename: attachment.filename,
        filesize: attachment.filesize,
        user_id: User.current&.id 
      })
      Rails.logger.error "附件敏感資料偵測失敗: #{error.message}"
    end
  end

  def handle_detection_result(result, user, project, content_type, content_preview)
    # 記錄偵測結果
    log_sensitive_operation(result, user, project, content_type, content_preview)
    
    # 檢查是否需要阻擋提交
    if should_block_submission?(result, user, project)
      raise SecurityError.new(generate_error_message(result))
    end
  end

  def should_block_submission?(result, user, project)
    # 檢查是否有覆蓋權限
    return false if user&.allowed_to?(:override_sensitive_detection, project)
    
    # 根據風險等級決定是否阻擋
    case result.risk_level
    when 'high'
      true
    when 'medium'
      # 中風險可以設定為警告或阻擋
      Setting.plugin_redmine_sensitive_data_guard&.dig('medium_risk_strategy') == 'block'
    else
      false
    end
  end

  def should_block_attachment_upload?(scan_result, user, project)
    # 檢查是否有覆蓋權限
    return false if user&.allowed_to?(:override_sensitive_detection, project)
    
    # 根據掃描結果決定是否阻擋
    scan_result[:risk_level] == 'high'
  end

  def generate_error_message(result)
    messages = []
    messages << "檢測到敏感資料：" if result.detected?
    result.detections.each do |detection|
      messages << "- #{detection[:type]}: #{detection[:description]}"
    end
    messages.join("\n")
  end

  def log_sensitive_operation(result, user, project, content_type, content_preview)
    return unless defined?(SensitiveOperationLog)

    begin
      SensitiveOperationLog.create!(
        user: user,
        project: project,
        operation_type: 'detection',
        content_type: content_type,
        detected_patterns: result.detections.map { |d| d[:type] }.join(','),
        content_preview: content_preview.to_s.truncate(500),
        risk_level: result.risk_level,
        ip_address: get_user_ip_address,
        user_agent: get_user_agent
      )
    rescue => e
      Rails.logger.error "記錄敏感操作失敗: #{e.message}"
    end
  end

  def log_attachment_scan(attachment, scan_result)
    return unless defined?(SensitiveOperationLog)

    begin
      SensitiveOperationLog.create!(
        user: User.current,
        project: attachment.project,
        operation_type: 'attachment_scan',
        content_type: 'attachment',
        detected_patterns: scan_result[:detections]&.join(','),
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

  def render_sensitive_data_warning
    return '' unless User.current&.logged?

    content = +''
    content << '<div class="sensitive-data-warning" style="margin: 10px 0; padding: 10px; background-color: #fff3cd; border: 1px solid #ffeaa7; border-radius: 4px;">'
    content << '<strong>⚠️ 敏感資料提醒：</strong>'
    content << '<p>請確保您提交的內容不包含敏感資料，如身分證號碼、信用卡號碼、API 金鑰等。</p>'
    content << '<p>系統會自動偵測並記錄敏感資料的使用情況。</p>'
    content << '</div>'
    content.html_safe
  end

  def render_attachment_scanning_warning
    return '' unless User.current&.logged?

    content = +''
    content << '<div class="attachment-scanning-warning" style="margin: 10px 0; padding: 10px; background-color: #d1ecf1; border: 1px solid #bee5eb; border-radius: 4px;">'
    content << '<strong>📎 檔案掃描提醒：</strong>'
    content << '<p>上傳的檔案將被自動掃描以偵測敏感資料。</p>'
    content << '<p>支援的檔案類型：TXT, CSV, DOC, XLS, PDF 等。</p>'
    content << '</div>'
    content.html_safe
  end

  def get_user_ip_address
    if defined?(request) && request.respond_to?(:remote_ip)
      request.remote_ip
    elsif User.current&.respond_to?(:current_ip)
      User.current.current_ip
    else
      'unknown'
    end
  end

  def get_user_agent
    if defined?(request) && request.respond_to?(:user_agent)
      request.user_agent
    elsif User.current&.respond_to?(:current_user_agent)
      User.current.current_user_agent
    else
      'unknown'
    end
  end
end
