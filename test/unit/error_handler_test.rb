# frozen_string_literal: true

# 獨立測試檔案 - ErrorHandlerTest
# 這個檔案可以在沒有完整 Redmine 環境的情況下執行測試

# 模擬 Redmine 環境
module Redmine
  module I18n
    def self.t(key, options = {})
      key.to_s
    end
  end
end

# 模擬 Rails 環境
module Rails
  def self.logger
    @logger ||= Logger.new(STDOUT)
  end
  
  def self.root
    Pathname.new(Dir.pwd)
  end
end

class Logger
  def error(message)
    puts "ERROR: #{message}"
  end
  
  def info(message)
    puts "INFO: #{message}"
  end
end

# 模擬 Timeout 模組
module Timeout
  class Error < StandardError
    def initialize(message = "處理超時")
      super(message)
    end
  end
end

# 模擬 ActiveRecord 模型
class ActiveRecord
  class RecordInvalid < StandardError
    def initialize(record)
      @record = record
      super("記錄無效")
    end
  end
  
  class RecordNotFound < StandardError
    def initialize(message = "記錄不存在")
      super(message)
    end
  end
  
  class StatementInvalid < StandardError
    def initialize(message = "SQL 語句無效")
      super(message)
    end
  end
end

# 模擬 ActiveSupport::TestCase
class TestCase
  def self.test(name, &block)
    define_method("test_#{name}", &block)
  end
  
  def assert_nil(actual, message = "")
    if actual.nil?
      puts "✅ #{message} - 通過"
    else
      puts "❌ #{message} - 失敗: 期望 nil，實際 #{actual}"
    end
  end
  
  def assert_not_nil(actual, message = "")
    if !actual.nil?
      puts "✅ #{message} - 通過"
    else
      puts "❌ #{message} - 失敗: 期望非 nil，實際 nil"
    end
  end
  
  def assert_equal(expected, actual, message = "")
    if expected == actual
      puts "✅ #{message} - 通過"
    else
      puts "❌ #{message} - 失敗: 期望 #{expected}，實際 #{actual}"
    end
  end
  
  def assert_not(condition, message = "")
    if !condition
      puts "✅ #{message} - 通過"
    else
      puts "❌ #{message} - 失敗: 期望 false，實際 true"
    end
  end
  
  def assert_includes(collection, item, message = "")
    if collection.include?(item)
      puts "✅ #{message} - 通過"
    else
      puts "❌ #{message} - 失敗: 期望包含 #{item}，實際 #{collection}"
    end
  end
  
  def assert_nothing_raised
    begin
      yield
      puts "✅ 沒有拋出異常 - 通過"
    rescue => e
      puts "❌ 拋出異常: #{e.message} - 失敗"
    end
  end
end

# 載入必要的文件
begin
  require_relative '../../lib/security_error'
rescue => e
  # 如果 SecurityError 已經定義，則跳過
  puts "SecurityError 已存在，跳過載入"
end

require_relative '../../lib/error_handler'

# 測試類別
class ErrorHandlerTest < TestCase
  def setup
    @context = { user_id: 1, project_id: 1, operation: 'test' }
    @file_info = { filename: 'test.txt', size: 1024, max_size: 50 }
  end
  
  # ==================== 偵測錯誤處理測試 ====================
  
  def test_handle_detection_error_with_security_error
    # 檢查 SecurityError 類是否正確定義
    if defined?(SecurityError)
      error = SecurityError.new("安全錯誤", "high", { pattern: "taiwan_id" })
    else
      error = StandardError.new("安全錯誤")
    end
    
    result = ErrorHandler.handle_detection_error(error, @context)
    
    assert_not result[:success], "安全錯誤應該返回失敗"
    if defined?(SecurityError)
      assert_equal "安全錯誤", result[:error]
      assert_equal "security", result[:type]
    else
      assert_equal "系統處理異常，請聯繫管理員", result[:error]
      assert_equal "general", result[:type]
    end
  end
  
  def test_handle_detection_error_with_timeout_error
    error = Timeout::Error.new("處理超時")
    
    result = ErrorHandler.handle_detection_error(error, @context)
    
    assert_not result[:success], "超時錯誤應該返回失敗"
    assert_equal "處理超時，請稍後再試", result[:error]
    assert_equal "timeout", result[:type]
  end
  
  def test_handle_detection_error_with_standard_error
    error = StandardError.new("一般錯誤")
    
    result = ErrorHandler.handle_detection_error(error, @context)
    
    assert_not result[:success], "一般錯誤應該返回失敗"
    assert_equal "系統處理異常，請聯繫管理員", result[:error]
    assert_equal "general", result[:type]
  end
  
  def test_handle_detection_error_with_unknown_error
    error = Exception.new("未知錯誤")
    
    result = ErrorHandler.handle_detection_error(error, @context)
    
    assert_not result[:success], "未知錯誤應該返回失敗"
    assert_equal "未知錯誤", result[:error]
    assert_equal "unknown", result[:type]
  end
  
  def test_handle_detection_error_with_nil_context
    error = StandardError.new("測試錯誤")
    
    result = ErrorHandler.handle_detection_error(error)
    
    assert_not result[:success], "無上下文錯誤應該返回失敗"
    assert_equal "系統處理異常，請聯繫管理員", result[:error]
  end
  
  # ==================== 檔案錯誤處理測試 ====================
  
  def test_handle_file_error_with_file_size_limit_exceeded
    error = FileSizeLimitExceededError.new("檔案大小超過限制")
    
    result = ErrorHandler.handle_file_error(error, @file_info)
    
    assert_not result[:success], "檔案大小錯誤應該返回失敗"
    assert_equal "檔案大小超過限制 (50MB)", result[:error]
    assert_equal "file_size", result[:type]
  end
  
  def test_handle_file_error_with_unsupported_file_format
    error = UnsupportedFileFormatError.new("不支援的檔案格式")
    
    result = ErrorHandler.handle_file_error(error, @file_info)
    
    assert_not result[:success], "檔案格式錯誤應該返回失敗"
    assert_equal "不支援的檔案格式", result[:error]
    assert_equal "file_format", result[:type]
  end
  
  def test_handle_file_error_with_corrupted_file
    error = CorruptedFileError.new("檔案已損壞")
    
    result = ErrorHandler.handle_file_error(error, @file_info)
    
    assert_not result[:success], "檔案損壞錯誤應該返回失敗"
    assert_equal "檔案可能已損壞", result[:error]
    assert_equal "file_corrupted", result[:type]
  end
  
  def test_handle_file_error_with_general_file_error
    error = StandardError.new("檔案處理錯誤")
    
    result = ErrorHandler.handle_file_error(error, @file_info)
    
    assert_not result[:success], "一般檔案錯誤應該返回失敗"
    assert_equal "檔案處理失敗", result[:error]
    assert_equal "file_processing", result[:type]
  end
  
  def test_handle_file_error_with_nil_file_info
    error = StandardError.new("檔案錯誤")
    
    result = ErrorHandler.handle_file_error(error)
    
    assert_not result[:success], "無檔案資訊錯誤應該返回失敗"
    assert_equal "檔案處理失敗", result[:error]
  end
  
  # ==================== 資料庫錯誤處理測試 ====================
  
  def test_handle_database_error_with_record_invalid
    error = ActiveRecord::RecordInvalid.new(create_invalid_record)
    
    result = ErrorHandler.handle_database_error(error, @context)
    
    assert_not result[:success], "記錄無效錯誤應該返回失敗"
    assert_equal "資料驗證失敗", result[:error]
    assert_equal "validation", result[:type]
  end
  
  def test_handle_database_error_with_record_not_found
    error = ActiveRecord::RecordNotFound.new("記錄不存在")
    
    result = ErrorHandler.handle_database_error(error, @context)
    
    assert_not result[:success], "記錄不存在錯誤應該返回失敗"
    assert_equal "記錄不存在", result[:error]
    assert_equal "not_found", result[:type]
  end
  
  def test_handle_database_error_with_statement_invalid
    error = ActiveRecord::StatementInvalid.new("SQL 語句無效")
    
    result = ErrorHandler.handle_database_error(error, @context)
    
    assert_not result[:success], "SQL 語句錯誤應該返回失敗"
    assert_equal "資料庫操作失敗", result[:error]
    assert_equal "database", result[:type]
  end
  
  def test_handle_database_error_with_general_database_error
    error = StandardError.new("資料庫錯誤")
    
    result = ErrorHandler.handle_database_error(error, @context)
    
    assert_not result[:success], "一般資料庫錯誤應該返回失敗"
    assert_equal "資料庫錯誤", result[:error]
    assert_equal "database", result[:type]
  end
  
  # ==================== 錯誤日誌記錄測試 ====================
  
  def test_log_security_error
    if defined?(SecurityError)
      error = SecurityError.new("安全錯誤", "high", { pattern: "taiwan_id" })
    else
      error = StandardError.new("安全錯誤")
    end
    
    # 測試日誌記錄（這裡只是檢查方法是否正常執行）
    assert_nothing_raised do
      # 使用 send 調用私有方法
      ErrorHandler.send(:log_security_error, error, @context)
    end
  end
  
  def test_log_timeout_error
    error = Timeout::Error.new("處理超時")
    
    # 測試日誌記錄
    assert_nothing_raised do
      ErrorHandler.send(:log_timeout_error, error, @context)
    end
  end
  
  def test_log_general_error
    error = StandardError.new("一般錯誤")
    
    # 測試日誌記錄
    assert_nothing_raised do
      ErrorHandler.send(:log_general_error, error, @context)
    end
  end
  
  def test_log_unknown_error
    error = Exception.new("未知錯誤")
    
    # 測試日誌記錄
    assert_nothing_raised do
      ErrorHandler.send(:log_unknown_error, error, @context)
    end
  end
  
  # ==================== 錯誤類型分類測試 ====================
  
  def test_error_type_classification
    # 測試不同錯誤類型的分類
    if defined?(SecurityError)
      security_error = SecurityError.new("安全錯誤")
    else
      security_error = StandardError.new("安全錯誤")
    end
    timeout_error = Timeout::Error.new("超時錯誤")
    standard_error = StandardError.new("一般錯誤")
    unknown_error = Exception.new("未知錯誤")
    
    if defined?(SecurityError)
      assert_equal "security", ErrorHandler.handle_detection_error(security_error)[:type]
    else
      assert_equal "general", ErrorHandler.handle_detection_error(security_error)[:type]
    end
    assert_equal "timeout", ErrorHandler.handle_detection_error(timeout_error)[:type]
    assert_equal "general", ErrorHandler.handle_detection_error(standard_error)[:type]
    assert_equal "unknown", ErrorHandler.handle_detection_error(unknown_error)[:type]
  end
  
  # ==================== 錯誤訊息格式測試 ====================
  
  def test_error_message_formatting
    error = StandardError.new("測試錯誤訊息")
    
    result = ErrorHandler.handle_detection_error(error, @context)
    
    assert_not result[:success], "錯誤應該返回失敗"
    assert result[:error].is_a?(String), "錯誤訊息應該是字串"
    assert_not result[:error].empty?, "錯誤訊息不應該為空"
  end
  
  def test_file_error_message_formatting
    error = FileSizeLimitExceededError.new("檔案大小錯誤")
    
    result = ErrorHandler.handle_file_error(error, { max_size: 100 })
    
    assert_not result[:success], "檔案錯誤應該返回失敗"
    assert_includes result[:error], "100MB", "錯誤訊息應該包含檔案大小限制"
  end
  
  # ==================== 錯誤上下文處理測試 ====================
  
  def test_error_context_handling
    context = {
      user_id: 123,
      project_id: 456,
      operation: 'file_scan',
      timestamp: Time.now
    }
    
    error = StandardError.new("上下文錯誤")
    
    result = ErrorHandler.handle_detection_error(error, context)
    
    assert_not result[:success], "上下文錯誤應該返回失敗"
    # 檢查上下文是否被正確處理（這裡只是檢查方法是否正常執行）
    assert_not_nil result, "應該返回錯誤結果"
  end
  
  # ==================== 邊界情況測試 ====================
  
  def test_handle_detection_error_with_nil_error
    # 測試 nil 錯誤處理
    result = ErrorHandler.handle_detection_error(nil, @context)
    
    assert_not result[:success], "nil 錯誤應該返回失敗"
    assert_equal "未知錯誤", result[:error]
    assert_equal "unknown", result[:type]
  end
  
  def test_handle_file_error_with_nil_error
    # 測試 nil 檔案錯誤處理
    result = ErrorHandler.handle_file_error(nil, @file_info)
    
    assert_not result[:success], "nil 檔案錯誤應該返回失敗"
    assert_equal "檔案處理失敗", result[:error]
    assert_equal "file_processing", result[:type]
  end
  
  def test_handle_database_error_with_nil_error
    # 測試 nil 資料庫錯誤處理
    result = ErrorHandler.handle_database_error(nil, @context)
    
    assert_not result[:success], "nil 資料庫錯誤應該返回失敗"
    assert_equal "資料庫錯誤", result[:error]
    assert_equal "database", result[:type]
  end
  
  # ==================== 效能測試 ====================
  
  def test_error_handling_performance
    # 測試錯誤處理的效能
    error = StandardError.new("效能測試錯誤")
    
    start_time = Time.now
    100.times do
      ErrorHandler.handle_detection_error(error, @context)
    end
    end_time = Time.now
    
    processing_time = end_time - start_time
    
    assert processing_time < 1, "錯誤處理應該在1秒內完成100次"
  end
  
  private
  
  def create_invalid_record
    # 創建一個無效的記錄用於測試
    record = Object.new
    def record.errors
      errors_obj = Object.new
      def errors_obj.full_messages
        ["欄位不能為空"]
      end
      errors_obj
    end
    record
  end
end

# 定義測試用的錯誤類別
class FileSizeLimitExceededError < StandardError; end
class UnsupportedFileFormatError < StandardError; end
class CorruptedFileError < StandardError; end

# 執行測試
if __FILE__ == $0
  puts "開始執行 ErrorHandlerTest 測試..."
  puts "=" * 50
  
  test = ErrorHandlerTest.new
  test.setup
  
  # 執行所有測試方法
  test_methods = ErrorHandlerTest.instance_methods.grep(/^test_/)
  
  test_methods.each do |method|
    puts "\n執行測試: #{method}"
    begin
      test.send(method)
      puts "✅ #{method} - 完成"
    rescue => e
      puts "❌ #{method} - 失敗: #{e.message}"
    end
    puts "-" * 30
  end
  
  puts "\n" + "=" * 50
  puts "測試完成！"
end
