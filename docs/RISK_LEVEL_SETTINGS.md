# 🔧 Redmine 敏感資料防護插件 - 風險等級設定指南

## 📋 設定概覽

本插件提供三個風險等級的詳細設定，每個等級都可以單獨啟用/停用，並且每個具體項目都可以獨立設定。本指南已於 2.0.3 版本進行了更新，反映了最新的程式碼修正和改進。

---

## 🔴 高風險設定

### 啟用高風險偵測
- **設定項目：** `enable_high_risk_detection`
- **預設值：** 啟用
- **說明：** 控制是否啟用高風險內容的偵測

### 高風險項目

#### 1. 台灣身分證號碼
- **設定項目：** `enable_taiwan_id_detection`
- **偵測模式：** `[A-Z][12]\d{8}`
- **風險說明：** 個人身份識別資訊，受個資法保護
- **處理方式：** 阻擋提交，需要覆蓋權限
- **範例：** `A123456789`, `B987654321`

#### 2. 信用卡號碼
- **設定項目：** `enable_credit_card_detection`
- **偵測模式：** `\d{4}[\s-]?\d{4}[\s-]?\d{4}[\s-]?\d{4}`
- **風險說明：** 金融敏感資訊，可能導致詐騙
- **處理方式：** 阻擋提交，需要覆蓋權限
- **範例：** `1234-5678-9012-3456`, `1234567890123456`

#### 3. API 金鑰或密碼
- **設定項目：** `enable_password_keyword_detection`
- **偵測模式：** `password|pwd|passwd|secret|key|token|api_key|auth`
- **風險說明：** 可能包含系統密碼或 API 金鑰
- **處理方式：** 阻擋提交，需要覆蓋權限
- **範例：**
  ```
  password: mysecret123
  API_KEY=abc123def456
  auth_token: xyz789
  ```

#### 4. 帳號密碼組合
- **設定項目：** `enable_credential_combination_detection`
- **偵測模式：** `username:password` 或 `user=xxx&password=xxx`
- **風險說明：** 包含完整的登入憑證，可直接用於系統入侵
- **處理方式：** 立即阻擋，需要管理員權限才能覆蓋
- **範例：**
  ```
  username=admin&password=123456
  user: admin, password: secret123
  login=test&pwd=password123
  ```

#### 5. 資料庫連線字串
- **設定項目：** `enable_database_connection_detection`
- **偵測模式：** `mysql://|postgresql://|mongodb://|redis://`
- **風險說明：** 包含資料庫認證資訊
- **處理方式：** 阻擋提交，需要覆蓋權限
- **範例：**
  ```
  mysql://user:password@localhost:3306/db
  postgresql://admin:secret@db.example.com:5432/mydb
  ```

### 高風險處理策略
- **設定項目：** `high_risk_strategy`
- **選項：** 阻擋、警告、記錄
- **預設值：** 阻擋
- **建議：** 根據組織安全政策調整

---

## 🟡 中風險設定

### 啟用中風險偵測
- **設定項目：** `enable_medium_risk_detection`
- **預設值：** 啟用
- **說明：** 控制是否啟用中風險內容的偵測

### 中風險項目

#### 1. 台灣手機號碼
- **設定項目：** `enable_taiwan_mobile_detection`
- **偵測模式：** `09\d{2}[\s-]?\d{3}[\s-]?\d{3}`
- **風險說明：** 個人聯繫資訊，可能被濫用
- **處理方式：** 警告提示，允許覆蓋
- **範例：** `0912345678`, `09-123-4567`

#### 2. Email 地址
- **設定項目：** `enable_email_detection`
- **偵測模式：** `[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}`
- **風險說明：** 個人聯繫資訊，可能被用於垃圾郵件
- **處理方式：** 警告提示，允許覆蓋
- **範例：** `user@example.com`, `test.user@domain.co.uk`

#### 3. 內部 IP 位址
- **設定項目：** `enable_internal_ip_detection`
- **偵測模式：** `192\.168\.|10\.|172\.(1[6-9]|2[0-9]|3[01])\.`
- **風險說明：** 內部網路資訊，可能暴露網路架構
- **處理方式：** 警告提示，允許覆蓋
- **範例：** `192.168.1.1`, `10.0.0.1`, `172.16.1.1`

### 中風險處理策略
- **設定項目：** `medium_risk_strategy`
- **選項：** 阻擋、警告、記錄
- **預設值：** 警告
- **建議：** 根據組織安全政策調整

---

## 🟢 低風險設定

### 啟用低風險偵測
- **設定項目：** `enable_low_risk_detection`
- **預設值：** 啟用
- **說明：** 控制是否啟用低風險內容的偵測

### 低風險項目

#### 1. 外部 IP 位址
- **設定項目：** `enable_external_ip_detection`
- **偵測模式：** `(?:[0-9]{1,3}\.){3}[0-9]{1,3}`
- **風險說明：** 公開網路資訊，風險較低
- **處理方式：** 僅記錄，不阻擋
- **範例：** `203.74.205.38`, `8.8.8.8`

### 低風險處理策略
- **設定項目：** `low_risk_strategy`
- **選項：** 阻擋、警告、記錄
- **預設值：** 記錄
- **建議：** 保持預設的記錄設定

---

## ⚙️ 進階設定

### 檔案掃描設定
- **啟用檔案掃描：** `enable_file_scanning`
- **最大檔案大小：** `max_file_size_mb` (預設：50MB)
- **支援的檔案類型：** TXT, CSV, DOC, DOCX, XLS, XLSX, PDF

### 通知設定
- **Email 通知：** `email_notifications`
- **Slack 通知：** `slack_webhook_url`
- **通知頻率：** `notification_frequency`

### 日誌保留設定
- **高風險記錄保留天數：** `retention_days_high_risk` (預設：2555天，7年)
- **一般記錄保留天數：** `retention_days_standard` (預設：1095天，3年)
- **覆蓋記錄保留天數：** `retention_days_override` (預設：1825天，5年)
- **自動清理：** `auto_cleanup_enabled`

### 效能設定
- **非同步處理：** `async_processing`
- **批次大小：** `batch_size`
- **Redis 快取：** `redis_cache_enabled`
- **掃描超時：** `scan_timeout`

---

## 🔄 設定更新

### 版本 2.0.3 更新重點

#### 1. 風險等級調整
- **移除極高風險等級**：簡化為三個風險等級
- **統一根險等級命名**：高風險、中風險、低風險
- **改進風險評估邏輯**：更精確的風險分類

#### 2. 錯誤處理改進
- **統一錯誤處理機制**：標準化的錯誤處理
- **錯誤分類和統計**：詳細的錯誤資訊記錄
- **錯誤通知機制**：可配置的錯誤通知

#### 3. 效能優化
- **快取機制改進**：更穩定的快取管理
- **檔案掃描優化**：更快速的檔案處理
- **資料庫查詢優化**：更高效的資料庫操作

#### 4. 安全性增強
- **權限檢查改進**：更嚴格的權限驗證
- **敏感資料遮蔽**：更好的資料保護
- **審計追蹤**：更完整的操作記錄

---

## 📊 設定範例

### 基本設定範例
```yaml
# 基本設定
enabled: true
scan_office_documents: true
max_file_size_mb: 50

# 風險等級設定
enable_high_risk_detection: true
enable_medium_risk_detection: true
enable_low_risk_detection: true

# 處理策略
high_risk_strategy: 'block'
medium_risk_strategy: 'warn'
low_risk_strategy: 'log'

# 日誌保留
retention_days_high_risk: 2555
retention_days_standard: 1095
retention_days_override: 1825
auto_cleanup_enabled: true
```

### 進階設定範例
```yaml
# 通知設定
email_notifications: true
slack_webhook_url: 'https://hooks.slack.com/services/...'
notification_frequency: 'immediate'

# 效能設定
async_processing: true
batch_size: 100
redis_cache_enabled: false
scan_timeout: 30

# 個別項目設定
enable_credential_combination_detection: true
enable_taiwan_id_detection: true
enable_credit_card_detection: true
enable_password_keyword_detection: true
enable_database_connection_detection: true
enable_taiwan_mobile_detection: true
enable_internal_ip_detection: true
enable_email_detection: true
```

---

## 🔍 故障排除

### 常見問題

#### 1. 偵測不準確
- **問題：** 敏感資料未被偵測到或誤報
- **解決方案：** 檢查偵測規則設定，調整正規表示式

#### 2. 效能問題
- **問題：** 檔案掃描速度慢
- **解決方案：** 調整檔案大小限制，啟用快取機制

#### 3. 權限問題
- **問題：** 無法覆蓋敏感資料偵測
- **解決方案：** 檢查用戶權限設定

#### 4. 日誌問題
- **問題：** 日誌記錄不完整
- **解決方案：** 檢查日誌保留設定，清理過期日誌

---

## 📞 支援

### 技術支援
- **GitHub Issues**：https://github.com/bluer1211/redmine-sensitive-data-guard-plugin/issues
- **文檔**：https://github.com/bluer1211/redmine-sensitive-data-guard-plugin/blob/main/README.md

### 開發者聯繫
- **開發者**：Jason Liu (bluer1211)
- **Email**：support@example.com

---

**指南版本：** 2.0.3  
**最後更新：** 2025-01-27
