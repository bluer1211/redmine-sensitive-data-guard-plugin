# frozen_string_literal: true

require File.expand_path('../../test_helper', __FILE__)

class ReviewControllerTest < ActionController::TestCase
  fixtures :users, :projects, :sensitive_operation_logs
  
  def setup
    @user = User.find(1)
    @project = Project.find(1)
    @request.session[:user_id] = @user.id
    
    # 確保用戶是管理員
    @user.update!(admin: true) unless @user.admin?
  end
  
  # ==================== INDEX 動作測試 ====================
  
  def test_index_with_filters
    # 創建測試數據
    pending_log = create_test_sensitive_log(
      user: @user,
      project: @project,
      review_status: 'pending',
      requires_review: true,
      risk_level: 'high'
    )
    
    approved_log = create_test_sensitive_log(
      user: @user,
      project: @project,
      review_status: 'approved',
      requires_review: true,
      risk_level: 'medium'
    )
    
    get :index, params: {
      project_id: @project.id,
      review_status: 'pending',
      risk_level: 'high',
      requires_review: 'true'
    }
    
    assert_response :success
    assert_template 'index'
    assert_not_nil assigns(:logs)
    assert_not_nil assigns(:statistics)
    assert_includes assigns(:logs), pending_log
    assert_not_includes assigns(:logs), approved_log
  end
  
  def test_index_without_filters
    get :index, params: { project_id: @project.id }
    assert_response :success
    assert_template 'index'
    assert_not_nil assigns(:logs)
    assert_not_nil assigns(:statistics)
  end
  
  def test_index_with_keyword_search
    log = create_test_sensitive_log(
      content_preview: '包含測試關鍵字的內容',
      project: @project,
      requires_review: true
    )
    
    get :index, params: {
      project_id: @project.id,
      keyword: '測試關鍵字'
    }
    
    assert_response :success
    assert_includes assigns(:logs), log
  end
  
  def test_index_with_pagination
    # 創建多個測試日誌
    25.times do
      create_test_sensitive_log(
        project: @project,
        requires_review: true
      )
    end
    
    get :index, params: {
      project_id: @project.id,
      page: 2
    }
    
    assert_response :success
    assert_not_nil assigns(:logs)
    assert assigns(:logs).length <= 20, "分頁應該限制在20條記錄"
  end
  
  # ==================== SHOW 動作測試 ====================
  
  def test_show_action
    log = create_test_sensitive_log(
      project: @project,
      requires_review: true
    )
    
    get :show, params: {
      id: log.id,
      project_id: @project.id
    }
    
    assert_response :success
    assert_template 'show'
    assert_equal log, assigns(:log)
  end
  
  def test_show_action_with_json_format
    log = create_test_sensitive_log(
      project: @project,
      requires_review: true
    )
    
    get :show, params: {
      id: log.id,
      project_id: @project.id
    }, format: :json
    
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
  
  # ==================== APPROVE 動作測試 ====================
  
  def test_approve_action
    log = create_test_sensitive_log(
      project: @project,
      review_status: 'pending',
      requires_review: true
    )
    
    assert_difference 'SensitiveOperationLog.where(review_status: "approved").count' do
      post :approve, params: {
        id: log.id,
        project_id: @project.id,
        review_comment: '核准此操作',
        review_decision: 'allow'
      }
    end
    
    assert_redirected_to reviews_path(project_id: @project.id)
    assert_not_nil flash[:notice]
    
    log.reload
    assert_equal 'approved', log.review_status
    assert_equal @user, log.reviewer
    assert_equal '核准此操作', log.review_comment
    assert_equal 'allow', log.review_decision
  end
  
  def test_approve_action_with_invalid_id
    post :approve, params: {
      id: 99999,
      project_id: @project.id
    }
    
    assert_response :not_found
  end
  
  def test_approve_action_without_permission
    @user.update!(admin: false)
    
    log = create_test_sensitive_log(
      project: @project,
      review_status: 'pending',
      requires_review: true
    )
    
    post :approve, params: {
      id: log.id,
      project_id: @project.id
    }
    
    assert_response :forbidden
  end
  
  # ==================== REJECT 動作測試 ====================
  
  def test_reject_action
    log = create_test_sensitive_log(
      project: @project,
      review_status: 'pending',
      requires_review: true
    )
    
    assert_difference 'SensitiveOperationLog.where(review_status: "rejected").count' do
      post :reject, params: {
        id: log.id,
        project_id: @project.id,
        review_comment: '拒絕此操作',
        review_decision: 'block'
      }
    end
    
    assert_redirected_to reviews_path(project_id: @project.id)
    assert_not_nil flash[:notice]
    
    log.reload
    assert_equal 'rejected', log.review_status
    assert_equal @user, log.reviewer
    assert_equal '拒絕此操作', log.review_comment
    assert_equal 'block', log.review_decision
  end
  
  def test_reject_action_with_invalid_id
    post :reject, params: {
      id: 99999,
      project_id: @project.id
    }
    
    assert_response :not_found
  end
  
  # ==================== BULK APPROVE 動作測試 ====================
  
  def test_bulk_approve_action
    logs = []
    3.times do
      logs << create_test_sensitive_log(
        project: @project,
        review_status: 'pending',
        requires_review: true
      )
    end
    
    assert_difference 'SensitiveOperationLog.where(review_status: "approved").count', 3 do
      post :bulk_approve, params: {
        project_id: @project.id,
        log_ids: logs.map(&:id),
        review_comment: '批次核准'
      }
    end
    
    assert_redirected_to reviews_path(project_id: @project.id)
    assert_not_nil flash[:notice]
    
    logs.each(&:reload)
    logs.each do |log|
      assert_equal 'approved', log.review_status
      assert_equal @user, log.reviewer
    end
  end
  
  def test_bulk_approve_action_with_no_logs
    post :bulk_approve, params: {
      project_id: @project.id,
      log_ids: []
    }
    
    assert_redirected_to reviews_path(project_id: @project.id)
    assert_not_nil flash[:error]
  end
  
  # ==================== BULK REJECT 動作測試 ====================
  
  def test_bulk_reject_action
    logs = []
    3.times do
      logs << create_test_sensitive_log(
        project: @project,
        review_status: 'pending',
        requires_review: true
      )
    end
    
    assert_difference 'SensitiveOperationLog.where(review_status: "rejected").count', 3 do
      post :bulk_reject, params: {
        project_id: @project.id,
        log_ids: logs.map(&:id),
        review_comment: '批次拒絕'
      }
    end
    
    assert_redirected_to reviews_path(project_id: @project.id)
    assert_not_nil flash[:notice]
    
    logs.each(&:reload)
    logs.each do |log|
      assert_equal 'rejected', log.review_status
      assert_equal @user, log.reviewer
    end
  end
  
  # ==================== STATISTICS 動作測試 ====================
  
  def test_statistics_action
    # 創建不同審核狀態的日誌
    create_test_sensitive_log(
      project: @project,
      review_status: 'pending',
      requires_review: true
    )
    
    create_test_sensitive_log(
      project: @project,
      review_status: 'approved',
      requires_review: true
    )
    
    create_test_sensitive_log(
      project: @project,
      review_status: 'rejected',
      requires_review: true
    )
    
    get :statistics, params: { project_id: @project.id }
    
    assert_response :success
    assert_not_nil assigns(:statistics)
    
    stats = assigns(:statistics)
    assert stats.key?('total_pending')
    assert stats.key?('total_approved')
    assert stats.key?('total_rejected')
    assert stats.key?('requires_review')
    assert stats.key?('review_rate')
  end
  
  def test_statistics_action_with_json_format
    get :statistics, params: {
      project_id: @project.id
    }, format: :json
    
    assert_response :success
    assert_equal 'application/json', response.content_type
    
    json_response = JSON.parse(response.body)
    assert json_response.key?('total_pending')
    assert json_response.key?('total_approved')
    assert json_response.key?('total_rejected')
  end
  
  # ==================== 權限控制測試 ====================
  
  def test_unauthorized_access
    @user.update!(admin: false)
    
    get :index, params: { project_id: @project.id }
    assert_response :forbidden
  end
  
  def test_show_requires_admin_or_reviewer
    @user.update!(admin: false)
    
    log = create_test_sensitive_log(
      project: @project,
      requires_review: true
    )
    
    get :show, params: {
      id: log.id,
      project_id: @project.id
    }
    
    assert_response :forbidden
  end
  
  def test_approve_requires_admin_or_reviewer
    @user.update!(admin: false)
    
    log = create_test_sensitive_log(
      project: @project,
      review_status: 'pending',
      requires_review: true
    )
    
    post :approve, params: {
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
  
  def test_show_with_invalid_project_id
    log = create_test_sensitive_log(project: @project)
    
    get :show, params: {
      id: log.id,
      project_id: 99999
    }
    
    assert_response :not_found
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
      ip_address: '192.168.1.1',
      review_status: 'pending',
      requires_review: true
    }.merge(attributes))
  end
end
