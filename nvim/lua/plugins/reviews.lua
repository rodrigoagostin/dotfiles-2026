local function age(iso)
  local y, mo, d, h, mi, s = (iso or ""):match("(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+)")
  if not y then
    return ""
  end
  local utc = os.time({ year = y, month = mo, day = d, hour = h, min = mi, sec = s })
  local diff = os.time() - (utc + (os.time() - os.time(os.date("!*t"))))
  if diff < 3600 then
    return math.max(0, math.floor(diff / 60)) .. "min"
  elseif diff < 86400 then
    return math.floor(diff / 3600) .. "h"
  end
  return math.floor(diff / 86400) .. "d"
end

local function show(prs, scope)
  if #prs == 0 then
    vim.notify("No PRs awaiting your review in " .. scope, vim.log.levels.INFO)
    return
  end
  vim.ui.select(prs, {
    prompt = "PRs awaiting my review (" .. scope .. ")",
    format_item = function(pr)
      return string.format(
        "%-30s %-18s %-5s %s%s",
        (pr.repository.name .. "#" .. pr.number):sub(1, 30),
        pr.author.login:sub(1, 18),
        age(pr.createdAt),
        pr.isDraft and "[draft] " or "",
        pr.title
      )
    end,
  }, function(pr)
    if pr then
      Snacks.picker.gh_actions({ type = "pr", repo = pr.repository.nameWithOwner, number = pr.number })
    end
  end)
end

local function search(repo, scope)
  local fields = "repository,number,title,author,createdAt,isDraft,url"
  local args = { "gh", "search", "prs", "--review-requested=@me", "--state=open", "--limit", "50", "--json", fields }
  if repo then
    vim.list_extend(args, { "--repo", repo })
  end
  vim.system(args, { text = true }, function(out)
    vim.schedule(function()
      local ok, prs = pcall(vim.json.decode, out.stdout or "")
      if out.code ~= 0 or not ok then
        vim.notify("Could not fetch PRs: " .. vim.trim(out.stderr or ""), vim.log.levels.WARN)
        return
      end
      show(prs, scope)
    end)
  end)
end

local function review_requests(all_repos)
  if all_repos then
    search(nil, "all repos")
    return
  end
  local args = { "gh", "repo", "view", "--json", "nameWithOwner", "-q", ".nameWithOwner" }
  vim.system(args, { cwd = LazyVim.root.git(), text = true }, function(out)
    vim.schedule(function()
      local repo = vim.trim(out.stdout or "")
      if out.code ~= 0 or repo == "" then
        vim.notify("Not inside a GitHub repository", vim.log.levels.WARN)
        return
      end
      search(repo, repo:match("[^/]+$"))
    end)
  end)
end

return {
  {
    "snacks.nvim",
    keys = {
      { "<leader>gr", function() review_requests(false) end, desc = "PRs awaiting my review (this repo)" },
      { "<leader>gR", function() review_requests(true) end, desc = "PRs awaiting my review (all repos)" },
    },
  },
}
