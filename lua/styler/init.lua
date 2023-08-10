local M = {}

---@type table<string, Theme>
M.themes = {}
---@type table<buffer, Theme>
M.bufs = {}

---@alias Theme {colorscheme: string, background?: "light"|"dark"}
---@alias ThemeHighlights table<string, table>

--added by RW from transparent.nvim
local tr_config = {
  groups = {
    'Normal', 'NormalNC', 'Comment', 'Constant', 'Special', 'Identifier',
    'Statement', 'PreProc', 'Type', 'Underlined', 'Todo', 'String', 'Function',
    'Conditional', 'Repeat', 'Operator', 'Structure', 'LineNr', 'NonText',
    'SignColumn', 'CursorLineNr', 'EndOfBuffer',
  },
  extra_groups = {},
  exclude_groups = {},
}
---@param group string|string[]
local function clear_group(group)
    local groups = type(group) == "string" and { group } or group
    for _, v in ipairs(groups) do
        if not vim.tbl_contains(tr_config.exclude_groups, v) then
            pcall(function()
                local attrs = vim.tbl_extend(
                    "force",
                    vim.api.nvim_get_hl_by_name(v, true),
                    { bg = "NONE", ctermbg = "NONE" }
                )
                attrs[true] = nil
                vim.api.nvim_set_hl(0, v, attrs)
            end)
        end
    end
end

local function tr_clear()
    -- local start = vim.loop.hrtime()

    clear_group(tr_config.groups)
    clear_group(tr_config.extra_groups)
    clear_group(type(vim.g.transparent_groups) == "table" and vim.g.transparent_groups or {})

    -- print((vim.loop.hrtime() - start) / 1e6, "ms")
end

---@param win window window id or 0 for the current window
---@param theme Theme
function M.set_theme(win, theme)
  win = win == 0 and vim.api.nvim_get_current_win() or win

  vim.w[win].theme = theme
  local ns = require("styler.theme").load(theme)
  vim.api.nvim_win_set_hl_ns(win, ns)
    tr_clear() -- set transparency - RW
end

function M.clear(win)
  if vim.w[win].theme then
    vim.api.nvim_win_set_hl_ns(win, 0)
    vim.w[win].theme = nil
  end
end

---@param opts? {buf?: number}
function M.update(opts)
  opts = opts or {}

  if opts.buf then
    opts.buf = opts.buf == 0 and vim.api.nvim_get_current_buf() or opts.buf
  end

  local wins = vim.api.nvim_list_wins()
  for _, win in ipairs(wins) do
    local buf = vim.api.nvim_win_get_buf(win)
    if not (opts.buf and opts.buf ~= buf) then
      local ft = vim.bo[buf].filetype
      local theme = M.bufs[buf] or M.themes[ft]
      if theme then
        M.set_theme(win, theme)
      else
        M.clear(win)
      end
    end
  end
end

---@param opts {themes: table<string, Theme>}
function M.setup(opts)
  M.themes = opts.themes
  local group = vim.api.nvim_create_augroup("styler", { clear = true })

  vim.api.nvim_create_user_command("Styler", function(event)
    ---@type string
    local colorscheme = event.args
    local theme = { colorscheme = colorscheme }
    M.bufs[vim.api.nvim_get_current_buf()] = theme
    M.set_theme(0, theme)
  end, {
    nargs = 1,
    desc = "Set colorscheme for the current window",
    complete = "color",
  })

  vim.api.nvim_create_autocmd("OptionSet", {
    group = group,
    pattern = "winhighlight",
    callback = function(event)
      ---@type number
      local buf = event.buf == 0 and vim.api.nvim_get_current_buf() or event.buf
      -- needs to be loaded twice, to prevent flickering
      -- due to the internal setting of winhighlight
      M.update({ buf = buf })
      vim.schedule(function()
        M.update({ buf = buf })
      end)
    end,
  })

  vim.api.nvim_create_autocmd({ "FileType", "BufWinEnter" ,"WinNew"}, {
    group = group,
    callback = function(event)
      M.update({ buf = event.buf })
    end,
  })
  M.update()
end

return M
