# frozen_string_literal: true

require File.expand_path('../../test_helper', __FILE__)

class SensitiveLogsControllerTest < ActionController::TestCase
  # 在生產環境中不使用 fixtures
  if ENV['RAILS_ENV'] != 'production'
    fixtures :users, :projects, :sensitive_operation_logs
  end
  
  def setup
    if ENV['RAILS_ENV'] == 'production'
      # 在生產環境中使用動態創建的測試數據
      @user = create_test_user(admin: true)
      @project = create_test_project
    else
      # 在測試環境中使用 fixtures
      @user = User.find(1)
      @project = Project.find(1)
      # 確保用戶是管理員
      @user.update!(admin: true) unless @user.admin?
    end
    
    @request.session[:user_id] = @user.id
  end
  
  # ==================== INDEX 動作測試 ====================
  
  def test_index_with_all_filters
    # 創建測試數據
    log1 = create_test_sensitive_log(
      user: @user,
      project: @project,
      risk_level: 'high',
      operation_type: 'blocked_submission',
      content_type: 'issue_description',
      file_type: 'txt',
      ip_address: '192.168.1.1',
      content_preview: '測試關鍵字內容',
      file_size: 500 * 1024,
      created_at: Date.current
    )
    
    get :index, params: {
      project_id: @project.id,
      user_id: @user.id,
      risk_level: 'high',
      operation_type: 'blocked_submission',
      content_type: 'issue_description',
      file_type: 'txt',
      ip_address: '192.168.1.1',
      keyword: '測試關鍵字',
      file_size_min: '100',
      file_size_max: '1000',
      start_date: Date.current.to_s,
      end_date: Date.current.to_s
    }
    
    assert_response :success
    assert_template 'index'
    assert_not_nil assigns(:logs)
    assert_not_nil assigns(:statistics)
    assert_includes assigns(:logs), log1
  end
  
  def test_index_without_filters
    get :index, params: { project_id: @project.id }
    assert_response :success
    assert_template 'index'
    assert_not_nil assigns(:logs)
    assert_not_nil assigns(:statistics)
  end
  
  def test_index_with_quick_filters
    # 測試今日篩選
    get :index, params: {
      project_id: @project.id,
      start_date: Date.current.to_s,
      end_date: Date.current.to_s
    }
    assert_response :success
    
    # 測試高風險篩選
    get :index, params: {
      project_id: @project.id,
      risk_level: 'high'
    }
    assert_response :success
    
    # 測試阻擋篩選
    get :index, params: {
      project_id: @project.id,
      operation_type: 'blocked_submission'
    }
    assert_response :success
  end
  
  def test_index_with_keyword_search
    log = create_test_sensitive_log(
      content_preview: '包含測試關鍵字的內容',
      project: @project
    )
    
    get :index, params: {
      project_id: @project.id,
      keyword: '測試關鍵字'
    }
    
    assert_response :success
    assert_includes assigns(:logs), log
  end
  
  def test_index_with_date_range
    log = create_test_sensitive_log(
      created_at: Date.current,
      project: @project
    )
    
    get :index, params: {
      project_id: @project.id,
      start_date: Date.current.to_s,
      end_date: Date.current.to_s
    }
    
    assert_response :success
    assert_includes assigns(:logs), log
  end
  
  def test_index_with_risk_level_filter
    high_risk_log = create_test_sensitive_log(
      risk_level: 'high',
      project: @project
    )
    low_risk_log = create_test_sensitive_log(
      risk_level: 'low',
      project: @project
    )
    
    get :index, params: {
      project_id: @project.id,
      risk_level: 'high'
    }
    
    assert_response :success
    assert_includes assigns(:logs), high_risk_log
    assert_not_includes assigns(:logs), low_risk_log
  end
  
  def test_index_with_operation_type_filter
    blocked_log = create_test_sensitive_log(
      operation_type: 'blocked_submission',
      project: @project
    )
    warning_log = create_test_sensitive_log(
      operation_type: 'warning',
      project: @project
    )
    
    get :index, params: {
      project_id: @project.id,
      operation_type: 'blocked_submission'
    }
    
    assert_response :success
    assert_includes assigns(:logs), blocked_log
    assert_not_includes assigns(:logs), warning_log
  end
  
  def test_index_with_file_size_filters
    large_file_log = create_test_sensitive_log(
      file_size: 2000 * 1024, # 2MB
      project: @project
    )
    small_file_log = create_test_sensitive_log(
      file_size: 500 * 1024, # 500KB
      project: @project
    )
    
    get :index, params: {
      project_id: @project.id,
      file_size_min: '1000', # 1MB
      file_size_max: '3000'  # 3MB
    }
    
    assert_response :success
    assert_includes assigns(:logs), large_file_log
    assert_not_includes assigns(:logs), small_file_log
  end
  
  def test_index_with_ip_address_filter
    log = create_test_sensitive_log(
      ip_address: '192.168.1.100',
      project: @project
    )
    
    get :index, params: {
      project_id: @project.id,
      ip_address: '192.168.1'
    }
    
    assert_response :success
    assert_includes assigns(:logs), log
  end
  
  def test_index_csv_export
    create_test_sensitive_log(project: @project)
    
    get :index, params: { 
      project_id: @project.id,
      format: 'csv'
    }
    
    assert_response :success
    assert_equal 'text/csv', response.content_type
    assert_match /sensitive_logs_#{Date.current}.csv/, response.headers['Content-Disposition']
    
    # 檢查 CSV 內容
    csv_lines = response.body.split("\n")
    assert csv_lines.length > 1, "CSV 應該包含標題行和數據行"
    assert_match /ID|User|Project|Operation Type|Content Type|Risk Level|IP Address|Created On/, csv_lines.first
  end
  
  def test_index_with_pagination
    # 創建多個測試日誌
    25.times { create_test_sensitive_log(project: @project) }
    
    get :index, params: { 
      project_id: @project.id,
      page: 2
    }
    
    assert_response :success
    assert_not_nil assigns(:logs)
    assert assigns(:logs).length <= 100, "應該限制在100條記錄內"
  end
  
  # ==================== SHOW 動作測試 ====================
  
  def test_show_action
    log = create_test_sensitive_log(project: @project)
    
    get :show, params: { 
      id: log.id, 
      project_id: @project.id 
    }
    
    assert_response :success
    assert_template 'show'
    assert_equal log, assigns(:log)
  end
  
  def test_show_action_with_json_format
    log = create_test_sensitive_log(project: @project)
    
    get :show, params: { 
      id: log.id, 
      project_id: @project.id,
      format: 'json'
    }
    
    assert_response :success
    assert_equal 'application/json', response.content_type
    
    json_response = JSON.parse(response.body)
    assert_equal log.id, json_response['id']
    assert_equal log.risk_level, json_response['risk_level']
  end
  
  def test_show_action_with_invalid_id
    get :show, params: { 
      id: 99999, 
      project_id: @project.id 
    }
    
    assert_response :not_found
  end
  
  # ==================== DESTROY 動作測試 ====================
  
  def test_destroy_action
    log = create_test_sensitive_log(project: @project)
    
    assert_difference 'SensitiveOperationLog.count', -1 do
      delete :destroy, params: { 
        id: log.id, 
        project_id: @project.id 
      }
    end
    
    assert_redirected_to sensitive_logs_path(project_id: @project.id)
    assert_not_nil flash[:notice]
  end
  
  def test_destroy_action_with_invalid_id
    delete :destroy, params: { 
      id: 99999, 
      project_id: @project.id 
    }
    
    assert_response :not_found
  end
  
  # ==================== CLEANUP 動作測試 ====================
  
  def test_cleanup_action
    # 創建一些舊日誌
    old_log = create_test_sensitive_log(
      created_at: 5.years.ago,
      project: @project
    )
    
    post :cleanup, params: { project_id: @project.id }
    
    assert_redirected_to sensitive_logs_path(project_id: @project.id)
    assert_not_nil flash[:notice]
  end
  
  # ==================== RISK_LEVELS 動作測試 ====================
  
  def test_risk_levels_action
    get :risk_levels, params: { project_id: @project.id }
    
    assert_response :success
    assert_template 'risk_levels'
  end
  
  # ==================== 權限測試 ====================
  
  def test_index_requires_admin
    @user.update!(admin: false)
    
    get :index, params: { project_id: @project.id }
    
    assert_response :forbidden
  end
  
  def test_show_requires_admin
    @user.update!(admin: false)
    log = create_test_sensitive_log(project: @project)
    
    get :show, params: { 
      id: log.id, 
      project_id: @project.id 
    }
    
    assert_response :forbidden
  end
  
  def test_destroy_requires_admin
    @user.update!(admin: false)
    log = create_test_sensitive_log(project: @project)
    
    delete :destroy, params: { 
      id: log.id, 
      project_id: @project.id 
    }
    
    assert_response :forbidden
  end
  
  # ==================== 錯誤處理測試 ====================
  
  def test_index_with_invalid_project_id
    get :index, params: { project_id: 99999 }
    
    assert_response :not_found
  end
  
  def test_index_with_invalid_date_format
    get :index, params: { 
      project_id: @project.id,
      start_date: 'invalid-date',
      end_date: 'invalid-date'
    }
    
    assert_response :success # 應該優雅地處理無效日期
  end
  
  def test_index_with_sql_injection_attempt
    get :index, params: { 
      project_id: @project.id,
      keyword: "'; DROP TABLE users; --"
    }
    
    assert_response :success
    # 確保沒有 SQL 錯誤發生
  end
  
  # ==================== 統計資料測試 ====================
  
  def test_statistics_data
    # 創建不同類型的日誌
    create_test_sensitive_log(risk_level: 'high', project: @project)
    create_test_sensitive_log(risk_level: 'medium', project: @project)
    create_test_sensitive_log(risk_level: 'low', project: @project)
    
    get :index, params: { project_id: @project.id }
    
    assert_response :success
    assert_not_nil assigns(:statistics)
    
    stats = assigns(:statistics)
    assert stats[:total_count] >= 3
    assert stats[:high_risk_count] >= 1
    assert stats[:medium_risk_count] >= 1
    assert stats[:low_risk_count] >= 1
  end
  
  # ==================== 輔助方法 ====================
  
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
      file_size: 1024 * 1024 # 1MB
    }.merge(attributes))
  end
end
