# 第四階段：產品化與測試

更新日期：2026-09-24

## 已實作

- 透過系統 `SMAppService` 控制開機自動啟動；只在 `.app` 中開放。
- 狀態欄精簡模式只顯示剩餘比例較低的平台；設定可保留。
- 剩餘用量低於 50% 的 macOS 提醒；以平台、視窗與重置時間去重，設定預設關閉。
- 網路恢復及 Mac 喚醒後立即刷新；既有失敗退避與離線快取繼續保留。
- `.app` 與可選 DMG 的本機打包腳本；預設使用免費的臨時簽章，亦可透過 `SIGNING_IDENTITY` 改用 Developer ID。
- Aivue SVG 已轉為 App `.icns`，安裝包使用新圖示；狀態欄與下拉 UI 尚未改動。
- Sparkle 2.10.0 已整合；有 HTTPS appcast 與 EdDSA 公鑰的安裝版會啟動更新器。未設定時不啟動。
- 提供 Developer ID 簽署、公證與 stapling 腳本，日後如改採正式發布可使用；目前不購買付費開發者資格。

## 打包

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer zsh scripts/package-app.sh
CREATE_DMG=1 DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer zsh scripts/package-app.sh
git tag v0.1.2 && git push origin main v0.1.2
APP_VERSION=0.1.2 APP_BUILD_NUMBER=3 zsh scripts/publish-update.sh
```

本機輸出位於 `dist/`。目前的下載版使用臨時簽章，沒有 Apple Developer ID 或公證；首次下載安裝時的 macOS 安全提示需另外驗收。

## 自動更新發布

- GitHub Pages 更新清單：[appcast.xml](https://zian0000.github.io/Aivue/appcast.xml)。Sparkle 目前使用的 `0.1.1` 更新封存檔：[Aivue-0.1.1.zip](https://zian0000.github.io/Aivue/Aivue-0.1.1.zip)。Pages 使用公開儲存庫的 `gh-pages` 分支。
- 一般下載安裝請使用 [v0.1.1 Release 的 DMG](https://github.com/Zian0000/Aivue/releases/download/v0.1.1/Aivue-0.1.1.dmg)；GitHub 在標籤頁自動提供的 Source code ZIP/TAR 是原始碼，不是 App 安裝檔。
- 更新簽章使用登入鑰匙圈中的 Sparkle 帳戶 `aivue`。私鑰不能加入 Git；應另外安全備份。失去私鑰會影響未來更新的簽章。
- `scripts/publish-update.sh` 以 `APP_VERSION` 與遞增的 `APP_BUILD_NUMBER` 打包、簽署更新封存檔與 appcast，推送到 `gh-pages`，並將同版本 DMG 加入 GitHub Release。先提交原始碼並建立 `v版本號` 標籤。此腳本需要 `dist/gh-pages` 工作目錄；新複製的專案可先執行 `git fetch origin gh-pages && git worktree add -b gh-pages dist/gh-pages origin/gh-pages`。若 Pages 推送成功但 Release 上傳失敗，可用 `python3 scripts/publish-github-release.py --version 版本號 --dmg dist/Aivue-版本號.dmg` 重試。
- 最初已安裝但沒有 `SUFeedURL` 與 `SUPublicEDKey` 的舊 App 無法自行升級，須手動安裝一次帶更新設定的版本。之後才會從上述更新清單檢查新版。
- `UPDATE_FEED_URL` 與 `UPDATE_PUBLIC_ED_KEY` 必須一起設定。Sparkle EdDSA 簽章與 Apple Developer ID 簽章不同；目前採用前者驗證更新檔。每次發布必須提高 `APP_BUILD_NUMBER`。

目前選擇低成本開發路線，暫不購買 Apple Developer Program，也不進行 Developer ID 簽署及公證。已驗證公開 appcast、更新封存檔與 EdDSA 簽章。2026-09-24 以隔離的 `0.1.0`（build 1）App 完成 Sparkle 更新提示、下載、解壓、安裝、重新啟動至 `0.1.1`（build 2）；新 App 通過 `codesign --verify --deep --strict`。若日後改採 Developer ID，`scripts/notarize-app.sh` 只讀取已存入 Keychain 的 notarytool profile，不在命令列或專案內保存 Apple 密碼。

## 待人工驗收

- 從 `.app` 啟用開機啟動後，登出／登入，確認只啟動一份。
- 首次開啟提醒權限、跨越 50% 門檻、App 重啟及重置後再次提醒。
- 長時間睡眠喚醒、網路斷線／恢復、時區變更。
- 在另一台 Mac 驗收未簽署版本的安裝與啟動體驗；正式簽署與公證目前不列入開發目標。
- 在另一台 Mac 驗收從已安裝版本升級的操作體驗。
