# frozen_string_literal: true

class SensitiveLogsController < ApplicationController
  before_action :find_project, only: [:index]
  before_action :find_log, only: [:show, :destroy]
  before_action :authorize_global

  def index
    @logs = SensitiveOperationLog.includes(:user, :project)
    
    # 專案篩選
    if @project
      @logs = @logs.by_project(@project.id)
    end
    
    # 風險等級篩選
    if params[:risk_level].present?
      @logs = @logs.where(risk_level: params[:risk_level])
    end
    
    # 操作類型篩選
    if params[:operation_type].present?
      @logs = @logs.where(operation_type: params[:operation_type])
    end
    
    # 日期範圍篩選
    if params[:start_date].present? && params[:end_date].present?
      begin
        start_date = Date.parse(params[:start_date])
        end_date = Date.parse(params[:end_date])
        @logs = @logs.where(created_at: start_date.beginning_of_day..end_date.end_of_day)
      rescue Date::Error
        flash[:error] = l(:error_invalid_date_format)
      end
    elsif params[:start_date].present?
      begin
        start_date = Date.parse(params[:start_date])
        @logs = @logs.where("DATE(created_at) >= ?", start_date)
      rescue Date::Error
        flash[:error] = l(:error_invalid_date_format)
      end
    elsif params[:end_date].present?
      begin
        end_date = Date.parse(params[:end_date])
        @logs = @logs.where("DATE(created_at) <= ?", end_date)
      rescue Date::Error
        flash[:error] = l(:error_invalid_date_format)
      end
    end
    
    # 排序
    @logs = @logs.recent
    
    # 分頁 - 使用簡單的 limit
    @logs = @logs.limit(100)
    
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
      begin
        count = SensitiveOperationLog.cleanup_old_logs
        flash[:notice] = l(:notice_cleanup_completed, count: count)
      rescue => e
        flash[:error] = l(:error_cleanup_failed, error: e.message)
      end
    end
    
    redirect_to sensitive_logs_path
  end
  
  def risk_levels
    # 風險等級清單頁面
    respond_to do |format|
      format.html
    end
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
        l(:field_id),
        l(:field_user),
        l(:field_project),
        l(:field_operation_type),
        l(:field_content_type),
        l(:field_risk_level),
        l(:field_ip_address),
        l(:field_created_on)
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