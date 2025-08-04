namespace :redmine_sensitive_data_guard do
  namespace :db do
    desc "檢查插件資料庫狀態"
    task :status => :environment do
      puts "🔍 檢查 Redmine 敏感資料防護插件資料庫狀態..."
      
      begin
        # 檢查資料表是否存在
        tables = {
          'sensitive_operation_logs' => SensitiveOperationLog,
          'detection_rules' => DetectionRule,
          'whitelist_rules' => WhitelistRule
        }
        
        tables.each do |table_name, model_class|
          if ActiveRecord::Base.connection.table_exists?(table_name)
            count = model_class.count
            puts "✅ #{table_name}: #{count} 筆記錄"
          else
            puts "❌ #{table_name}: 資料表不存在"
          end
        end
        
        # 檢查索引
        puts "\n📊 索引狀態："
        if ActiveRecord::Base.connection.table_exists?('sensitive_operation_logs')
          indexes = ActiveRecord::Base.connection.indexes('sensitive_operation_logs')
          indexes.each do |index|
            puts "   - #{index.name}: #{index.columns.join(', ')}"
          end
        end
        
        puts "\n🎉 資料庫檢查完成！"
        
      rescue => e
        puts "❌ 檢查失敗：#{e.message}"
        puts e.backtrace.first(5)
      end
    end
    
    desc "初始化插件預設資料"
    task :seed => :environment do
      puts "🌱 初始化 Redmine 敏感資料防護插件預設資料..."
      
      begin
        # 載入種子檔案
        seed_file = File.join(File.dirname(__FILE__), '..', 'db', 'seeds.rb')
        load seed_file if File.exist?(seed_file)
        
        puts "✅ 預設資料初始化完成！"
        
      rescue => e
        puts "❌ 初始化失敗：#{e.message}"
        puts e.backtrace.first(5)
      end
    end
    
    desc "清理過期日誌"
    task :cleanup => :environment do
      puts "🧹 清理過期日誌..."
      
      begin
        # 取得設定
        settings = Setting.plugin_redmine_sensitive_data_guard
        
        retention_days = {
          'high' => settings['retention_days_high_risk'] || 2555,  # 7年
          'medium' => settings['retention_days_standard'] || 1095,  # 3年
          'low' => settings['retention_days_standard'] || 1095   # 3年
        }
        
        total_deleted = 0
        
        retention_days.each do |risk_level, days|
          cutoff_date = days.days.ago
          deleted_count = SensitiveOperationLog.where(risk_level: risk_level)
                                               .where('created_at < ?', cutoff_date)
                                               .delete_all
          
          puts "   - #{risk_level} 風險等級：刪除 #{deleted_count} 筆記錄（#{days} 天前）"
          total_deleted += deleted_count
        end
        
        puts "✅ 清理完成！總共刪除 #{total_deleted} 筆過期記錄"
        
      rescue => e
        puts "❌ 清理失敗：#{e.message}"
        puts e.backtrace.first(5)
      end
    end
    
    desc "備份插件資料"
    task :backup => :environment do
      puts "💾 備份插件資料..."
      
      begin
        backup_dir = Rails.root.join('backups', 'plugins', 'sensitive_data_guard')
        FileUtils.mkdir_p(backup_dir)
        
        timestamp = Time.now.strftime('%Y%m%d_%H%M%S')
        
        # 備份資料表
        tables = ['sensitive_operation_logs', 'detection_rules', 'whitelist_rules']
        
        tables.each do |table_name|
          if ActiveRecord::Base.connection.table_exists?(table_name)
            backup_file = backup_dir.join("#{table_name}_#{timestamp}.json")
            
            data = ActiveRecord::Base.connection.execute("SELECT * FROM #{table_name}")
            File.write(backup_file, data.to_a.to_json)
            
            puts "   - #{table_name}: 備份到 #{backup_file}"
          end
        end
        
        puts "✅ 備份完成！"
        
      rescue => e
        puts "❌ 備份失敗：#{e.message}"
        puts e.backtrace.first(5)
      end
    end
    
    desc "重置插件資料庫（危險操作）"
    task :reset => :environment do
      puts "⚠️  警告：此操作將刪除所有插件資料！"
      print "請輸入 'YES' 確認："
      confirmation = STDIN.gets.chomp
      
      if confirmation == 'YES'
        puts "🗑️  重置插件資料庫..."
        
        begin
          # 刪除所有資料
          SensitiveOperationLog.delete_all
          DetectionRule.delete_all
          WhitelistRule.delete_all
          
          # 重新執行遷移
          Rake::Task['redmine:plugins:migrate:down'].invoke
          Rake::Task['redmine:plugins:migrate'].invoke
          
          # 重新初始化資料
          Rake::Task['redmine_sensitive_data_guard:db:seed'].invoke
          
          puts "✅ 重置完成！"
          
        rescue => e
          puts "❌ 重置失敗：#{e.message}"
          puts e.backtrace.first(5)
        end
      else
        puts "❌ 操作已取消"
      end
    end
  end
end 