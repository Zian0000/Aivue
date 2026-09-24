#!/usr/bin/env python3
"""Attach a built DMG to the matching GitHub release."""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

REPOSITORY = "Zian0000/Aivue"
API = f"https://api.github.com/repos/{REPOSITORY}"


def github_token() -> str:
    result = subprocess.run(
        ["git", "credential", "fill"],
        input="protocol=https\nhost=github.com\n\n",
        text=True,
        capture_output=True,
        check=True,
    )
    credential = dict(line.split("=", 1) for line in result.stdout.splitlines() if "=" in line)
    if not credential.get("password"):
        raise RuntimeError("找不到 GitHub 憑證，無法上傳 Release 附件。")
    return credential["password"]


def request(url: str, token: str, method: str = "GET", data: bytes | None = None,
            content_type: str = "application/vnd.github+json"):
    headers = {
        "Authorization": f"Bearer {token}",
        "Accept": "application/vnd.github+json",
        "Content-Type": content_type,
        "User-Agent": "Aivue-release-publisher",
        "X-GitHub-Api-Version": "2022-11-28",
    }
    req = urllib.request.Request(url, data=data, method=method, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=120) as response:
            return json.load(response)
    except urllib.error.HTTPError as error:
        detail = json.load(error)
        raise RuntimeError(f"GitHub API {error.code}: {detail.get('message', '未知錯誤')}") from error


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--version", required=True)
    parser.add_argument("--dmg", type=Path, required=True)
    args = parser.parse_args()
    if not args.dmg.is_file():
        raise RuntimeError(f"找不到 DMG：{args.dmg}")

    token = github_token()
    tag = f"v{args.version}"
    try:
        release = request(f"{API}/releases/tags/{urllib.parse.quote(tag)}", token)
    except RuntimeError as error:
        if "GitHub API 404:" not in str(error):
            raise
        body = (
            f"Aivue {args.version}，支援 macOS 14+ 與 Apple Silicon。\n\n"
            "下載下方 DMG 安裝。此版本使用臨時簽章，未經 Apple Developer ID 公證。"
            "App 內的 Sparkle 更新會透過 EdDSA 簽章驗證後續版本。"
        )
        release = request(
            f"{API}/releases", token, method="POST",
            data=json.dumps({"tag_name": tag, "name": tag, "body": body}).encode(),
        )

    if any(asset["name"] == args.dmg.name for asset in release.get("assets", [])):
        print(f"Release 附件已存在：{args.dmg.name}")
        return

    upload_url = release["upload_url"].split("{", 1)[0]
    upload_url += "?" + urllib.parse.urlencode({"name": args.dmg.name})
    asset = request(
        upload_url, token, method="POST", data=args.dmg.read_bytes(),
        content_type="application/x-apple-diskimage",
    )
    if asset.get("size") != args.dmg.stat().st_size:
        raise RuntimeError("GitHub 回報的附件大小與本機 DMG 不一致。")
    print(f"已上傳：{asset['browser_download_url']}")


if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, subprocess.CalledProcessError) as error:
        print(error, file=sys.stderr)
        sys.exit(1)
