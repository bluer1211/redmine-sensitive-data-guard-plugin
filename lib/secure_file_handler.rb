# frozen_string_literal: true

# 安全檔案處理器
# 負責安全地處理檔案上傳、掃描和驗證
class SecureFileHandler
  include Redmine::I18n
  
  attr_reader :max_file_size, :allowed_extensions, :scan_timeout
  
  def initialize(settings = {})
    @max_file_size = (settings['max_file_size_mb'] || 50) * 1024 * 1024 # 轉換為 bytes
    @allowed_extensions = settings['allowed_extensions'] || default_allowed_extensions
    @scan_timeout = settings['scan_timeout'] || 30 # 秒
  end
  
  # 安全地處理檔案上傳
  def process_upload(file, user, project = nil)
    return error_result('檔案不能為空') if file.blank?
    
    # 基本驗證
    validation_result = validate_file(file)
    return validation_result unless validation_result[:valid]
    
    # 檔案完整性檢查
    integrity_result = check_file_integrity(file)
    return integrity_result unless integrity_result[:valid]
    
    # 安全掃描
    scan_result = secure_scan(file)
    return scan_result unless scan_result[:valid]
    
    # 記錄處理結果
    log_file_processing(file, user, project, scan_result)
    
    success_result(scan_result)
  rescue => e
    error_result("檔案處理失敗: #{e.message}")
  end
  
  # 驗證檔案
  def validate_file(file)
    # 檢查檔案大小
    if file.size > @max_file_size
      return error_result("檔案大小超過限制 (#{format_file_size(file.size)} > #{format_file_size(@max_file_size)})")
    end
    
    # 檢查檔案類型
    extension = get_file_extension(file.original_filename)
    unless @allowed_extensions.include?(extension.downcase)
      return error_result("不支援的檔案類型: #{extension}")
    end
    
    # 檢查檔案名稱安全性
    unless safe_filename?(file.original_filename)
      return error_result("檔案名稱包含不安全字符")
    end
    
    # 檢查檔案內容類型
    unless safe_content_type?(file.content_type)
      return error_result("不支援的內容類型: #{file.content_type}")
    end
    
    success_result
  end
  
  # 檢查檔案完整性
  def check_file_integrity(file)
    begin
      # 檢查檔案是否可讀
      unless File.readable?(file.path)
        return error_result("檔案無法讀取")
      end
      
      # 檢查檔案是否為空
      if File.size(file.path) == 0
        return error_result("檔案為空")
      end
      
      # 檢查檔案是否損壞（基本檢查）
      if corrupted_file?(file.path)
        return error_result("檔案可能已損壞")
      end
      
      success_result
    rescue => e
      error_result("檔案完整性檢查失敗: #{e.message}")
    end
  end
  
  # 安全掃描
  def secure_scan(file)
    begin
      # 設定掃描超時
      Timeout::timeout(@scan_timeout) do
        scanner = FileScanner.new
        result = scanner.scan_file(file.path, file.original_filename)
        
        if result[:detected]
          return error_result("檢測到敏感資料: #{result[:message]}")
        end
        
        success_result(result)
      end
    rescue Timeout::Error
      error_result("掃描超時")
    rescue => e
      error_result("掃描失敗: #{e.message}")
    end
  end
  
  # 批量處理檔案
  def batch_process(files, user, project = nil)
    results = []
    files.each do |file|
      result = process_upload(file, user, project)
      results << {
        filename: file.original_filename,
        result: result
      }
    end
    results
  end
  
  # 清理臨時檔案
  def cleanup_temp_files(temp_files)
    temp_files.each do |temp_file|
      begin
        File.delete(temp_file) if File.exist?(temp_file)
      rescue => e
        Rails.logger.error "清理臨時檔案失敗: #{e.message}"
      end
    end
  end
  
  private
  
  def default_allowed_extensions
    %w[txt log md json xml csv doc docx xls xlsx pdf]
  end
  
  def get_file_extension(filename)
    return '' if filename.blank?
    File.extname(filename).gsub('.', '').downcase
  end
  
  def safe_filename?(filename)
    return false if filename.blank?
    
    # 檢查是否包含危險字符
    dangerous_chars = /[<>:"\/\\|?*]/
    return false if filename.match?(dangerous_chars)
    
    # 檢查是否為保留名稱
    reserved_names = %w[CON PRN AUX NUL COM1 COM2 COM3 COM4 COM5 COM6 COM7 COM8 COM9 LPT1 LPT2 LPT3 LPT4 LPT5 LPT6 LPT7 LPT8 LPT9]
    return false if reserved_names.include?(filename.upcase)
    
    true
  end
  
  def safe_content_type?(content_type)
    return false if content_type.blank?
    
    # 允許的內容類型
    allowed_types = [
      'text/plain',
      'text/csv',
      'application/json',
      'application/xml',
      'application/pdf',
      'application/msword',
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'application/vnd.ms-excel',
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
    ]
    
    allowed_types.include?(content_type.downcase)
  end
  
  def corrupted_file?(file_path)
    begin
      # 基本檢查：嘗試讀取檔案
      File.read(file_path, 1)
      false
    rescue
      true
    end
  end
  
  def format_file_size(bytes)
    return "0 B" if bytes == 0
    
    units = ['B', 'KB', 'MB', 'GB']
    exp = (Math.log(bytes) / Math.log(1024)).to_i
    exp = [exp, units.length - 1].min
    
    "%.1f %s" % [bytes.to_f / (1024 ** exp), units[exp]]
  end
  
  def log_file_processing(file, user, project, scan_result)
    return unless defined?(SensitiveOperationLog)

    begin
      SensitiveOperationLog.create!(
        user: user,
        project: project,
        operation_type: 'file_upload',
        content_type: 'attachment',
        detected_patterns: scan_result[:detections]&.join(','),
        content_preview: "檔案: #{file.original_filename}",
        file_type: get_file_extension(file.original_filename),
        file_size: file.size,
        risk_level: scan_result[:risk_level] || 'low',
        ip_address: get_user_ip_address,
        user_agent: get_user_agent
      )
    rescue => e
      Rails.logger.error "記錄檔案處理失敗: #{e.message}"
    end
  end
  
  def get_user_ip_address
    if defined?(request) && request.respond_to?(:remote_ip)
      request.remote_ip
    else
      'unknown'
    end
  end
  
  def get_user_agent
    if defined?(request) && request.respond_to?(:user_agent)
      request.user_agent
    else
      'unknown'
    end
  end
  
  def success_result(data = {})
    { valid: true, data: data }
  end
  
  def error_result(message)
    { valid: false, error: message }
  end
end
