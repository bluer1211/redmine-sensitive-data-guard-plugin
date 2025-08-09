# frozen_string_literal: true

class LogManagementService
  include Redmine::I18n
  
  def self.cleanup_old_logs
    new.cleanup_old_logs
  end
  
  def self.generate_retention_report
    new.generate_retention_report
  end
  
  def self.export_logs_for_archival
    new.export_logs_for_archival
  end
  
  def cleanup_old_logs
    cleanup_results = {
      operation_logs_deleted: 0,
      notification_logs_deleted: 0,
      errors: []
    }
    
    begin
      # 清理操作日誌
      cleanup_results[:operation_logs_deleted] = cleanup_operation_logs
      
      # 清理通知日誌
      cleanup_results[:notification_logs_deleted] = cleanup_notification_logs
      
      # 記錄清理結果
      log_cleanup_result(cleanup_results)
      
    rescue => e
      cleanup_results[:errors] << "清理過程發生錯誤: #{e.message}"
      Rails.logger.error "日誌清理失敗: #{e.message}"
    end
    
    cleanup_results
  end
  
  def generate_retention_report
    report = {
      generated_at: Time.current,
      operation_logs: generate_operation_logs_report,
      notification_logs: generate_notification_logs_report,
      retention_policy: get_retention_policy,
      recommendations: generate_recommendations
    }
    
    report
  end
  
  def export_logs_for_archival
    export_data = {
      operation_logs: export_operation_logs,
      notification_logs: export_notification_logs,
      export_metadata: {
        exported_at: Time.current,
        total_operation_logs: SensitiveOperationLog.count,
        total_notification_logs: defined?(NotificationLog) ? NotificationLog.count : 0
      }
    }
    
    export_data
  end
  
  private
  
  def cleanup_operation_logs
    retention_days = get_retention_days('operation_logs')
    cutoff_date = retention_days.days.ago
    
    # 刪除過期的操作日誌
    deleted_count = SensitiveOperationLog.where('created_at < ?', cutoff_date).delete_all
    
    Rails.logger.info "已清理 #{deleted_count} 條過期操作日誌 (保留天數: #{retention_days})"
    
    deleted_count
  end
  
  def cleanup_notification_logs
    retention_days = get_retention_days('notification_logs')
    cutoff_date = retention_days.days.ago
    
    # 檢查 NotificationLog 模型是否存在
    unless defined?(NotificationLog)
      Rails.logger.info "NotificationLog 模型不存在，跳過通知日誌清理"
      return 0
    end
    
    # 刪除過期的通知日誌
    deleted_count = NotificationLog.where('created_at < ?', cutoff_date).delete_all
    
    Rails.logger.info "已清理 #{deleted_count} 條過期通知日誌 (保留天數: #{retention_days})"
    
    deleted_count
  end
  
  def generate_operation_logs_report
    total_count = SensitiveOperationLog.count
    high_risk_count = SensitiveOperationLog.high_risk.count if SensitiveOperationLog.respond_to?(:high_risk)
    medium_risk_count = SensitiveOperationLog.medium_risk.count if SensitiveOperationLog.respond_to?(:medium_risk)
    low_risk_count = SensitiveOperationLog.low_risk.count if SensitiveOperationLog.respond_to?(:low_risk)
    
    {
      total_count: total_count,
      high_risk_count: high_risk_count || 0,
      medium_risk_count: medium_risk_count || 0,
      low_risk_count: low_risk_count || 0,
      retention_days: get_retention_days('operation_logs'),
      oldest_log_date: SensitiveOperationLog.minimum(:created_at),
      newest_log_date: SensitiveOperationLog.maximum(:created_at)
    }
  end
  
  def generate_notification_logs_report
    unless defined?(NotificationLog)
      return {
        total_count: 0,
        retention_days: get_retention_days('notification_logs'),
        message: 'NotificationLog 模型不存在'
      }
    end
    
    total_count = NotificationLog.count
    
    {
      total_count: total_count,
      retention_days: get_retention_days('notification_logs'),
      oldest_log_date: NotificationLog.minimum(:created_at),
      newest_log_date: NotificationLog.maximum(:created_at)
    }
  end
  
  def get_retention_policy
    {
      operation_logs_retention_days: get_retention_days('operation_logs'),
      notification_logs_retention_days: get_retention_days('notification_logs'),
      auto_cleanup_enabled: Setting.plugin_redmine_sensitive_data_guard&.dig('auto_cleanup_enabled') || true
    }
  end
  
  def generate_recommendations
    recommendations = []
    
    # 檢查操作日誌數量
    operation_logs_report = generate_operation_logs_report
    if operation_logs_report[:total_count] > 10000
      recommendations << "操作日誌數量較多 (#{operation_logs_report[:total_count]} 條)，建議定期清理"
    end
    
    # 檢查高風險日誌比例
    if operation_logs_report[:total_count] > 0
      high_risk_ratio = operation_logs_report[:high_risk_count].to_f / operation_logs_report[:total_count] * 100
      if high_risk_ratio > 20
        recommendations << "高風險日誌比例較高 (#{high_risk_ratio.round(1)}%)，建議檢查系統安全性"
      end
    end
    
    if recommendations.empty?
      recommendations << "日誌管理狀況良好，無需特別建議"
    end
    
    recommendations
  end
  
  def export_operation_logs
    SensitiveOperationLog.includes(:user, :project)
      .order(created_at: :desc)
      .limit(1000)
      .map do |log|
        {
          id: log.id,
          user_name: log.user&.name,
          project_name: log.project&.name,
          operation_type: log.operation_type,
          content_type: log.content_type,
          risk_level: log.risk_level,
          detected_patterns: log.detected_patterns,
          content_preview: log.content_preview,
          ip_address: log.ip_address,
          created_at: log.created_at
        }
      end
  end
  
  def export_notification_logs
    unless defined?(NotificationLog)
      return []
    end
    
    NotificationLog.order(created_at: :desc)
      .limit(1000)
      .map do |log|
        {
          id: log.id,
          notification_type: log.notification_type,
          recipient: log.recipient,
          content: log.content,
          sent_at: log.sent_at,
          created_at: log.created_at
        }
      end
  end
  
  def get_retention_days(log_type)
    setting_key = "#{log_type}_retention_days"
    Setting.plugin_redmine_sensitive_data_guard&.dig(setting_key) || default_retention_days(log_type)
  end
  
  def default_retention_days(log_type)
    case log_type
    when 'operation_logs'
      1095 # 3年
    when 'notification_logs'
      365  # 1年
    else
      365  # 預設1年
    end
  end
  
  def log_cleanup_result(results)
    cleanup_log = {
      timestamp: Time.current,
      operation_logs_deleted: results[:operation_logs_deleted],
      notification_logs_deleted: results[:notification_logs_deleted],
      errors: results[:errors]
    }
    
    Rails.logger.info "日誌清理完成: #{cleanup_log}"
  end
end
