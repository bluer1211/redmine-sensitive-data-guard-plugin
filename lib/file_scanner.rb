# frozen_string_literal: true

# 檔案掃描器
# 負責掃描上傳檔案中的敏感資料
class FileScanner
  include Redmine::I18n
  
  attr_reader :detector, :max_file_size_mb, :supported_extensions

  def initialize(settings = {})
    @detector = SimpleSensitiveDataDetector.new
    @max_file_size_mb = settings['max_file_size_mb'] || 50
    @supported_extensions = settings['supported_extensions'] || default_supported_extensions
  end

  # 掃描檔案
  def scan_file(file_path, original_filename = nil)
    return scan_result(false, '檔案路徑不能為空') if file_path.blank?
    
    # 檢查檔案是否存在
    unless File.exist?(file_path)
      return scan_result(false, '檔案不存在')
    end

    # 檢查檔案大小
    begin
      file_size_mb = File.size(file_path) / (1024.0 * 1024.0)
      if file_size_mb > @max_file_size_mb
        return scan_result(false, "檔案大小超過限制 (#{file_size_mb.round(2)}MB > #{@max_file_size_mb}MB)")
      end
    rescue => e
      return scan_result(false, "無法讀取檔案大小: #{e.message}")
    end

    # 檢查檔案類型
    extension = get_file_extension(original_filename || file_path)
    unless @supported_extensions.include?(extension.downcase)
      return scan_result(false, "不支援的檔案類型: #{extension}")
    end

    # 根據檔案類型進行掃描
    case extension.downcase
    when 'txt', 'log', 'md', 'json', 'xml', 'csv'
      scan_text_file(file_path)
    when 'doc', 'docx'
      scan_word_document(file_path)
    when 'xls', 'xlsx'
      scan_excel_document(file_path)
    when 'pdf'
      scan_pdf_document(file_path)
    else
      scan_text_file(file_path) # 預設當作文字檔案處理
    end
  end

  # 掃描文字檔案
  def scan_text_file(file_path)
    begin
      content = extract_text_from_text_file(file_path)
      scan_content(content)
    rescue => e
      scan_result(false, "讀取檔案失敗: #{e.message}")
    end
  end

  # 掃描 Word 文件
  def scan_word_document(file_path)
    begin
      content = extract_text_from_word(file_path)
      scan_content(content)
    rescue => e
      scan_result(false, "讀取 Word 文件失敗: #{e.message}")
    end
  end

  # 掃描 Excel 文件
  def scan_excel_document(file_path)
    begin
      content = extract_text_from_excel(file_path)
      scan_content(content)
    rescue => e
      scan_result(false, "讀取 Excel 文件失敗: #{e.message}")
    end
  end

  # 掃描 PDF 文件
  def scan_pdf_document(file_path)
    begin
      content = extract_text_from_pdf(file_path)
      scan_content(content)
    rescue => e
      scan_result(false, "讀取 PDF 文件失敗: #{e.message}")
    end
  end

  # 掃描內容
  def scan_content(content)
    return scan_result(false, '檔案內容為空') if content.blank?

    begin
      result = @detector.scan(content)
      
      if result.detected?
        scan_result(true, "檢測到敏感資料", result)
      else
        scan_result(false, "未檢測到敏感資料")
      end
    rescue => e
      scan_result(false, "掃描內容失敗: #{e.message}")
    end
  end

  # 檢查檔案是否安全
  def file_safe?(file_path, original_filename = nil)
    result = scan_file(file_path, original_filename)
    !result[:detected]
  end

  private

  def default_supported_extensions
    %w[txt log md json xml csv doc docx xls xlsx pdf]
  end

  def get_file_extension(filename)
    File.extname(filename).gsub('.', '').downcase
  end

  def extract_text_from_text_file(file_path)
    begin
      # 嘗試偵測編碼
      content = File.read(file_path, encoding: 'BOM|UTF-8')
      content.force_encoding('UTF-8')
      content
    rescue => e
      Rails.logger.error "讀取文字檔案失敗: #{e.message}"
      ''
    end
  end

  def extract_text_from_word(file_path)
    begin
      # 簡化的 Word 文件文字提取
      # 這裡可以整合第三方 gem 如 'docx' 或 'ruby-docx'
      content = "Word 文件內容提取功能需要額外的 gem 支援"
      content
    rescue => e
      Rails.logger.error "讀取 Word 文件失敗: #{e.message}"
      ''
    end
  end

  def extract_text_from_excel(file_path)
    begin
      # 簡化的 Excel 文件文字提取
      # 這裡可以整合第三方 gem 如 'roo' 或 'creek'
      content = "Excel 文件內容提取功能需要額外的 gem 支援"
      content
    rescue => e
      Rails.logger.error "讀取 Excel 文件失敗: #{e.message}"
      ''
    end
  end

  def extract_text_from_pdf(file_path)
    begin
      # 簡化的 PDF 文件文字提取
      # 這裡可以整合第三方 gem 如 'pdf-reader' 或 'pdf-forms'
      content = "PDF 文件內容提取功能需要額外的 gem 支援"
      content
    rescue => e
      Rails.logger.error "讀取 PDF 文件失敗: #{e.message}"
      ''
    end
  end

  def scan_result(detected, message, detection_result = nil)
    {
      detected: detected,
      message: message,
      risk_level: detection_result&.risk_level || (detected ? 'medium' : 'low'),
      patterns: detection_result&.detections&.map { |d| d[:type] } || [],
      detection_count: detection_result&.total_matches || 0,
      details: detection_result&.detections || [],
      preview: message
    }
  end
end
