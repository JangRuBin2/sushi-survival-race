#!/usr/bin/env bash
# 클라우드 세션(rokit 없음)에서 rokit.toml과 같은 버전의 도구를 받아요. docs/DEV-SETUP.md 6절.
#   bash tools/cloud/install-tools.sh [설치 폴더]   (기본: $HOME/.sushi-tools)
#   그다음 출력되는 export PATH=... 줄을 실행하세요 (명령마다 새 셸이면 매번).
set -euo pipefail
DEST="${1:-$HOME/.sushi-tools}"
mkdir -p "$DEST/bin"
cd "$DEST"
URLS=(
  "https://github.com/rojo-rbx/rojo/releases/download/v7.7.1/rojo-7.7.1-linux-x86_64.zip"
  "https://github.com/JohnnyMorganz/StyLua/releases/download/v2.5.2/stylua-linux-x86_64.zip"
  "https://github.com/Kampfkarren/selene/releases/download/0.32.0/selene-0.32.0-linux.zip"
  "https://github.com/lune-org/lune/releases/download/v0.10.5/lune-0.10.5-linux-x86_64.zip"
  "https://github.com/JohnnyMorganz/luau-lsp/releases/download/1.70.1/luau-lsp-linux-x86_64.zip"
)
for url in "${URLS[@]}"; do
  file="$(basename "$url")"
  [ -f "$file" ] || curl -sSLf -o "$file" "$url"
  unzip -o -q "$file" -d bin
done
chmod +x bin/*
echo "export PATH=$DEST/bin:\$PATH"
