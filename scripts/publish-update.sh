#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h:h}"
pages_dir="$project_dir/dist/gh-pages"
sparkle_bin="$project_dir/.build/artifacts/sparkle/Sparkle/bin"
feed_base='https://zian0000.github.io/Aivue'

if [[ -z "${APP_VERSION:-}" || -z "${APP_BUILD_NUMBER:-}" ]]; then
  print -u2 '請設定 APP_VERSION 與 APP_BUILD_NUMBER。'
  exit 1
fi
if ! git -C "$project_dir" show-ref --verify --quiet "refs/tags/v$APP_VERSION"; then
  print -u2 "請先提交原始碼並建立 v$APP_VERSION 標籤。"
  exit 1
fi
if [[ "$(git -C "$project_dir" rev-parse HEAD)" != "$(git -C "$project_dir" rev-parse "refs/tags/v$APP_VERSION^{commit}")" ]]; then
  print -u2 "目前 HEAD 必須是 v$APP_VERSION 標籤指向的提交。"
  exit 1
fi
if [[ -n "$(git -C "$project_dir" status --porcelain --untracked-files=no)" ]]; then
  print -u2 '原始碼有未提交的修改，請先提交並更新版本標籤。'
  exit 1
fi
if [[ -z "$(git -C "$project_dir" ls-remote origin "refs/tags/v$APP_VERSION")" ]]; then
  print -u2 "請先將 v$APP_VERSION 標籤推送到 GitHub。"
  exit 1
fi
if [[ ! -d "$pages_dir/.git" && ! -f "$pages_dir/.git" ]]; then
  print -u2 "找不到 gh-pages 工作目錄：$pages_dir"
  exit 1
fi
if [[ ! -x "$sparkle_bin/generate_keys" || ! -x "$sparkle_bin/generate_appcast" ]]; then
  print -u2 '找不到 Sparkle 簽章工具，請先執行 swift build。'
  exit 1
fi

git -C "$pages_dir" pull --ff-only
if [[ -n "$(git -C "$pages_dir" status --porcelain)" ]]; then
  print -u2 'gh-pages 工作目錄有未提交的修改，請先處理。'
  exit 1
fi

archive="$pages_dir/Aivue-$APP_VERSION.zip"
if [[ -e "$archive" ]]; then
  print -u2 "版本封存檔已存在：$archive"
  exit 1
fi

public_key="$($sparkle_bin/generate_keys --account aivue -p)"
APP_VERSION="$APP_VERSION" APP_BUILD_NUMBER="$APP_BUILD_NUMBER" \
  UPDATE_FEED_URL="$feed_base/appcast.xml" UPDATE_PUBLIC_ED_KEY="$public_key" \
  CREATE_DMG=1 zsh "$project_dir/scripts/package-app.sh"

app_dir="$project_dir/dist/Aivue.app"
dmg="$project_dir/dist/Aivue-$APP_VERSION.dmg"
mv "$project_dir/dist/Aivue.dmg" "$dmg"
ditto -c -k --sequesterRsrc --keepParent "$app_dir" "$archive"
"$sparkle_bin/generate_appcast" --account aivue \
  --download-url-prefix "$feed_base/" --maximum-deltas 0 "$pages_dir"

git -C "$pages_dir" add -A
git -C "$pages_dir" commit -m "Publish Aivue $APP_VERSION ($APP_BUILD_NUMBER)"
git -C "$pages_dir" push origin gh-pages
python3 "$project_dir/scripts/publish-github-release.py" --version "$APP_VERSION" --dmg "$dmg"
print "更新已發布：$feed_base/appcast.xml"
