class CreateSensitiveOperationLogs < ActiveRecord::Migration[6.0]
  def change
    unless table_exists?(:sensitive_operation_logs)
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
        t.string :risk_level, null: false, default: 'medium'
        t.integer :detection_count, default: 0
        t.text :detection_details
        
        # Review 相關欄位
        t.string :review_status, default: 'pending', null: false
        t.references :reviewer, null: true, foreign_key: { to_table: :users }
        t.datetime :reviewed_at
        t.text :review_comment
        t.string :review_decision
        t.boolean :requires_review, default: false, null: false
        
        t.timestamps
      end
      
      add_index :sensitive_operation_logs, :operation_type
      add_index :sensitive_operation_logs, :risk_level
      add_index :sensitive_operation_logs, :created_at
      add_index :sensitive_operation_logs, :review_status
      add_index :sensitive_operation_logs, :requires_review
    end
  end
end 