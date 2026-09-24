#!/usr/bin/env bash
set -euo pipefail
DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

mkdir -p ~/.claude
if [ -e ~/.claude/settings.json ] && [ ! -L ~/.claude/settings.json ]; then
  mv ~/.claude/settings.json ~/.claude/settings.json.bak
fi
ln -sf "$DOTFILES/claude/settings.json" ~/.claude/settings.json

while IFS=$'\t' read -r repo skills; do
  [ -z "$repo" ] && continue
  npx skills add "$repo" -g -y -s $skills
done < "$DOTFILES/claude/skills.list"
