# frozen_string_literal: true

require File.expand_path('../../test_helper', __FILE__)

class SensitiveDataGuardIntegrationTest < ActionDispatch::IntegrationTest
  fixtures :users, :projects, :sensitive_operation_logs
  
  def setup
    @user = User.find(1)
    @project = Project.find(1)
    @user.update!(admin: true) unless @user.admin?
    
    # 登入用戶
    post '/login', params: {
      username: @user.login,
      password: 'password123'
    }
  end
  
  # ==================== 完整流程測試 ====================
  
  def test_complete_sensitive_data_detection_flow
    # 1. 創建包含敏感資料的內容
    sensitive_content = "用戶資料：身分證 A123456789，手機 0912345678，信用卡 1234-5678-9012-3456"
    
    # 2. 模擬提交包含敏感資料的問題
    assert_difference 'SensitiveOperationLog.count' do
      post "/projects/#{@project.identifier}/issues", params: {
        issue: {
          subject: '測試問題',
          description: sensitive_content,
          tracker_id: 1,
          status_id: 1
        }
      }
    end
    
    # 3. 檢查是否創建了敏感操作日誌
    log = SensitiveOperationLog.last
    assert_not_nil log
    assert_equal 'high', log.risk_level
    assert_includes log.detected_patterns, 'taiwan_id'
    assert_includes log.detected_patterns, 'taiwan_mobile'
    assert_includes log.detected_patterns, 'credit_card'
    
    # 4. 訪問敏感日誌列表
    get "/sensitive_logs?project_id=#{@project.id}"
    assert_response :success
    assert_includes response.body, '測試問題'
    
    # 5. 查看詳細日誌
    get "/sensitive_logs/#{log.id}?project_id=#{@project.id}"
    assert_response :success
    assert_includes response.body, log.content_preview
  end
  
  def test_sensitive_data_filtering_and_search
    # 創建不同類型的敏感日誌
    high_risk_log = create_test_sensitive_log(
      risk_level: 'high',
      content_preview: '高風險內容：A123456789',
      operation_type: 'blocked_submission'
    )
    
    medium_risk_log = create_test_sensitive_log(
      risk_level: 'medium',
      content_preview: '中風險內容：0912345678',
      operation_type: 'warning'
    )
    
    low_risk_log = create_test_sensitive_log(
      risk_level: 'low',
      content_preview: '低風險內容',
      operation_type: 'detection'
    )
    
    # 測試高風險篩選
    get "/sensitive_logs?project_id=#{@project.id}&risk_level=high"
    assert_response :success
    assert_includes response.body, high_risk_log.content_preview
    assert_not_includes response.body, medium_risk_log.content_preview
    assert_not_includes response.body, low_risk_log.content_preview
    
    # 測試關鍵字搜尋
    get "/sensitive_logs?project_id=#{@project.id}&keyword=高風險"
    assert_response :success
    assert_includes response.body, high_risk_log.content_preview
    assert_not_includes response.body, medium_risk_log.content_preview
    
    # 測試操作類型篩選
    get "/sensitive_logs?project_id=#{@project.id}&operation_type=blocked_submission"
    assert_response :success
    assert_includes response.body, high_risk_log.content_preview
    assert_not_includes response.body, medium_risk_log.content_preview
  end
  
  def test_csv_export_functionality
    # 創建測試日誌
    create_test_sensitive_log(content_preview: '測試內容')
    
    # 測試 CSV 導出
    get "/sensitive_logs?project_id=#{@project.id}&format=csv"
    assert_response :success
    assert_equal 'text/csv', response.content_type
    
    # 檢查 CSV 內容
    csv_lines = response.body.split("\n")
    assert csv_lines.length > 1, "CSV 應該包含標題行和數據行"
    
    # 檢查標題行
    headers = csv_lines.first
    assert_includes headers, 'ID'
    assert_includes headers, 'User'
    assert_includes headers, 'Project'
    assert_includes headers, 'Operation Type'
    assert_includes headers, 'Content Type'
    assert_includes headers, 'Risk Level'
    
    # 檢查數據行
    data_line = csv_lines[1]
    assert_includes data_line, '測試內容'
  end
  
  def test_cleanup_functionality
    # 創建舊日誌
    old_log = create_test_sensitive_log(
      created_at: 5.years.ago,
      risk_level: 'low'
    )
    
    # 創建新日誌
    new_log = create_test_sensitive_log(
      created_at: Date.current,
      risk_level: 'high'
    )
    
    # 執行清理
    post "/sensitive_logs/cleanup?project_id=#{@project.id}"
    assert_redirected_to "/sensitive_logs?project_id=#{@project.id}"
    
    # 檢查舊日誌是否被清理
    assert_nil SensitiveOperationLog.find_by(id: old_log.id)
    assert_not_nil SensitiveOperationLog.find_by(id: new_log.id)
  end
  
  def test_risk_levels_page
    get "/sensitive_logs/risk_levels?project_id=#{@project.id}"
    assert_response :success
    assert_includes response.body, '風險等級'
  end
  
  def test_log_detail_page
    log = create_test_sensitive_log(
      content_preview: '詳細測試內容',
      detected_patterns: 'taiwan_id,credit_card'
    )
    
    get "/sensitive_logs/#{log.id}?project_id=#{@project.id}"
    assert_response :success
    assert_includes response.body, '詳細測試內容'
    assert_includes response.body, 'taiwan_id'
    assert_includes response.body, 'credit_card'
  end
  
  def test_log_deletion
    log = create_test_sensitive_log
    
    # 測試刪除日誌
    assert_difference 'SensitiveOperationLog.count', -1 do
      delete "/sensitive_logs/#{log.id}?project_id=#{@project.id}"
    end
    
    assert_redirected_to "/sensitive_logs?project_id=#{@project.id}"
  end
  
  def test_unauthorized_access
    # 登出用戶
    delete '/logout'
    
    # 嘗試訪問敏感日誌頁面
    get "/sensitive_logs?project_id=#{@project.id}"
    assert_redirected_to '/login'
  end
  
  def test_non_admin_access
    # 創建非管理員用戶
    non_admin = User.create!(
      login: 'nonadmin',
      firstname: 'Non',
      lastname: 'Admin',
      mail: 'nonadmin@example.com',
      password: 'password123',
      password_confirmation: 'password123',
      status: User::STATUS_ACTIVE,
      admin: false
    )
    
    # 登入非管理員用戶
    post '/login', params: {
      username: 'nonadmin',
      password: 'password123'
    }
    
    # 嘗試訪問敏感日誌頁面
    get "/sensitive_logs?project_id=#{@project.id}"
    assert_response :forbidden
  end
  
  def test_sensitive_data_detection_in_different_content_types
    # 測試問題描述中的敏感資料
    assert_difference 'SensitiveOperationLog.count' do
      post "/projects/#{@project.identifier}/issues", params: {
        issue: {
          subject: '包含敏感資料的問題',
          description: '身分證：A123456789',
          tracker_id: 1,
          status_id: 1
        }
      }
    end
    
    # 測試問題備註中的敏感資料
    issue = Issue.last
    assert_difference 'SensitiveOperationLog.count' do
      post "/issues/#{issue.id}/notes", params: {
        notes: '備註中的敏感資料：0912345678'
      }
    end
    
    # 檢查日誌
    logs = SensitiveOperationLog.last(2)
    assert_equal 2, logs.length
    assert_includes logs.first.detected_patterns, 'taiwan_id'
    assert_includes logs.last.detected_patterns, 'taiwan_mobile'
  end
  
  def test_file_upload_with_sensitive_data
    # 模擬檔案上傳包含敏感資料
    file_content = "檔案內容：A123456789 0912345678"
    uploaded_file = Rack::Test::UploadedFile.new(
      StringIO.new(file_content),
      'text/plain',
      'test.txt'
    )
    
    assert_difference 'SensitiveOperationLog.count' do
      post "/projects/#{@project.identifier}/issues", params: {
        issue: {
          subject: '檔案上傳測試',
          description: '測試檔案上傳',
          tracker_id: 1,
          status_id: 1,
          attachments: [uploaded_file]
        }
      }
    end
    
    log = SensitiveOperationLog.last
    assert_equal 'file_attachment', log.content_type
    assert_includes log.detected_patterns, 'taiwan_id'
    assert_includes log.detected_patterns, 'taiwan_mobile'
  end
  
  def test_statistics_display
    # 創建不同類型的日誌
    create_test_sensitive_log(risk_level: 'high')
    create_test_sensitive_log(risk_level: 'medium')
    create_test_sensitive_log(risk_level: 'low')
    
    get "/sensitive_logs?project_id=#{@project.id}"
    assert_response :success
    
    # 檢查統計資料顯示
    assert_includes response.body, '總計'
    assert_includes response.body, '高風險'
    assert_includes response.body, '中風險'
    assert_includes response.body, '低風險'
  end
  
  def test_pagination_and_limits
    # 創建超過限制的日誌
    150.times { create_test_sensitive_log }
    
    get "/sensitive_logs?project_id=#{@project.id}"
    assert_response :success
    
    # 檢查是否限制在100條記錄
    logs_count = assigns(:logs).length
    assert logs_count <= 100, "應該限制在100條記錄內，實際有 #{logs_count} 條"
  end
  
  private
  
  def create_test_sensitive_log(attributes = {})
    SensitiveOperationLog.create!({
      user_id: @user.id,
      project_id: @project.id,
      operation_type: 'issue_creation',
      content_type: 'issue_description',
      risk_level: 'high',
      detected_patterns: 'taiwan_id,credit_card',
      content_preview: '測試內容',
      ip_address: '192.168.1.1',
      file_type: 'txt',
      file_size: 1024 * 1024
    }.merge(attributes))
  end
end
