local icons = {
  success = "✓",
  failure = "✗",
  cancelled = "⊘",
  skipped = "–",
  in_progress = "●",
  queued = "○",
  waiting = "○",
  pending = "○",
}

local my_login

local function to_epoch(iso)
  local y, mo, d, h, mi, s = (iso or ""):match("(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+)")
  if not y then
    return nil
  end
  local utc = os.time({ year = y, month = mo, day = d, hour = h, min = mi, sec = s })
  return utc + (os.time() - os.time(os.date("!*t")))
end

local function span(seconds)
  seconds = math.max(0, seconds)
  if seconds < 60 then
    return seconds .. "s"
  elseif seconds < 3600 then
    return math.floor(seconds / 60) .. "min"
  elseif seconds < 86400 then
    return math.floor(seconds / 3600) .. "h"
  end
  return math.floor(seconds / 86400) .. "d"
end

local function state_of(run)
  return run.status == "completed" and run.conclusion or run.status
end

local function progress_of(run)
  local started = to_epoch(run.run_started_at) or os.time()
  if run.status == "completed" then
    return "took " .. span((to_epoch(run.updated_at) or started) - started)
  end
  local elapsed = span(os.time() - started) .. " ago"
  if run.jobs_total then
    return string.format("%d/%d jobs, started %s", run.jobs_done, run.jobs_total, elapsed)
  end
  return elapsed
end

local function gh(args, root, callback)
  vim.system(vim.list_extend({ "gh" }, args), { cwd = root, text = true }, function(out)
    vim.schedule(function()
      local ok, data = pcall(vim.json.decode, out.stdout or "")
      callback(out.code == 0 and ok and data or nil, vim.trim(out.stderr or ""))
    end)
  end)
end

local hidden_steps = { ["Set up job"] = true, ["Complete job"] = true }
local namespace = vim.api.nvim_create_namespace("pipeline_panel")
local icon_hl = {
  ["✓"] = "DiagnosticOk",
  ["✗"] = "DiagnosticError",
  ["●"] = "DiagnosticWarn",
  ["○"] = "Comment",
  ["⊘"] = "Comment",
  ["–"] = "Comment",
}
local panel = { run = nil, root = nil, jobs = {}, win = nil, buf = nil, timer = nil }

local function took(item)
  local started = to_epoch(item.started_at)
  if not started then
    return ""
  end
  if item.status == "completed" then
    return span((to_epoch(item.completed_at) or started) - started)
  end
  return span(os.time() - started) .. " ago"
end

local function render()
  if not (panel.buf and vim.api.nvim_buf_is_valid(panel.buf)) then
    return
  end
  local run = panel.run
  local lines = {
    string.format("%s %s · %s · %s · %s", icons[state_of(run)] or "?", run.name, run.head_branch, run.actor, progress_of(run)),
    "  " .. run.display_title,
    "",
  }
  for _, job in ipairs(panel.jobs) do
    local job_state = state_of(job)
    if job_state ~= "skipped" then
      table.insert(lines, string.format("%s %-58s %s", icons[job_state] or "?", job.name:sub(1, 58), took(job)))
      for _, step in ipairs(job.steps or {}) do
        local step_state = state_of(step)
        local ran = step_state ~= "skipped" and step.status ~= "queued" and step.status ~= "pending"
        if ran and not hidden_steps[step.name] and not step.name:match("^Post ") then
          table.insert(lines, string.format("    %s %-54s %s", icons[step_state] or "?", step.name:sub(1, 54), took(step)))
        end
      end
    end
  end
  vim.bo[panel.buf].modifiable = true
  vim.api.nvim_buf_set_lines(panel.buf, 0, -1, false, lines)
  vim.bo[panel.buf].modifiable = false
  vim.api.nvim_buf_clear_namespace(panel.buf, namespace, 0, -1)
  for index, line in ipairs(lines) do
    local indent, icon = line:match("^(%s*)([^%s%w]+) ")
    if icon and icon_hl[icon] then
      vim.api.nvim_buf_set_extmark(panel.buf, namespace, index - 1, #indent, {
        end_col = #indent + #icon,
        hl_group = icon_hl[icon],
      })
    end
  end
end

local function stop_timer()
  if panel.timer then
    panel.timer:stop()
    panel.timer:close()
    panel.timer = nil
  end
end

local function refresh()
  local run, root = panel.run, panel.root
  if not run then
    return
  end
  local base = "repos/{owner}/{repo}/actions/runs/" .. run.id
  gh({ "api", base }, root, function(raw)
    if panel.run ~= run then
      return
    end
    if raw then
      local was_running = run.status ~= "completed"
      run.status, run.conclusion, run.updated_at = raw.status, raw.conclusion, raw.updated_at
      if was_running and run.status == "completed" then
        stop_timer()
        local ok = run.conclusion == "success"
        vim.notify(
          (ok and "✓ passed: " or "✗ " .. tostring(run.conclusion) .. ": ") .. run.name .. " (" .. run.head_branch .. ")",
          ok and vim.log.levels.INFO or vim.log.levels.ERROR,
          { title = "Pipeline" }
        )
      end
    end
    gh({ "api", base .. "/jobs?per_page=100" }, root, function(jobs)
      if panel.run ~= run then
        return
      end
      if jobs and jobs.jobs then
        panel.jobs = jobs.jobs
        run.jobs_total = #jobs.jobs
        run.jobs_done = #vim.tbl_filter(function(job)
          return job.status == "completed"
        end, jobs.jobs)
      end
      render()
    end)
  end)
end

local function open_panel()
  if not (panel.buf and vim.api.nvim_buf_is_valid(panel.buf)) then
    panel.buf = vim.api.nvim_create_buf(false, true)
    vim.bo[panel.buf].bufhidden = "hide"
    vim.bo[panel.buf].filetype = "pipeline"
    local function map(key, fn)
      vim.keymap.set("n", key, fn, { buffer = panel.buf, nowait = true })
    end
    map("q", function()
      panel.win:hide()
    end)
    map("<Esc>", function()
      panel.win:hide()
    end)
    map("r", refresh)
    map("o", function()
      vim.ui.open(panel.run.url)
    end)
  end
  if panel.win and panel.win:valid() then
    panel.win:focus()
    return
  end
  panel.win = Snacks.win({
    buf = panel.buf,
    position = "float",
    width = 86,
    height = 0.7,
    border = "rounded",
    title = " Pipeline ",
    title_pos = "center",
    footer = " o open on GitHub   r refresh   q close ",
    footer_pos = "center",
    wo = { wrap = false, cursorline = true, number = false, relativenumber = false, signcolumn = "no" },
  })
end

local function show(root, run)
  stop_timer()
  panel.run, panel.root, panel.jobs = run, root, {}
  open_panel()
  render()
  refresh()
  if run.status ~= "completed" then
    panel.timer = vim.uv.new_timer()
    panel.timer:start(6000, 6000, vim.schedule_wrap(refresh))
  end
end

local function select_run(root, runs, action, only_mine, first)
  if only_mine then
    runs = vim.tbl_filter(function(run)
      return run.actor == my_login
    end, runs)
    if #runs == 0 then
      vim.notify("None of the 40 most recent runs are yours", vim.log.levels.INFO)
      return
    end
  end
  if first then
    action(root, runs[1])
    return
  end
  vim.ui.select(runs, {
    prompt = only_mine and "My pipelines" or "Pipelines",
    format_item = function(run)
      return string.format(
        "%s %s %-22s %-26s %-14s %-5s %-18s %s",
        icons[state_of(run)] or "?",
        run.actor == my_login and "★" or " ",
        run.name:sub(1, 22),
        run.head_branch:sub(1, 26),
        run.actor:sub(1, 14),
        span(os.time() - (to_epoch(run.created_at) or os.time())),
        progress_of(run),
        run.display_title
      )
    end,
  }, function(run)
    if run then
      action(root, run)
    end
  end)
end

local function pick_run(action, only_mine, first)
  local root = LazyVim.root.git()
  local function load()
    gh({ "api", "repos/{owner}/{repo}/actions/runs?per_page=40" }, root, function(data, err)
      if not data or not data.workflow_runs or #data.workflow_runs == 0 then
        vim.notify("Could not list pipelines: " .. err, vim.log.levels.WARN)
        return
      end
      local runs = {}
      local pending = 0
      local function done()
        if pending == 0 then
          select_run(root, runs, action, only_mine, first)
        end
      end
      for _, raw in ipairs(data.workflow_runs) do
        local actor = raw.triggering_actor or raw.actor or {}
        local run = {
          id = raw.id,
          name = raw.name or "?",
          head_branch = type(raw.head_branch) == "string" and raw.head_branch or "-",
          display_title = raw.display_title or "",
          status = raw.status,
          conclusion = raw.conclusion,
          created_at = raw.created_at,
          run_started_at = raw.run_started_at,
          updated_at = raw.updated_at,
          url = raw.html_url,
          actor = actor.login or "?",
        }
        table.insert(runs, run)
        if run.status == "in_progress" then
          pending = pending + 1
          gh({ "api", "repos/{owner}/{repo}/actions/runs/" .. run.id .. "/jobs?per_page=100" }, root, function(jobs)
            if jobs and jobs.jobs then
              run.jobs_total = #jobs.jobs
              run.jobs_done = #vim.tbl_filter(function(job)
                return job.status == "completed"
              end, jobs.jobs)
            end
            pending = pending - 1
            done()
          end)
        end
      end
      done()
    end)
  end
  if my_login then
    load()
    return
  end
  gh({ "api", "user" }, root, function(user)
    my_login = user and user.login or ""
    load()
  end)
end

local function toggle_panel()
  if panel.win and panel.win:valid() then
    panel.win:hide()
    return
  end
  if panel.run then
    open_panel()
    refresh()
    return
  end
  pick_run(show, true, true)
end

return {
  {
    "snacks.nvim",
    keys = {
      { "<leader>gt", toggle_panel, desc = "Pipeline (toggle)" },
      { "<leader>ga", function() pick_run(show) end, desc = "GitHub Actions (all)" },
      { "<leader>gm", function() pick_run(show, true) end, desc = "GitHub Actions (mine)" },
      { "<leader>gA", function() pick_run(function(_, run) vim.ui.open(run.url) end) end, desc = "GitHub Actions (open in browser)" },
    },
  },
}
