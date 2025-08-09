# 敏感資料防護插件測試文檔

## 概述

本目錄包含敏感資料防護插件的完整測試套件，涵蓋單元測試、整合測試和功能測試。

**測試版本：** v2.0.3  
**主要支援：** Redmine 6.0.6  
**最後更新：** 2025-01-27

## 測試環境要求

### 支援的 Redmine 版本
- **Redmine 6.0.6** ✅ (主要支援版本 - 完全測試和驗證)
- **Redmine 6.0.x** ✅ (相容 - 6.0.0 及以上版本)
- **Redmine 5.x** ⚠️ (部分功能可能受限 - 不建議使用)

### 系統要求
- **Ruby 版本**：3.0+ (推薦 3.3.9)
- **Rails 版本**：6.0+ (推薦 7.2.2.1)
- **資料庫**：MySQL 8.0+, PostgreSQL 12+, SQLite 3.35+

## 測試結構

```
test/
├── test_helper.rb                    # 測試輔助方法和配置
├── run_tests.rb                      # 測試執行腳本
├── unit/                            # 單元測試
│   ├── sensitive_logs_controller_test.rb
│   ├── sensitive_operation_log_test.rb
│   ├── file_scanner_test.rb
│   └── simple_sensitive_data_detector_test.rb
├── integration/                     # 整合測試
│   └── sensitive_data_guard_integration_test.rb
└── README.md                        # 本文件
```

## 測試類型

### 1. 單元測試 (Unit Tests)

#### SensitiveLogsControllerTest
- 測試控制器動作（index, show, destroy, cleanup, risk_levels）
- 測試篩選和搜尋功能
- 測試 CSV 導出功能
- 測試權限控制
- 測試錯誤處理

#### SensitiveOperationLogTest
- 測試模型驗證
- 測試關聯關係
- 測試範圍查詢
- 測試統計方法
- 測試清理功能
- 測試顯示方法

#### FileScannerTest
- 測試檔案掃描功能
- 測試不同檔案類型
- 測試敏感資料偵測
- 測試效能和錯誤處理

#### SimpleSensitiveDataDetectorTest
- 測試敏感資料偵測算法
- 測試不同類型的敏感資料
- 測試風險等級分類
- 測試效能和邊界情況

### 2. 整合測試 (Integration Tests)

#### SensitiveDataGuardIntegrationTest
- 測試完整的工作流程
- 測試用戶界面交互
- 測試端到端功能
- 測試權限和安全性

## 運行測試

### 運行所有測試
```bash
ruby test/run_tests.rb
```

### 運行特定測試文件
```bash
ruby test/run_tests.rb test/unit/sensitive_logs_controller_test.rb
```

### 運行整合測試
```bash
ruby test/run_tests.rb test/integration/sensitive_data_guard_integration_test.rb
```

### 詳細輸出
```bash
ruby test/run_tests.rb -v
```

## 測試輔助方法

### 創建測試數據
```ruby
# 創建測試用戶
user = create_test_user(admin: true)

# 創建測試專案
project = create_test_project(name: "測試專案")

# 創建測試敏感日誌
log = create_test_sensitive_log(
  risk_level: 'high',
  content_preview: '測試內容'
)
```

### 檢查敏感資料偵測
```ruby
# 檢查是否偵測到敏感資料
assert_sensitive_data_detected(result, ['taiwan_id', 'credit_card'])

# 檢查是否未偵測到敏感資料
assert_sensitive_data_not_detected(result)
```

### 檢查統計資料
```ruby
# 檢查統計資料包含必要欄位
assert_statistics_include(stats, [:total_count, :high_risk_count, :medium_risk_count])
```

## 測試覆蓋範圍

### 功能覆蓋
- [x] 敏感資料偵測
- [x] 日誌記錄和管理
- [x] 篩選和搜尋
- [x] CSV 導出
- [x] 權限控制
- [x] 錯誤處理
- [x] 統計報告
- [x] 清理功能

### 代碼覆蓋
- [x] 控制器動作
- [x] 模型方法
- [x] 服務類
- [x] 輔助方法
- [x] 視圖模板

## 測試數據

### Fixtures
測試使用以下 fixtures：
- `users.yml` - 用戶數據
- `projects.yml` - 專案數據
- `sensitive_operation_logs.yml` - 敏感操作日誌數據

### 動態測試數據
測試中會動態創建測試數據，包括：
- 測試用戶
- 測試專案
- 測試敏感日誌
- 測試檔案

## 注意事項

1. **測試環境**：確保測試環境已正確配置
2. **數據庫**：測試會使用測試數據庫，不會影響生產數據
3. **清理**：測試會自動清理創建的測試數據
4. **權限**：測試會模擬不同的用戶權限
5. **檔案**：測試會創建臨時檔案，測試完成後會自動清理

## 故障排除

### 常見問題

1. **測試失敗**：檢查測試環境配置
2. **權限錯誤**：確保測試用戶有適當權限
3. **數據庫錯誤**：檢查測試數據庫連接
4. **檔案錯誤**：檢查臨時檔案目錄權限

### 調試技巧

1. 使用 `-v` 選項獲取詳細輸出
2. 檢查測試日誌
3. 使用 `puts` 或 `Rails.logger` 輸出調試信息
4. 檢查測試數據狀態

## 貢獻指南

1. 新增測試時，請遵循現有的測試模式
2. 確保測試覆蓋新功能
3. 更新測試文檔
4. 運行所有測試確保通過
5. 提交前檢查測試覆蓋率
