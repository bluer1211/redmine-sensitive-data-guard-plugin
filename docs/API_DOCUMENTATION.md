# 🔌 Redmine 敏感資料防護插件 - API 文檔

## 📋 概述

本文檔描述了 Redmine 敏感資料防護插件的核心 API 介面。本文檔已於 2.0.3 版本進行了更新，反映了最新的程式碼修正和改進。

---

## 🎯 核心 API

### 1. 敏感資料偵測 API

#### 1.1 文字內容偵測

**端點：** `POST /sensitive_data_guard/detect`

**請求範例：**
```json
{
  "content": "用戶資料：身分證 A123456789，手機 0912345678",
  "content_type": "issue_description",
  "project_id": 1,
  "user_id": 1
}
```

**回應範例：**
```json
{
  "success": true,
  "detected": true,
  "risk_level": "high",
  "detections": [
    {
      "type": "taiwan_id",
      "description": "台灣身分證號碼",
      "matches": ["A123456789"],
      "count": 1
    }
  ],
  "total_matches": 1,
  "processing_time": 0.023
}
```

#### 1.2 檔案內容偵測

**端點：** `POST /sensitive_data_guard/detect_file`

**請求範例：**
```json
{
  "file": "base64_encoded_file_content",
  "filename": "test.txt",
  "content_type": "text/plain",
  "project_id": 1,
  "user_id": 1
}
```

**回應範例：**
```json
{
  "success": true,
  "detected": true,
  "risk_level": "high",
  "file_info": {
    "filename": "test.txt",
    "size": 1024,
    "content_type": "text/plain"
  },
  "detections": [
    {
      "type": "credit_card",
      "description": "信用卡號碼",
      "matches": ["1234-5678-9012-3456"],
      "count": 1
    }
  ]
}
```

### 2. 日誌管理 API

#### 2.1 查詢敏感操作日誌

**端點：** `GET /sensitive_logs`

**查詢參數：**
- `project_id`：專案 ID（可選）
- `risk_level`：風險等級（high/medium/low）
- `operation_type`：操作類型（detection/blocked_submission/warning/override）
- `start_date`：開始日期（YYYY-MM-DD）
- `end_date`：結束日期（YYYY-MM-DD）
- `page`：頁碼（預設：1）
- `per_page`：每頁數量（預設：100）

**回應範例：**
```json
{
  "logs": [
    {
      "id": 1,
      "user": {
        "id": 1,
        "name": "John Doe"
      },
      "project": {
        "id": 1,
        "name": "Test Project"
      },
      "operation_type": "detection",
      "content_type": "issue",
      "risk_level": "high",
      "detected_patterns": "taiwan_id,credit_card",
      "content_preview": "用戶資料：身分證 A123456789...",
      "ip_address": "192.168.1.1",
      "created_at": "2025-01-27T10:30:00Z"
    }
  ],
  "statistics": {
    "total_count": 150,
    "high_risk_count": 25,
    "medium_risk_count": 75,
    "low_risk_count": 50
  }
}
```

#### 2.2 查看特定日誌詳情

**端點：** `GET /sensitive_logs/:id`

**回應範例：**
```json
{
  "id": 1,
  "user": {
    "id": 1,
    "name": "John Doe"
  },
  "project": {
    "id": 1,
    "name": "Test Project"
  },
  "operation_type": "detection",
  "content_type": "issue",
  "risk_level": "high",
  "detected_patterns": "taiwan_id,credit_card",
  "content_preview": "用戶資料：身分證 A123456789，手機 0912345678",
  "file_type": null,
  "file_size": null,
  "ip_address": "192.168.1.1",
  "user_agent": "Mozilla/5.0...",
  "review_status": "pending",
  "requires_review": false,
  "created_at": "2025-01-27T10:30:00Z",
  "updated_at": "2025-01-27T10:30:00Z"
}
```

### 3. 審核管理 API

#### 3.1 查詢審核列表

**端點：** `GET /reviews`

**查詢參數：**
- `project_id`：專案 ID（可選）
- `review_status`：審核狀態（pending/approved/rejected）
- `risk_level`：風險等級（high/medium/low）
- `requires_review`：是否需要審核（true/false）
- `keyword`：搜尋關鍵字

**回應範例：**
```json
{
  "logs": [
    {
      "id": 1,
      "user": {
        "id": 1,
        "name": "John Doe"
      },
      "project": {
        "id": 1,
        "name": "Test Project"
      },
      "review_status": "pending",
      "requires_review": true,
      "risk_level": "high",
      "created_at": "2025-01-27T10:30:00Z"
    }
  ],
  "statistics": {
    "total_pending": 15,
    "total_approved": 120,
    "total_rejected": 5,
    "requires_review": 25
  }
}
```

#### 3.2 核准審核

**端點：** `POST /reviews/:id/approve`

**請求範例：**
```json
{
  "comment": "核准原因說明",
  "decision": "allow"
}
```

**回應範例：**
```json
{
  "success": true,
  "message": "已核准此記錄"
}
```

#### 3.3 拒絕審核

**端點：** `POST /reviews/:id/reject`

**請求範例：**
```json
{
  "comment": "拒絕原因說明",
  "decision": "block"
}
```

**回應範例：**
```json
{
  "success": true,
  "message": "已拒絕此記錄"
}
```

### 4. 效能監控 API

#### 4.1 效能監控概覽

**端點：** `GET /performance_monitor`

**回應範例：**
```json
{
  "system_health": {
    "cpu_usage": 45.2,
    "memory_usage": 67.8,
    "disk_io": 23.1
  },
  "cache_health": {
    "cache_available": true,
    "hit_rate": 78.5,
    "total_requests": 1250,
    "cache_hits": 982
  },
  "processing_stats": {
    "pending_jobs": 5,
    "completed_jobs": 1250,
    "failed_jobs": 3
  }
}
```

#### 4.2 即時效能數據

**端點：** `GET /performance_monitor/realtime`

**回應範例：**
```json
{
  "current_load": {
    "cpu_usage": 42.1,
    "memory_usage": 65.3,
    "active_connections": 25
  },
  "recent_activities": [
    {
      "timestamp": "2025-01-27T10:30:00Z",
      "type": "detection",
      "duration": 0.023
    }
  ]
}
```

---

## 🔧 錯誤處理

### 錯誤回應格式

所有 API 錯誤都遵循統一的錯誤回應格式：

```json
{
  "success": false,
  "error": "錯誤訊息",
  "type": "錯誤類型",
  "details": {
    "field": "具體錯誤欄位",
    "code": "錯誤代碼"
  }
}
```

### 常見錯誤代碼

| 錯誤代碼 | 說明 | HTTP 狀態碼 |
|---------|------|-------------|
| `validation_error` | 資料驗證失敗 | 400 |
| `permission_denied` | 權限不足 | 403 |
| `not_found` | 資源不存在 | 404 |
| `internal_error` | 內部伺服器錯誤 | 500 |
| `timeout` | 處理超時 | 408 |

---

## 🔐 認證與權限

### 認證方式

所有 API 都需要進行認證，支援以下認證方式：

1. **Session 認證**：使用 Redmine 的 session 認證
2. **API Key 認證**：使用 API Key 進行認證（未來版本支援）

### 權限要求

| API 端點 | 所需權限 |
|---------|---------|
| `GET /sensitive_logs` | `view_sensitive_logs` |
| `GET /reviews` | `review_sensitive_data` |
| `POST /reviews/:id/approve` | `review_sensitive_data` |
| `POST /reviews/:id/reject` | `review_sensitive_data` |
| `GET /performance_monitor` | `view_performance_monitor` |

---

## 📊 使用範例

### JavaScript 範例

```javascript
// 偵測敏感資料
async function detectSensitiveData(content) {
  const response = await fetch('/sensitive_data_guard/detect', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
    },
    body: JSON.stringify({
      content: content,
      content_type: 'issue_description',
      project_id: 1
    })
  });
  
  return await response.json();
}

// 查詢敏感日誌
async function getSensitiveLogs(projectId = null) {
  const params = new URLSearchParams();
  if (projectId) params.append('project_id', projectId);
  
  const response = await fetch(`/sensitive_logs?${params}`);
  return await response.json();
}
```

### Ruby 範例

```ruby
# 使用插件 API
require 'net/http'
require 'json'

class SensitiveDataGuardAPI
  def initialize(base_url, api_key = nil)
    @base_url = base_url
    @api_key = api_key
  end
  
  def detect_content(content, content_type = 'text')
    uri = URI("#{@base_url}/sensitive_data_guard/detect")
    request = Net::HTTP::Post.new(uri)
    request['Content-Type'] = 'application/json'
    
    request.body = {
      content: content,
      content_type: content_type
    }.to_json
    
    response = Net::HTTP.start(uri.hostname, uri.port) do |http|
      http.request(request)
    end
    
    JSON.parse(response.body)
  end
  
  def get_logs(project_id = nil)
    uri = URI("#{@base_url}/sensitive_logs")
    uri.query = URI.encode_www_form({ project_id: project_id }.compact)
    
    request = Net::HTTP::Get.new(uri)
    response = Net::HTTP.start(uri.hostname, uri.port) do |http|
      http.request(request)
    end
    
    JSON.parse(response.body)
  end
end
```

---

## 🔄 版本相容性

### API 版本控制

- **v2.0.3**：最新版本，支援完整的錯誤處理和安全性改進
- **v2.0.x**：支援 Redmine 6.0.6 和 Rails 7.2.2.1
- **v1.0.x**：舊版本，僅支援 Redmine 4.1.1

### 向後相容性

- API 端點保持向後相容
- 新增的欄位為可選欄位
- 移除的欄位會提供替代方案

---

## 📞 支援

### 技術支援

- **GitHub Issues**：https://github.com/bluer1211/redmine-sensitive-data-guard-plugin/issues
- **文檔**：https://github.com/bluer1211/redmine-sensitive-data-guard-plugin/blob/main/README.md

### 開發者聯繫

- **開發者**：Jason Liu (bluer1211)
- **Email**：support@example.com

---

**最後更新：** 2025-01-27  
**版本：** 2.0.3
