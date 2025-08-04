# frozen_string_literal: true

class SensitiveOperationLog < ActiveRecord::Base
  belongs_to :user
  belongs_to :project, optional: true
  
  validates :operation_type, presence: true
  validates :content_type, presence: true
  validates :risk_level, inclusion: { in: %w[high medium low] }
  
  scope :high_risk, -> { where(risk_level: 'high') }
  scope :medium_risk, -> { where(risk_level: 'medium') }
  scope :low_risk, -> { where(risk_level: 'low') }
  scope :blocked, -> { where(operation_type: 'blocked_submission') }
  scope :warnings, -> { where(operation_type: 'warning') }
  scope :overrides, -> { where(operation_type: 'override') }
  
  scope :recent, -> { order(created_at: :desc) }
  scope :by_project, ->(project_id) { where(project_id: project_id) }
  scope :by_user, ->(user_id) { where(user_id: user_id) }
  scope :by_date_range, ->(start_date, end_date) { where(created_at: start_date..end_date) }
  
  # 分頁設定
  self.per_page = 20
  
  def self.create_table_sql
    <<~SQL
      CREATE TABLE IF NOT EXISTS sensitive_operation_logs (
        id INT PRIMARY KEY AUTO_INCREMENT,
        user_id INT NOT NULL,
        project_id INT NULL,
        operation_type VARCHAR(50) NOT NULL,
        content_type VARCHAR(50) NOT NULL,
        detected_patterns TEXT,
        content_preview TEXT,
        override_reason TEXT,
        file_type VARCHAR(20),
        file_size INT,
        ip_address VARCHAR(45),
        user_agent TEXT,
        risk_level ENUM('high', 'medium', 'low') DEFAULT 'medium',
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        INDEX idx_user_id (user_id),
        INDEX idx_project_id (project_id),
        INDEX idx_operation_type (operation_type),
        INDEX idx_risk_level (risk_level),
        INDEX idx_created_at (created_at),
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
        FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE
      );
    SQL
  end
  
  def self.cleanup_old_logs
    settings = Setting.plugin_redmine_sensitive_data_guard || {}
    
    # 高風險記錄保留7年
    high_risk_days = settings['retention_days_high_risk'] || 2555
    high_risk.where('created_at < ?', high_risk_days.days.ago).delete_all
    
    # 一般記錄保留3年
    standard_days = settings['retention_days_standard'] || 1095
    where(risk_level: ['medium', 'low'])
      .where('created_at < ?', standard_days.days.ago)
      .delete_all
    
    # 覆蓋記錄保留5年
    override_days = settings['retention_days_override'] || 1825
    overrides.where('created_at < ?', override_days.days.ago).delete_all
  end
  
  def self.statistics(project_id = nil, date_range = nil)
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
  end
  
  def detected_patterns_parsed
    return [] if detected_patterns.blank?
    
    JSON.parse(detected_patterns)
  rescue JSON::ParserError
    []
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
      '未知'
    end
  end
  
  def operation_type_display
    case operation_type
    when 'blocked_submission'
      '阻擋提交'
    when 'warning'
      '警告'
    when 'override'
      '覆蓋提交'
    else
      operation_type
    end
  end
  
  def content_type_display
    case content_type
    when 'issue'
      '問題'
    when 'wiki'
      'Wiki頁面'
    when 'project'
      '專案'
    when 'attachment'
      '附件'
    else
      content_type
    end
  end
  
  def masked_content_preview
    return content_preview if content_preview.blank?
    
    # 進一步遮蔽敏感內容
    masked = content_preview.dup
    
    # 遮蔽身分證號
    masked.gsub!(/([A-Z][12]\d{6})\d{2}/, '\1**')
    
    # 遮蔽信用卡號
    masked.gsub!(/(\d{4}[-\\s]?\d{4}[-\\s]?\d{4})[-\\s]?\d{4}/, '\1-****')
    
    # 遮蔽手機號碼
    masked.gsub!(/(09\d{2}-?\d{3})-?\d{3}/, '\1-***')
    
    masked
  end
end 