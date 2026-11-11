# dotfiles

Neovim (LazyVim) and tmux setup for TypeScript work, tuned for debugging,
GitHub workflows and Claude Code, all without leaving the terminal.

```
.
├── nvim/          LazyVim config (symlinked to ~/.config/nvim)
├── tmux/          tmux.conf (symlinked to ~/.tmux.conf)
├── zsh/           shell aliases
└── install.sh     links everything into place
```

## Install

```sh
git clone https://github.com/rodrigoagostin/dotfiles-2026.git ~/workspace/dotfiles-2026
~/workspace/dotfiles-2026/install.sh --deps   # --deps installs neovim, tmux, lazygit, fd, ripgrep, gh and node via Homebrew
```

Existing files are backed up with a timestamp before being replaced. Open
`nvim` once so lazy.nvim installs the plugins, then run `gh auth login` for the
GitHub features.

Requirements: Neovim 0.12+, tmux 3.3+, macOS (clipboard uses `pbcopy`).

## Neovim

Built on [LazyVim](https://www.lazyvim.org) with these extras:
`lang.typescript`, `lang.json`, `lang.markdown`, `dap.core`,
`formatting.prettier`, `linting.eslint`, `ai.claudecode`.

Everything below is custom and lives in `nvim/lua/plugins`.

### Debugging (`debug.lua`)

| Key          | Action                                                        |
| ------------ | ------------------------------------------------------------- |
| `<leader>dR` | Pick a `package.json` script and run it under the debugger    |
| `<leader>dx` | Restart the current session                                   |
| `F5`         | Continue                                                      |
| `F10`        | Step over                                                     |
| `F11`        | Step into                                                     |
| `F12`        | Step out                                                      |

`<leader>dR` finds every `package.json` from the current file up to the
project root, picks yarn, pnpm or npm from the lockfile and launches the
script with `js-debug-adapter`, attaching to child processes automatically.
It sets `TURBO_ENV_MODE=loose` so the debugger survives turbo's strict env
mode, and remembers extra `KEY=value` env per package.

Two extra DAP configurations are registered for `ts/js/tsx/jsx`: attach to a
process on port 9229 and launch Chrome against a localhost URL.

### Git and GitHub (`pipeline.lua`, `reviews.lua`)

| Key          | Action                                                    |
| ------------ | --------------------------------------------------------- |
| `<leader>gt` | Toggle the pipeline panel for the tracked run             |
| `<leader>ga` | Pick any recent GitHub Actions run in this repo           |
| `<leader>gm` | Pick one of your own runs                                 |
| `<leader>gA` | Open the Actions page in the browser                      |
| `<leader>gr` | PRs awaiting your review in this repo                     |
| `<leader>gR` | PRs awaiting your review across all repos                 |

The pipeline panel lists only the steps that actually ran, with pass/fail and
durations, refreshes every 6 seconds while the run is in progress and
notifies when it finishes. Inside the panel: `o` opens the run on GitHub,
`r` refreshes, `q` closes.

### Pickers (`picker.lua`)

| Key          | Action                                                           |
| ------------ | ---------------------------------------------------------------- |
| `<leader>fv` | Find `.env*` files in the project (node_modules, dist excluded)  |
| `<leader>sf` | Functions in the current buffer                                  |

`<leader>sf` uses Treesitter on JS/TS so it lists declared functions, methods
and `const x = () =>` while skipping inline callbacks; other languages fall
back to LSP symbols filtered to functions.

### Claude Code (`claude.lua`)

| Key          | Action                                    |
| ------------ | ----------------------------------------- |
| `<leader>ac` | Toggle the Claude panel                   |
| `Ctrl-/`     | Hide the panel and keep editing           |
| `Ctrl-x`     | Normal mode inside the terminal to scroll |

### Other

| Key              | Action                                              |
| ---------------- | --------------------------------------------------- |
| `Ctrl-h/j/k/l`   | Move between Neovim windows and tmux panes          |
| `<leader>qr`     | Restart Neovim and restore the session              |

Prettier only runs in projects that have a Prettier config or a local
`prettier` binary (`format.lua`), and `.env` files are never auto-formatted.

## tmux

Prefix stays `Ctrl-b`.

| Key                  | Action                                 |
| -------------------- | -------------------------------------- |
| `prefix c`           | New window in the current directory    |
| `prefix \|` / `-`    | Split right / below                    |
| `prefix x`           | Kill pane                              |
| `prefix H/J/K/L`     | Resize pane (repeatable)               |
| `Ctrl-h/j/k/l`       | Move between panes (Neovim aware)      |
| `prefix g`           | lazygit in a popup                     |
| `prefix r`           | Reload config                          |
| `v` / `y` (copy mode)| Select / copy to the system clipboard  |

Windows start at 1, renumber on close, mouse is on and the status line is kept
minimal.

## zsh

`zsh/aliases.zsh` adds `t`, which attaches to the `main` tmux session or
creates it.
