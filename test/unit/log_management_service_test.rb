# frozen_string_literal: true

require File.expand_path('../../test_helper', __FILE__)

class LogManagementServiceTest < ActiveSupport::TestCase
  def setup
    @user = create_test_user
    @project = create_test_project
  end
  
  # ==================== 清理舊日誌測試 ====================
  
  def test_cleanup_old_logs
    # 創建一些舊日誌
    old_log = create_test_sensitive_log(
      user: @user,
      project: @project,
      created_at: 4.years.ago
    )
    
    recent_log = create_test_sensitive_log(
      user: @user,
      project: @project,
      created_at: 1.month.ago
    )
    
    result = LogManagementService.cleanup_old_logs
    
    assert_not_nil result, "清理結果不應該為空"
    assert result.key?('operation_logs_deleted'), "結果應該包含操作日誌刪除數量"
    assert result.key?('notification_logs_deleted'), "結果應該包含通知日誌刪除數量"
    assert result.key?('errors'), "結果應該包含錯誤列表"
    
    # 檢查舊日誌是否被刪除
    assert_nil SensitiveOperationLog.find_by(id: old_log.id), "舊日誌應該被刪除"
    assert_not_nil SensitiveOperationLog.find_by(id: recent_log.id), "新日誌應該保留"
  end
  
  def test_cleanup_old_logs_with_no_old_logs
    # 確保沒有舊日誌
    SensitiveOperationLog.where('created_at < ?', 3.years.ago).delete_all
    
    result = LogManagementService.cleanup_old_logs
    
    assert_not_nil result, "清理結果不應該為空"
    assert_equal 0, result['operation_logs_deleted'], "沒有舊日誌時應該刪除0條"
    assert_equal 0, result['notification_logs_deleted'], "沒有舊通知日誌時應該刪除0條"
  end
  
  def test_cleanup_old_logs_with_errors
    # 模擬清理過程中的錯誤
    SensitiveOperationLog.stubs(:where).raises(StandardError.new("清理錯誤"))
    
    result = LogManagementService.cleanup_old_logs
    
    assert_not_nil result, "清理結果不應該為空"
    assert result['errors'].any?, "應該包含錯誤信息"
  end
  
  # ==================== 生成保留報告測試 ====================
  
  def test_generate_retention_report
    # 創建一些測試日誌
    create_test_sensitive_log(user: @user, project: @project)
    create_test_sensitive_log(user: @user, project: @project)
    
    report = LogManagementService.generate_retention_report
    
    assert_not_nil report, "保留報告不應該為空"
    assert report.key?('generated_at'), "報告應該包含生成時間"
    assert report.key?('operation_logs'), "報告應該包含操作日誌信息"
    assert report.key?('notification_logs'), "報告應該包含通知日誌信息"
    assert report.key?('retention_policy'), "報告應該包含保留策略"
    assert report.key?('recommendations'), "報告應該包含建議"
  end
  
  def test_generate_retention_report_with_empty_data
    # 清空所有日誌
    SensitiveOperationLog.delete_all
    
    report = LogManagementService.generate_retention_report
    
    assert_not_nil report, "保留報告不應該為空"
    assert report.key?('generated_at'), "報告應該包含生成時間"
    assert report['operation_logs']['total_count'] == 0, "操作日誌數量應該為0"
  end
  
  def test_generate_retention_report_structure
    report = LogManagementService.generate_retention_report
    
    # 檢查操作日誌報告結構
    if report['operation_logs']
      assert report['operation_logs'].key?('total_count'), "操作日誌應該包含總數量"
      assert report['operation_logs'].key?('retention_days'), "操作日誌應該包含保留天數"
      assert report['operation_logs'].key?('to_cleanup'), "操作日誌應該包含待清理數量"
    end
    
    # 檢查通知日誌報告結構
    if report['notification_logs']
      assert report['notification_logs'].key?('total_count'), "通知日誌應該包含總數量"
      assert report['notification_logs'].key?('retention_days'), "通知日誌應該包含保留天數"
      assert report['notification_logs'].key?('to_cleanup'), "通知日誌應該包含待清理數量"
    end
  end
  
  # ==================== 導出歸檔日誌測試 ====================
  
  def test_export_logs_for_archival
    # 創建一些測試日誌
    log1 = create_test_sensitive_log(user: @user, project: @project)
    log2 = create_test_sensitive_log(user: @user, project: @project)
    
    export_data = LogManagementService.export_logs_for_archival
    
    assert_not_nil export_data, "導出資料不應該為空"
    assert export_data.key?('operation_logs'), "導出資料應該包含操作日誌"
    assert export_data.key?('notification_logs'), "導出資料應該包含通知日誌"
    assert export_data.key?('export_metadata'), "導出資料應該包含元資料"
    
    # 檢查元資料
    metadata = export_data['export_metadata']
    assert metadata.key?('exported_at'), "元資料應該包含導出時間"
    assert metadata.key?('total_operation_logs'), "元資料應該包含總操作日誌數量"
    assert metadata.key?('total_notification_logs'), "元資料應該包含總通知日誌數量"
  end
  
  def test_export_logs_for_archival_with_empty_data
    # 清空所有日誌
    SensitiveOperationLog.delete_all
    
    export_data = LogManagementService.export_logs_for_archival
    
    assert_not_nil export_data, "導出資料不應該為空"
    assert export_data['export_metadata']['total_operation_logs'] == 0, "總操作日誌數量應該為0"
  end
  
  def test_export_logs_for_archival_structure
    export_data = LogManagementService.export_logs_for_archival
    
    # 檢查操作日誌結構
    if export_data['operation_logs']
      assert export_data['operation_logs'].is_a?(Array), "操作日誌應該是陣列"
    end
    
    # 檢查通知日誌結構
    if export_data['notification_logs']
      assert export_data['notification_logs'].is_a?(Array), "通知日誌應該是陣列"
    end
  end
  
  # ==================== 清理操作日誌測試 ====================
  
  def test_cleanup_operation_logs
    # 創建一些舊操作日誌
    old_log = create_test_sensitive_log(
      user: @user,
      project: @project,
      created_at: 4.years.ago
    )
    
    recent_log = create_test_sensitive_log(
      user: @user,
      project: @project,
      created_at: 1.month.ago
    )
    
    deleted_count = LogManagementService.cleanup_operation_logs
    
    assert deleted_count >= 0, "刪除數量應該是非負數"
    assert_nil SensitiveOperationLog.find_by(id: old_log.id), "舊操作日誌應該被刪除"
    assert_not_nil SensitiveOperationLog.find_by(id: recent_log.id), "新操作日誌應該保留"
  end
  
  def test_cleanup_operation_logs_with_no_old_logs
    # 確保沒有舊操作日誌
    SensitiveOperationLog.where('created_at < ?', 3.years.ago).delete_all
    
    deleted_count = LogManagementService.cleanup_operation_logs
    
    assert_equal 0, deleted_count, "沒有舊操作日誌時應該刪除0條"
  end
  
  # ==================== 清理通知日誌測試 ====================
  
  def test_cleanup_notification_logs
    # 創建一些舊通知日誌（如果存在 NotificationLog 模型）
    if defined?(NotificationLog)
      old_notification = NotificationLog.create!(
        user: @user,
        project: @project,
        message: '舊通知',
        created_at: 4.years.ago
      )
      
      recent_notification = NotificationLog.create!(
        user: @user,
        project: @project,
        message: '新通知',
        created_at: 1.month.ago
      )
      
      deleted_count = LogManagementService.cleanup_notification_logs
      
      assert deleted_count >= 0, "刪除數量應該是非負數"
      assert_nil NotificationLog.find_by(id: old_notification.id), "舊通知日誌應該被刪除"
      assert_not_nil NotificationLog.find_by(id: recent_notification.id), "新通知日誌應該保留"
    else
      # 如果沒有 NotificationLog 模型，測試方法是否正常執行
      deleted_count = LogManagementService.cleanup_notification_logs
      assert_equal 0, deleted_count, "沒有通知日誌模型時應該返回0"
    end
  end
  
  def test_cleanup_notification_logs_with_no_old_logs
    # 確保沒有舊通知日誌
    if defined?(NotificationLog)
      NotificationLog.where('created_at < ?', 3.years.ago).delete_all
    end
    
    deleted_count = LogManagementService.cleanup_notification_logs
    
    assert_equal 0, deleted_count, "沒有舊通知日誌時應該刪除0條"
  end
  
  # ==================== 保留策略測試 ====================
  
  def test_get_retention_policy
    policy = LogManagementService.get_retention_policy
    
    assert_not_nil policy, "保留策略不應該為空"
    assert policy.key?('operation_logs_retention_days'), "策略應該包含操作日誌保留天數"
    assert policy.key?('notification_logs_retention_days'), "策略應該包含通知日誌保留天數"
    assert policy.key?('auto_cleanup_enabled'), "策略應該包含自動清理啟用狀態"
  end
  
  def test_get_retention_policy_structure
    policy = LogManagementService.get_retention_policy
    
    # 檢查保留天數是否為正整數
    if policy['operation_logs_retention_days']
      assert policy['operation_logs_retention_days'].is_a?(Integer), "操作日誌保留天數應該是整數"
      assert policy['operation_logs_retention_days'] > 0, "操作日誌保留天數應該大於0"
    end
    
    if policy['notification_logs_retention_days']
      assert policy['notification_logs_retention_days'].is_a?(Integer), "通知日誌保留天數應該是整數"
      assert policy['notification_logs_retention_days'] > 0, "通知日誌保留天數應該大於0"
    end
  end
  
  # ==================== 建議生成測試 ====================
  
  def test_generate_recommendations
    recommendations = LogManagementService.generate_recommendations
    
    assert_not_nil recommendations, "建議不應該為空"
    assert recommendations.is_a?(Array), "建議應該是陣列"
  end
  
  def test_generate_recommendations_with_high_log_count
    # 創建大量日誌以觸發建議
    1000.times do
      create_test_sensitive_log(user: @user, project: @project)
    end
    
    recommendations = LogManagementService.generate_recommendations
    
    assert_not_nil recommendations, "建議不應該為空"
    assert recommendations.is_a?(Array), "建議應該是陣列"
  end
  
  # ==================== 錯誤處理測試 ====================
  
  def test_cleanup_old_logs_with_database_error
    # 模擬資料庫錯誤
    SensitiveOperationLog.stubs(:where).raises(ActiveRecord::StatementInvalid.new("資料庫錯誤"))
    
    result = LogManagementService.cleanup_old_logs
    
    assert_not_nil result, "清理結果不應該為空"
    assert result['errors'].any?, "應該包含錯誤信息"
  end
  
  def test_generate_retention_report_with_error
    # 模擬報告生成錯誤
    SensitiveOperationLog.stubs(:count).raises(StandardError.new("報告生成錯誤"))
    
    report = LogManagementService.generate_retention_report
    
    assert_not_nil report, "保留報告不應該為空"
    # 應該處理錯誤而不拋出異常
  end
  
  def test_export_logs_for_archival_with_error
    # 模擬導出錯誤
    SensitiveOperationLog.stubs(:all).raises(StandardError.new("導出錯誤"))
    
    export_data = LogManagementService.export_logs_for_archival
    
    assert_not_nil export_data, "導出資料不應該為空"
    # 應該處理錯誤而不拋出異常
  end
  
  # ==================== 效能測試 ====================
  
  def test_cleanup_performance
    # 創建大量舊日誌進行效能測試
    1000.times do
      create_test_sensitive_log(
        user: @user,
        project: @project,
        created_at: 4.years.ago
      )
    end
    
    start_time = Time.current
    result = LogManagementService.cleanup_old_logs
    end_time = Time.current
    
    processing_time = end_time - start_time
    
    assert processing_time < 30, "清理應該在30秒內完成"
    assert_not_nil result, "清理結果不應該為空"
  end
  
  def test_report_generation_performance
    # 創建大量日誌進行報告生成效能測試
    1000.times do
      create_test_sensitive_log(user: @user, project: @project)
    end
    
    start_time = Time.current
    report = LogManagementService.generate_retention_report
    end_time = Time.current
    
    processing_time = end_time - start_time
    
    assert processing_time < 10, "報告生成應該在10秒內完成"
    assert_not_nil report, "保留報告不應該為空"
  end
  
  # ==================== 邊界情況測試 ====================
  
  def test_cleanup_old_logs_with_extreme_dates
    # 測試極端日期情況
    very_old_log = create_test_sensitive_log(
      user: @user,
      project: @project,
      created_at: 100.years.ago
    )
    
    future_log = create_test_sensitive_log(
      user: @user,
      project: @project,
      created_at: 1.year.from_now
    )
    
    result = LogManagementService.cleanup_old_logs
    
    assert_not_nil result, "清理結果不應該為空"
    assert_nil SensitiveOperationLog.find_by(id: very_old_log.id), "極舊日誌應該被刪除"
    assert_not_nil SensitiveOperationLog.find_by(id: future_log.id), "未來日誌應該保留"
  end
  
  def test_generate_retention_report_with_mixed_data
    # 測試混合資料的報告生成
    create_test_sensitive_log(user: @user, project: @project, created_at: 1.day.ago)
    create_test_sensitive_log(user: @user, project: @project, created_at: 1.month.ago)
    create_test_sensitive_log(user: @user, project: @project, created_at: 1.year.ago)
    
    report = LogManagementService.generate_retention_report
    
    assert_not_nil report, "保留報告不應該為空"
    assert report.key?('operation_logs'), "報告應該包含操作日誌信息"
  end
  
  private
  
  def create_test_sensitive_log(attributes = {})
    SensitiveOperationLog.create!({
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
