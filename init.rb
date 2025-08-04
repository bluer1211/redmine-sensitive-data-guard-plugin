require 'redmine'

Redmine::Plugin.register :redmine_sensitive_data_guard do
  name 'Redmine Sensitive Data Guard Plugin'
  author 'Jason Liu (bluer1211)'
  description 'Sensitive data detection and audit logging plugin for Redmine'
  version '1.0.1'
  url 'https://github.com/bluer1211/redmine-sensitive-data-guard-plugin'
  author_url 'https://github.com/bluer1211'
  
  # 版本相容性
  requires_redmine version_or_higher: '3.4.0'
  
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
    
    # 偵測設定
    'detection_sensitivity' => 'medium',
    'enable_realtime_validation' => true,
    'enable_file_scanning' => true
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
  end
  
  # 選單項目
  menu :admin_menu, :sensitive_data_guard, { :controller => 'sensitive_logs', :action => 'index' }, 
       :caption => :label_sensitive_data_guard, :html => { :class => 'icon icon-security' }
  
  # 專案選單
  menu :project_menu, :sensitive_logs, { :controller => 'sensitive_logs', :action => 'index' }, 
       :caption => :label_sensitive_logs, :param => :project_id, :html => { :class => 'icon icon-security' }
end

# 在插件載入後初始化
Rails.configuration.to_prepare do
  # 載入插件組件
  require File.expand_path('../lib/sensitive_data_detector', __FILE__)
  require File.expand_path('../lib/office_document_parser', __FILE__)
  require File.expand_path('../lib/notification_service', __FILE__)
  require File.expand_path('../lib/log_retention_manager', __FILE__)
  require File.expand_path('../lib/hooks', __FILE__)
  
  # 載入模型
  require File.expand_path('../app/models/sensitive_operation_log', __FILE__)
  require File.expand_path('../app/models/detection_rule', __FILE__)
  
  # 載入控制器
  require File.expand_path('../app/controllers/sensitive_logs_controller', __FILE__)
  require File.expand_path('../app/controllers/detection_rules_controller', __FILE__)
  require File.expand_path('../app/controllers/sensitive_operations_controller', __FILE__)
  
  # 初始化鉤子
  SensitiveDataGuard::Hooks.after_plugins_loaded
end 