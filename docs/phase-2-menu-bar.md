# 第二階段：Codex Menu Bar 骨架

更新日期：2026-09-23

收尾進度：**95%**

## 已實作

- SwiftUI `MenuBarExtra` 原生狀態列應用程式入口
- 狀態列顯示 Codex 剩餘百分比
- 點擊後顯示 5 小時與 7 天視窗
- 顯示已使用、剩餘、重置日期與倒數
- UI 每秒更新重置倒數
- Codex 用量每 60 秒刷新
- 手動立即更新
- 保留最後成功快取，刷新失敗時顯示警告
- 透過 `codex app-server --stdio` 及 `account/rateLimits/read` 重用官方登入
- 查詢逾時與子行程清理
- JSON-RPC 回應解析單元測試
- Codex 與 Claude 成功快照會寫入 Application Support JSON 快取
- App 重啟、離線或查詢失敗時保留上次成功資料
- 超過兩個同步週期（最少120秒）時顯示過期提示
- 快取損壞時安全忽略，不影響即時查詢

## 安全性

App 不讀取或儲存 ChatGPT 密碼、Cookie 與 access token。授權狀態由本機 Codex 管理，Menu Bar App 只接收用量結果。

## 驗證狀態

- 所有 Swift 檔案通過編譯器語法解析。
- `git diff --check` 通過。
- Codex JSON-RPC 唯讀請求已在相同本機環境端到端驗證。
- Xcode 26.6（Swift 6.3.3，macOS SDK 26.5）完整編譯通過。
- 3 個解析與資料模型單元測試通過。
- 1 個本機 Codex 登入整合測試通過，已實際取得用量與重置時間。
- `swift run AIUsageMenuBar` 建置成功，Menu Bar 進程可持續執行。

## 驗證指令

目前 Xcode 位於 `~/Downloads/Xcode.app`，執行：

```shell
DEVELOPER_DIR="$HOME/Downloads/Xcode.app/Contents/Developer" xcrun swift test
DEVELOPER_DIR="$HOME/Downloads/Xcode.app/Contents/Developer" xcrun swift run AIUsageMenuBar
```

執行含真實帳號的唯讀整合測試：

```shell
RUN_LIVE_CODEX_USAGE_TEST=1 DEVELOPER_DIR="$HOME/Downloads/Xcode.app/Contents/Developer" xcrun swift test
```
