local function_patterns = {
  "(function_declaration name: (_) @name) @fn",
  "(generator_function_declaration name: (_) @name) @fn",
  "(method_definition name: (_) @name) @fn",
  "(variable_declarator name: (identifier) @name value: [(arrow_function) (function_expression)]) @fn",
  "(public_field_definition name: (_) @name value: [(arrow_function) (function_expression)]) @fn",
  "(field_definition property: (_) @name value: [(arrow_function) (function_expression)]) @fn",
  "(pair key: (property_identifier) @name value: [(arrow_function) (function_expression)]) @fn",
}

local function treesitter_functions(buf)
  local ok, parser = pcall(vim.treesitter.get_parser, buf)
  if not ok or not parser then
    return nil
  end
  local lang = parser:lang()
  if not vim.tbl_contains({ "typescript", "tsx", "javascript" }, lang) then
    return nil
  end
  local root = parser:parse()[1]:root()
  local file = vim.api.nvim_buf_get_name(buf)
  local items = {}
  for _, pattern in ipairs(function_patterns) do
    local parsed, query = pcall(vim.treesitter.query.parse, lang, pattern)
    if parsed then
      for _, match in query:iter_matches(root, buf, 0, -1) do
        local name, range
        for id, nodes in pairs(match) do
          local node = nodes[#nodes]
          if query.captures[id] == "name" then
            name = vim.treesitter.get_node_text(node, buf)
          else
            range = { node:range() }
          end
        end
        if name and range then
          table.insert(items, {
            text = name,
            name = name,
            file = file,
            buf = buf,
            pos = { range[1] + 1, range[2] },
            range = range,
          })
        end
      end
    end
  end
  table.sort(items, function(a, b)
    if a.range[1] ~= b.range[1] then
      return a.range[1] < b.range[1]
    end
    return a.range[2] < b.range[2]
  end)
  for _, item in ipairs(items) do
    item.depth = 0
    for _, other in ipairs(items) do
      local starts_before = other.range[1] < item.range[1]
        or (other.range[1] == item.range[1] and other.range[2] < item.range[2])
      local ends_after = other.range[3] > item.range[3]
        or (other.range[3] == item.range[3] and other.range[4] >= item.range[4])
      if other ~= item and starts_before and ends_after then
        item.depth = item.depth + 1
      end
    end
  end
  return items
end

local function function_symbols()
  local items = treesitter_functions(vim.api.nvim_get_current_buf())
  if not items then
    Snacks.picker.lsp_symbols({
      title = "Functions",
      filter = { default = { "Function", "Method", "Constructor" } },
    })
    return
  end
  Snacks.picker({
    title = "Functions",
    items = items,
    format = function(item)
      return {
        { string.rep("  ", item.depth) },
        { item.name, "Function" },
        { "  " },
        { tostring(item.pos[1]), "Comment" },
      }
    end,
  })
end

local function env_files()
  local root = LazyVim.root()
  local out = vim.system({
    "fd", "--hidden", "--no-ignore", "--type", "f", "--glob", ".env*",
    "--exclude", "node_modules", "--exclude", ".git", "--exclude", "cdk.out", "--exclude", "dist",
  }, { cwd = root, text = true }):wait()
  local files = vim.split(vim.trim(out.stdout or ""), "\n", { trimempty = true })
  if #files == 0 then
    vim.notify("No .env files found in " .. root, vim.log.levels.WARN)
    return
  end
  table.sort(files, function(a, b)
    local da, db = select(2, a:gsub("/", "")), select(2, b:gsub("/", ""))
    if da ~= db then
      return da < db
    end
    return a < b
  end)
  vim.ui.select(files, { prompt = ".env files" }, function(file)
    if file then
      vim.cmd.edit(vim.fn.fnameescape(root .. "/" .. file))
    end
  end)
end

return {
  {
    "snacks.nvim",
    opts = {
      picker = {
        sources = {
          files = { hidden = true },
        },
      },
    },
    keys = {
      { "<leader>fv", env_files, desc = "Find .env files" },
      { "<leader>sf", function_symbols, desc = "Functions (buffer)" },
    },
  },
}
