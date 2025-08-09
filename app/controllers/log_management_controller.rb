class LogManagementController < ApplicationController
  before_action :require_admin
  
  def index
    @retention_report = LogManagementService.generate_retention_report
    @cleanup_stats = get_cleanup_stats
  end
  
  def cleanup
    if request.post?
      results = LogManagementService.cleanup_old_logs
      
      if results[:errors].empty?
        flash[:notice] = l(:notice_cleanup_completed, 
                          operation_logs: results[:operation_logs_deleted],
                          notification_logs: results[:notification_logs_deleted])
      else
        flash[:error] = l(:error_cleanup_failed, errors: results[:errors].join(', '))
      end
      
      redirect_to log_management_index_path
    else
      render_404
    end
  end
  
  def retention_report
    @retention_report = LogManagementService.generate_retention_report
    
    respond_to do |format|
      format.html
      format.json { render json: @retention_report }
      format.csv do
        send_data generate_retention_report_csv(@retention_report),
                  filename: "retention_report_#{Date.current}.csv"
      end
    end
  end
  
  def export_archival
    export_data = LogManagementService.export_logs_for_archival
    
    respond_to do |format|
      format.json do
        send_data export_data.to_json,
                  filename: "logs_archival_#{Date.current}.json",
                  type: 'application/json'
      end
      format.csv do
        send_data generate_archival_csv(export_data),
                  filename: "logs_archival_#{Date.current}.csv"
      end
    end
  end
  
  def settings
    if request.post?
      update_retention_settings
      flash[:notice] = l(:notice_successful_update)
      redirect_to log_management_index_path
    end
  end
  
  private
  
  def get_cleanup_stats
    {
      last_cleanup: get_last_cleanup_time,
      next_cleanup: get_next_cleanup_time,
      auto_cleanup_enabled: Setting.plugin_redmine_sensitive_data_guard['auto_cleanup_enabled'] == '1',
      cleanup_frequency: Setting.plugin_redmine_sensitive_data_guard['cleanup_frequency'] || 'weekly'
    }
  end
  
  def get_last_cleanup_time
    # 這裡可以從資料庫或檔案中獲取最後清理時間
    # 暫時返回 nil
    nil
  end
  
  def get_next_cleanup_time
    last_cleanup = get_last_cleanup_time
    if last_cleanup
      last_cleanup + 1.week
    else
      Time.current + 1.week
    end
  end
  
  def update_retention_settings
    settings = params[:settings] || {}
    # 更新設定邏輯
  end
  
  def generate_retention_report_csv(report)
    require 'csv'
    
    CSV.generate(headers: true) do |csv|
      csv << ['報告類型', '記錄數量', '保留天數', '建議清理數量']
      
      if report[:operation_logs]
        csv << ['操作日誌', report[:operation_logs][:total_count], report[:operation_logs][:retention_days], report[:operation_logs][:to_cleanup]]
      end
      
      if report[:notification_logs]
        csv << ['通知日誌', report[:notification_logs][:total_count], report[:notification_logs][:retention_days], report[:notification_logs][:to_cleanup]]
      end
    end
  end
  
  def generate_archival_csv(export_data)
    require 'csv'
    
    CSV.generate(headers: true) do |csv|
      csv << ['ID', '操作類型', '風險等級', '使用者', '專案', '建立時間', '內容預覽']
      
      if export_data[:operation_logs]
        export_data[:operation_logs].each do |log|
          csv << [
            log[:id],
            log[:operation_type],
            log[:risk_level],
            log[:user_name],
            log[:project_name],
            log[:created_at],
            log[:content_preview]
          ]
        end
      end
    end
  end
end
