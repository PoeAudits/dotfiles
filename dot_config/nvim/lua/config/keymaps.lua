-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here
--
vim.keymap.set("n", "<leader>j", "<cmd>cnext<CR>zz")
vim.keymap.set("n", "<leader>k", "<cmd>cprev<CR>zz")
vim.keymap.set("n", "<leader>l", "<cmd>lnext<CR>zz")
vim.keymap.set("n", "<leader>h", "<cmd>lprev<CR>zz")
vim.keymap.set("i", "jj", "<Esc>", { desc = "Exit insert mode" })
vim.keymap.set("n", "<leader>o", "o<Esc>k")
vim.keymap.set("n", "<leader>O", "O<Esc>")

-- vim.keymap.set("n", "<leader>ac", function()
--   local cmd = [[tmux send-keys -t "$(tmux display-message -p '\#S'):git" 'opencode run "/commit"' C-m]]
--   vim.fn.system(cmd)
-- end, { desc = "Agent Commit with Opencode" })
-- vim.keymap.set("n", "<leader>ah", function()
--   local cmd = [[tmux send-keys -t "$(tmux display-message -p '\#S'):git" 'opencode run "/history"' C-m]]
--   vim.fn.system(cmd)
-- end, { desc = "Agent Update the History with Opencode" })
