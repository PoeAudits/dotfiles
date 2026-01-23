-- Default theme for server mode (when Omarchy theme symlink doesn't exist)
-- On desktop, the theme.lua symlink managed by Omarchy takes precedence

local theme_symlink = vim.fn.stdpath("config") .. "/lua/plugins/theme.lua"
local is_omarchy_desktop = vim.fn.filereadable(theme_symlink) == 1

-- Only apply default theme on server (when no Omarchy theme symlink exists)
if is_omarchy_desktop then
  return {}
end

return {
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "tokyonight",
    },
  },
}
