-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

vim.keymap.set("n", "<leader>qr", "<cmd>restart<cr>", { desc = "Restart Neovim" })

-- Rust: run the project (cargo run) in a terminal split
vim.keymap.set("n", "<leader>rr", function()
  vim.cmd("w")
  -- find the nearest Cargo.toml above the current file (not the folder nvim was opened in)
  local root = vim.fs.root(0, "Cargo.toml")
  if not root then
    vim.notify("No Cargo.toml found above this file", vim.log.levels.WARN)
    return
  end
  -- if the file is in src/bin/, run that binary (e.g. src/bin/02_variables.rs -> --bin 02_variables)
  local cmd = "cargo run"
  local file = vim.api.nvim_buf_get_name(0)
  if file:match("/src/bin/[^/]+%.rs$") then
    cmd = cmd .. " --bin " .. vim.fn.fnamemodify(file, ":t:r")
  end
  Snacks.terminal(cmd, { cwd = root, auto_close = false, win = { position = "bottom" } })
end, { desc = "Cargo run" })

-- Rust: pick what to run (main, tests, examples...)
vim.keymap.set("n", "<leader>rp", function()
  vim.cmd.RustLsp("runnables")
end, { desc = "Rust runnables (pick)" })

-- Rust: run the last runnable again
vim.keymap.set("n", "<leader>rl", function()
  vim.cmd.RustLsp({ "runnables", bang = true })
end, { desc = "Rust rerun last" })

-- Rust exercises: run all tests with Ferris' status (scripts/ferris.sh)
vim.keymap.set("n", "<leader>rt", function()
  vim.cmd("silent! wall")
  local root = vim.fs.root(0, "Cargo.toml")
  if not root or vim.fn.filereadable(root .. "/scripts/ferris.sh") == 0 then
    vim.notify("scripts/ferris.sh not found above this file", vim.log.levels.WARN)
    return
  end
  Snacks.terminal("./scripts/ferris.sh", { cwd = root, auto_close = false, win = { position = "bottom" } })
end, { desc = "Ferris: run all tests" })
