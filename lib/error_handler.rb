# frozen_string_literal: true

# 統一錯誤處理類別
class ErrorHandler
  include Redmine::I18n
  
  class << self
    # 處理偵測引擎錯誤
    def handle_detection_error(error, context = {})
      case error
      when SecurityError
        log_security_error(error, context)
        { success: false, error: error.message, type: 'security' }
      when Timeout::Error
        log_timeout_error(error, context)
        { success: false, error: '處理超時，請稍後再試', type: 'timeout' }
      when StandardError
        log_general_error(error, context)
        { success: false, error: '系統處理異常，請聯繫管理員', type: 'general' }
      else
        log_unknown_error(error, context)
        { success: false, error: '未知錯誤', type: 'unknown' }
      end
    end
    
    # 處理檔案處理錯誤
    def handle_file_error(error, file_info = {})
      case error
      when FileSizeLimitExceededError
        { success: false, error: "檔案大小超過限制 (#{file_info[:max_size]}MB)", type: 'file_size' }
      when UnsupportedFileFormatError
        { success: false, error: '不支援的檔案格式', type: 'file_format' }
      when CorruptedFileError
        { success: false, error: '檔案可能已損壞', type: 'file_corrupted' }
      else
        { success: false, error: '檔案處理失敗', type: 'file_processing' }
      end
    end
    
    # 處理資料庫錯誤
    def handle_database_error(error, context = {})
      case error
      when ActiveRecord::RecordInvalid
        { success: false, error: '資料驗證失敗', type: 'validation' }
      when ActiveRecord::RecordNotFound
        { success: false, error: '記錄不存在', type: 'not_found' }
      when ActiveRecord::StatementInvalid
        { success: false, error: '資料庫操作失敗', type: 'database' }
      else
        { success: false, error: '資料庫錯誤', type: 'database' }
      end
    end
    
    private
    
    def log_security_error(error, context)
      Rails.logger.error "安全錯誤: #{error.message} | 上下文: #{context}"
    end
    
    def log_timeout_error(error, context)
      Rails.logger.error "超時錯誤: #{error.message} | 上下文: #{context}"
    end
    
    def log_general_error(error, context)
      Rails.logger.error "一般錯誤: #{error.message} | 上下文: #{context}"
    end
    
    def log_unknown_error(error, context)
      Rails.logger.error "未知錯誤: #{error.class} - #{error.message} | 上下文: #{context}"
    end
  end
end

# 自定義錯誤類別
class FileSizeLimitExceededError < StandardError; end
class UnsupportedFileFormatError < StandardError; end
class CorruptedFileError < StandardError; end
