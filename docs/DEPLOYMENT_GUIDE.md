# 🚀 Redmine 敏感資料防護插件 - 部署指南

## 📋 概述

本指南將幫助您成功部署 Redmine 敏感資料防護插件到生產環境。本插件已於 2.0.3 版本進行了全面的程式碼審核和品質改進。

---

## 🎯 系統需求

### 最低需求
- **Redmine 版本**: 6.0.6+
- **Ruby 版本**: 3.0+
- **Rails 版本**: 6.0+
- **資料庫**: MySQL 8.0+ / PostgreSQL 12+ / SQLite 3.35+
- **記憶體**: 4GB RAM
- **儲存空間**: 2GB 可用空間

### 推薦配置
- **Redmine 版本**: 6.0.6
- **Ruby 版本**: 3.3.9
- **Rails 版本**: 7.2.2.1
- **資料庫**: MySQL 8.0+ 或 PostgreSQL 12+
- **記憶體**: 8GB RAM
- **儲存空間**: 10GB 可用空間

### 版本相容性
- **v2.0.3**：最新穩定版本，支援完整的錯誤處理和安全性改進
- **v2.0.x**：支援 Redmine 6.0.6 (Rails 7.2.2.1, Ruby 3.3.9)

---

## 📦 安裝步驟

### 步驟 1: 環境準備

#### 1.1 檢查系統環境
```bash
# 檢查 Redmine 版本
bundle exec rake redmine:info RAILS_ENV=production

# 檢查 Ruby 版本
ruby --version

# 檢查 Rails 版本
bundle exec rails --version

# 檢查資料庫連接
bundle exec rake db:version RAILS_ENV=production
```

#### 1.2 備份現有資料
```bash
# 備份資料庫
mysqldump -u username -p redmine_database > redmine_backup_$(date +%Y%m%d_%H%M%S).sql

# 備份 Redmine 檔案
tar -czf redmine_files_backup_$(date +%Y%m%d_%H%M%S).tar.gz /path/to/redmine
```

### 步驟 2: 插件安裝

#### 2.1 下載插件
```bash
# 進入 Redmine 插件目錄
cd /path/to/redmine/plugins/

# 克隆插件
git clone https://github.com/bluer1211/redmine-sensitive-data-guard-plugin.git redmine_sensitive_data_guard

# 進入插件目錄
cd redmine_sensitive_data_guard

# 檢查版本（確保是最新版本）
git log --oneline -5
```

#### 2.2 安裝依賴
```bash
# 回到 Redmine 根目錄
cd /path/to/redmine

# 安裝 Gem 依賴
bundle install

# 檢查依賴衝突
bundle check
```

### 步驟 3: 資料庫配置

#### 3.1 執行遷移

##### 生產環境遷移
```bash
# 執行資料庫遷移
bundle exec rake redmine:plugins:migrate RAILS_ENV=production

# 檢查遷移狀態
bundle exec rake redmine:plugins:migrate:status RAILS_ENV=production

# 驗證資料庫表結構
bundle exec rake redmine:plugins:migrate RAILS_ENV=production VERSION=0
```

##### 開發環境遷移
```bash
# 執行資料庫遷移（開發環境）
bundle exec rake redmine:plugins:migrate RAILS_ENV=development

# 執行種子資料初始化（開發環境）
bundle exec rake redmine:plugins:seed RAILS_ENV=development

# 檢查遷移狀態
bundle exec rake redmine:plugins:migrate:status RAILS_ENV=development
```

### 步驟 4: 配置驗證

#### 4.1 檢查插件狀態
```bash
# 檢查插件是否正確載入
bundle exec rails console RAILS_ENV=production

# 在 Rails console 中執行
> Redmine::Plugin.all.map(&:name)
> Redmine::Plugin.find('redmine_sensitive_data_guard')
```

#### 4.2 驗證資料庫表
```bash
# 檢查敏感操作日誌表
bundle exec rails console RAILS_ENV=production

# 在 Rails console 中執行
> SensitiveOperationLog.count
> DetectionRule.count
> WhitelistRule.count
```

---

## ⚙️ 配置說明

### 基本設定

#### 插件啟用
1. 進入「管理」→「設定」→「插件」
2. 找到「Redmine Sensitive Data Guard Plugin」
3. 點擊「配置」進行設定

#### 主要配置項目
- **啟用插件**：啟用敏感資料防護功能
- **檔案掃描**：掃描上傳的檔案內容
- **檔案大小限制**：設定最大檔案大小（預設 50MB）

### 風險等級設定
- **高風險偵測**：身分證號、信用卡號、API Key
- **中風險偵測**：手機號碼、Email、內部 IP
- **低風險偵測**：外部 IP、一般密碼

### 處理策略
- **阻擋**：直接阻止提交
- **警告**：顯示警告但允許提交
- **記錄**：僅記錄不阻擋

---

## 🛠️ 故障排除

### 遷移失敗
```bash
# 檢查錯誤日誌
tail -f /var/log/redmine/production.log

# 重新執行遷移
bundle exec rake redmine:plugins:migrate:redo RAILS_ENV=production

# 檢查資料庫連接
bundle exec rake db:version RAILS_ENV=production
```

### 資料庫連接問題
```bash
# 檢查資料庫連接
bundle exec rake db:version RAILS_ENV=production

# 檢查資料庫配置
cat config/database.yml
```

### 路由問題
```bash
# 檢查路由配置
bundle exec rails routes | grep sensitive

# 重新載入路由
touch tmp/restart.txt
```

### 權限問題
```bash
# 檢查檔案權限
ls -la /path/to/redmine/plugins/redmine_sensitive_data_guard

# 修正權限
chmod -R 755 /path/to/redmine/plugins/redmine_sensitive_data_guard
```

### 開發環境問題
```bash
# 檢查開發環境遷移狀態
bundle exec rake redmine:plugins:migrate:status RAILS_ENV=development

# 重新執行開發環境遷移
bundle exec rake redmine:plugins:migrate:redo RAILS_ENV=development

# 重新執行種子資料
bundle exec rake redmine:plugins:seed RAILS_ENV=development
```

---

## 📊 驗證安裝

安裝完成後，您可以透過以下方式驗證：

1. **檢查插件列表**：管理 → 設定 → 插件
2. **檢查選單項目**：管理選單中應出現「敏感資料防護」
3. **檢查權限**：用戶 → 權限中應有相關權限選項

### 開發環境驗證
```bash
# 檢查開發環境資料
bundle exec rails console RAILS_ENV=development

# 在 Rails console 中執行
> DetectionRule.count
> WhitelistRule.count
> SensitiveOperationLog.count
```

### 功能測試
1. **敏感資料偵測測試**：建立包含敏感資料的內容
2. **檔案掃描測試**：上傳包含敏感資料的檔案
3. **權限控制測試**：測試不同權限的用戶操作

---

## 🗑️ 卸載插件

### 1. 備份資料（重要）
```bash
# 備份插件資料
bundle exec rake redmine_sensitive_data_guard:db:backup RAILS_ENV=production
```

### 2. 停用插件
1. 進入「管理」→「設定」→「插件」
2. 找到「Redmine Sensitive Data Guard Plugin」
3. 點擊「停用」

### 3. 移除插件檔案
```bash
# 移除插件目錄
rm -rf /path/to/redmine/plugins/redmine_sensitive_data_guard

# 清理快取
bundle exec rake tmp:clear
```

---

## 🔄 更新指南

### 從舊版本更新
```bash
# 備份現有安裝
cp -r /path/to/redmine/plugins/redmine_sensitive_data_guard /path/to/backup/

# 更新插件
cd /path/to/redmine/plugins/redmine_sensitive_data_guard
git pull origin main

# 執行遷移
bundle exec rake redmine:plugins:migrate RAILS_ENV=production

# 重啟應用
touch tmp/restart.txt
```

### 版本相容性檢查
- 確保 Redmine 版本符合要求
- 檢查 Ruby 和 Rails 版本相容性
- 驗證資料庫版本支援

---

## 📞 支援與聯繫

### 技術支援
- **GitHub Issues**：https://github.com/bluer1211/redmine-sensitive-data-guard-plugin/issues
- **文檔**：https://github.com/bluer1211/redmine-sensitive-data-guard-plugin/blob/main/README.md

### 緊急聯繫
- **開發者**：Jason Liu (bluer1211)
- **Email**：support@example.com

---

**最後更新：** 2025-01-27  
**版本：** 2.0.3
