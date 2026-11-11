-- Linguagens dos projetos em ~/workspace.
-- Os extras do LazyVim (LSP, formatter, linter, DAP e neotest por linguagem) ficam em
-- lazyvim.json para carregar na ordem certa: Rust (rustaceanvim, crates.nvim, codelldb, toml),
-- Go, TypeScript/Tailwind/Prisma, Dart, Kotlin, Python, SQL, Terraform, Docker, YAML, JSON,
-- Markdown, Git, dap.core e test.core. Aqui fica só o que os extras não cobrem.
return {
  -- Swift: planta, souffleur (sourcekit-lsp e swift-format do Xcode, não vêm do Mason)
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        sourcekit = {
          mason = false,
          filetypes = { "swift", "objc", "objcpp" },
          root_dir = function(bufnr, on_dir)
            local root = vim.fs.root(bufnr, { "Package.swift", "buildServer.json", ".git" })
              or vim.fs.root(bufnr, function(name) return name:match("%.xcodeproj$") end)
            on_dir(root or vim.fn.getcwd())
          end,
        },
      },
    },
  },
  {
    "stevearc/conform.nvim",
    opts = {
      formatters_by_ft = {
        swift = { "swift_format" },
        sh = { "shfmt" },
        zsh = { "shfmt" },
      },
      formatters = {
        swift_format = { command = "xcrun", args = { "swift-format", "format", "--assume-filename", "$FILENAME" } },
      },
    },
  },

  -- SQL: tudo é Postgres
  {
    "stevearc/conform.nvim",
    opts = function(_, opts)
      opts.formatters = opts.formatters or {}
      opts.formatters.sqlfluff = { args = { "format", "--dialect=postgres", "-" }, require_cwd = false }
    end,
  },
  {
    "mfussenegger/nvim-lint",
    opts = function(_, opts)
      opts.linters = opts.linters or {}
      opts.linters.sqlfluff = { args = { "lint", "--format=json", "--dialect=postgres" } }
    end,
  },

  -- Shell scripts
  {
    "neovim/nvim-lspconfig",
    opts = { servers = { bashls = {} } },
  },

  -- Treesitter para o resto
  {
    "nvim-treesitter/nvim-treesitter",
    opts = {
      ensure_installed = {
        "swift", "kotlin", "dart", "sql", "terraform", "hcl", "bash",
        "html", "css", "lua", "toml", "yaml", "json", "dockerfile", "make",
        "gomod", "gosum", "gowork", "prisma", "rust", "tsx", "typescript",
      },
    },
  },

  -- Debug: Flutter/Dart e Swift (Go, TS, Rust, Python e Kotlin já vêm dos extras)
  {
    "mfussenegger/nvim-dap",
    optional = true,
    opts = function()
      local dap = require("dap")

      dap.adapters.dart = { type = "executable", command = "dart", args = { "debug_adapter" } }
      dap.adapters.flutter = { type = "executable", command = "flutter", args = { "debug_adapter" } }
      dap.configurations.dart = {
        { type = "flutter", request = "launch", name = "Flutter: rodar app", program = "lib/main.dart", cwd = "${workspaceFolder}" },
        { type = "dart", request = "launch", name = "Dart: arquivo atual", program = "${file}", cwd = "${workspaceFolder}" },
      }

      -- Swift (pacotes SwiftPM / CLIs). Apps iOS: depurar pelo Xcode.
      local lldb_dap = vim.fn.trim(vim.fn.system("xcrun --find lldb-dap 2>/dev/null"))
      if lldb_dap ~= "" and vim.v.shell_error == 0 then
        dap.adapters.lldb = { type = "executable", command = lldb_dap, name = "lldb" }
        dap.configurations.swift = {
          {
            type = "lldb",
            request = "launch",
            name = "Swift: rodar executável",
            program = function()
              return vim.fn.input("Executável: ", vim.fn.getcwd() .. "/.build/debug/", "file")
            end,
            cwd = "${workspaceFolder}",
          },
        }
      end
    end,
  },
}
