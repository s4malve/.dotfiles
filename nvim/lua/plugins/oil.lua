return {
	"stevearc/oil.nvim",
	config = function()
		vim.keymap.set("n", "<leader>pv", "<CMD>Oil<CR>", { desc = "Open current directory" })

		local oil = require("oil")

		oil.setup({
			default_file_explorer = true,
			keymaps = {
				["-"] = "actions.parent",
				["<CR>"] = "actions.select",
				["<C-l>"] = "actions.refresh",
			},
			use_default_keymaps = false,
			columns = {
				"icon",
				-- "permissions",
				-- "size",
				-- "mtime",
			},
			view_options = {
				-- Show files and directories that start with "."
				show_hidden = true,
			},
		})
	end,
	-- Optional dependencies
	dependencies = { "nvim-tree/nvim-web-devicons" },
}
