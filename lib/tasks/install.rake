namespace :redmine_sensitive_data_guard do
  namespace :install do
    desc "檢查安裝環境和依賴"
    task :check => :environment do
      puts "🔍 檢查 Redmine 敏感資料防護插件安裝環境..."
      
      # 檢查 Redmine 版本
      puts "\n📋 Redmine 版本檢查："
      redmine_version = Redmine::VERSION.to_s
      puts "   - 當前版本：#{redmine_version}"
      
      if Gem::Version.new(redmine_version) >= Gem::Version.new('3.4.0')
        puts "   ✅ Redmine 版本符合要求"
      else
        puts "   ⚠️  Redmine 版本可能不相容，建議升級到 3.4.0 以上"
      end
      
      # 檢查 Ruby 版本
      puts "\n💎 Ruby 版本檢查："
      ruby_version = RUBY_VERSION
      puts "   - 當前版本：#{ruby_version}"
      
      if Gem::Version.new(ruby_version) >= Gem::Version.new('2.5.0')
        puts "   ✅ Ruby 版本符合要求"
      else
        puts "   ❌ Ruby 版本不符合要求，需要 2.5.0 以上"
      end
      
      # 檢查 Rails 版本
      puts "\n🚂 Rails 版本檢查："
      rails_version = Rails::VERSION::STRING
      puts "   - 當前版本：#{rails_version}"
      
      if Gem::Version.new(rails_version) >= Gem::Version.new('5.2.0')
        puts "   ✅ Rails 版本符合要求"
      else
        puts "   ❌ Rails 版本不符合要求，需要 5.2.0 以上"
      end
      
      # 檢查 Gem 依賴
      puts "\n📦 Gem 依賴檢查："
      required_gems = {
        'rubyzip' => '1.3.0',
        'nokogiri' => '1.12.0',
        'roo' => '2.8.0',
        'pdf-reader' => '2.8.0'
      }
      
      optional_gems = {
        'sidekiq' => '6.4.0',
        'redis' => '4.2.0',
        'slack-notifier' => '2.4.0',
        'axlsx' => '2.1.0'
      }
      
      puts "   必要依賴："
      required_gems.each do |gem_name, min_version|
        begin
          gem_spec = Gem::Specification.find_by_name(gem_name)
          if gem_spec
            version = gem_spec.version.to_s
            if Gem::Version.new(version) >= Gem::Version.new(min_version)
              puts "   ✅ #{gem_name} (#{version})"
            else
              puts "   ⚠️  #{gem_name} (#{version}) - 建議升級到 #{min_version} 以上"
            end
          else
            puts "   ❌ #{gem_name} - 未安裝"
          end
        rescue Gem::MissingSpecError
          puts "   ❌ #{gem_name} - 未安裝"
        end
      end
      
      puts "   可選依賴："
      optional_gems.each do |gem_name, min_version|
        begin
          gem_spec = Gem::Specification.find_by_name(gem_name)
          if gem_spec
            version = gem_spec.version.to_s
            if Gem::Version.new(version) >= Gem::Version.new(min_version)
              puts "   ✅ #{gem_name} (#{version})"
            else
              puts "   ⚠️  #{gem_name} (#{version}) - 建議升級到 #{min_version} 以上"
            end
          else
            puts "   ℹ️  #{gem_name} - 未安裝（可選）"
          end
        rescue Gem::MissingSpecError
          puts "   ℹ️  #{gem_name} - 未安裝（可選）"
        end
      end
      
      # 檢查資料庫
      puts "\n🗄️ 資料庫檢查："
      begin
        adapter = ActiveRecord::Base.connection.adapter_name.downcase
        puts "   - 資料庫類型：#{adapter}"
        
        if ['mysql', 'postgresql', 'sqlite'].include?(adapter)
          puts "   ✅ 資料庫類型支援"
        else
          puts "   ⚠️  資料庫類型可能不支援"
        end
        
        # 檢查資料表
        tables = ['sensitive_operation_logs', 'detection_rules', 'whitelist_rules']
        tables.each do |table_name|
          if ActiveRecord::Base.connection.table_exists?(table_name)
            count = ActiveRecord::Base.connection.execute("SELECT COUNT(*) FROM #{table_name}").first[0]
            puts "   ✅ #{table_name}: #{count} 筆記錄"
          else
            puts "   ❌ #{table_name}: 資料表不存在"
          end
        end
        
      rescue => e
        puts "   ❌ 資料庫檢查失敗：#{e.message}"
      end
      
      # 檢查檔案權限
      puts "\n📁 檔案權限檢查："
      plugin_dir = Rails.root.join('plugins', 'redmine_sensitive_data_guard')
      if Dir.exist?(plugin_dir)
        puts "   ✅ 插件目錄存在：#{plugin_dir}"
        
        # 檢查重要檔案
        important_files = [
          'init.rb',
          'README.md',
          'db/migrate/001_create_sensitive_operation_logs.rb',
          'app/models/sensitive_operation_log.rb'
        ]
        
        important_files.each do |file|
          file_path = plugin_dir.join(file)
          if File.exist?(file_path)
            puts "   ✅ #{file}"
          else
            puts "   ❌ #{file} - 檔案不存在"
          end
        end
      else
        puts "   ❌ 插件目錄不存在：#{plugin_dir}"
      end
      
      # 檢查設定
      puts "\n⚙️ 設定檢查："
      begin
        settings = Setting.plugin_redmine_sensitive_data_guard
        if settings && settings['enabled']
          puts "   ✅ 插件已啟用"
          puts "   - 檔案掃描：#{settings['scan_office_documents'] ? '啟用' : '停用'}"
          puts "   - 檔案大小限制：#{settings['max_file_size_mb']}MB"
          puts "   - Email 通知：#{settings['email_notifications'] ? '啟用' : '停用'}"
        else
          puts "   ⚠️  插件未啟用或設定不完整"
        end
      rescue => e
        puts "   ❌ 設定檢查失敗：#{e.message}"
      end
      
      puts "\n🎉 安裝環境檢查完成！"
    end
    
    desc "執行完整安裝流程"
    task :setup => :environment do
      puts "🚀 開始執行 Redmine 敏感資料防護插件完整安裝..."
      
      # 1. 檢查環境
      puts "\n1️⃣ 檢查安裝環境..."
      Rake::Task['redmine_sensitive_data_guard:install:check'].invoke
      
      # 2. 執行遷移
      puts "\n2️⃣ 執行資料庫遷移..."
      begin
        Rake::Task['redmine:plugins:migrate'].invoke
        puts "   ✅ 資料庫遷移完成"
      rescue => e
        puts "   ❌ 資料庫遷移失敗：#{e.message}"
        return
      end
      
      # 3. 初始化資料
      puts "\n3️⃣ 初始化預設資料..."
      begin
        Rake::Task['redmine_sensitive_data_guard:db:seed'].invoke
        puts "   ✅ 預設資料初始化完成"
      rescue => e
        puts "   ⚠️  預設資料初始化失敗：#{e.message}"
      end
      
      # 4. 檢查結果
      puts "\n4️⃣ 檢查安裝結果..."
      Rake::Task['redmine_sensitive_data_guard:db:status'].invoke
      
      puts "\n🎉 安裝流程完成！"
      puts "\n📋 後續步驟："
      puts "1. 重啟 Redmine 服務"
      puts "2. 登入管理員帳號"
      puts "3. 進入「管理」→「設定」→「插件」"
      puts "4. 配置「Redmine Sensitive Data Guard Plugin」"
      puts "5. 設定用戶權限"
    end
  end
end 