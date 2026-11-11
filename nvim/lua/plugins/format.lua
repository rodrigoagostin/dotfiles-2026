local config_names = {
  ".prettierrc",
  ".prettierrc.json",
  ".prettierrc.js",
  ".prettierrc.cjs",
  ".prettierrc.mjs",
  ".prettierrc.yaml",
  ".prettierrc.yml",
  "prettier.config.js",
  "prettier.config.cjs",
  "prettier.config.mjs",
}

local cache = {}

local function project_uses_prettier(dirname)
  if cache[dirname] ~= nil then
    return cache[dirname]
  end
  local found = #vim.fs.find(config_names, { upward = true, path = dirname }) > 0
  if not found then
    local dir = dirname
    while dir and dir ~= "/" do
      if vim.uv.fs_stat(dir .. "/node_modules/.bin/prettier") then
        found = true
        break
      end
      dir = vim.fs.dirname(dir)
    end
  end
  cache[dirname] = found
  return found
end

return {
  {
    "stevearc/conform.nvim",
    opts = function(_, opts)
      local prettier = opts.formatters and opts.formatters.prettier
      if not prettier then
        return
      end
      local base = prettier.condition
      prettier.condition = function(self, ctx)
        return project_uses_prettier(ctx.dirname) and (base == nil or base(self, ctx))
      end
    end,
  },
}
