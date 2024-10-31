vim.g.netrw_liststyle = 3

local map = vim.keymap.set

-- Move selection
map("v", "J", ":m '>+1<CR>gv=gv")
map("v", "K", ":m '<-2<CR>gv=gv")

-- Scroll centered
map("n", "<C-d>", "<C-d>zz")
map("n", "<C-u>", "<C-u>zz")

-- START Copying/Pasting/Deleting without loosing the current buffer
-- Copying
map({ "n", "v" }, "<leader>y", [["+y]])
map("n", "<leader>Y", [["+Y]])

-- Pasting
map("x", "<leader>p", [["_dP]])

-- Deleting
map({ "n", "v" }, "<leader>d", [["_d]])
-- END Copying/Pasting/Deleting

map("n", "<leader>s", [[:%s/\<<C-r><C-w>\>/<C-r><C-w>/gI<Left><Left><Left>]])
map("v", "<leader>sr", [[:%s/\<<C-R><C-W>\>/g<Left><Left>]])

-- Make the current file executable
map("n", "<leader>x", "<cmd>!chmod +x %<CR>", { silent = true })

-- Clear highlight on search when pressing <Esc> in normal mode
map("n", "<Esc>", "<cmd>nohlsearch<CR>")

-- Diagnostic keymaps
map("n", "<leader>e", vim.diagnostic.open_float, { desc = "Show diagnostic [E]rror messages" })
map("n", "<leader>q", vim.diagnostic.setloclist, { desc = "Open diagnostic [Q]uickfix list" })
