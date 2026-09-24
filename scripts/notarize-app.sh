#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h:h}"
app_dir="$project_dir/dist/Aivue.app"
dmg="$project_dir/dist/Aivue.dmg"

if [[ -z "${NOTARY_PROFILE:-}" ]]; then
  print -u2 '請先在 Keychain 設定 notarytool profile，並提供 NOTARY_PROFILE。'
  exit 1
fi
if [[ ! -f "$dmg" || ! -d "$app_dir" ]]; then
  print -u2 '找不到 .app 或 DMG；請先以 SIGNING_IDENTITY 和 CREATE_DMG=1 打包。'
  exit 1
fi

codesign --verify --deep --strict --verbose=2 "$app_dir"
xcrun notarytool submit "$dmg" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$dmg"
xcrun stapler validate "$dmg"
print "公證完成：$dmg"
