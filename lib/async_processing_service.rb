# frozen_string_literal: true

# 非同步處理服務
# 負責處理檔案掃描、通知發送等耗時操作
class AsyncProcessingService
  include Redmine::I18n
  
  class << self
    # 非同步檔案掃描
    def async_scan_file(attachment_id, user_id, project_id = nil)
      # 簡化版本 - 直接同步處理
      sync_scan_file(attachment_id, user_id, project_id)
    end
    
    # 同步檔案掃描（降級方案）
    def sync_scan_file(attachment_id, user_id, project_id = nil)
      attachment = Attachment.find_by(id: attachment_id)
      return unless attachment
      
      user = User.find_by(id: user_id)
      project = project_id ? Project.find_by(id: project_id) : attachment.project
      
      scanner = FileScanner.new
      result = scanner.scan_file(attachment.diskfile, attachment.filename)
      
      if result[:detected]
        log_attachment_scan(attachment, result, user, project)
        send_notification_if_needed(result, user, project)
      end
      
      result
    end
    
    # 非同步通知發送
    def async_send_notification(operation_log_id)
      # 簡化版本 - 直接同步處理
      sync_send_notification(operation_log_id)
    end
    
    # 同步通知發送（降級方案）
    def sync_send_notification(operation_log_id)
      operation_log = SensitiveOperationLog.find_by(id: operation_log_id)
      return unless operation_log
      
      # 簡化版本 - 只記錄到日誌
      Rails.logger.info "發送敏感資料通知: #{operation_log.id}"
    end
    
    # 批次處理
    def batch_process_attachments(attachment_ids, user_id, project_id = nil)
      # 簡化版本 - 直接同步處理
      sync_batch_process_attachments(attachment_ids, user_id, project_id)
    end
    
    # 同步批次處理（降級方案）
    def sync_batch_process_attachments(attachment_ids, user_id, project_id = nil)
      user = User.find_by(id: user_id)
      project = project_id ? Project.find_by(id: project_id) : nil
      
      results = []
      attachment_ids.each do |attachment_id|
        begin
          result = sync_scan_file(attachment_id, user_id, project_id)
          results << { attachment_id: attachment_id, result: result }
        rescue => e
          results << { attachment_id: attachment_id, error: e.message }
        end
      end
      
      results
    end
    
    # 清理過期日誌（非同步）
    def async_cleanup_logs
      # 簡化版本 - 直接同步處理
      sync_cleanup_logs
    end
    
    # 同步日誌清理（降級方案）
    def sync_cleanup_logs
      SensitiveOperationLog.cleanup_old_logs if defined?(SensitiveOperationLog)
    end
    
    private
    
    def log_attachment_scan(attachment, scan_result, user, project)
      return unless defined?(SensitiveOperationLog)
      
      SensitiveOperationLog.create!(
        user: user,
        project: project,
        operation_type: 'attachment_scan',
        content_type: 'file_attachment',
        detected_patterns: scan_result[:patterns]&.to_json || scan_result[:detections]&.to_json,
        content_preview: scan_result[:preview] || "檔案: #{attachment.filename}",
        file_type: attachment.content_type || File.extname(attachment.filename).downcase.gsub('.', ''),
        file_size: attachment.filesize,
        risk_level: scan_result[:risk_level] || 'medium',
        detection_count: scan_result[:detection_count] || scan_result[:detections]&.length || 0,
        detection_details: scan_result[:details]&.to_json || scan_result[:message],
        ip_address: get_user_ip_address(user),
        user_agent: get_user_agent(user)
      )
    rescue => e
      Rails.logger.error "記錄附件掃描失敗: #{e.message}"
    end
    
    def send_notification_if_needed(scan_result, user, project)
      return unless scan_result[:detected]
      
      # 簡化版本 - 只記錄到日誌
      Rails.logger.info "需要發送通知: 用戶=#{user&.login}, 專案=#{project&.identifier}"
    end
    
    def get_user_ip_address(user)
      if defined?(request) && request.respond_to?(:remote_ip)
        request.remote_ip
      else
        'unknown'
      end
    end
    
    def get_user_agent(user)
      if defined?(request) && request.respond_to?(:user_agent)
        request.user_agent
      else
        'unknown'
      end
    end
  end
end
