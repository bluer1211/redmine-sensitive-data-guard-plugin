class CreateWhitelistRules < ActiveRecord::Migration[5.2]
  def change
    create_table :whitelist_rules do |t|
      t.string :name, null: false
      t.enum :whitelist_type, enum_name: :whitelist_type_enum, null: false
      t.text :pattern, null: false
      t.enum :match_type, enum_name: :match_type_enum, default: 'exact'
      t.text :description
      t.string :category, default: 'general'
      t.references :project, null: true, foreign_key: true
      t.references :user, null: true, foreign_key: true
      t.string :ip_range
      t.string :ip_geolocation
      t.integer :ip_reputation_score, default: 0
      t.text :conditions
      t.boolean :enabled, default: true
      t.datetime :expires_at
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.timestamps
    end
    
    add_index :whitelist_rules, :name
    add_index :whitelist_rules, :whitelist_type
    add_index :whitelist_rules, :enabled
    add_index :whitelist_rules, :category
    
    # 建立白名單類型枚舉
    execute <<~SQL
      CREATE TYPE whitelist_type_enum AS ENUM ('content', 'user', 'project', 'ip');
    SQL
    
    # 建立匹配類型枚舉
    execute <<~SQL
      CREATE TYPE match_type_enum AS ENUM ('exact', 'regex', 'wildcard');
    SQL
    
    # 插入預設白名單規則
    execute <<~SQL
      INSERT INTO whitelist_rules (name, whitelist_type, pattern, match_type, description, category, enabled, created_by_id, created_at, updated_at) VALUES
      ('測試環境 IP', 'ip', '192.168.1.0/24', 'wildcard', '測試環境 IP 範圍', 'development', true, 1, NOW(), NOW()),
      ('範例資料', 'content', 'example|test|sample|demo', 'regex', '範例和測試資料', 'general', true, 1, NOW(), NOW()),
      ('系統管理員', 'user', 'admin', 'exact', '系統管理員帳號', 'system', true, 1, NOW(), NOW());
    SQL
  end
  
  def down
    drop_table :whitelist_rules
    execute "DROP TYPE IF EXISTS whitelist_type_enum;"
    execute "DROP TYPE IF EXISTS match_type_enum;"
  end
end 