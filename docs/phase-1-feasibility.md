# 第一階段：資料取得技術驗證

驗證日期：2026-09-23

## 結論

Menu Bar App 可行。Codex 有可程式化且能沿用本機官方登入的資料來源；Claude 有結構化用量資料，但個人訂閱沒有公開第三方 API，需要在我們的 App 內一次性連結 Claude 帳號，並將 session 留在 App 自己的 WebKit 儲存空間。

階段收尾狀態：**95%**。核心資料取得、重啟後 session 保留、Google OAuth 與真實用量讀取已驗證；其他訂閱方案及登入自然過期仍需長時間或外部帳號驗證。

## 本機環境

- ChatGPT Desktop：已安裝
- Codex CLI：`0.155.0-alpha.9.2`
- Codex 登入：ChatGPT 帳號
- Claude Desktop：`2.2553.1`
- Claude 登入：Pro 方案
- Claude CLI：未安裝

驗證過程不輸出、複製或儲存 Cookie、access token 或密碼。

診斷紀錄只保留 URL 的 scheme、host 與 path；query 與 fragment 會移除，避免留存 OAuth 驗證參數。每次 App 啟動會重建診斷紀錄，不長期累積。

## Codex / ChatGPT 方案

### 已驗證

Codex 內附的 app-server 提供 JSON-RPC 方法：

```text
account/rateLimits/read
```

使用本機現有 ChatGPT 登入狀態的唯讀請求已成功回傳：

- 5 小時視窗已使用百分比
- 7 天視窗已使用百分比
- 兩個視窗的精確重置時間
- 方案類型
- 一般用量是否仍可使用

### 實作方式

App 不直接讀取 token，也不複製 ChatGPT 憑證。它啟動本機 `codex app-server --stdio`，透過 JSON-RPC 取得用量快照。

### 邊界

這組資料是 **Codex 在 ChatGPT 方案中的額度**，不是所有 ChatGPT Chat 模型的統一額度。ChatGPT Chat 的限制可能依模型、功能與方案分開計算，不應在 UI 上誤稱為「ChatGPT 總用量」。

### 收尾驗證

- 真實本機 Codex 登入整合測試通過。
- 認證失效錯誤會轉成明確的重新登入提示。
- 缺少 primary/secondary 視窗時拒絕不完整回應。
- 未知方案名稱會原樣保留，異常百分比會限制在 0–100。

## Claude

### 已驗證

Claude Desktop 的 Usage 頁面可顯示結構化資料：

- Current session 已使用百分比與重置時間
- This week 已使用百分比與重置時間
- 每週各產品使用占比
- 最後更新時間

Claude 前端使用的結構化請求為：

```text
GET /api/organizations/{organization-id}/usage?source={source}
```

回應中的視窗項目含 `utilization` 與 `resets_at`，不需要 OCR。

### 實作限制

- 這是 Claude 網頁內部介面，不是對第三方保證穩定的公開 API。
- macOS 不允許一般 App 安全借用 Claude Desktop 的 Cookie / session。
- 直接讀取 Claude Desktop 的本機 Cookie 儲存不列入方案，因為權限、安全與維護風險過高。
- Accessibility 可以讀到 Usage 畫面，但需要 Claude 開啟且停在指定頁，只適合調查，不作為產品資料來源。

### 收尾驗證

- Claude Pro 真實帳號已成功讀取 5 小時與 7 天視窗。
- Google OAuth 子視窗、驗證回傳與主 WebView session 已驗證。
- App 重啟後 session 保留且可自動讀取用量。
- `not_authenticated` 會轉成「需要重新連結」錯誤。
- 支援目前欄位與相容別名，並支援 UTC、時區偏移、有／無毫秒的 ISO 8601 時間。
- 未知方案名稱不會導致解析失敗。

### 建議方式

在我們的 App 內建立 Claude 連結流程：

1. 使用 `WKWebView` 打開 Claude 官方登入頁。
2. 使用者直接在 Claude 頁面登入；App 不接觸密碼。
3. session 由 App 的 WebKit 儲存空間管理。
4. 在同網域內呼叫用量介面，只將百分比與時間傳回 native layer。
5. session 失效時顯示「需要重新連結」。

## 更新策略

- UI 與重置倒數：每 1 秒刷新
- 平台用量：每 60 秒輪詢，後續可開放 30–300 秒設定
- 點開 Menu Bar 且快取過期：立即刷新
- 偵測到任務完成：在不需要過度權限的前提下觸發刷新
- 失敗退避：1、2、5、10 分鐘
- 離線時保留最後成功資料，並標記為過期

## 第二階段建議

先以 Codex provider 完成單平台 Menu Bar 骨架，因為它的本機登入重用與結構化資料都已實測成功。第三階段再加入 Claude `WKWebView` 連結流程。

Menu Bar 的平台名稱應先顯示「Codex」，除非後續找到能正確代表 ChatGPT Chat 額度的資料來源。

## 尚未能完全驗證

- Claude Free、Max、Team 與 Enterprise 方案需要對應帳號；目前以容錯解析與未知方案測試降低風險。
- Codex 其他 ChatGPT 方案尚無外部帳號可實測。
- 真實 session 自然過期需要等待平台過期；目前已以錯誤回應自動化測試覆蓋。
- 內部 API 改版無法預先排除，需保留診斷與相容解析。
