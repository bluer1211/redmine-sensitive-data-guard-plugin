# 🔌 Redmine 敏感資料防護插件

## 📋 概述

Redmine 敏感資料防護插件是一個強大的資訊安全工具，用於防止使用者在 Redmine 系統中儲存、傳輸或散布機敏資訊。本插件提供自動偵測、即時阻擋、操作稽核和通知管理等功能。

## 🎯 系統需求

### 支援的 Redmine 版本
- **Redmine 4.1.1** ✅ (主要支援版本)
- **Redmine 4.1.x** ✅ (相容)
- **Redmine 4.0.x** ✅ (相容)
- **Redmine 3.4.x** ⚠️ (部分功能可能受限)

### 系統環境需求
- **Ruby 版本**：2.5 或更高版本
- **Rails 版本**：5.2 或更高版本
- **資料庫**：MySQL 5.7+, PostgreSQL 9.6+, SQLite 3.8+
- **瀏覽器**：Chrome 60+, Firefox 55+, Safari 12+, Edge 79+

### 建議配置
- **記憶體**：最少 2GB RAM
- **儲存空間**：至少 1GB 可用空間
- **CPU**：雙核心或更高
- **網路**：穩定的網路連線（用於通知功能）

## 🎯 主要功能

### ✅ 敏感資料偵測
- **身分證號碼**：台灣身分證號格式偵測
- **信用卡號碼**：信用卡號格式偵測
- **API 金鑰**：API Key、Secret、Token 偵測
- **帳號密碼**：使用者帳號密碼組合偵測
- **手機號碼**：台灣手機號碼格式偵測
- **Email 地址**：Email 格式偵測
- **IP 位址**：內部和外部 IP 位址偵測

### ✅ Office 文件掃描
- 支援 `.docx`, `.xlsx`, `.pptx`, `.pdf` 檔案格式
- 自動掃描檔案內容中的敏感資訊
- 檔案大小限制和效能優化

### ✅ 即時阻擋與警告
- 高風險內容自動阻擋提交
- 中低風險內容顯示警告訊息
- 支援覆蓋權限機制
- 白名單例外處理

### ✅ 操作稽核記錄
- 完整的操作日誌記錄
- 分級保留策略（高風險7年、一般3年）
- 自動清理過期日誌
- 統計報表和匯出功能

### ✅ 通知管理
- Email 通知機制
- Slack 整合（可選）
- 即時警報和定期摘要

## 🚀 快速開始

### 1. 安裝插件

```bash
# 將插件複製到 Redmine 插件目錄
cp -r redmine_sensitive_data_guard /path/to/redmine/plugins/

# 重啟 Redmine 服務
sudo systemctl restart redmine
```

### 2. 執行資料庫遷移

```bash
# 進入 Redmine 目錄
cd /path/to/redmine

# 執行遷移
bundle exec rake redmine:plugins:migrate RAILS_ENV=production
```

### 3. 啟用插件

1. 以管理員身份登入 Redmine
2. 進入「管理」→「設定」→「插件」
3. 找到「Redmine Sensitive Data Guard Plugin」
4. 點擊「配置」進行設定
5. 啟用插件功能

### 版本相容性檢查

在安裝前，請確認您的 Redmine 版本：

```bash
# 檢查 Redmine 版本
bundle exec rake redmine:info RAILS_ENV=production

# 檢查 Ruby 版本
ruby --version

# 檢查 Rails 版本
bundle exec rails --version
```

## ⚙️ 配置說明

### 基本設定
- **啟用插件**：開啟/關閉插件功能
- **檔案掃描**：啟用 Office 文件內容掃描
- **檔案大小限制**：設定最大檔案大小（預設 50MB）

### 風險等級設定
- **高風險偵測**：身分證號、信用卡號、API Key
- **中風險偵測**：手機號碼、Email、內部 IP
- **低風險偵測**：外部 IP、一般密碼

### 處理策略
- **阻擋**：直接阻止提交
- **警告**：顯示警告但允許提交
- **記錄**：僅記錄不阻擋

### 日誌保留
- **高風險記錄**：保留 7 年（符合個資法）
- **一般記錄**：保留 3 年
- **覆蓋記錄**：保留 5 年

## 📊 使用統計

### 日誌查詢
- 進入「管理」→「敏感資料防護」
- 查看敏感操作日誌
- 支援多條件篩選和搜尋
- 匯出 CSV 報表

### 統計資訊
- 總操作次數
- 按風險等級統計
- 按操作類型統計
- 趨勢分析圖表

## 🔧 開發資訊

### 技術架構
- **Ruby on Rails**：主要開發框架
- **正規表示式**：敏感資料偵測引擎
- **ActiveRecord**：資料庫操作
- **Redmine Hooks**：系統整合

### 版本相容性說明

#### Redmine 4.1.1 (主要支援版本)
- ✅ 完整功能支援
- ✅ 所有新功能特性
- ✅ 最佳效能表現
- ✅ 完整測試覆蓋

#### Redmine 4.1.x (相容版本)
- ✅ 核心功能支援
- ✅ 基本偵測功能
- ✅ 穩定運行

#### Redmine 4.0.x (相容版本)
- ✅ 核心功能支援
- ✅ 基本偵測功能
- ⚠️ 部分進階功能可能受限
- ✅ 穩定運行

#### Redmine 3.4.x (有限支援)
- ⚠️ 基本偵測功能
- ❌ 部分新功能不支援
- ⚠️ 可能需要手動調整
- ⚠️ 建議升級到 4.x 版本

### 檔案結構
```
redmine_sensitive_data_guard/
├── app/
│   ├── controllers/     # 控制器
│   ├── models/         # 資料模型
│   └── views/          # 視圖模板
├── lib/                # 核心邏輯
├── config/             # 配置文件
├── db/                 # 資料庫遷移
└── docs/              # 技術文檔
```

### 自訂開發
- 支援自訂偵測規則
- 可擴展通知管道
- 模組化設計架構
- 完整的 API 文檔

## 📚 相關文檔

- [功能規格書](docs/redmine_sensitive_data_guard_specification.md)
- [實作計劃](docs/redmine_sensitive_data_guard_implementation_plan.md)
- [版本記錄](docs/CHANGELOG.md)
- [文件版本管理指南](docs/DOCUMENT_VERSION_GUIDE.md)

## 🛡️ 安全特性

### 資料保護
- 敏感內容自動遮蔽
- 安全的日誌儲存
- 權限控制機制
- 審計追蹤功能

### 合規性
- 符合台灣《個人資料保護法》
- 符合歐盟 GDPR 規範
- 符合 ISO 27001 標準
- 支援企業安全政策

## 🤝 支援與貢獻

### 問題回報
如有問題或建議，請提交 Issue：
- GitHub Issues：[連結]
- 技術支援：[聯絡方式]

### 貢獻開發
歡迎提交 Pull Request：
1. Fork 專案
2. 建立功能分支
3. 提交變更
4. 發起 Pull Request

## 📄 授權條款

本專案採用 MIT 授權條款，詳見 [LICENSE](LICENSE) 文件。

## 👥 開發團隊

- **作者**：Jason Liu (bluer1211)
- **版本**：1.0.1
- **最後更新**：2025-08-04
- **GitHub**：https://github.com/bluer1211

## 📋 版本歷史

### v1.0.1 (2025-08-04)
- ✅ 新增 Redmine 4.1.1 版本支援
- ✅ 更新系統需求文件
- ✅ 改善安裝指南
- ✅ 新增版本檢查工具

### v1.0.0 (2025-08-01)
- 🎉 初始版本發布
- ✅ 基礎敏感資料偵測功能
- ✅ 基本阻擋機制
- ✅ 操作日誌記錄
- ✅ 管理設定介面

---

**注意**：本插件僅為預防性偵測工具，最終資料保護責任仍由系統管理者負責。 