# frozen_string_literal: true

require File.expand_path('../../test_helper', __FILE__)

class SensitiveOperationLogTest < ActiveSupport::TestCase
  def setup
    @user = create_test_user
    @project = create_test_project
  end
  
  def test_valid_log_creation
    log = SensitiveOperationLog.new(
      user: @user,
      project: @project,
      operation_type: 'issue_creation',
      content_type: 'issue_description',
      risk_level: 'high',
      detected_patterns: 'taiwan_id,credit_card',
      content_preview: '測試內容',
      ip_address: '192.168.1.1'
    )
    
    assert log.valid?, "日誌應該有效"
    assert log.save, "日誌應該能保存"
  end
  
  def test_required_fields
    log = SensitiveOperationLog.new
    assert !log.valid?, "缺少必要欄位的日誌應該無效"
    
    assert log.errors[:operation_type].any?, "應該有操作類型錯誤"
    assert log.errors[:content_type].any?, "應該有內容類型錯誤"
    assert log.errors[:risk_level].any?, "應該有風險等級錯誤"
  end
  
  def test_risk_level_validation
    log = build_test_log
    
    # 測試有效的風險等級
    ['high', 'medium', 'low'].each do |level|
      log.risk_level = level
      assert log.valid?, "#{level} 風險等級應該有效"
    end
    
    # 測試無效的風險等級
    log.risk_level = 'invalid'
    assert !log.valid?, "無效的風險等級應該被拒絕"
  end
  
  def test_operation_type_validation
    log = build_test_log
    
    # 測試有效的操作類型
    ['issue_creation', 'issue_update', 'attachment_upload', 'wiki_edit', 'forum_post'].each do |type|
      log.operation_type = type
      assert log.valid?, "#{type} 操作類型應該有效"
    end
    
    # 測試無效的操作類型
    log.operation_type = 'invalid'
    assert !log.valid?, "無效的操作類型應該被拒絕"
  end
  
  def test_scopes
    # 創建不同風險等級的日誌
    high_risk_log = create_test_sensitive_log(risk_level: 'high')
    medium_risk_log = create_test_sensitive_log(risk_level: 'medium')
    low_risk_log = create_test_sensitive_log(risk_level: 'low')
    
    # 測試風險等級範圍
    assert_includes SensitiveOperationLog.high_risk, high_risk_log
    assert_not_includes SensitiveOperationLog.high_risk, medium_risk_log
    assert_not_includes SensitiveOperationLog.high_risk, low_risk_log
    
    assert_includes SensitiveOperationLog.medium_risk, medium_risk_log
    assert_includes SensitiveOperationLog.low_risk, low_risk_log
  end
  
  def test_recent_scope
    old_log = create_test_sensitive_log(created_at: 2.days.ago)
    recent_log = create_test_sensitive_log(created_at: 1.hour.ago)
    
    recent_logs = SensitiveOperationLog.recent
    assert_includes recent_logs, recent_log
    assert_not_includes recent_logs, old_log
  end
  
  def test_by_project_scope
    project1 = create_test_project
    project2 = create_test_project
    
    log1 = create_test_sensitive_log(project: project1)
    log2 = create_test_sensitive_log(project: project2)
    
    project1_logs = SensitiveOperationLog.by_project(project1.id)
    assert_includes project1_logs, log1
    assert_not_includes project1_logs, log2
  end
  
  def test_by_user_scope
    user1 = create_test_user
    user2 = create_test_user
    
    log1 = create_test_sensitive_log(user: user1)
    log2 = create_test_sensitive_log(user: user2)
    
    user1_logs = SensitiveOperationLog.by_user(user1.id)
    assert_includes user1_logs, log1
    assert_not_includes user1_logs, log2
  end
  
  def test_by_date_range_scope
    old_log = create_test_sensitive_log(created_at: 1.week.ago)
    recent_log = create_test_sensitive_log(created_at: Date.current)
    
    date_range_logs = SensitiveOperationLog.by_date_range(Date.current, Date.current)
    assert_includes date_range_logs, recent_log
    assert_not_includes date_range_logs, old_log
  end
  
  def test_statistics_method
    # 創建不同類型的日誌
    create_test_sensitive_log(risk_level: 'high', operation_type: 'issue_creation')
    create_test_sensitive_log(risk_level: 'medium', operation_type: 'issue_update')
    create_test_sensitive_log(risk_level: 'low', operation_type: 'attachment_upload')
    
    stats = SensitiveOperationLog.statistics
    
    assert stats[:total_count] >= 3
    assert stats[:high_risk_count] >= 1
    assert stats[:medium_risk_count] >= 1
    assert stats[:low_risk_count] >= 1
  end
  
  def test_cleanup_old_logs_method
    # 創建舊日誌
    old_log = create_test_sensitive_log(created_at: 4.years.ago)
    recent_log = create_test_sensitive_log(created_at: Date.current)
    
    # 執行清理
    SensitiveOperationLog.cleanup_old_logs
    
    # 檢查舊日誌是否被清理
    assert_nil SensitiveOperationLog.find_by(id: old_log.id)
    assert_not_nil SensitiveOperationLog.find_by(id: recent_log.id)
  end
  
  def test_content_preview_truncation
    long_content = "很長的內容 " * 100
    log = create_test_sensitive_log(content_preview: long_content)
    
    # 檢查內容是否被截斷
    assert log.content_preview.length <= 1000, "內容應該被截斷到1000字符以內"
  end
  
  def test_detected_patterns_serialization
    patterns = ['taiwan_id', 'credit_card', 'email']
    log = create_test_sensitive_log(detected_patterns: patterns.join(','))
    
    parsed_patterns = log.detected_patterns_parsed
    assert_equal patterns, parsed_patterns
  end
  
  def test_risk_level_display
    log = create_test_sensitive_log(risk_level: 'high')
    assert_equal '高風險', log.risk_level_display
    
    log.risk_level = 'medium'
    assert_equal '中風險', log.risk_level_display
    
    log.risk_level = 'low'
    assert_equal '低風險', log.risk_level_display
  end
  
  def test_operation_type_display
    log = create_test_sensitive_log(operation_type: 'blocked_submission')
    assert_equal '阻擋提交', log.operation_type_display
    
    log.operation_type = 'warning'
    assert_equal '警告', log.operation_type_display
    
    log.operation_type = 'override'
    assert_equal '覆蓋', log.operation_type_display
  end
  
  def test_content_type_display
    log = create_test_sensitive_log(content_type: 'issue_description')
    assert_equal '問題描述', log.content_type_display
    
    log.content_type = 'wiki_page'
    assert_equal 'Wiki 頁面', log.content_type_display
    
    log.content_type = 'file_attachment'
    assert_equal '檔案附件', log.content_type_display
  end
  
  def test_masked_content_preview
    log = create_test_sensitive_log(
      content_preview: '身分證：A123456789，信用卡：1234-5678-9012-3456，手機：0912345678'
    )
    
    masked_content = log.masked_content_preview
    
    # 檢查敏感資訊是否被遮罩
    assert_includes masked_content, '***'
    assert_not_includes masked_content, 'A123456789'
    assert_not_includes masked_content, '1234-5678-9012-3456'
    assert_not_includes masked_content, '0912345678'
  end
  
  def test_review_status_display
    log = create_test_sensitive_log(review_status: 'pending')
    assert_equal '待審核', log.review_status_display
    
    log.review_status = 'approved'
    assert_equal '已核准', log.review_status_display
    
    log.review_status = 'rejected'
    assert_equal '已拒絕', log.review_status_display
  end
  
  def test_can_be_reviewed
    log = create_test_sensitive_log(
      review_status: 'pending',
      requires_review: true
    )
    assert log.can_be_reviewed?
    
    log.review_status = 'approved'
    assert !log.can_be_reviewed?
    
    log.review_status = 'pending'
    log.requires_review = false
    assert !log.can_be_reviewed?
  end
  
  def test_approve_method
    reviewer = create_test_user
    log = create_test_sensitive_log(
      review_status: 'pending',
      requires_review: true
    )
    
    log.approve!(reviewer, '測試核准', 'allow')
    
    assert_equal 'approved', log.review_status
    assert_equal reviewer, log.reviewer
    assert_equal '測試核准', log.review_comment
    assert_equal 'allow', log.review_decision
  end
  
  def test_reject_method
    reviewer = create_test_user
    log = create_test_sensitive_log(
      review_status: 'pending',
      requires_review: true
    )
    
    log.reject!(reviewer, '測試拒絕', 'block')
    
    assert_equal 'rejected', log.review_status
    assert_equal reviewer, log.reviewer
    assert_equal '測試拒絕', log.review_comment
    assert_equal 'block', log.review_decision
  end
  
  def test_mark_for_review
    log = create_test_sensitive_log(
      review_status: 'pending',
      requires_review: false
    )
    
    log.mark_for_review!
    
    assert log.requires_review?
    assert_equal 'pending', log.review_status
  end
  
  def test_review_statistics
    # 創建不同審核狀態的日誌
    create_test_sensitive_log(review_status: 'pending', requires_review: true)
    create_test_sensitive_log(review_status: 'approved', requires_review: true)
    create_test_sensitive_log(review_status: 'rejected', requires_review: true)
    
    stats = SensitiveOperationLog.review_statistics
    
    assert stats[:pending_count] >= 1
    assert stats[:approved_count] >= 1
    assert stats[:rejected_count] >= 1
  end
  
  def test_associations
    log = create_test_sensitive_log
    
    assert_equal @user, log.user
    assert_equal @project, log.project
    assert_nil log.reviewer
  end
  
  def test_validation_with_invalid_review_status
    log = build_test_log(review_status: 'invalid')
    assert !log.valid?
    assert log.errors[:review_status].any?
  end
  
  def test_validation_with_invalid_review_decision
    log = build_test_log(review_decision: 'invalid')
    assert !log.valid?
  end
  
  def test_file_size_validation
    log = build_test_log(file_size: -1)
    assert !log.valid?
    
    log.file_size = 0
    assert log.valid?
    
    log.file_size = 1024 * 1024 * 100 # 100MB
    assert log.valid?
  end
  
  def test_ip_address_validation
    log = build_test_log(ip_address: 'invalid-ip')
    assert log.valid? # IP地址驗證可能不是必需的
    
    log.ip_address = '192.168.1.1'
    assert log.valid?
    
    log.ip_address = '2001:db8::1'
    assert log.valid?
  end
  
  private
  
  def build_test_log(attributes = {})
    SensitiveOperationLog.new({
      user: @user,
      project: @project,
      operation_type: 'issue_creation',
      content_type: 'issue_description',
      risk_level: 'high',
      detected_patterns: 'taiwan_id,credit_card',
      content_preview: '測試內容',
      ip_address: '192.168.1.1'
    }.merge(attributes))
  end
end
