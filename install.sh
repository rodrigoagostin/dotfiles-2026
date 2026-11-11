#!/usr/bin/env bash
set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"

link() {
  local source="$1" target="$2"
  if [ -L "$target" ] && [ "$(readlink "$target")" = "$source" ]; then
    echo "ok       $target"
    return
  fi
  if [ -e "$target" ] || [ -L "$target" ]; then
    mv "$target" "$target.bak-$STAMP"
    echo "backup   $target -> $target.bak-$STAMP"
  fi
  mkdir -p "$(dirname "$target")"
  ln -s "$source" "$target"
  echo "linked   $target"
}

install_deps() {
  if ! command -v brew >/dev/null; then
    echo "Homebrew not found, skipping dependencies"
    return
  fi
  brew install neovim tmux lazygit fd ripgrep gh node
}

[ "${1:-}" = "--deps" ] && install_deps

link "$DOTFILES/nvim" "$HOME/.config/nvim"
link "$DOTFILES/tmux/tmux.conf" "$HOME/.tmux.conf"

if ! grep -q "dotfiles-2026/zsh/aliases.zsh" "$HOME/.zshrc" 2>/dev/null; then
  echo
  echo "Add this line to your ~/.zshrc:"
  echo "  source \"$DOTFILES/zsh/aliases.zsh\""
fi

echo
echo "Done. Open nvim once to let lazy.nvim install the plugins."
