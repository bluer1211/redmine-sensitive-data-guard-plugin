class CreateWhitelistRules < ActiveRecord::Migration[6.0]
  def change
    unless table_exists?(:whitelist_rules)
      create_table :whitelist_rules do |t|
        t.string :name, null: false
        t.string :whitelist_type, null: false
        t.text :pattern, null: false
        t.string :match_type, default: 'exact'
        t.text :description
        t.string :category, default: 'general'
        t.integer :project_id, null: true
        t.integer :user_id, null: true
        t.string :ip_range
        t.string :ip_geolocation
        t.integer :ip_reputation_score, default: 0
        t.text :conditions
        t.boolean :enabled, default: true
        t.datetime :expires_at
        t.integer :created_by_id, null: true
        t.timestamps
      end
      
      add_index :whitelist_rules, :name
      add_index :whitelist_rules, :whitelist_type
      add_index :whitelist_rules, :enabled
      add_index :whitelist_rules, :category
      
      # 添加外鍵約束
      add_foreign_key :whitelist_rules, :projects, column: :project_id, on_delete: :cascade
      add_foreign_key :whitelist_rules, :users, column: :user_id, on_delete: :cascade
      add_foreign_key :whitelist_rules, :users, column: :created_by_id, on_delete: :nullify
      
      # 插入預設白名單規則
      reversible do |dir|
        dir.up do
          # 檢查是否有管理員用戶
          admin_user_id = connection.select_value("SELECT id FROM users WHERE admin = true LIMIT 1") || 1
          
          # 檢查是否為開發環境
          is_development = Rails.env.development? || Rails.env.test?
          
          execute <<~SQL
            INSERT INTO whitelist_rules (name, whitelist_type, pattern, match_type, description, category, enabled, created_by_id, created_at, updated_at) VALUES
            ('測試環境 IP', 'ip', '192.168.1.0/24', 'wildcard', '測試環境 IP 範圍', 'development', true, #{admin_user_id}, NOW(), NOW()),
            ('範例資料', 'content', 'example|test|sample|demo', 'regex', '範例和測試資料', 'general', true, #{admin_user_id}, NOW(), NOW()),
            ('系統管理員', 'user', 'admin', 'exact', '系統管理員帳號', 'system', true, #{admin_user_id}, NOW(), NOW());
          SQL
          
          # 如果是開發環境，添加額外的開發用白名單規則
          if is_development
            execute <<~SQL
              INSERT INTO whitelist_rules (name, whitelist_type, pattern, match_type, description, category, enabled, created_by_id, created_at, updated_at) VALUES
              ('開發環境 IP', 'ip', '127.0.0.1|localhost', 'regex', '本地開發環境 IP', 'development', true, #{admin_user_id}, NOW(), NOW()),
              ('開發測試資料', 'content', 'dev|test|debug|localhost', 'regex', '開發測試資料', 'development', true, #{admin_user_id}, NOW(), NOW()),
              ('開發用戶', 'user', 'developer|test|admin', 'regex', '開發測試用戶', 'development', true, #{admin_user_id}, NOW(), NOW());
            SQL
          end
        end
      end
    end
  end
  
  def down
    drop_table :whitelist_rules if table_exists?(:whitelist_rules)
  end
end 