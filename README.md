# �� Redmine 敏感資料防護插件

[![Redmine Version](https://img.shields.io/badge/Redmine-4.1.1-brightgreen.svg)](https://www.redmine.org/)
[![Ruby Version](https://img.shields.io/badge/Ruby-2.5+-red.svg)](https://www.ruby-lang.org/)
[![Rails Version](https://img.shields.io/badge/Rails-5.2+-blue.svg)](https://rubyonrails.org/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Version](https://img.shields.io/badge/Version-1.0.1-orange.svg)](https://github.com/bluer1211/redmine-sensitive-data-guard-plugin/releases)

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

Redmine 敏感資料防護插件是一個強大的資訊安全工具，用於防止使用者在 Redmine 系統中儲存、傳輸或散布機敏資訊。本插件提供自動偵測、即時阻擋、操作稽核和通知管理等功能。

### 🌟 核心特色

- 🔍 **智能偵測**：支援 10+ 種敏感資料類型偵測
- 🚫 **即時阻擋**：高風險內容自動阻擋提交
- 📄 **文件掃描**：支援 Office 文件內容掃描
- 📊 **完整稽核**：詳細的操作日誌記錄
- 🔔 **即時通知**：Email 和 Slack 通知整合
- ⚙️ **靈活配置**：可自訂偵測規則和處理策略

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

### 📦 安裝方式

#### 方式一：Git Clone（推薦）
```bash
# 進入 Redmine 插件目錄
cd /path/to/redmine/plugins/

# 克隆插件
git clone https://github.com/bluer1211/redmine-sensitive-data-guard-plugin.git redmine_sensitive_data_guard

# 進入插件目錄
cd redmine_sensitive_data_guard

# 安裝依賴
bundle install
```

#### 方式二：手動下載
```bash
# 下載並解壓到插件目錄
wget https://github.com/bluer1211/redmine-sensitive-data-guard-plugin/archive/main.zip
unzip main.zip -d /path/to/redmine/plugins/
mv redmine-sensitive-data-guard-plugin-main redmine_sensitive_data_guard
```

### 🔧 安裝步驟

#### 1. 安裝 Gem 依賴
```bash
# 進入 Redmine 目錄
cd /path/to/redmine

# 安裝插件所需的 Gem 依賴
bundle install

# 檢查 Gem 是否安裝成功
bundle list | grep -E "(rubyzip|nokogiri|roo|pdf-reader|sidekiq|redis|slack-notifier|axlsx)"
```

#### 2. 執行資料庫遷移
```bash
# 執行遷移（建立資料表）
bundle exec rake redmine:plugins:migrate RAILS_ENV=production

# 初始化預設資料（可選）
bundle exec rake db:seed:redmine_plugins RAILS_ENV=production
```

#### 3. 檢查資料庫狀態
```bash
# 檢查遷移狀態
bundle exec rake redmine:plugins:migrate:status RAILS_ENV=production

# 檢查資料表是否建立成功
bundle exec rails console RAILS_ENV=production
# 在 Rails console 中執行：
# SensitiveOperationLog.count
# DetectionRule.count
# WhitelistRule.count
# exit
```

#### 4. 重啟 Redmine 服務
```bash
# 重啟 Redmine 服務
sudo systemctl restart redmine

# 或使用其他方式重啟
sudo service redmine restart
```

#### 5. 啟用插件
1. 以管理員身份登入 Redmine
2. 進入「管理」→「設定」→「插件」
3. 找到「Redmine Sensitive Data Guard Plugin」
4. 點擊「配置」進行設定
5. 啟用插件功能

#### 6. 設定用戶權限
1. 進入「管理」→「角色與權限」
2. 選擇要設定的角色（如：管理員、專案管理員等）
3. 在「敏感資料防護」模組中勾選以下權限：
   - **查看敏感日誌**：允許查看敏感操作日誌
   - **管理敏感規則**：允許管理偵測規則
   - **覆蓋敏感偵測**：允許覆蓋敏感資料偵測
4. 點擊「儲存」

#### 7. 設定專案權限（可選）
1. 進入特定專案
2. 點擊「設定」→「成員」
3. 為專案成員分配適當的敏感資料防護權限
4. 或進入「設定」→「模組」啟用「敏感資料防護」模組

### 📊 資料庫結構

插件會建立以下資料表：

#### 核心資料表
- **`sensitive_operation_logs`** - 敏感操作日誌
- **`detection_rules`** - 偵測規則
- **`whitelist_rules`** - 白名單規則

#### 預設資料
- ✅ **8 個預設偵測規則**（身分證號、信用卡號、API Key 等）
- ✅ **3 個預設白名單規則**（測試環境、範例資料、管理員）
- ✅ **完整的索引優化**（提升查詢效能）

### 🔍 資料庫相容性

#### 支援的資料庫
- ✅ **MySQL 5.7+** (推薦)
- ✅ **PostgreSQL 9.6+** (推薦)
- ✅ **SQLite 3.8+** (開發環境)

#### 資料庫要求
- **儲存空間**：至少 100MB 可用空間
- **權限**：需要 CREATE TABLE 和 CREATE INDEX 權限
- **字符集**：建議使用 UTF-8 編碼

### 🛠️ 故障排除

#### 遷移失敗
```bash
# 檢查錯誤日誌
tail -f /var/log/redmine/production.log

# 重新執行遷移
bundle exec rake redmine:plugins:migrate:redo RAILS_ENV=production

# 如果仍有問題，可以重置插件資料庫
bundle exec rake redmine:plugins:migrate:down RAILS_ENV=production
bundle exec rake redmine:plugins:migrate RAILS_ENV=production
```

#### 資料庫連接問題
```bash
# 檢查資料庫連接
bundle exec rake db:version RAILS_ENV=production

# 檢查資料庫配置
cat config/database.yml
```

### 🛠️ 資料庫管理工具

插件提供了多個 Rake 任務來管理資料庫：

#### 檢查資料庫狀態
```bash
# 檢查資料表狀態和記錄數量
bundle exec rake redmine_sensitive_data_guard:db:status RAILS_ENV=production
```

#### 初始化預設資料
```bash
# 載入預設偵測規則和白名單
bundle exec rake redmine_sensitive_data_guard:db:seed RAILS_ENV=production
```

#### 清理過期日誌
```bash
# 根據保留策略清理過期日誌
bundle exec rake redmine_sensitive_data_guard:db:cleanup RAILS_ENV=production
```

#### 備份插件資料
```bash
# 備份所有插件資料表
bundle exec rake redmine_sensitive_data_guard:db:backup RAILS_ENV=production
```

#### 重置插件資料庫（危險操作）
```bash
# 完全重置插件資料庫（需要確認）
bundle exec rake redmine_sensitive_data_guard:db:reset RAILS_ENV=production
```

### 🔍 安裝檢查工具

#### 檢查安裝環境
```bash
# 全面檢查安裝環境和依賴
bundle exec rake redmine_sensitive_data_guard:install:check RAILS_ENV=production
```

#### 執行完整安裝流程
```bash
# 一鍵執行完整安裝流程（推薦新手使用）
bundle exec rake redmine_sensitive_data_guard:install:setup RAILS_ENV=production
```

#### 檢查項目包括
- ✅ **Redmine 版本相容性**
- ✅ **Ruby/Rails 版本要求**
- ✅ **Gem 依賴安裝狀態**
- ✅ **資料庫連接和資料表**
- ✅ **檔案權限和完整性**
- ✅ **插件設定狀態**

### 📋 資料庫維護建議

#### 定期維護
- **每日**：檢查日誌數量
- **每週**：清理過期日誌
- **每月**：備份插件資料
- **每季**：檢查資料庫效能

#### 效能優化
- 定期清理過期日誌
- 監控資料表大小
- 檢查索引使用情況
- 適時調整保留策略

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

### ✅ 安裝驗證

安裝完成後，您可以透過以下方式驗證：

1. **檢查插件列表**：管理 → 設定 → 插件
2. **檢查選單項目**：管理選單中應出現「敏感資料防護」
3. **檢查權限**：用戶 → 權限中應有相關權限選項

### 🗑️ 卸載插件

#### 1. 備份資料（重要）
```bash
# 備份插件資料
bundle exec rake redmine_sensitive_data_guard:db:backup RAILS_ENV=production
```

#### 2. 停用插件
1. 進入「管理」→「設定」→「插件」
2. 找到「Redmine Sensitive Data Guard Plugin」
3. 點擊「停用」

#### 3. 移除資料庫資料（可選）
```bash
# 移除插件資料表（危險操作）
bundle exec rake redmine:plugins:migrate:down RAILS_ENV=production

# 或保留資料表僅移除插件檔案
```

#### 4. 移除插件檔案
```bash
# 移除插件目錄
rm -rf /path/to/redmine/plugins/redmine_sensitive_data_guard

# 重啟 Redmine 服務
sudo systemctl restart redmine
```

#### 5. 清理 Gem 依賴（可選）
```bash
# 如果沒有其他插件使用這些 Gem，可以移除
bundle update
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

### 📞 問題回報

如有問題或建議，請提交 Issue：

- 🐛 **Bug 回報**：[GitHub Issues](https://github.com/bluer1211/redmine-sensitive-data-guard-plugin/issues)
- 💡 **功能建議**：[Feature Requests](https://github.com/bluer1211/redmine-sensitive-data-guard-plugin/issues/new?template=feature_request.md)
- 📖 **文檔問題**：[Documentation Issues](https://github.com/bluer1211/redmine-sensitive-data-guard-plugin/issues/new?template=documentation.md)

### 🔧 技術支援

- 📧 **Email 支援**：bluer1211@gmail.com
- 💬 **討論區**：[GitHub Discussions](https://github.com/bluer1211/redmine-sensitive-data-guard-plugin/discussions)
- 📚 **文檔**：[Wiki](https://github.com/bluer1211/redmine-sensitive-data-guard-plugin/wiki)

### 🌟 貢獻開發

歡迎提交 Pull Request 來改善插件！

#### 貢獻流程

1. **Fork 專案**
   ```bash
   git clone https://github.com/YOUR_USERNAME/redmine-sensitive-data-guard-plugin.git
   cd redmine-sensitive-data-guard-plugin
   ```

2. **建立功能分支**
   ```bash
   git checkout -b feature/your-feature-name
   ```

3. **提交變更**
   ```bash
   git add .
   git commit -m "feat: 新增功能描述"
   ```

4. **發起 Pull Request**
   - 前往 [GitHub Pull Requests](https://github.com/bluer1211/redmine-sensitive-data-guard-plugin/pulls)
   - 點擊 "New Pull Request"
   - 選擇您的分支並提交

#### 開發指南

- 📋 **開發規範**：請參考 [CONTRIBUTING.md](CONTRIBUTING.md)
- 🧪 **測試指南**：請參考 [TESTING.md](docs/TESTING.md)
- 📝 **程式碼風格**：遵循 Ruby 和 Rails 最佳實踐

### 🏆 貢獻者

感謝所有為此專案做出貢獻的開發者！

[![Contributors](https://contributors-img.web.app/image?repo=bluer1211/redmine-sensitive-data-guard-plugin)](https://github.com/bluer1211/redmine-sensitive-data-guard-plugin/graphs/contributors)

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

## 🔗 相關連結

- 🌐 **官方網站**：[Redmine](https://www.redmine.org/)
- 📚 **完整文檔**：[GitHub Wiki](https://github.com/bluer1211/redmine-sensitive-data-guard-plugin/wiki)
- 🐛 **問題回報**：[GitHub Issues](https://github.com/bluer1211/redmine-sensitive-data-guard-plugin/issues)
- 💬 **討論區**：[GitHub Discussions](https://github.com/bluer1211/redmine-sensitive-data-guard-plugin/discussions)
- 📦 **下載頁面**：[GitHub Releases](https://github.com/bluer1211/redmine-sensitive-data-guard-plugin/releases)

## ⭐ 給我們一個星標

如果這個插件對您有幫助，請給我們一個星標！

[![GitHub stars](https://img.shields.io/github/stars/bluer1211/redmine-sensitive-data-guard-plugin.svg?style=social&label=Star)](https://github.com/bluer1211/redmine-sensitive-data-guard-plugin)
[![GitHub forks](https://img.shields.io/github/forks/bluer1211/redmine-sensitive-data-guard-plugin.svg?style=social&label=Fork)](https://github.com/bluer1211/redmine-sensitive-data-guard-plugin/fork)

---

**注意**：本插件僅為預防性偵測工具，最終資料保護責任仍由系統管理者負責。 