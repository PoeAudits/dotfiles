return {

	{
		"supermaven-inc/supermaven-nvim",
		config = function()
			require("supermaven-nvim").setup({})
			local function toggle_supermaven()
				local api = require("supermaven-nvim.api")
				if api.is_running() then
					api.stop()
					print("Supermaven disabled")
				else
					api.start()
					print("Supermaven enabled")
				end
			end
			vim.keymap.set("n", "<leader>sm", toggle_supermaven, {
				desc = "Toggle Supermaven",
				silent = true,
			})
		end,
	},
}
