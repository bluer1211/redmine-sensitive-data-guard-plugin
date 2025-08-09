# frozen_string_literal: true

Rails.application.routes.draw do
  # 敏感操作日誌管理
  resources :sensitive_logs, only: [:index, :show, :destroy] do
    collection do
      post :cleanup
      get :risk_levels
    end
  end

  # 偵測規則管理
  resources :detection_rules, only: [:index, :show, :create, :update, :destroy] do
    collection do
      post :toggle
      post :import
      post :export
    end
  end

  # 敏感操作管理
  resources :sensitive_operations, only: [:index, :show, :destroy] do
    collection do
      post :bulk_delete
      post :export
      get :statistics
    end
  end

  # 敏感資料防護設定管理
  resources :sensitive_data_guard_settings, only: [] do
    collection do
      post :test_email
    end
  end

  # 審核管理 - 修正控制器名稱
  resources :reviews, controller: 'review', only: [:index, :show] do
    collection do
      post :bulk_approve
      post :bulk_reject
      get :statistics
    end

    member do
      post :approve
      post :reject
    end
  end

  # 效能監控管理 - 修正路由配置
  match 'performance_monitor', to: 'performance_monitor#index', via: :get, as: :performance_monitor
  match 'performance_monitor/realtime', to: 'performance_monitor#realtime', via: :get, as: :performance_monitor_realtime
  match 'performance_monitor/system_health', to: 'performance_monitor#system_health', via: :get, as: :performance_monitor_system_health
  match 'performance_monitor/export_report', to: 'performance_monitor#export_report', via: :get, as: :performance_monitor_export_report
  match 'performance_monitor/cleanup_metrics', to: 'performance_monitor#cleanup_metrics', via: :post, as: :performance_monitor_cleanup_metrics
end
