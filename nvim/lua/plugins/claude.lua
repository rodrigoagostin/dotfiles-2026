return {
  {
    "coder/claudecode.nvim",
    opts = {
      terminal = {
        split_side = "right",
        split_width_percentage = 0.42,
        snacks_win_opts = {
          keys = {
            term_normal = false,
            nav_j = false,
            nav_k = false,
            nav_l = false,
            claude_normal = { "<C-x>", "<C-\\><C-n>", mode = "t", desc = "Normal mode (scroll)" },
          },
        },
      },
      diff_opts = {
        keep_terminal_focus = true,
      },
    },
  },
}
