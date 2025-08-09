# frozen_string_literal: true

# 簡化的敏感資料偵測引擎
# 使用基本的正規表示式來偵測常見的敏感資料模式

require 'digest'

class SimpleSensitiveDataDetector
  attr_reader :patterns, :detection_results

  def initialize
    @patterns = get_cached_patterns
    @detection_results = []
  end

  # 掃描內容中的敏感資料
  def scan(content)
    return empty_result if content.blank?

    begin
      # 檢查快取
      content_hash = Digest::MD5.hexdigest(content.to_s)
      cached_result = CacheManager.get_cached_file_scan_result(content_hash)
      
      if cached_result
        CacheManager.record_cache_request(true)
        return cached_result
      end

      CacheManager.record_cache_request(false)
      @detection_results = []
      content_str = content.to_s

      @patterns.each do |pattern_name, pattern_config|
        begin
          matches = find_matches(content_str, pattern_config[:regex], pattern_config[:options])
          
          if matches.any?
            @detection_results << DetectionResult.new(
              pattern_name: pattern_name,
              pattern_type: pattern_config[:type],
              matches: matches,
              risk_level: pattern_config[:risk_level],
              description: pattern_config[:description]
            )
          end
        rescue => e
          Rails.logger.error "偵測模式 #{pattern_name} 執行失敗: #{e.message}"
          next
        end
      end

      result = DetectionSummary.new(@detection_results)
      
      # 快取結果
      begin
        CacheManager.cache_file_scan_result(content_hash, result)
      rescue => e
        Rails.logger.error "快取結果失敗: #{e.message}"
      end
      
      result
    rescue => e
      ErrorHandler.handle_detection_error(e, { content_length: content.to_s.length })
      Rails.logger.error "敏感資料偵測失敗: #{e.message}"
      empty_result
    end
  end

  # 檢查是否包含敏感資料
  def contains_sensitive_data?(content)
    return false if content.blank?

    begin
      # 檢查快取
      content_hash = Digest::MD5.hexdigest(content.to_s)
      cached_result = CacheManager.get_cached_file_scan_result(content_hash)
      
      if cached_result
        CacheManager.record_cache_request(true)
        return cached_result.detected?
      end

      CacheManager.record_cache_request(false)
      content_str = content.to_s
      result = @patterns.any? do |_pattern_name, pattern_config|
        begin
          content_str.match?(pattern_config[:regex])
        rescue => e
          Rails.logger.error "檢查模式執行失敗: #{e.message}"
          false
        end
      end
      
      # 快取結果
      begin
        CacheManager.cache_file_scan_result(content_hash, result)
      rescue => e
        Rails.logger.error "快取結果失敗: #{e.message}"
      end
      
      result
    rescue => e
      Rails.logger.error "敏感資料檢查失敗: #{e.message}"
      false
    end
  end

  private

  def define_detection_patterns
    {
      'taiwan_id' => {
        regex: /\b[A-Z][12]\d{8}\b/,
        type: 'regex',
        risk_level: 'high',
        description: '台灣身分證號碼',
        options: {}
      },
      'credit_card' => {
        regex: /\b\d{4}[-\s]?\d{4}[-\s]?\d{4}[-\s]?\d{4}\b/,
        type: 'regex',
        risk_level: 'high',
        description: '信用卡號碼',
        options: {}
      },
      'api_key' => {
        regex: /(?i)(?:api[_-]?key|secret|token)\s*[:=]\s*['"]?[a-zA-Z0-9]{20,}['"]?/,
        type: 'regex',
        risk_level: 'high',
        description: 'API Key、Secret、Token',
        options: { case_insensitive: true }
      },
      'credential_combination' => {
        regex: /(?i)(?:user(?:name|id)?|login|account)\s*[:=]\s*['"]?[^'"\s]+['"]?\s*(?:password|pwd|pass)\s*[:=]\s*['"]?[^'"\s]{6,}['"]?/,
        type: 'regex',
        risk_level: 'high',
        description: '帳號密碼組合',
        options: { case_insensitive: true }
      },
      'taiwan_mobile' => {
        regex: /\b09\d{2}[-\s]?\d{3}[-\s]?\d{3}\b/,
        type: 'regex',
        risk_level: 'medium',
        description: '台灣手機號碼',
        options: {}
      },
      'email' => {
        regex: /\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b/,
        type: 'regex',
        risk_level: 'medium',
        description: 'Email 地址',
        options: {}
      },
      'internal_ip' => {
        regex: /\b(?:192\.168\.|10\.|172\.(?:1[6-9]|2[0-9]|3[01])\.)\d{1,3}\.\d{1,3}\b/,
        type: 'regex',
        risk_level: 'medium',
        description: '內部 IP 位址',
        options: {}
      },
      'external_ip' => {
        regex: /\b(?:[0-9]{1,3}\.){3}[0-9]{1,3}\b/,
        type: 'regex',
        risk_level: 'low',
        description: '外部 IP 位址',
        options: {}
      }
    }
  end

  def get_cached_patterns
    # 嘗試從快取獲取偵測規則
    cached_patterns = CacheManager.get_cached_detection_rules
    return cached_patterns unless cached_patterns.empty?

    # 如果快取沒有，重新載入規則
    patterns = define_detection_patterns
    
    # 快取規則
    begin
      CacheManager.cache_detection_rules(patterns)
    rescue => e
      Rails.logger.error "快取偵測規則失敗: #{e.message}"
    end
    
    patterns
  end

  def find_matches(content, regex, options = {})
    matches = []
    
    begin
      if options[:case_insensitive]
        content.scan(regex) { |match| matches << match }
      else
        content.scan(regex) { |match| matches << match }
      end
      
      matches.uniq
    rescue => e
      Rails.logger.error "正規表示式匹配失敗: #{e.message}"
      []
    end
  end

  def empty_result
    DetectionSummary.new([])
  end
end

# 偵測結果類別
class DetectionResult
  attr_reader :pattern_name, :pattern_type, :matches, :risk_level, :description

  def initialize(pattern_name:, pattern_type:, matches:, risk_level:, description:)
    @pattern_name = pattern_name
    @pattern_type = pattern_type
    @matches = matches
    @risk_level = risk_level
    @description = description
  end

  def detected?
    matches.any?
  end

  def match_count
    matches.length
  end

  def first_match
    matches.first
  end

  def to_h
    {
      type: pattern_name,
      description: description,
      matches: matches,
      count: match_count
    }
  end
end

# 偵測摘要類別
class DetectionSummary
  attr_reader :results

  def initialize(results)
    @results = results
  end

  def detected?
    results.any? { |result| result.detected? }
  end

  def total_matches
    results.inject(0) { |sum, result| sum + result.match_count }
  end

  def high_risk_detections
    results.select { |r| r.risk_level == 'high' }
  end

  def has_high_risk?
    results.any? { |r| r.risk_level == 'high' }
  end

  def all_matches
    results.map(&:matches).flatten
  end

  def risk_level
    if has_high_risk?
      'high'
    elsif results.any? { |r| r.risk_level == 'medium' }
      'medium'
    elsif results.any? { |r| r.risk_level == 'low' }
      'low'
    else
      'none'
    end
  end

  def detections
    results.map do |result|
      result.to_h
    end
  end
end
