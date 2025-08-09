# frozen_string_literal: true

require File.expand_path('../../test_helper', __FILE__)

class FileScannerTest < ActiveSupport::TestCase
  def setup
    @scanner = FileScanner.new
    @test_file_path = Rails.root.join('tmp', 'test_file.txt')
  end
  
  def teardown
    File.delete(@test_file_path) if File.exist?(@test_file_path)
  end
  
  def test_scan_text_file_with_sensitive_data
    content = "用戶資料：身分證 A123456789，手機 0912345678"
    create_test_file(content)
    
    result = @scanner.scan_file(@test_file_path, 'test.txt')
    
    assert result[:detected], "應該偵測到敏感資料"
    assert_equal 'high', result[:risk_level], "應該被分類為高風險"
    assert_includes result[:detections], 'taiwan_id', "應該偵測到身分證號碼"
    assert_includes result[:detections], 'taiwan_mobile', "應該偵測到手機號碼"
  end
  
  def test_scan_text_file_with_safe_data
    content = "這是一個安全的測試檔案，不包含任何敏感資料。"
    create_test_file(content)
    
    result = @scanner.scan_file(@test_file_path, 'test.txt')
    
    assert !result[:detected], "不應該偵測到敏感資料"
    assert_equal 'low', result[:risk_level], "應該被分類為低風險"
  end
  
  def test_scan_csv_file
    content = "姓名,身分證號碼,手機號碼\n張三,A123456789,0912345678"
    create_test_file(content)
    
    result = @scanner.scan_file(@test_file_path, 'test.csv')
    
    assert result[:detected], "應該偵測到敏感資料"
    assert_includes result[:detections], 'taiwan_id', "應該偵測到身分證號碼"
    assert_includes result[:detections], 'taiwan_mobile', "應該偵測到手機號碼"
  end
  
  def test_scan_large_file
    # 創建一個大檔案（超過1MB）
    content = "正常內容 " * 50000 + "A123456789"
    create_test_file(content)
    
    result = @scanner.scan_file(@test_file_path, 'large.txt')
    
    assert result[:detected], "應該在大檔案中偵測到敏感資料"
    assert_includes result[:detections], 'taiwan_id', "應該偵測到身分證號碼"
  end
  
  def test_scan_unsupported_file_type
    content = "測試內容"
    create_test_file(content)
    
    result = @scanner.scan_file(@test_file_path, 'test.xyz')
    
    assert !result[:detected], "不支援的檔案類型不應該被掃描"
    assert_equal 'low', result[:risk_level], "不支援的檔案類型應該被分類為低風險"
  end
  
  def test_scan_file_with_special_characters
    content = "身分證：A123456789\n電話：0912345678\r\nEmail：test@example.com"
    create_test_file(content)
    
    result = @scanner.scan_file(@test_file_path, 'test.txt')
    
    assert result[:detected], "應該在包含特殊字符的檔案中偵測到敏感資料"
    assert_includes result[:detections], 'taiwan_id', "應該偵測到身分證號碼"
    assert_includes result[:detections], 'taiwan_mobile', "應該偵測到手機號碼"
    assert_includes result[:detections], 'email', "應該偵測到Email"
  end
  
  def test_scan_file_with_encoding_issues
    content = "測試內容：A123456789".encode('UTF-8')
    create_test_file(content)
    
    result = @scanner.scan_file(@test_file_path, 'test.txt')
    
    assert result[:detected], "應該在UTF-8編碼的檔案中偵測到敏感資料"
    assert_includes result[:detections], 'taiwan_id', "應該偵測到身分證號碼"
  end
  
  def test_scan_file_with_binary_content
    # 創建一個包含二進制內容的檔案
    binary_content = "\x00\x01\x02\x03A123456789\x04\x05\x06"
    create_test_file(binary_content, 'wb')
    
    result = @scanner.scan_file(@test_file_path, 'test.bin')
    
    # 二進制檔案應該被跳過或返回低風險
    assert_equal 'low', result[:risk_level], "二進制檔案應該被分類為低風險"
  end
  
  def test_scan_file_performance
    content = "正常內容 " * 10000 + "A123456789"
    create_test_file(content)
    
    start_time = Time.current
    result = @scanner.scan_file(@test_file_path, 'test.txt')
    end_time = Time.current
    
    processing_time = end_time - start_time
    assert processing_time < 5.0, "檔案掃描時間應該小於5秒，實際時間: #{processing_time}秒"
    assert result[:detected], "應該在大量內容中偵測到敏感資料"
  end
  
  def test_scan_file_with_empty_content
    create_test_file("")
    
    result = @scanner.scan_file(@test_file_path, 'test.txt')
    
    assert !result[:detected], "空檔案不應該被偵測到敏感資料"
    assert_equal 'low', result[:risk_level], "空檔案應該被分類為低風險"
  end
  
  def test_scan_file_with_only_whitespace
    create_test_file("   \n\t\r\n  ")
    
    result = @scanner.scan_file(@test_file_path, 'test.txt')
    
    assert !result[:detected], "只包含空白字符的檔案不應該被偵測到敏感資料"
    assert_equal 'low', result[:risk_level], "空白檔案應該被分類為低風險"
  end
  
  def test_scan_file_error_handling
    # 測試掃描不存在的檔案
    result = @scanner.scan_file('/path/to/nonexistent/file.txt', 'test.txt')
    
    assert !result[:detected], "不存在的檔案不應該被偵測到敏感資料"
    assert_equal 'low', result[:risk_level], "不存在的檔案應該被分類為低風險"
  end
  
  private
  
  def create_test_file(content, mode = 'w')
    File.open(@test_file_path, mode) do |f|
      f.write(content)
    end
  end
end
