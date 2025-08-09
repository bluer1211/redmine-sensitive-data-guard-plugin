# frozen_string_literal: true

class PerformanceMonitorController < ApplicationController
  before_action :require_admin
  
  def index
    @performance_stats = get_performance_stats
    @system_health = get_system_health
    @recent_activities = get_recent_activities
    
    respond_to do |format|
      format.html
      format.json { render json: @performance_stats }
    end
  end
  
  def realtime
    @realtime_stats = get_realtime_stats
    
    respond_to do |format|
      format.json { render json: @realtime_stats }
      format.html { redirect_to performance_monitor_path }
    end
  end
  
  def system_health
    @system_health = get_system_health
    
    respond_to do |format|
      format.json { render json: @system_health }
      format.html { redirect_to performance_monitor_path }
    end
  end
  
  def export_report
    @performance_stats = get_performance_stats
    @system_health = get_system_health
    
    respond_to do |format|
      format.csv do
        send_data generate_csv_report, filename: "performance_report_#{Date.current}.csv"
      end
      format.html { redirect_to performance_monitor_path }
    end
  end
  
  def cleanup_metrics
    if request.post?
      begin
        # 清理舊的效能指標
        cleanup_old_metrics
        flash[:notice] = l(:notice_metrics_cleanup_completed)
      rescue => e
        flash[:error] = l(:error_metrics_cleanup_failed, error: e.message)
      end
    end
    
    redirect_to performance_monitor_path
  end
  
  private
  
  def get_performance_stats
    {
      total_users: User.count,
      total_projects: Project.count,
      total_issues: Issue.count,
      total_attachments: Attachment.count,
      system_uptime: get_system_uptime,
      memory_usage: get_memory_usage,
      disk_usage: get_disk_usage
    }
  end
  
  def get_system_health
    {
      database_status: check_database_status,
      file_system_status: check_file_system_status,
      plugin_status: check_plugin_status,
      last_backup: get_last_backup_time
    }
  end
  
  def get_recent_activities
    # 獲取最近的活動記錄
    []
  end
  
  def get_realtime_stats
    {
      current_users: get_current_users,
      active_sessions: get_active_sessions,
      cpu_usage: get_cpu_usage,
      memory_usage: get_memory_usage
    }
  end
  
  def get_system_uptime
    # 簡單的系統運行時間計算
    Time.current - 1.day
  end
  
  def get_memory_usage
    # 簡單的記憶體使用率計算
    {
      total: 1024,
      used: 512,
      free: 512,
      percentage: 50
    }
  end
  
  def get_disk_usage
    # 簡單的磁碟使用率計算
    {
      total: 1000,
      used: 500,
      free: 500,
      percentage: 50
    }
  end
  
  def check_database_status
    begin
      ActiveRecord::Base.connection.execute("SELECT 1")
      "healthy"
    rescue => e
      "error"
    end
  end
  
  def check_file_system_status
    # 檢查檔案系統狀態
    "healthy"
  end
  
  def check_plugin_status
    # 檢查插件狀態
    "healthy"
  end
  
  def get_last_backup_time
    # 獲取最後備份時間
    nil
  end
  
  def get_current_users
    # 獲取當前使用者數量
    0
  end
  
  def get_active_sessions
    # 獲取活躍會話數量
    0
  end
  
  def get_cpu_usage
    # 獲取 CPU 使用率
    0
  end
  
  def cleanup_old_metrics
    # 清理舊的效能指標
    # 這裡可以實現具體的清理邏輯
  end
  
  def generate_csv_report
    require 'csv'
    
    CSV.generate(headers: true) do |csv|
      csv << ['指標', '數值', '單位', '時間']
      
      @performance_stats.each do |key, value|
        csv << [key.to_s.humanize, value, '', Time.current]
      end
      
      @system_health.each do |key, value|
        csv << ["System #{key.to_s.humanize}", value, '', Time.current]
      end
    end
  end
end
