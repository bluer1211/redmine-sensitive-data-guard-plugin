class SensitiveDataGuardSettingsController < ApplicationController
  before_action :require_admin
  before_action :find_plugin
  
  def test_email
    recipients = params[:recipients]
    
    if recipients.blank?
      render json: { success: false, message: '請輸入收件人 Email 地址' }
      return
    end
    
    # 驗證 Email 格式
    email_list = recipients.split(',').map(&:strip)
    invalid_emails = email_list.reject { |email| email =~ /\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i }
    
    if invalid_emails.any?
      render json: { success: false, message: "無效的 Email 格式: #{invalid_emails.join(', ')}" }
      return
    end
    
    begin
      # 發送測試郵件
      email_list.each do |email|
        send_test_email(email)
      end
      
      render json: { success: true, message: "測試郵件已發送給: #{email_list.join(', ')}" }
    rescue => e
      Rails.logger.error "Email 測試失敗: #{e.message}"
      render json: { success: false, message: "發送失敗: #{e.message}" }
    end
  end
  
  private
  
  def find_plugin
    @plugin = Redmine::Plugin.find('redmine_sensitive_data_guard')
  rescue ActiveRecord::RecordNotFound
    render_404
  end
  
  def send_test_email(email)
    # 建立測試郵件內容
    subject = "[Redmine] 敏感資料防護 - 測試通知"
    body = <<~EMAIL
      您好，
      
      這是一封來自 Redmine 敏感資料防護系統的測試通知。
      
      如果您收到這封郵件，表示：
      1. 郵件配置正確
      2. SMTP 連線正常
      3. 測試通知功能運作正常
      
      測試時間：#{Time.current.strftime('%Y-%m-%d %H:%M:%S')}
      測試系統：Redmine 敏感資料防護插件
      
      此郵件僅為測試用途，請勿回覆。
      
      ---
      Redmine 敏感資料防護系統
      自動發送，請勿回覆
    EMAIL
    
    # 使用 ActionMailer 發送郵件
    mail = ActionMailer::Base.mail(
      from: Setting.mail_from,
      to: email,
      subject: subject,
      body: body
    )
    
    mail.deliver_now
    
    Rails.logger.info "測試郵件已發送給: #{email}"
  end
end
