# frozen_string_literal: true

require 'redmine'

Redmine::Plugin.register :redmine_sensitive_data_guard do
  name 'Redmine Sensitive Data Guard Plugin'
  author 'Jason Liu (bluer1211)'
  description 'Sensitive data detection and audit logging plugin for Redmine'
  version '2.0.0'
  url 'https://github.com/bluer1211/redmine-sensitive-data-guard-plugin'
  author_url 'https://github.com/bluer1211'
  
  # 版本相容性 - 支援 Redmine 6.0.6
  requires_redmine version_or_higher: '6.0.0'
  
  # 設定設定頁面
  settings default: {
    # 基本設定
    'enabled' => true,
    'scan_office_documents' => true,
    'max_file_size_mb' => 50,
    
    # 通知設定
    'email_notifications' => true,
    'slack_webhook_url' => '',
    'notification_recipients' => [],
    'notification_frequency' => 'immediate',
    
    # 日誌保留設定
    'retention_days_high_risk' => 2555,  # 7年
    'retention_days_standard' => 1095,   # 3年
    'retention_days_override' => 1825,   # 5年
    'auto_cleanup_enabled' => true,
    'backup_required' => true,
    
    # 效能設定
    'async_processing' => true,
    'batch_size' => 100,
    'redis_cache_enabled' => false,
    'scan_timeout' => 30,
    
    # 偵測設定
    'detection_sensitivity' => 'medium',
    'enable_realtime_validation' => true,
    'enable_file_scanning' => true,
    
    # 風險等級設定
    'enable_high_risk_detection' => true,
    'enable_medium_risk_detection' => true,
    'enable_low_risk_detection' => true,
    
    # 處理策略設定
    'high_risk_strategy' => 'block',
    'medium_risk_strategy' => 'warn',
    'low_risk_strategy' => 'log',
    
    # 個別項目設定
    'enable_credential_combination_detection' => true,
    'enable_taiwan_id_detection' => true,
    'enable_credit_card_detection' => true,
    'enable_password_keyword_detection' => true,
    'enable_database_connection_detection' => true,
    'enable_taiwan_mobile_detection' => true,
    'enable_internal_ip_detection' => true,
    'enable_email_detection' => true,
    
    # 國際化設定
    'default_language' => 'zh-TW',
    'supported_languages' => ['zh-TW', 'en', 'ja'],
    
    # 監控設定
    'enable_performance_monitoring' => true,
    'monitoring_retention_days' => 30,
    'auto_cleanup_metrics' => true
  }, partial: 'settings/sensitive_data_guard_settings'
  
  # 權限定義
  project_module :sensitive_data_guard do
    permission :view_sensitive_logs, {
      :sensitive_logs => [:index, :show]
    }
    permission :manage_sensitive_rules, {
      :detection_rules => [:index, :new, :create, :edit, :update, :destroy]
    }
    permission :override_sensitive_detection, {
      :sensitive_operations => [:override]
    }
    permission :review_sensitive_data, {
      :reviews => [:index, :show, :approve, :reject, :bulk_approve, :bulk_reject, :statistics]
    }
    permission :view_performance_monitor, {
      :performance_monitor => [:index, :realtime, :system_health, :export_report]
    }
    permission :manage_performance_monitor, {
      :performance_monitor => [:cleanup_metrics]
    }
  end
  
  # 選單項目
  # 隱藏敏感資料防護選單 - 不在管理頁面顯示
  # menu :admin_menu, :sensitive_data_guard, { :controller => 'sensitive_logs', :action => 'index' }, 
  #      :caption => :label_sensitive_data_guard, :html => { :class => 'icon icon-security' }
  
  # 隱藏通知設定選單 - 不在管理頁面顯示
  # menu :admin_menu, :notification_settings, { :controller => 'notification_settings', :action => 'index' }, 
  #      :caption => :label_notification_settings, :html => { :class => 'icon icon-email' }
  
  # 專案選單 - 保留在專案頁面中
  menu :project_menu, :sensitive_logs, { :controller => 'sensitive_logs', :action => 'index' }, 
       :caption => :label_sensitive_logs, :param => :project_id, :html => { :class => 'icon icon-security' }
  
  # 審核選單 - 在專案頁面中
  menu :project_menu, :reviews, { :controller => 'reviews', :action => 'index' }, 
       :caption => :label_reviews, :param => :project_id, :html => { :class => 'icon icon-checked' }
  
  # 效能監控選單 - 在管理頁面中
  menu :admin_menu, :performance_monitor, { :controller => 'performance_monitor', :action => 'index' }, 
       :caption => :label_performance_monitoring, :html => { :class => 'icon icon-stats' }
end

# 在插件載入後初始化
Rails.configuration.to_prepare do
  # 載入錯誤類別
  require File.expand_path('../lib/security_error', __FILE__)
  
  # 載入簡化偵測引擎
  require File.expand_path('../lib/simple_sensitive_data_detector', __FILE__)
  
  # 載入檔案掃描相關類別
  require File.expand_path('../lib/file_scanner', __FILE__)
  require File.expand_path('../lib/attachment_scanner', __FILE__)
  
  # 載入安全檔案處理器
  require File.expand_path('../lib/secure_file_handler', __FILE__)
  
  # 載入非同步處理服務
  require File.expand_path('../lib/async_processing_service', __FILE__)
  
  # 載入效能監控服務
  require File.expand_path('../lib/performance_monitor', __FILE__)
  
  # 載入 Hooks
  require File.expand_path('../lib/sensitive_data_guard_hooks', __FILE__)
  
  # 載入模型
  require File.expand_path('../app/models/sensitive_operation_log', __FILE__)
end 