local js_filetypes = { "typescript", "javascript", "typescriptreact", "javascriptreact" }
local state_file = vim.fn.stdpath("state") .. "/debug-run.json"

local function read_json(path)
  local fd = io.open(path, "r")
  if not fd then
    return nil
  end
  local ok, data = pcall(vim.json.decode, fd:read("*a"))
  fd:close()
  return ok and data or nil
end

local function write_json(path, data)
  local fd = io.open(path, "w")
  if fd then
    fd:write(vim.json.encode(data))
    fd:close()
  end
end

local function start_dir()
  local name = vim.api.nvim_buf_get_name(0)
  if vim.bo.buftype == "" and name ~= "" then
    return vim.fs.dirname(name)
  end
  return vim.uv.cwd()
end

local function package_manager(dir)
  local lock = vim.fs.find({ "yarn.lock", "pnpm-lock.yaml", "package-lock.json" }, { upward = true, path = dir })[1]
  local name = lock and vim.fs.basename(lock) or ""
  if name == "yarn.lock" then
    return "yarn"
  elseif name == "pnpm-lock.yaml" then
    return "pnpm"
  end
  return "npm"
end

local function collect_scripts()
  local files = vim.fs.find("package.json", { upward = true, path = start_dir(), limit = math.huge })
  local cwd_pkg = vim.uv.cwd() .. "/package.json"
  if vim.uv.fs_stat(cwd_pkg) and not vim.tbl_contains(files, cwd_pkg) then
    table.insert(files, cwd_pkg)
  end
  local items = {}
  for _, file in ipairs(files) do
    local pkg = read_json(file)
    if pkg and type(pkg.scripts) == "table" then
      local dir = vim.fs.dirname(file)
      local names = vim.tbl_keys(pkg.scripts)
      table.sort(names)
      for _, script in ipairs(names) do
        table.insert(items, {
          dir = dir,
          package = pkg.name or vim.fs.basename(dir),
          script = script,
          command = pkg.scripts[script],
        })
      end
    end
  end
  return items
end

local function parse_env(text)
  local env = { TURBO_ENV_MODE = "loose", FORCE_COLOR = "1" }
  for key, value in text:gmatch("([%w_]+)=(%S+)") do
    env[key] = value
  end
  return env
end

local function launch(item, env_text)
  require("dap").run({
    type = "pwa-node",
    request = "launch",
    name = item.script .. " (" .. item.package .. ")",
    cwd = item.dir,
    runtimeExecutable = package_manager(item.dir),
    runtimeArgs = { "run", item.script },
    env = parse_env(env_text),
    console = "integratedTerminal",
    sourceMaps = true,
    autoAttachChildProcesses = true,
    skipFiles = { "<node_internals>/**", "**/node_modules/**" },
    resolveSourceMapLocations = { "**", "!**/node_modules/**" },
  })
end

local function run_script()
  local items = collect_scripts()
  if #items == 0 then
    vim.notify("No package.json with scripts found", vim.log.levels.WARN)
    return
  end
  vim.ui.select(items, {
    prompt = "Run with debugger",
    format_item = function(item)
      return string.format("%-28s %-24s %s", item.script, item.package, item.command)
    end,
  }, function(item)
    if not item then
      return
    end
    local state = read_json(state_file) or {}
    vim.ui.input({ prompt = "Extra env (KEY=value ...): ", default = state[item.dir] or "" }, function(env_text)
      if env_text == nil then
        return
      end
      state[item.dir] = env_text
      write_json(state_file, state)
      launch(item, env_text)
    end)
  end)
end

return {
  {
    "mfussenegger/nvim-dap",
    keys = {
      { "<leader>dR", run_script, desc = "Run package.json script (debug)" },
      { "<leader>dx", function() require("dap").restart() end, desc = "Restart" },
      { "<F5>", function() require("dap").continue() end, desc = "Debug: Continue" },
      { "<F10>", function() require("dap").step_over() end, desc = "Debug: Step Over" },
      { "<F11>", function() require("dap").step_into() end, desc = "Debug: Step Into" },
      { "<F12>", function() require("dap").step_out() end, desc = "Debug: Step Out" },
    },
    opts = function()
      local dap = require("dap")
      local extra = {
        {
          type = "pwa-node",
          request = "attach",
          name = "Attach (port 9229)",
          port = 9229,
          cwd = "${workspaceFolder}",
          sourceMaps = true,
          skipFiles = { "<node_internals>/**", "**/node_modules/**" },
          resolveSourceMapLocations = { "**", "!**/node_modules/**" },
        },
        {
          type = "pwa-chrome",
          request = "launch",
          name = "Chrome (frontend on localhost)",
          url = function()
            return vim.fn.input("URL: ", "http://localhost:3000")
          end,
          webRoot = "${workspaceFolder}",
          sourceMaps = true,
          userDataDir = vim.fn.stdpath("cache") .. "/dap-chrome",
        },
      }
      for _, language in ipairs(js_filetypes) do
        dap.configurations[language] = dap.configurations[language] or {}
        for _, config in ipairs(extra) do
          table.insert(dap.configurations[language], vim.deepcopy(config))
        end
      end
    end,
  },
}
