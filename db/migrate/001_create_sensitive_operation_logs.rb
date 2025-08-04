class CreateSensitiveOperationLogs < ActiveRecord::Migration[5.2]
  def change
    create_table :sensitive_operation_logs do |t|
      t.references :user, null: false, foreign_key: true
      t.references :project, null: true, foreign_key: true
      t.string :operation_type, null: false
      t.string :content_type, null: false
      t.text :detected_patterns
      t.text :content_preview
      t.text :override_reason
      t.string :file_type
      t.integer :file_size
      t.string :ip_address
      t.text :user_agent
      t.enum :risk_level, enum_name: :risk_level_enum, default: 'medium'
      t.timestamps
    end
    
    add_index :sensitive_operation_logs, :operation_type
    add_index :sensitive_operation_logs, :risk_level
    add_index :sensitive_operation_logs, :created_at
    
    # 建立風險等級枚舉類型
    execute <<~SQL
      CREATE TYPE risk_level_enum AS ENUM ('high', 'medium', 'low');
    SQL
  end
  
  def down
    drop_table :sensitive_operation_logs
    execute "DROP TYPE IF EXISTS risk_level_enum;"
  end
end 