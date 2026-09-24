#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h:h}"
build_dir="${BUILD_DIR:-$project_dir/.build}"
output_dir="$project_dir/dist"
app_dir="$output_dir/Aivue.app"
developer_dir="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

DEVELOPER_DIR="$developer_dir" swift build -c release --disable-sandbox --scratch-path "$build_dir"
rm -rf "$app_dir"
mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"
cp "$build_dir/release/AIUsageMenuBar" "$app_dir/Contents/MacOS/AIUsageMenuBar"
sparkle_framework="$build_dir/artifacts/sparkle/Sparkle/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework"
if [[ ! -d "$sparkle_framework" ]]; then
  print -u2 '找不到 Sparkle.framework，無法製作可執行的 App。'
  exit 1
fi
mkdir -p "$app_dir/Contents/Frameworks"
ditto "$sparkle_framework" "$app_dir/Contents/Frameworks/Sparkle.framework"
resource_bundle="$build_dir/release/AIUsageMenuBar_AIUsageMenuBar.bundle"
if [[ -d "$resource_bundle" ]]; then
  ditto "$resource_bundle" "$app_dir/Contents/Resources/AIUsageMenuBar_AIUsageMenuBar.bundle"
fi

cp "$project_dir/scripts/Info.plist" "$app_dir/Contents/Info.plist"
if [[ -n "${APP_VERSION:-}" ]]; then
  /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $APP_VERSION" "$app_dir/Contents/Info.plist"
fi
if [[ -n "${APP_BUILD_NUMBER:-}" ]]; then
  /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $APP_BUILD_NUMBER" "$app_dir/Contents/Info.plist"
fi
if [[ -n "${UPDATE_FEED_URL:-}" || -n "${UPDATE_PUBLIC_ED_KEY:-}" ]]; then
  if [[ -z "${UPDATE_FEED_URL:-}" || -z "${UPDATE_PUBLIC_ED_KEY:-}" || "$UPDATE_FEED_URL" != https://* ]]; then
    print -u2 '更新設定需要 UPDATE_FEED_URL（HTTPS）及 UPDATE_PUBLIC_ED_KEY 同時提供。'
    exit 1
  fi
  /usr/libexec/PlistBuddy -c "Add :SUFeedURL string $UPDATE_FEED_URL" "$app_dir/Contents/Info.plist"
  /usr/libexec/PlistBuddy -c "Add :SUPublicEDKey string $UPDATE_PUBLIC_ED_KEY" "$app_dir/Contents/Info.plist"
fi
cp "$project_dir/Sources/AIUsageMenuBar/Resources/Aivue.icns" "$app_dir/Contents/Resources/Aivue.icns"

if [[ -n "${SIGNING_IDENTITY:-}" ]]; then
  codesign --force --deep --options runtime --timestamp --sign "$SIGNING_IDENTITY" "$app_dir"
else
  codesign --force --deep --sign - "$app_dir"
  print '未設定 SIGNING_IDENTITY：輸出臨時簽章的測試版，未經 Apple Developer ID 驗證。'
fi
codesign --verify --deep --strict --verbose=2 "$app_dir"

if [[ "${CREATE_DMG:-0}" == "1" ]]; then
  hdiutil create -quiet -volname Aivue -srcfolder "$app_dir" -format UDZO -ov "$output_dir/Aivue.dmg"
  print "完成：$output_dir/Aivue.dmg"
fi

print "完成：$app_dir"
