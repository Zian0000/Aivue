<img src="Aivue-logo2.svg" alt="Aivue Logo" width="96" />

# Aivue

這是一個 macOS 狀態列工具，用來顯示 Codex（ChatGPT 方案）與 Claude 的區段用量、總用量及重置時間。

## 安裝與更新

目前版本 `0.1.2`：[下載 macOS DMG](https://github.com/Zian0000/Aivue/releases/download/v0.1.2/Aivue-0.1.2.dmg)。打開 DMG 後，將 `Aivue.app` 複製到「應用程式」資料夾。支援 macOS 14 以上的 Apple Silicon Mac。

App 已接上 Sparkle 自動更新；從 `0.1.1` 升級到 `0.1.2` 的下載、安裝與重新啟動流程已驗證。目前版本採免費的臨時簽章，未使用 Apple Developer ID 公證。

## 專案狀態

- 第一階段：資料取得技術驗證 — 95%（核心驗收完成）
- 第二階段：單平台 Menu Bar 骨架 — 95%
- 第三階段：雙平台整合 — 95%
- 第四階段：產品化與測試 — 主要功能、App 圖示及 Sparkle 更新來源已實作；已完成 `0.1.0` → `0.1.1` → `0.1.2` 的升級驗證，其他 Mac 的安裝體驗仍待驗收

技術驗證細節請參閱 [docs/phase-1-feasibility.md](docs/phase-1-feasibility.md)。

第二階段實作狀態請參閱 [docs/phase-2-menu-bar.md](docs/phase-2-menu-bar.md)。

第三階段實作狀態請參閱 [docs/phase-3-claude.md](docs/phase-3-claude.md)。

第四階段與安裝打包方式請參閱 [docs/phase-4-productization.md](docs/phase-4-productization.md)。
