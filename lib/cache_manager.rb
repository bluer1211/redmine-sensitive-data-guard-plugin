# frozen_string_literal: true

# 快取管理類別
class CacheManager
  include Redmine::I18n
  
  class << self
    # 快取鍵前綴
    CACHE_PREFIX = 'sensitive_data_guard'
    
    # 快取偵測規則
    def cache_detection_rules(rules, ttl = 1.hour)
      begin
        cache_key = "#{CACHE_PREFIX}:detection_rules"
        Rails.cache.write(cache_key, rules, expires_in: ttl)
        true
      rescue => e
        Rails.logger.error "快取偵測規則失敗: #{e.message}"
        false
      end
    end
    
    def get_cached_detection_rules
      begin
        cache_key = "#{CACHE_PREFIX}:detection_rules"
        Rails.cache.read(cache_key) || {}
      rescue => e
        Rails.logger.error "獲取快取偵測規則失敗: #{e.message}"
        {}
      end
    end
    
    # 快取檔案掃描結果
    def cache_file_scan_result(file_hash, result, ttl = 1.hour)
      begin
        cache_key = "#{CACHE_PREFIX}:file_scan:#{file_hash}"
        Rails.cache.write(cache_key, result, expires_in: ttl)
        true
      rescue => e
        Rails.logger.error "快取檔案掃描結果失敗: #{e.message}"
        false
      end
    end
    
    def get_cached_file_scan_result(file_hash)
      begin
        cache_key = "#{CACHE_PREFIX}:file_scan:#{file_hash}"
        Rails.cache.read(cache_key)
      rescue => e
        Rails.logger.error "獲取快取檔案掃描結果失敗: #{e.message}"
        nil
      end
    end
    
    # 清理快取
    def clear_cache(pattern = nil)
      begin
        if pattern
          Rails.cache.delete_matched("#{CACHE_PREFIX}:#{pattern}")
        else
          Rails.cache.delete_matched("#{CACHE_PREFIX}:*")
        end
        true
      rescue => e
        Rails.logger.error "清理快取失敗: #{e.message}"
        false
      end
    end
    
    # 快取健康檢查
    def cache_health_check
      begin
        {
          cache_available: Rails.cache.respond_to?(:read),
          total_requests: Rails.cache.read("#{CACHE_PREFIX}:total_requests") || 0,
          cache_hits: Rails.cache.read("#{CACHE_PREFIX}:cache_hits") || 0,
          hit_rate: calculate_hit_rate
        }
      rescue => e
        Rails.logger.error "快取健康檢查失敗: #{e.message}"
        {
          cache_available: false,
          total_requests: 0,
          cache_hits: 0,
          hit_rate: 0
        }
      end
    end
    
    # 記錄快取請求
    def record_cache_request(hit = false)
      begin
        Rails.cache.increment("#{CACHE_PREFIX}:total_requests", 1)
        Rails.cache.increment("#{CACHE_PREFIX}:cache_hits", 1) if hit
      rescue => e
        Rails.logger.error "記錄快取請求失敗: #{e.message}"
      end
    end
    
    private
    
    def calculate_hit_rate
      total_requests = Rails.cache.read("#{CACHE_PREFIX}:total_requests") || 0
      cache_hits = Rails.cache.read("#{CACHE_PREFIX}:cache_hits") || 0
      
      return 0 if total_requests == 0
      (cache_hits.to_f / total_requests * 100).round(2)
    end
  end
end
