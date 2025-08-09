# frozen_string_literal: true

class SensitiveOperationLog < ActiveRecord::Base
  belongs_to :user
  belongs_to :project, optional: true
  belongs_to :reviewer, class_name: 'User', optional: true
  
  validates :operation_type, presence: true
  validates :content_type, presence: true
  validates :risk_level, inclusion: { in: %w[high medium low] }
  validates :review_status, inclusion: { in: %w[pending approved rejected] }
  
  scope :high_risk, -> { where(risk_level: 'high') }
  scope :medium_risk, -> { where(risk_level: 'medium') }
  scope :low_risk, -> { where(risk_level: 'low') }
  scope :blocked, -> { where(operation_type: 'blocked_submission') }
  scope :warnings, -> { where(operation_type: 'warning') }
  scope :overrides, -> { where(operation_type: 'override') }
  
  # Review scopes
  scope :pending_review, -> { where(review_status: 'pending') }
  scope :approved, -> { where(review_status: 'approved') }
  scope :rejected, -> { where(review_status: 'rejected') }
  scope :requires_review, -> { where(requires_review: true) }
  scope :reviewed_by, ->(reviewer_id) { where(reviewer_id: reviewer_id) }
  
  scope :recent, -> { order(created_at: :desc) }
  scope :by_project, ->(project_id) { where(project_id: project_id) }
  scope :by_user, ->(user_id) { where(user_id: user_id) }
  scope :by_date_range, ->(start_date, end_date) { where(created_at: start_date..end_date) }
  
  def self.cleanup_old_logs
    settings = Setting.plugin_redmine_sensitive_data_guard || {}
    
    begin
      # 高風險記錄保留7年
      high_risk_days = settings['retention_days_high_risk'] || 2555
      high_risk_deleted = high_risk.where('created_at < ?', high_risk_days.days.ago).delete_all
      
      # 一般記錄保留3年
      standard_days = settings['retention_days_standard'] || 1095
      standard_deleted = where(risk_level: ['medium', 'low'])
        .where('created_at < ?', standard_days.days.ago)
        .delete_all
      
      # 覆蓋記錄保留5年
      override_days = settings['retention_days_override'] || 1825
      override_deleted = overrides.where('created_at < ?', override_days.days.ago).delete_all
      
      # 返回清理的記錄數量
      high_risk_deleted + standard_deleted + override_deleted
    rescue => e
      Rails.logger.error "清理舊日誌失敗: #{e.message}"
      0
    end
  end
  
  def self.statistics(project_id = nil, date_range = nil)
    begin
      scope = all
      scope = scope.by_project(project_id) if project_id
      scope = scope.by_date_range(date_range.begin, date_range.end) if date_range
      
      {
        total_count: scope.count,
        high_risk_count: scope.high_risk.count,
        medium_risk_count: scope.medium_risk.count,
        low_risk_count: scope.low_risk.count,
        blocked_count: scope.blocked.count,
        warning_count: scope.warnings.count,
        override_count: scope.overrides.count
      }
    rescue => e
      Rails.logger.error "統計資料計算失敗: #{e.message}"
      {
        total_count: 0,
        high_risk_count: 0,
        medium_risk_count: 0,
        low_risk_count: 0,
        blocked_count: 0,
        warning_count: 0,
        override_count: 0
      }
    end
  end
  
  def self.review_statistics(project_id = nil)
    begin
      scope = all
      scope = scope.by_project(project_id) if project_id
      
      {
        total_pending: scope.pending_review.count,
        total_approved: scope.approved.count,
        total_rejected: scope.rejected.count,
        requires_review: scope.requires_review.count
      }
    rescue => e
      Rails.logger.error "審核統計資料計算失敗: #{e.message}"
      {
        total_pending: 0,
        total_approved: 0,
        total_rejected: 0,
        requires_review: 0
      }
    end
  end
  
  def detected_patterns_parsed
    return [] if detected_patterns.blank?
    
    begin
      JSON.parse(detected_patterns)
    rescue JSON::ParserError => e
      Rails.logger.error "JSON 解析失敗: #{e.message}"
      # 如果不是 JSON 格式，嘗試分割逗號
      detected_patterns.split(',').map(&:strip)
    rescue => e
      Rails.logger.error "解析偵測模式失敗: #{e.message}"
      []
    end
  end

  def risk_level_display
    case risk_level
    when 'high'
      '高風險'
    when 'medium'
      '中風險'
    when 'low'
      '低風險'
    else
      risk_level.to_s.humanize
    end
  end

  def operation_type_display
    case operation_type
    when 'detection'
      '偵測'
    when 'blocked_submission'
      '已封鎖'
    when 'warning'
      '警告'
    when 'override'
      '覆寫'
    else
      operation_type.to_s.humanize
    end
  end

  def content_type_display
    case content_type
    when 'issue'
      '問題描述'
    when 'wiki'
      'Wiki 頁面'
    when 'message'
      '訊息'
    when 'attachment'
      '附件'
    else
      content_type.to_s.humanize
    end
  end

  def masked_content_preview
    return content_preview if content_preview.blank?

    begin
      masked = content_preview.dup
      
      # 遮蔽敏感資料
      detected_patterns_parsed.each do |pattern|
        case pattern
        when /taiwan_id/i
          masked.gsub!(/\b[A-Z][12]\d{8}\b/, '***-****-****')
        when /credit_card/i
          masked.gsub!(/\b\d{4}[-\s]?\d{4}[-\s]?\d{4}[-\s]?\d{4}\b/, '****-****-****-****')
        when /phone/i
          masked.gsub!(/\b09\d{2}[-\s]?\d{3}[-\s]?\d{3}\b/, '09**-***-***')
        when /email/i
          masked.gsub!(/\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b/) { |match| "#{match[0..2]}***@#{match.split('@').last}" }
        end
      end
      
      masked
    rescue => e
      Rails.logger.error "遮蔽內容預覽失敗: #{e.message}"
      content_preview
    end
  end

  def review_status_display
    case review_status
    when 'pending'
      '待審核'
    when 'approved'
      '已核准'
    when 'rejected'
      '已拒絕'
    else
      review_status.to_s.humanize
    end
  end

  def review_decision_display
    case review_decision
    when 'allow'
      '允許'
    when 'block'
      '封鎖'
    when 'warn'
      '警告'
    else
      review_decision.to_s.humanize if review_decision
    end
  end

  def can_be_reviewed?
    review_status == 'pending' && requires_review
  end

  def reviewed?
    review_status != 'pending'
  end

  def approve!(reviewer, comment = nil, decision = 'allow')
    update!(
      review_status: 'approved',
      reviewer: reviewer,
      reviewed_at: Time.current,
      review_comment: comment,
      review_decision: decision
    )
  rescue => e
    Rails.logger.error "核准記錄失敗: #{e.message}"
    raise e
  end

  def reject!(reviewer, comment = nil, decision = 'block')
    update!(
      review_status: 'rejected',
      reviewer: reviewer,
      reviewed_at: Time.current,
      review_comment: comment,
      review_decision: decision
    )
  rescue => e
    Rails.logger.error "拒絕記錄失敗: #{e.message}"
    raise e
  end

  def mark_for_review!
    update!(requires_review: true, review_status: 'pending')
  end
end 