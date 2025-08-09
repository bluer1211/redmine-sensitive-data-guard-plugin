# 🛡️ Redmine 敏感資料防護插件

[![Redmine Version](https://img.shields.io/badge/Redmine-6.0.6-brightgreen.svg)](https://www.redmine.org/)
[![Ruby Version](https://img.shields.io/badge/Ruby-3.3.9-red.svg)](https://www.ruby-lang.org/)
[![Rails Version](https://img.shields.io/badge/Rails-7.2.2.1-blue.svg)](https://rubyonrails.org/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Version](https://img.shields.io/badge/Version-2.0.0-orange.svg)](https://github.com/bluer1211/redmine-sensitive-data-guard-plugin/releases)

> 🛡️ **強大的 Redmine 敏感資料防護工具**  
> 自動偵測、即時阻擋、操作稽核，保護您的敏感資訊安全

## 📋 快速導覽

- [🎯 系統需求](#-系統需求)
- [🚀 快速開始](#-快速開始)
- [⚙️ 配置說明](#️-配置說明)
- [📊 使用統計](#-使用統計)
- [🔧 開發資訊](#-開發資訊)
- [📚 相關文檔](#-相關文檔)
- [🛡️ 安全特性](#️-安全特性)
- [🤝 支援與貢獻](#-支援與貢獻)

## 📋 概述

Redmine 敏感資料防護插件是一個強大的資訊安全工具，用於防止使用者在 Redmine 系統中儲存、傳輸或散布機敏資訊。本插件提供自動偵測、即時阻擋、操作稽核等功能。

### 🌟 核心特色

- 🔍 **智能偵測**：支援 10+ 種敏感資料類型偵測
- 🚫 **即時阻擋**：高風險內容自動阻擋提交
- 📄 **文件掃描**：支援 Office 文件內容掃描
- 📊 **完整稽核**：詳細的操作日誌記錄
- ⚙️ **靈活配置**：可自訂偵測規則和處理策略

## 🎯 系統需求

### 支援的 Redmine 版本
- **Redmine 6.0.6** ✅ (主要支援版本)
- **Redmine 6.0.x** ✅ (相容)
- **Redmine 5.x** ⚠️ (部分功能可能受限)
- **Redmine 4.x** ⚠️ (不建議使用)

### 系統環境需求
- **Ruby 版本**：3.0 或更高版本 (推薦 3.3.9)
- **Rails 版本**：6.0 或更高版本 (推薦 7.2.2.1)
- **資料庫**：MySQL 8.0+, PostgreSQL 12+, SQLite 3.35+
- **瀏覽器**：Chrome 90+, Firefox 88+, Safari 14+, Edge 90+

### 建議配置
- **記憶體**：最少 4GB RAM
- **儲存空間**：至少 2GB 可用空間
- **CPU**：四核心或更高
- **網路**：穩定的網路連線

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

## 🚀 快速開始

### 安裝步驟

1. **下載插件**
   ```bash
   cd /path/to/redmine/plugins/
   git clone https://github.com/bluer1211/redmine-sensitive-data-guard-plugin.git redmine_sensitive_data_guard
   ```

2. **安裝依賴**
   ```bash
   cd /path/to/redmine
   bundle install
   ```

3. **執行資料庫遷移**

   **生產環境：**
   ```bash
   bundle exec rake redmine:plugins:migrate RAILS_ENV=production
   ```

   **開發環境：**
   ```bash
   bundle exec rake redmine:plugins:migrate RAILS_ENV=development
   bundle exec rake redmine:plugins:seed RAILS_ENV=development
   ```

4. **重啟 Redmine**
   ```bash
   # 如果使用 Passenger
   touch tmp/restart.txt
   
   # 如果使用 Puma/Unicorn
   sudo systemctl restart redmine
   ```

5. **配置插件**
   - 進入「管理」→「設定」→「插件」
   - 找到「Redmine Sensitive Data Guard Plugin」
   - 點擊「配置」進行設定

### 開發環境設定

開發環境會自動添加以下專用規則：

- **開發環境測試規則**：`test|dev|development`
- **範例資料規則**：`example|sample|demo`
- **開發環境 IP**：`127.0.0.1|localhost`
- **開發測試資料**：`dev|test|debug|localhost`
- **開發用戶**：`developer|test|admin`

### 驗證安裝

1. **檢查插件列表**：管理 → 設定 → 插件
2. **檢查選單項目**：管理選單中應出現「敏感資料防護」
3. **檢查權限**：用戶 → 權限中應有相關權限選項

**開發環境驗證：**
```bash
bundle exec rails console RAILS_ENV=development

# 在 Rails console 中執行
> DetectionRule.count
> WhitelistRule.count
> SensitiveOperationLog.count
``` 