local M = {}

function M.window_center(input_width)
	return {
		relative = "win",
		row = vim.api.nvim_win_get_height(0) / 2 - 1,
		col = vim.api.nvim_win_get_width(0) / 2 - input_width / 2,
	}
end

function M.under_cursor(_)
	return {
		relative = "cursor",
		row = 1,
		col = 0,
	}
end

function M.input(opts, on_confirm)
	local prompt = opts.prompt and string.format(" %s", opts.prompt) or " Input: "
	local default = opts.default or ""
	on_confirm = on_confirm or function() end

	local min_width = M.config.min_width
	local dynamic_width = M.config.dynamic_width

	-- Initial input width calculation
	local function calculate_width()
		local default_width = vim.str_utfindex(default) + 10
		local prompt_width = vim.str_utfindex(prompt) + 10
		local input_width = math.max(min_width, default_width, prompt_width)
		return input_width
	end

	local input_width = calculate_width()

	local default_win_config = {
		focusable = true,
		style = "minimal",
		border = M.config.border,
		width = input_width,
		height = 1,
		title = prompt,
	}

	-- Apply user's window config.
	local win_config = vim.tbl_deep_extend("force", default_win_config, M.window_center(M.config.min_width))

	-- Position the window if rename
	if prompt == " New Name: " then
		win_config = vim.tbl_deep_extend("force", win_config, M.under_cursor(win_config.width))
	end

	-- Create floating window
	local buffer = vim.api.nvim_create_buf(false, true)
	local window = vim.api.nvim_open_win(buffer, true, win_config)
	vim.api.nvim_buf_set_text(buffer, 0, 0, 0, 0, { default })

	-- Put cursor at the end of the default value
	vim.cmd("startinsert")
	vim.api.nvim_win_set_cursor(window, { 1, vim.str_utfindex(default) + 1 })

	-- Adjust width dynamically as user types
	if dynamic_width then
		vim.api.nvim_create_autocmd("TextChangedI", {
			buffer = buffer,
			callback = function()
				if vim.api.nvim_win_is_valid(window) then
					local lines = vim.api.nvim_buf_get_lines(buffer, 0, 1, false)
					local new_width = math.max(min_width, vim.str_utfindex(lines[1] or "") + 5)
					vim.api.nvim_win_set_config(window, { width = new_width })
				end
			end,
		})
	end

	-- Enter to confirm
	vim.keymap.set({ "n", "i", "v" }, "<cr>", function()
		if vim.api.nvim_win_is_valid(window) then
			local lines = vim.api.nvim_buf_get_lines(buffer, 0, 1, false)
			vim.cmd("stopinsert")
			on_confirm(lines[1])
			vim.api.nvim_win_close(window, true)
		end
	end, { buffer = buffer })

	-- Esc or q to close
	local function close_window()
		if vim.api.nvim_win_is_valid(window) then
			on_confirm(nil)
			vim.cmd("stopinsert")
			vim.api.nvim_win_close(window, true)
		end
	end

	vim.keymap.set("n", "<esc>", close_window, { buffer = buffer })
	vim.keymap.set("n", "q", close_window, { buffer = buffer })
end

M.setup = function(user_config)
	local configs = {
		border = "rounded",
		min_width = 30,
		dynamic_width = true,
	}

	M.config = vim.tbl_deep_extend("force", configs, user_config)

	vim.ui.input = M.input
end

return M
