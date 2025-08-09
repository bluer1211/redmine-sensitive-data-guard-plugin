class CreateDetectionRules < ActiveRecord::Migration[6.0]
  def change
    unless table_exists?(:detection_rules)
      create_table :detection_rules do |t|
        t.string :name, null: false
        t.text :pattern, null: false
        t.string :risk_level, default: 'medium'
        t.boolean :enabled, default: true
        t.text :description
        t.string :rule_type, default: 'regex'
        t.integer :priority, default: 0
        t.timestamps
      end
      
      add_index :detection_rules, :name, unique: true
      add_index :detection_rules, :risk_level
      add_index :detection_rules, :enabled
      add_index :detection_rules, :priority
      
      # 插入預設偵測規則
      reversible do |dir|
        dir.up do
          # 檢查是否為開發環境
          is_development = Rails.env.development? || Rails.env.test?
          
          execute <<~SQL
            INSERT INTO detection_rules (name, pattern, risk_level, description, rule_type, priority, created_at, updated_at) VALUES
            ('台灣身分證號', '^[A-Z][12]\\d{8}$', 'high', '台灣身分證號格式偵測', 'regex', 100, NOW(), NOW()),
            ('信用卡號', '\\b\\d{4}[\\-\\s]?\\d{4}[\\-\\s]?\\d{4}[\\-\\s]?\\d{4}\\b', 'high', '信用卡號格式偵測', 'regex', 90, NOW(), NOW()),
            ('API Key', '(?i)(?:api[_-]?key|secret|token)\\s*[:=]\\s*[''"]?[a-zA-Z0-9]{20,}[''"]?', 'high', 'API Key、Secret、Token 偵測', 'regex', 85, NOW(), NOW()),
            ('帳號密碼組合', '(?i)(?:user(?:name|id)?|login|account)\\s*[:=]\\s*[''"]?[^''"\\s]+[''"]?\\s*(?:password|pwd|pass)\\s*[:=]\\s*[''"]?[^''"\\s]{6,}[''"]?', 'high', '使用者帳號密碼組合偵測', 'regex', 80, NOW(), NOW()),
            ('台灣手機號碼', '09\\d{2}[\\-\\s]?\\d{3}[\\-\\s]?\\d{3}', 'medium', '台灣手機號碼格式偵測', 'regex', 70, NOW(), NOW()),
            ('Email 地址', '\\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Z|a-z]{2,}\\b', 'medium', 'Email 格式偵測', 'regex', 60, NOW(), NOW()),
            ('內部 IP 位址', '\\b(?:192\\.168\\.|10\\.|172\\.(?:1[6-9]|2[0-9]|3[01])\\.)\\d{1,3}\\.\\d{1,3}\\b', 'medium', '內部 IP 位址偵測', 'regex', 50, NOW(), NOW()),
            ('外部 IP 位址', '\\b(?:[0-9]{1,3}\\.){3}[0-9]{1,3}\\b', 'low', '外部 IP 位址偵測', 'regex', 40, NOW(), NOW());
          SQL
          
          # 如果是開發環境，添加額外的開發用規則
          if is_development
            execute <<~SQL
              INSERT INTO detection_rules (name, pattern, risk_level, description, rule_type, priority, created_at, updated_at) VALUES
              ('開發環境測試', 'test|dev|development', 'low', '開發環境測試用規則', 'regex', 10, NOW(), NOW()),
              ('範例資料', 'example|sample|demo', 'low', '範例資料偵測', 'regex', 5, NOW(), NOW());
            SQL
          end
        end
      end
    end
  end
  
  def down
    drop_table :detection_rules if table_exists?(:detection_rules)
  end
end 