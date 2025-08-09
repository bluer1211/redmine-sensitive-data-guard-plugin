# frozen_string_literal: true

class ReviewController < ApplicationController
  before_action :find_log, only: [:show, :approve, :reject, :update]
  before_action :require_admin_or_reviewer
  before_action :find_project, only: [:index]
  
  def index
    @logs = SensitiveOperationLog.includes(:user, :project, :reviewer)
    
    # 專案篩選
    if @project
      @logs = @logs.by_project(@project.id)
    end
    
    # 篩選條件
    @logs = @logs.where(review_status: params[:review_status]) if params[:review_status].present?
    @logs = @logs.where(risk_level: params[:risk_level]) if params[:risk_level].present?
    @logs = @logs.where(user_id: params[:user_id]) if params[:user_id].present?
    @logs = @logs.where(requires_review: true) if params[:requires_review] == 'true'
    
    # 搜尋
    if params[:keyword].present?
      keyword = "%#{params[:keyword]}%"
      @logs = @logs.where("content_preview LIKE ? OR detected_patterns LIKE ? OR review_comment LIKE ?", keyword, keyword, keyword)
    end
    
    # 排序
    @logs = @logs.order(created_at: :desc)
    
    # 分頁 - 使用簡單的 limit
    @logs = @logs.limit(20)
    
    # 統計資料
    @statistics = SensitiveOperationLog.review_statistics(@project&.id)
    
    respond_to do |format|
      format.html
      format.json { render json: { logs: @logs, statistics: @statistics } }
    end
  end
  
  def show
    respond_to do |format|
      format.html
      format.json { render json: @log }
    end
  end
  
  def approve
    if @log.can_be_reviewed?
      begin
        @log.approve!(User.current, params[:comment], params[:decision])
        
        # 發送通知
        send_review_notification(@log, 'approved')
        
        respond_to do |format|
          format.html { redirect_to review_path(@log), notice: l(:notice_review_approved) }
          format.json { render json: { success: true, message: l(:notice_review_approved) } }
        end
      rescue => e
        Rails.logger.error "審核核准失敗: #{e.message}"
        respond_to do |format|
          format.html { redirect_to review_path(@log), alert: l(:error_review_failed) }
          format.json { render json: { success: false, message: l(:error_review_failed) } }
        end
      end
    else
      respond_to do |format|
        format.html { redirect_to review_path(@log), alert: l(:error_review_not_allowed) }
        format.json { render json: { success: false, message: l(:error_review_not_allowed) } }
      end
    end
  end
  
  def reject
    if @log.can_be_reviewed?
      begin
        @log.reject!(User.current, params[:comment], params[:decision])
        
        # 發送通知
        send_review_notification(@log, 'rejected')
        
        respond_to do |format|
          format.html { redirect_to review_path(@log), notice: l(:notice_review_rejected) }
          format.json { render json: { success: true, message: l(:notice_review_rejected) } }
        end
      rescue => e
        Rails.logger.error "審核拒絕失敗: #{e.message}"
        respond_to do |format|
          format.html { redirect_to review_path(@log), alert: l(:error_review_failed) }
          format.json { render json: { success: false, message: l(:error_review_failed) } }
        end
      end
    else
      respond_to do |format|
        format.html { redirect_to review_path(@log), alert: l(:error_review_not_allowed) }
        format.json { render json: { success: false, message: l(:error_review_not_allowed) } }
      end
    end
  end
  
  def bulk_approve
    log_ids = params[:log_ids]
    if log_ids.present?
      logs = SensitiveOperationLog.where(id: log_ids, review_status: 'pending')
      approved_count = 0
      
      logs.each do |log|
        if log.can_be_reviewed?
          begin
            log.approve!(User.current, params[:comment], params[:decision])
            send_review_notification(log, 'approved')
            approved_count += 1
          rescue => e
            Rails.logger.error "批次審核核准失敗 (ID: #{log.id}): #{e.message}"
          end
        end
      end
      
      respond_to do |format|
        format.html { redirect_to reviews_path, notice: l(:notice_bulk_review_approved, count: approved_count) }
        format.json { render json: { success: true, message: l(:notice_bulk_review_approved, count: approved_count) } }
      end
    else
      respond_to do |format|
        format.html { redirect_to reviews_path, alert: l(:error_no_logs_selected) }
        format.json { render json: { success: false, message: l(:error_no_logs_selected) } }
      end
    end
  end
  
  def bulk_reject
    log_ids = params[:log_ids]
    if log_ids.present?
      logs = SensitiveOperationLog.where(id: log_ids, review_status: 'pending')
      rejected_count = 0
      
      logs.each do |log|
        if log.can_be_reviewed?
          begin
            log.reject!(User.current, params[:comment], params[:decision])
            send_review_notification(log, 'rejected')
            rejected_count += 1
          rescue => e
            Rails.logger.error "批次審核拒絕失敗 (ID: #{log.id}): #{e.message}"
          end
        end
      end
      
      respond_to do |format|
        format.html { redirect_to reviews_path, notice: l(:notice_bulk_review_rejected, count: rejected_count) }
        format.json { render json: { success: true, message: l(:notice_bulk_review_rejected, count: rejected_count) } }
      end
    else
      respond_to do |format|
        format.html { redirect_to reviews_path, alert: l(:error_no_logs_selected) }
        format.json { render json: { success: false, message: l(:error_no_logs_selected) } }
      end
    end
  end
  
  def statistics
    @statistics = SensitiveOperationLog.review_statistics(@project&.id)
    
    respond_to do |format|
      format.html
      format.json { render json: @statistics }
    end
  end

  private
  
  def find_log
    @log = SensitiveOperationLog.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_404
  end
  
  def find_project
    @project = Project.find(params[:project_id]) if params[:project_id].present?
  rescue ActiveRecord::RecordNotFound
    render_404
  end
  
  def require_admin_or_reviewer
    unless User.current.admin? || User.current.allowed_to?(:review_sensitive_data, @project)
      render_403
      return
    end
  end
  
  def send_review_notification(log, action)
    # 發送審核結果通知
    recipients = Setting.plugin_redmine_sensitive_data_guard&.dig('notification_recipients') || []
    
    if recipients.any?
      begin
        # 簡化版本 - 只記錄到日誌
        Rails.logger.info "發送審核通知: #{action} - #{log.id} 給 #{recipients.join(', ')}"
      rescue => e
        Rails.logger.error "發送審核通知失敗: #{e.message}"
      end
    end
  end
end
