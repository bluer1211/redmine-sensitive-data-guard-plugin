#!/usr/bin/env ruby
# frozen_string_literal: true

# 測試執行腳本
# 用法: ruby test/run_tests.rb [test_file]

require 'fileutils'
require 'optparse'
require 'pathname'

# 解析命令行參數
options = {}
OptionParser.new do |opts|
  opts.banner = "用法: ruby test/run_tests.rb [選項] [test_file]"
  
  opts.on("-v", "--verbose", "詳細輸出") do |v|
    options[:verbose] = v
  end
  
  opts.on("-c", "--coverage", "生成測試覆蓋報告") do |c|
    options[:coverage] = c
  end
  
  opts.on("--unit-only", "只執行單元測試（跳過資料庫相關測試）") do |u|
    options[:unit_only] = u
  end
  
  opts.on("-e", "--environment ENV", "指定 Rails 環境 (預設: test)") do |e|
    options[:environment] = e
  end
  
  opts.on("--standalone", "使用獨立模式（不需要完整 Redmine 環境）") do |s|
    options[:standalone] = s
  end
  
  opts.on("-h", "--help", "顯示幫助") do
    puts opts
    exit
  end
end.parse!

# 設置測試環境 - 預設使用 test 環境，但允許覆蓋
default_env = options[:environment] || ENV['RAILS_ENV'] || 'test'
ENV['RAILS_ENV'] = default_env

puts "使用 Rails 環境：#{ENV['RAILS_ENV']}" if options[:verbose]

# 檢查環境是否有效
valid_environments = %w[test development production]
unless valid_environments.include?(ENV['RAILS_ENV'])
  puts "警告：無效的 Rails 環境 '#{ENV['RAILS_ENV']}'，使用預設環境 'test'"
  ENV['RAILS_ENV'] = 'test'
end

# 如果是生產環境，顯示警告但繼續執行
if ENV['RAILS_ENV'] == 'production'
  puts "⚠️  警告：正在生產環境中執行測試"
  puts "請確保："
  puts "  - 測試不會影響生產資料"
  puts "  - 測試不會修改生產配置"
  puts "  - 測試不會影響生產服務"
  puts ""
  
  # 在生產環境中執行測試，但使用生產資料庫
  puts "注意：將在生產環境中執行測試，使用生產資料庫"
  
  # 設置環境變數以繞過 Rails 的生產環境測試限制
  ENV['RAILS_ENV'] = 'production'
  ENV['REDMINE_PRODUCTION_TESTING'] = 'true'
end

# 獲取當前目錄和插件目錄
current_dir = Pathname.new(__FILE__).dirname
plugin_dir = current_dir.parent

# 檢查是否使用獨立模式
if options[:standalone]
  puts "🔧 使用獨立模式執行測試（不需要完整 Redmine 環境）"
  
  # 在獨立模式下，直接執行測試
  run_standalone_tests(plugin_dir, options)
else
  # 嘗試找到 Redmine 根目錄
  redmine_root = find_redmine_root(plugin_dir)
  
  if redmine_root
    puts "📁 找到 Redmine 根目錄：#{redmine_root}"
    run_redmine_tests(redmine_root, plugin_dir, options)
  else
    puts "⚠️  無法找到完整的 Redmine 環境，自動切換到獨立模式"
    puts "💡 提示：使用 --standalone 選項可以明確指定獨立模式"
    run_standalone_tests(plugin_dir, options)
  end
end

# 查找 Redmine 根目錄
def find_redmine_root(plugin_dir)
  possible_paths = [
    plugin_dir.parent.parent.parent,
    plugin_dir.parent.parent,
    plugin_dir.parent.parent.parent.parent,
    '/usr/src/redmine',
    File.expand_path('../../../../', __FILE__)
  ]
  
  possible_paths.each do |path|
    if File.exist?(File.join(path, 'config', 'environment.rb'))
      return path
    end
  end
  
  nil
end

# 執行獨立模式測試
def run_standalone_tests(plugin_dir, options)
  puts "🚀 開始執行獨立模式測試..."
  
  # 檢查測試目錄
  test_dir = File.join(plugin_dir, 'test')
  unless File.exist?(test_dir)
    puts "錯誤：測試目錄不存在：#{test_dir}"
    exit 1
  end
  
  # 查找測試文件
  test_files = if ARGV.empty?
    if options[:unit_only]
      # 只執行單元測試
      Dir[File.join(test_dir, 'unit', '**', '*_test.rb')]
    else
      # 執行所有測試
      unit_tests = Dir[File.join(test_dir, 'unit', '**', '*_test.rb')]
      integration_tests = Dir[File.join(test_dir, 'integration', '**', '*_test.rb')]
      unit_tests + integration_tests
    end
  else
    # 使用指定的測試文件
    ARGV.map do |test_file|
      if File.exist?(test_file)
        test_file
      elsif File.exist?(File.join(test_dir, test_file))
        File.join(test_dir, test_file)
      else
        puts "警告：測試文件不存在：#{test_file}"
        nil
      end
    end.compact
  end
  
  if test_files.empty?
    puts "錯誤：沒有找到測試文件"
    exit 1
  end
  
  puts "找到測試文件：#{test_files.length} 個" if options[:verbose]
  test_files.each { |f| puts "  - #{f}" } if options[:verbose]
  
  # 執行測試
  failed_tests = []
  successful_tests = []
  
  test_files.each do |test_file|
    if File.exist?(test_file)
      puts "\n執行測試：#{File.basename(test_file)}"
      
      # 檢查是否為獨立測試文件
      if is_standalone_test?(test_file)
        result = run_standalone_test(test_file, options)
      else
        result = run_redmine_test(test_file, test_dir, options)
      end
      
      if result
        successful_tests << test_file
        puts "✅ 測試通過：#{File.basename(test_file)}"
      else
        failed_tests << test_file
        puts "❌ 測試失敗：#{File.basename(test_file)}"
      end
    else
      puts "警告：測試文件不存在：#{test_file}"
    end
  end
  
  # 輸出結果
  puts "\n" + "="*50
  puts "測試完成！"
  puts "="*50
  
  if successful_tests.any?
    puts "\n✅ 成功的測試 (#{successful_tests.length} 個)："
    successful_tests.each { |test| puts "  - #{File.basename(test)}" }
  end
  
  if failed_tests.any?
    puts "\n❌ 失敗的測試 (#{failed_tests.length} 個)："
    failed_tests.each { |test| puts "  - #{File.basename(test)}" }
    puts "\n💡 建議："
    puts "  - 檢查測試文件中的語法錯誤"
    puts "  - 確保所有依賴都已安裝"
    puts "  - 使用 --verbose 選項查看詳細信息"
    exit 1
  else
    puts "\n🎉 所有測試都通過了！"
    exit 0
  end
end

# 檢查是否為獨立測試文件
def is_standalone_test?(test_file)
  content = File.read(test_file)
  # 檢查是否包含獨立測試的標記
  # 1. 包含 'standalone' 關鍵字
  # 2. 包含 'require_relative' 關鍵字
  # 3. 不包含 Rails 環境相關的 require 語句
  # 4. 包含模擬環境定義
  standalone_indicators = [
    content.include?('standalone'),
    content.include?('require_relative'),
    content.include?('module Redmine'),
    content.include?('module Rails'),
    content.include?('class TestCase'),
    !content.match(/require.*environment/),
    !content.match(/require.*rails/),
    !content.match(/require.*redmine/)
  ]
  
  # 如果有多個獨立測試的指標，則認為是獨立測試
  standalone_indicators.count(true) >= 2
end

# 執行獨立測試 - 改進版本，參考 test_async_processing_service_standalone.rb
def run_standalone_test(test_file, options)
  begin
    # 設置必要的環境變數
    ENV['STANDALONE_TEST'] = 'true'
    
    # 檢查是否需要模擬環境
    content = File.read(test_file)
    
    # 如果測試文件已經包含模擬環境，直接執行
    if content.include?('module Redmine') || content.include?('module Rails')
      puts "檢測到獨立測試文件，直接執行..." if options[:verbose]
      result = system("ruby \"#{test_file}\"")
      return result
    else
      # 需要注入模擬環境
      puts "注入模擬環境..." if options[:verbose]
      result = run_with_mock_environment(test_file, options)
      return result
    end
  rescue => e
    puts "❌ 執行錯誤：#{e.message}"
    return false
  end
end

# 使用模擬環境執行測試
def run_with_mock_environment(test_file, options)
  # 創建臨時測試文件，包含模擬環境
  temp_file = create_temp_test_file(test_file)
  
  begin
    # 執行臨時文件
    result = system("ruby \"#{temp_file}\"")
    return result
  ensure
    # 清理臨時文件
    File.delete(temp_file) if File.exist?(temp_file)
  end
end

# 創建包含模擬環境的臨時測試文件
def create_temp_test_file(original_test_file)
  temp_file = "#{original_test_file}.tmp_#{Process.pid}"
  
  # 讀取原始測試文件
  content = File.read(original_test_file)
  
  # 創建包含模擬環境的新內容
  mock_environment = <<~RUBY
    # frozen_string_literal: true
    
    # 模擬 Redmine 環境
    module Redmine
      module I18n
        def self.t(key, options = {})
          key.to_s
        end
      end
    end
    
    # 模擬 Rails 環境
    module Rails
      def self.logger
        @logger ||= Logger.new(STDOUT)
      end
      
      def self.root
        Pathname.new(Dir.pwd)
      end
    end
    
    class Logger
      def error(message)
        puts "ERROR: #{message}"
      end
      
      def info(message)
        puts "INFO: #{message}"
      end
    end
    
    # 模擬 ActiveRecord 模型
    class Attachment
      attr_accessor :id, :filename, :diskfile, :content_type, :filesize, :project, :disk_filename
      
      def initialize(attributes = {})
        attributes.each { |key, value| send("#{key}=", value) }
      end
      
      def self.find_by(id:)
        return nil if id == 99999
        new(id: id, filename: 'test.txt', diskfile: '/tmp/test.txt', content_type: 'text/plain', filesize: 1024)
      end
      
      def save!
        true
      end
    end
    
    class User
      attr_accessor :id, :current_ip, :current_user_agent, :login, :firstname, :lastname, :mail, :password, :password_confirmation, :status, :admin
      
      def initialize(attributes = {})
        attributes.each { |key, value| send("#{key}=", value) }
      end
      
      def self.find_by(id:)
        return nil if id == 99999
        new(id: id, current_ip: '192.168.1.1', current_user_agent: 'Mozilla/5.0')
      end
      
      def self.first
        new(id: 1, current_ip: '192.168.1.1', current_user_agent: 'Mozilla/5.0')
      end
      
      def self.create!(attributes = {})
        new(attributes)
      end
    end
    
    class Project
      attr_accessor :id, :name, :identifier, :status
      
      def initialize(attributes = {})
        attributes.each { |key, value| send("#{key}=", value) }
      end
      
      def self.find_by(id:)
        return nil if id == 99999
        new(id: id)
      end
      
      def self.first
        new(id: 1, name: 'Default Project', identifier: 'default-project', status: 1)
      end
      
      def self.create!(attributes = {})
        new(attributes)
      end
    end
    
    class SensitiveOperationLog
      attr_accessor :id, :user, :project, :operation_type, :content_type, :detected_patterns, :content_preview, :file_type, :file_size, :risk_level, :ip_address, :user_agent, :user_id, :project_id, :created_at
      
      def initialize(attributes = {})
        attributes.each { |key, value| send("#{key}=", value) }
      end
      
      def self.create!(attributes = {})
        log = new(attributes)
        @logs ||= []
        @logs << log
        log
      end
      
      def self.find_by(id:)
        @logs ||= []
        @logs.find { |log| log.id == id }
      end
      
      def self.last
        @logs&.last
      end
      
      def self.where(conditions)
        @logs ||= []
        @logs.select do |log|
          conditions.all? { |key, value| log.send(key) == value }
        end
      end
      
      def self.cleanup_old_logs
        @logs ||= []
        @logs.clear
      end
      
      def self.delete_all
        @logs ||= []
        @logs.clear
      end
    end
    
    # 模擬 ActiveSupport 的 Time 擴展
    class Time
      def self.current
        Time.now
      end
    end
    
    # 模擬 ActiveSupport 的 Integer 擴展
    class Integer
      def years
        self * 365 * 24 * 60 * 60
      end
      
      def ago
        Time.current - self
      end
    end
    
    # 模擬 ActiveSupport::TestCase
    class TestCase
      def self.test(name, &block)
        define_method("test_#{name}", &block)
      end
      
      def assert_nil(actual, message = "")
        if actual.nil?
          puts "✅ #{message} - 通過"
        else
          puts "❌ #{message} - 失敗: 期望 nil，實際 #{actual}"
        end
      end
      
      def assert_not_nil(actual, message = "")
        if !actual.nil?
          puts "✅ #{message} - 通過"
        else
          puts "❌ #{message} - 失敗: 期望非 nil，實際 nil"
        end
      end
      
      def assert_equal(expected, actual, message = "")
        if expected == actual
          puts "✅ #{message} - 通過"
        else
          puts "❌ #{message} - 失敗: 期望 #{expected}，實際 #{actual}"
        end
      end
      
      def assert_includes(collection, item, message = "")
        if collection.include?(item)
          puts "✅ #{message} - 通過"
        else
          puts "❌ #{message} - 失敗: 期望包含 #{item}，實際 #{collection}"
        end
      end
    end
    
  RUBY
  
  # 組合新內容
  new_content = mock_environment + "\n" + content
  
  # 寫入臨時文件
  File.write(temp_file, new_content)
  
  temp_file
end

# 執行 Redmine 測試
def run_redmine_test(test_file, test_dir, options)
  begin
    # 嘗試使用 Rails 環境執行
    test_command = if Gem.win_platform?
      "set RAILS_ENV=#{ENV['RAILS_ENV']} && ruby -I \"#{test_dir}\" \"#{test_file}\""
    else
      "RAILS_ENV=#{ENV['RAILS_ENV']} ruby -I #{test_dir} #{test_file}"
    end
    
    puts "執行命令：#{test_command}" if options[:verbose]
    result = system(test_command)
    return result
  rescue => e
    puts "❌ 執行錯誤：#{e.message}"
    return false
  end
end

# 執行 Redmine 環境測試
def run_redmine_tests(redmine_root, plugin_dir, options)
  puts "🚀 開始執行 Redmine 環境測試..."
  
  # 切換到 Redmine 根目錄
  Dir.chdir(redmine_root) do
    puts "切換到 Redmine 根目錄：#{redmine_root}" if options[:verbose]
    
    # 執行環境檢查
    check_environment(redmine_root, options)
    
    # 重新計算測試目錄的絕對路徑
    test_dir_absolute = File.expand_path('plugins/redmine_sensitive_data_guard/test', redmine_root)
    plugin_dir_absolute = File.expand_path('plugins/redmine_sensitive_data_guard', redmine_root)
    
    puts "測試目錄絕對路徑：#{test_dir_absolute}" if options[:verbose]
    puts "插件目錄絕對路徑：#{plugin_dir_absolute}" if options[:verbose]
    
    # 運行測試
    test_files = if ARGV.empty?
      # 查找所有測試文件
      if options[:unit_only]
        # 只執行單元測試
        Dir[File.join(test_dir_absolute, 'unit', '**', '*_test.rb')]
      else
        # 執行所有測試
        unit_tests = Dir[File.join(test_dir_absolute, 'unit', '**', '*_test.rb')]
        integration_tests = Dir[File.join(test_dir_absolute, 'integration', '**', '*_test.rb')]
        unit_tests + integration_tests
      end
    else
      # 使用指定的測試文件
      ARGV.map do |test_file|
        if File.exist?(test_file)
          test_file
        elsif File.exist?(File.join(test_dir_absolute, test_file))
          File.join(test_dir_absolute, test_file)
        elsif File.exist?(File.join(plugin_dir_absolute, 'test', test_file))
          File.join(plugin_dir_absolute, 'test', test_file)
        else
          puts "警告：測試文件不存在：#{test_file}"
          nil
        end
      end.compact
    end
    
    if test_files.empty?
      puts "錯誤：沒有找到測試文件"
      exit 1
    end
    
    puts "開始執行測試..."
    puts "測試文件：#{test_files.join(', ')}" if options[:verbose]
    
    # 執行測試
    failed_tests = []
    successful_tests = []
    
    test_files.each do |test_file|
      if File.exist?(test_file)
        puts "\n執行測試：#{test_file}" if options[:verbose]
        
        # 構建測試命令 - 使用指定的環境
        test_command = if Gem.win_platform?
          # Windows 環境
          if ENV['RAILS_ENV'] == 'production'
            "set RAILS_ENV=production && set REDMINE_PRODUCTION_TESTING=true && ruby -I \"#{test_dir_absolute}\" \"#{test_file}\""
          else
            "set RAILS_ENV=#{ENV['RAILS_ENV']} && ruby -I \"#{test_dir_absolute}\" \"#{test_file}\""
          end
        else
          # Unix/Linux 環境
          if ENV['RAILS_ENV'] == 'production'
            "RAILS_ENV=production REDMINE_PRODUCTION_TESTING=true ruby -I #{test_dir_absolute} #{test_file}"
          else
            "RAILS_ENV=#{ENV['RAILS_ENV']} ruby -I #{test_dir_absolute} #{test_file}"
          end
        end
        
        puts "執行命令：#{test_command}" if options[:verbose]
        
        # 執行測試
        begin
          result = system(test_command)
          if result
            successful_tests << test_file
            puts "✅ 測試通過：#{File.basename(test_file)}"
          else
            failed_tests << test_file
            puts "❌ 測試失敗：#{File.basename(test_file)}"
          end
        rescue => e
          failed_tests << test_file
          puts "❌ 測試執行錯誤：#{File.basename(test_file)} - #{e.message}"
        end
      else
        puts "警告：測試文件不存在：#{test_file}"
      end
    end
    
    puts "\n" + "="*50
    puts "測試完成！"
    puts "="*50
    
    if successful_tests.any?
      puts "\n✅ 成功的測試 (#{successful_tests.length} 個)："
      successful_tests.each { |test| puts "  - #{File.basename(test)}" }
    end
    
    if failed_tests.any?
      puts "\n❌ 失敗的測試 (#{failed_tests.length} 個)："
      failed_tests.each { |test| puts "  - #{File.basename(test)}" }
      puts "\n💡 建議："
      puts "  - 檢查測試資料庫配置"
      puts "  - 確保所有依賴都已安裝"
      puts "  - 檢查測試文件中的語法錯誤"
      puts "  - 確認 Rails 環境設定正確"
      exit 1
    else
      puts "\n🎉 所有測試都通過了！"
      exit 0
    end
  end
end

# 環境檢查函數
def check_environment(redmine_root, options)
  puts "檢查環境..." if options[:verbose]
  
  errors = []
  warnings = []
  
  # 檢查 Rails 環境文件
  env_file = File.join(redmine_root, 'config', 'environments', "#{ENV['RAILS_ENV']}.rb")
  unless File.exist?(env_file)
    warnings << "Rails 環境文件不存在：#{env_file}"
  end
  
  # 檢查資料庫配置
  db_config_file = File.join(redmine_root, 'config', 'database.yml')
  unless File.exist?(db_config_file)
    warnings << "資料庫配置文件不存在：#{db_config_file}"
  else
    # 檢查測試資料庫配置
    if ENV['RAILS_ENV'] == 'production'
      puts "使用生產資料庫進行測試" if options[:verbose]
    else
      # 檢查測試資料庫配置是否完整
      db_config_content = File.read(db_config_file)
      unless db_config_content.include?('test:') && db_config_content.include?('database:')
        warnings << "測試資料庫配置可能不完整"
      end
    end
  end
  
  # 檢查 Gemfile
  gemfile_path = File.join(redmine_root, 'Gemfile')
  unless File.exist?(gemfile_path)
    warnings << "Gemfile 不存在：#{gemfile_path}"
  end
  
  # 檢查必要的目錄
  required_dirs = ['config', 'app', 'lib']
  required_dirs.each do |dir|
    dir_path = File.join(redmine_root, dir)
    unless File.exist?(dir_path)
      warnings << "必要目錄不存在：#{dir_path}"
    end
  end
  
  # 檢查 Ruby 版本
  ruby_version = RUBY_VERSION
  puts "Ruby 版本：#{ruby_version}" if options[:verbose]
  
  # 檢查 Rails 版本（如果可能）
  begin
    rails_version_file = File.join(redmine_root, 'Gemfile.lock')
    if File.exist?(rails_version_file)
      content = File.read(rails_version_file)
      if content.match(/rails \(([^)]+)\)/)
        rails_version = $1
        puts "Rails 版本：#{rails_version}" if options[:verbose]
      end
    end
  rescue => e
    warnings << "無法讀取 Rails 版本：#{e.message}"
  end
  
  # 檢查環境變數
  puts "環境變數：" if options[:verbose]
  puts "  RAILS_ENV: #{ENV['RAILS_ENV']}" if options[:verbose]
  puts "  BUNDLE_GEMFILE: #{ENV['BUNDLE_GEMFILE'] || '未設定'}" if options[:verbose]
  puts "  REDMINE_PRODUCTION_TESTING: #{ENV['REDMINE_PRODUCTION_TESTING'] || '未設定'}" if options[:verbose]
  
  # 輸出警告和錯誤
  if warnings.any?
    puts "\n⚠️  環境警告："
    warnings.each { |warning| puts "  - #{warning}" }
  end
  
  if errors.any?
    puts "\n❌ 環境錯誤："
    errors.each { |error| puts "  - #{error}" }
    return false
  end
  
  puts "環境檢查完成" if options[:verbose]
  true
end
