# 資料庫種子檔案 - 初始化預設資料

puts "🌱 開始初始化 Redmine 敏感資料防護插件..."

# 檢查是否為開發環境
is_development = Rails.env.development? || Rails.env.test?

# 檢查是否已有資料
if DetectionRule.count == 0
  puts "📋 建立預設偵測規則..."
  
  # 建立預設偵測規則
  rules = [
    {
      name: '台灣身分證號',
      pattern: '^[A-Z][12]\d{8}$',
      risk_level: 'high',
      description: '台灣身分證號格式偵測',
      rule_type: 'regex',
      priority: 100
    },
    {
      name: '信用卡號',
      pattern: '\b\d{4}[\-\s]?\d{4}[\-\s]?\d{4}[\-\s]?\d{4}\b',
      risk_level: 'high',
      description: '信用卡號格式偵測',
      rule_type: 'regex',
      priority: 90
    },
    {
      name: 'API Key',
      pattern: '(?i)(?:api[_-]?key|secret|token)\s*[:=]\s*[''"]?[a-zA-Z0-9]{20,}[''"]?',
      risk_level: 'high',
      description: 'API Key、Secret、Token 偵測',
      rule_type: 'regex',
      priority: 85
    },
    {
      name: '帳號密碼組合',
      pattern: '(?i)(?:user(?:name|id)?|login|account)\s*[:=]\s*[''"]?[^''"\s]+[''"]?\s*(?:password|pwd|pass)\s*[:=]\s*[''"]?[^''"\s]{6,}[''"]?',
      risk_level: 'high',
      description: '使用者帳號密碼組合偵測',
      rule_type: 'regex',
      priority: 80
    },
    {
      name: '台灣手機號碼',
      pattern: '09\d{2}[\-\s]?\d{3}[\-\s]?\d{3}',
      risk_level: 'medium',
      description: '台灣手機號碼格式偵測',
      rule_type: 'regex',
      priority: 70
    },
    {
      name: 'Email 地址',
      pattern: '\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b',
      risk_level: 'medium',
      description: 'Email 格式偵測',
      rule_type: 'regex',
      priority: 60
    },
    {
      name: '內部 IP 位址',
      pattern: '\b(?:192\.168\.|10\.|172\.(?:1[6-9]|2[0-9]|3[01])\.)\d{1,3}\.\d{1,3}\b',
      risk_level: 'medium',
      description: '內部 IP 位址偵測',
      rule_type: 'regex',
      priority: 50
    },
    {
      name: '外部 IP 位址',
      pattern: '\b(?:[0-9]{1,3}\.){3}[0-9]{1,3}\b',
      risk_level: 'low',
      description: '外部 IP 位址偵測',
      rule_type: 'regex',
      priority: 40
    }
  ]
  
  # 如果是開發環境，添加額外的開發用規則
  if is_development
    development_rules = [
      {
        name: '開發環境測試',
        pattern: 'test|dev|development',
        risk_level: 'low',
        description: '開發環境測試用規則',
        rule_type: 'regex',
        priority: 10
      },
      {
        name: '範例資料',
        pattern: 'example|sample|demo',
        risk_level: 'low',
        description: '範例資料偵測',
        rule_type: 'regex',
        priority: 5
      }
    ]
    rules.concat(development_rules)
  end
  
  rules.each do |rule_data|
    DetectionRule.create!(rule_data)
  end
  
  puts "✅ 已建立 #{rules.length} 個預設偵測規則"
else
  puts "ℹ️  偵測規則已存在，跳過初始化"
end

# 建立預設白名單規則
if WhitelistRule.count == 0
  puts "📋 建立預設白名單規則..."
  
  # 取得第一個管理員用戶
  admin_user = User.where(admin: true).first || User.first
  
  whitelist_rules = [
    {
      name: '測試環境 IP',
      whitelist_type: 'ip',
      pattern: '192.168.1.0/24',
      match_type: 'wildcard',
      description: '測試環境 IP 範圍',
      category: 'development',
      created_by: admin_user
    },
    {
      name: '範例資料',
      whitelist_type: 'content',
      pattern: 'example|test|sample|demo',
      match_type: 'regex',
      description: '範例和測試資料',
      category: 'general',
      created_by: admin_user
    },
    {
      name: '系統管理員',
      whitelist_type: 'user',
      pattern: 'admin',
      match_type: 'exact',
      description: '系統管理員帳號',
      category: 'system',
      created_by: admin_user
    }
  ]
  
  # 如果是開發環境，添加額外的開發用白名單規則
  if is_development
    development_whitelist_rules = [
      {
        name: '開發環境 IP',
        whitelist_type: 'ip',
        pattern: '127.0.0.1|localhost',
        match_type: 'regex',
        description: '本地開發環境 IP',
        category: 'development',
        created_by: admin_user
      },
      {
        name: '開發測試資料',
        whitelist_type: 'content',
        pattern: 'dev|test|debug|localhost',
        match_type: 'regex',
        description: '開發測試資料',
        category: 'development',
        created_by: admin_user
      },
      {
        name: '開發用戶',
        whitelist_type: 'user',
        pattern: 'developer|test|admin',
        match_type: 'regex',
        description: '開發測試用戶',
        category: 'development',
        created_by: admin_user
      }
    ]
    whitelist_rules.concat(development_whitelist_rules)
  end
  
  whitelist_rules.each do |rule_data|
    WhitelistRule.create!(rule_data)
  end
  
  puts "✅ 已建立 #{whitelist_rules.length} 個預設白名單規則"
else
  puts "ℹ️  白名單規則已存在，跳過初始化"
end

puts "🎉 Redmine 敏感資料防護插件初始化完成！"
puts "📊 統計資訊："
puts "   - 偵測規則：#{DetectionRule.count} 個"
puts "   - 白名單規則：#{WhitelistRule.count} 個"
puts "   - 操作日誌：#{SensitiveOperationLog.count} 筆"

# 如果是開發環境，顯示額外的開發資訊
if is_development
  puts "🔧 開發環境資訊："
  puts "   - 環境：#{Rails.env}"
  puts "   - 資料庫：#{ActiveRecord::Base.connection.adapter_name}"
  puts "   - 已啟用開發模式專用規則"
end 