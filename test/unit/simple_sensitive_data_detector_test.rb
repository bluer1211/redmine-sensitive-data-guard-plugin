# frozen_string_literal: true

require File.expand_path('../../test_helper', __FILE__)

class SimpleSensitiveDataDetectorTest < ActiveSupport::TestCase
  def setup
    @detector = SimpleSensitiveDataDetector.new
  end
  
  # 測試台灣身分證號碼偵測
  def test_taiwan_id_detection
    test_cases = [
      { content: "A123456789", expected: true },
      { content: "B987654321", expected: true },
      { content: "C123456789", expected: false }, # 無效的字母
      { content: "A12345678", expected: false },  # 位數不足
      { content: "A1234567890", expected: false } # 位數過多
    ]
    
    test_cases.each do |test_case|
      result = @detector.scan(test_case[:content])
      assert_equal test_case[:expected], result.detected?, 
                   "身分證號碼偵測失敗: #{test_case[:content]}"
    end
  end
  
  # 測試信用卡號碼偵測
  def test_credit_card_detection
    test_cases = [
      { content: "1234-5678-9012-3456", expected: true },
      { content: "1234567890123456", expected: true },
      { content: "1234 5678 9012 3456", expected: true },
      { content: "123456789012345", expected: false },  # 位數不足
      { content: "12345678901234567", expected: false } # 位數過多
    ]
    
    test_cases.each do |test_case|
      result = @detector.scan(test_case[:content])
      assert_equal test_case[:expected], result.detected?, 
                   "信用卡號碼偵測失敗: #{test_case[:content]}"
    end
  end
  
  # 測試台灣手機號碼偵測
  def test_taiwan_mobile_detection
    test_cases = [
      { content: "0912345678", expected: true },
      { content: "0987654321", expected: true },
      { content: "091234567", expected: false },   # 位數不足
      { content: "09123456789", expected: false }, # 位數過多
      { content: "0812345678", expected: false }   # 無效的前綴
    ]
    
    test_cases.each do |test_case|
      result = @detector.scan(test_case[:content])
      assert_equal test_case[:expected], result.detected?, 
                   "手機號碼偵測失敗: #{test_case[:content]}"
    end
  end
  
  # 測試密碼關鍵字偵測
  def test_password_keyword_detection
    test_cases = [
      { content: "password: mysecret123", expected: true },
      { content: "API_KEY=abc123def456", expected: true },
      { content: "auth_token: xyz789", expected: true },
      { content: "username: admin", expected: false }, # 不包含密碼關鍵字
      { content: "normal text", expected: false }
    ]
    
    test_cases.each do |test_case|
      result = @detector.scan(test_case[:content])
      assert_equal test_case[:expected], result.detected?, 
                   "密碼關鍵字偵測失敗: #{test_case[:content]}"
    end
  end
  
  # 測試帳號密碼組合偵測
  def test_username_password_combination_detection
    test_cases = [
      { content: "username=admin&password=123456", expected: true },
      { content: "user: admin, password: secret123", expected: true },
      { content: "login=test&pwd=password123", expected: true },
      { content: "username: admin", expected: false }, # 只有帳號
      { content: "password: 123456", expected: false } # 只有密碼
    ]
    
    test_cases.each do |test_case|
      result = @detector.scan(test_case[:content])
      assert_equal test_case[:expected], result.detected?, 
                   "帳號密碼組合偵測失敗: #{test_case[:content]}"
    end
  end
  
  # 測試 Email 地址偵測
  def test_email_detection
    test_cases = [
      { content: "user@example.com", expected: true },
      { content: "test.email@domain.org", expected: true },
      { content: "invalid-email", expected: false },
      { content: "user@", expected: false },
      { content: "@domain.com", expected: false }
    ]
    
    test_cases.each do |test_case|
      result = @detector.scan(test_case[:content])
      assert_equal test_case[:expected], result.detected?, 
                   "Email 地址偵測失敗: #{test_case[:content]}"
    end
  end
  
  # 測試 IP 地址偵測
  def test_ip_address_detection
    test_cases = [
      { content: "192.168.1.1", expected: true },
      { content: "10.0.0.1", expected: true },
      { content: "172.16.0.1", expected: true },
      { content: "256.256.256.256", expected: false }, # 無效 IP
      { content: "192.168.1", expected: false }        # 不完整 IP
    ]
    
    test_cases.each do |test_case|
      result = @detector.scan(test_case[:content])
      assert_equal test_case[:expected], result.detected?, 
                   "IP 地址偵測失敗: #{test_case[:content]}"
    end
  end
  
  # 測試風險等級分類
  def test_risk_level_classification
    # 高風險測試
    high_risk_content = "A123456789 1234-5678-9012-3456"
    result = @detector.scan(high_risk_content)
    assert result.detected?, "應該偵測到高風險內容"
    assert result.has_high_risk?, "應該包含高風險偵測"
    
    # 中風險測試
    medium_risk_content = "0912345678 user@example.com"
    result = @detector.scan(medium_risk_content)
    assert result.detected?, "應該偵測到中風險內容"
    
    # 低風險測試
    low_risk_content = "normal text without sensitive data"
    result = @detector.scan(low_risk_content)
    assert !result.detected?, "不應該偵測到敏感資料"
  end
  
  # 測試空內容處理
  def test_empty_content_handling
    empty_contents = [nil, "", "   ", "\n", "\t"]
    
    empty_contents.each do |content|
      result = @detector.scan(content)
      assert !result.detected?, "空內容不應該被偵測為敏感資料: #{content.inspect}"
    end
  end
  
  # 測試 contains_sensitive_data? 方法
  def test_contains_sensitive_data_method
    sensitive_content = "A123456789 0912345678"
    assert @detector.contains_sensitive_data?(sensitive_content), "應該偵測到敏感資料"
    
    safe_content = "normal text"
    assert !@detector.contains_sensitive_data?(safe_content), "不應該偵測到敏感資料"
  end
  
  # 測試效能
  def test_performance
    large_content = "normal text " * 1000 + "A123456789"
    start_time = Time.now
    result = @detector.scan(large_content)
    end_time = Time.now
    
    assert result.detected?, "應該偵測到敏感資料"
    assert (end_time - start_time) < 1.0, "掃描應該在 1 秒內完成"
  end
  
  # 測試特殊字元處理
  def test_special_characters_handling
    special_content = "身分證：A123456789\n電話：0912345678\r\nEmail：test@example.com"
    result = @detector.scan(special_content)
    assert result.detected?, "應該偵測到包含特殊字元的敏感資料"
  end
  
  # 測試多種敏感資料組合
  def test_multiple_sensitive_data_combination
    combined_content = "用戶資料：身分證 A123456789，手機 0912345678，信用卡 1234-5678-9012-3456，Email：test@example.com"
    result = @detector.scan(combined_content)
    assert result.detected?, "應該偵測到多種敏感資料"
    assert result.total_matches > 1, "應該偵測到多個匹配"
  end
end
