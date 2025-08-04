# frozen_string_literal: true

class SensitiveLogsController < ApplicationController
  before_action :require_admin, only: [:index, :show, :destroy]
  before_action :find_project, only: [:index]
  before_action :find_log, only: [:show, :destroy]
  
  def index
    @logs = SensitiveOperationLog.includes(:user, :project)
    
    # 篩選條件
    @logs = @logs.by_project(@project.id) if @project
    @logs = @logs.by_user(params[:user_id]) if params[:user_id].present?
    @logs = @logs.where(risk_level: params[:risk_level]) if params[:risk_level].present?
    @logs = @logs.where(operation_type: params[:operation_type]) if params[:operation_type].present?
    
    # 日期範圍篩選
    if params[:start_date].present? && params[:end_date].present?
      start_date = Date.parse(params[:start_date])
      end_date = Date.parse(params[:end_date])
      @logs = @logs.by_date_range(start_date, end_date)
    end
    
    # 排序
    @logs = @logs.recent
    
    # 分頁
    @logs = @logs.paginate(page: params[:page], per_page: 20)
    
    # 統計資料
    @statistics = SensitiveOperationLog.statistics(@project&.id)
    
    respond_to do |format|
      format.html
      format.csv { send_data generate_csv, filename: "sensitive_logs_#{Date.current}.csv" }
    end
  end
  
  def show
    respond_to do |format|
      format.html
      format.json { render json: @log }
    end
  end
  
  def destroy
    if @log.destroy
      flash[:notice] = l(:notice_successful_delete)
    else
      flash[:error] = l(:error_failed_to_delete)
    end
    
    redirect_to sensitive_logs_path
  end
  
  def cleanup
    if request.post?
      count = SensitiveOperationLog.cleanup_old_logs
      flash[:notice] = "已清理 #{count} 筆過期日誌"
    end
    
    redirect_to sensitive_logs_path
  end
  
  private
  
  def find_project
    @project = Project.find(params[:project_id]) if params[:project_id].present?
  rescue ActiveRecord::RecordNotFound
    render_404
  end
  
  def find_log
    @log = SensitiveOperationLog.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_404
  end
  
  def generate_csv
    require 'csv'
    
    CSV.generate(headers: true) do |csv|
      csv << [
        'ID',
        '使用者',
        '專案',
        '操作類型',
        '內容類型',
        '風險等級',
        'IP位址',
        '建立時間'
      ]
      
      @logs.each do |log|
        csv << [
          log.id,
          log.user&.name,
          log.project&.name,
          log.operation_type_display,
          log.content_type_display,
          log.risk_level_display,
          log.ip_address,
          log.created_at
        ]
      end
    end
  end
end 