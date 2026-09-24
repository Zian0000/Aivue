# 第三階段：Claude 與雙平台整合

更新日期：2026-09-23

收尾進度：**95%**

## 已實作

- Menu Bar 同時顯示 `C xx%` 與 `A xx%`
- Codex 與 Claude 狀態分開管理，一個平台失敗不會清除另一個平台資料
- Claude 連結視窗使用官方 `claude.ai` 登入頁
- Claude session 由應用程式的持久化 `WKWebsiteDataStore` 保存
- 密碼只送到 Claude 網頁，原生程式不讀取登入表單內容
- 登入後從同網域取得 organization 與 usage JSON
- 支援 Claude `five_hour` 與 `seven_day` 視窗
- 支援未連結、載入中、查詢失敗與快取狀態
- 雙平台全部更新按鈕與 60 秒自動刷新
- Codex 與 Claude 獨立 1、2、5、10 分鐘錯誤退避
- 可選擇顯示 Codex、Claude 或兩者
- 可選擇 60、300、600、1800 秒同步頻率
- 網路恢復與 Mac 喚醒後立即更新
- Claude 斷開連結會清除 App 自有 WebKit session
- 設定保留至 UserDefaults

## 自動測試

- 完整 Swift 6.3.3 編譯通過
- Codex 本機登入整合測試通過
- Claude 用量 JSON 解析測試通過
- Claude 未登入錯誤轉換測試通過
- 總計 6 個測試通過

## 已完成人工驗證

Claude Pro 實際帳號已完成：

- 能取得目前區段百分比
- 能取得每週百分比
- 重置時間與 Claude Usage 頁面一致
- App 重開後 session 仍存在

## 留待產品化階段

- 正式設定視窗與 UI 定稿
- 長時間睡眠喚醒與真實網路斷線壓力測試
- 目前不自行儲存 token/密碼，WebKit 由系統管理 session，因此沒有可放入 Keychain 的應用程式憑證
