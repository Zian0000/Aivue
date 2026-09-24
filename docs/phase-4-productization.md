# 第四階段：產品化與測試

更新日期：2026-09-24

## 已實作

- 透過系統 `SMAppService` 控制開機自動啟動；只在 `.app` 中開放。
- 狀態欄精簡模式只顯示剩餘比例較低的平台；設定可保留。
- 剩餘用量低於 50% 的 macOS 提醒；以平台、視窗與重置時間去重，設定預設關閉。
- 網路恢復及 Mac 喚醒後立即刷新；既有失敗退避與離線快取繼續保留。
- 正式 `.app` 與可選 DMG 的本機打包腳本；可透過 `SIGNING_IDENTITY` 簽署。
- Aivue SVG 已轉為 App `.icns`，安裝包使用新圖示；狀態欄與下拉 UI 尚未改動。
- Sparkle 2.10.0 已整合；提供 HTTPS appcast 與 EdDSA 公鑰時，安裝版會自動檢查及安裝更新。未設定時不啟動更新器。
- 提供 Developer ID 簽署、公證與 stapling 腳本，等待帳號與憑證到位。

## 打包

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer zsh scripts/package-app.sh
CREATE_DMG=1 DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer zsh scripts/package-app.sh
SIGNING_IDENTITY='Developer ID Application: …' CREATE_DMG=1 zsh scripts/package-app.sh
APP_VERSION=0.2.0 APP_BUILD_NUMBER=2 UPDATE_FEED_URL=https://example.com/appcast.xml UPDATE_PUBLIC_ED_KEY='…' SIGNING_IDENTITY='Developer ID Application: …' CREATE_DMG=1 zsh scripts/package-app.sh
NOTARY_PROFILE='aivue-notary' zsh scripts/notarize-app.sh
```

輸出位於 `dist/`。未簽署版本只適合本機測試；公開散佈前仍需 Developer ID、Apple 公證及正式更新來源。

`UPDATE_FEED_URL` 與 `UPDATE_PUBLIC_ED_KEY` 必須一起設定。上述 `example.com` 僅為範例，不能直接拿來發布。Sparkle 的 EdDSA 私鑰應保存在 Keychain；用 Sparkle 的 `generate_keys` 建立，更新封存檔與 appcast 使用 `generate_appcast` 簽署產生。不要把私鑰加入專案。每次發布必須提高 `APP_BUILD_NUMBER`。

本機目前沒有 Developer ID Application 憑證，使用者也尚未決定更新發布網址。因此目前的 App 和 DMG **尚未完成正式簽署、公證或端到端更新驗收**，Sparkle 會保持停用。`scripts/notarize-app.sh` 只讀取已存入 Keychain 的 notarytool profile，不在命令列或專案內保存 Apple 密碼。

## 待人工驗收

- 從 `.app` 啟用開機啟動後，登出／登入，確認只啟動一份。
- 首次開啟提醒權限、跨越 50% 門檻、App 重啟及重置後再次提醒。
- 長時間睡眠喚醒、網路斷線／恢復、時區變更。
- 以正式簽署憑證打包、公證及在另一台 Mac 安裝。
- 選定 HTTPS 發布位置，建立 EdDSA 金鑰與 appcast，測試舊版到新版的實際更新。
