local M = {} -- M stands for module, a naming convention

function M.setup(opts)
	opts = opts or {}
	if type(opts.includes) ~= "table" or #opts.includes == 0 then
		vim.api.nvim_err_writeln("ftp-redux: Please specify included file extensions in plugin config.")
		return
	end

	M.includeString = ""
	for k, v in pairs(opts.includes) do
		M.includeString = M.includeString .. " -I **." .. v
	end

	if type(opts.concurrent_transfers) ~= "number" or opts.concurrent_transfers <= 0 then
		M.concurrent_transfers = 4
	else
		M.concurrent_transfers = math.floor(opts.concurrent_transfers)
	end

	vim.api.nvim_create_autocmd("BufWritePost", {
		callback = M.uploadCallback,
	})

	vim.api.nvim_create_user_command("PullFtp", function()
		local projectRoot = M.getProjectRoot(vim.fn.getcwd())
		if projectRoot then
			local settings = M.getProjectSettings(projectRoot .. "/.conn")
			if settings then
				vim.cmd(
					"!lftp -e 'mirror --no-empty-dirs -n "
						.. M.includeString
						.. " --parallel="
						.. M.concurrent_transfers
						.. " "
						.. settings[5]
						.. " "
						.. projectRoot
						.. "; exit;' '"
						.. settings[1]
						.. "://"
						.. settings[3]
						.. ":"
						.. settings[4]
						.. "@"
						.. settings[2]
						.. "'"
				)
			end
		end
	end, {})
end

function M.uploadCallback(ev)
	local projectRoot = M.getProjectRoot(ev.match)
	if projectRoot then
		if projectRoot .. "/.conn" == ev.match then
			return
		end
		local settings = M.getProjectSettings(projectRoot .. "/.conn")
		if settings then
			local relativePath = M.getRelativePath(projectRoot, ev.match)
			vim.cmd(
				"silent !lftp -e 'put "
					.. ev.match
					.. " -o ./"
					.. settings[5]
					.. relativePath
					.. "; exit;' '"
					.. settings[1]
					.. "://"
					.. settings[3]
					.. ":"
					.. settings[4]
					.. "@"
					.. settings[2]
					.. "'"
			)
		end
	end
end

function M.getProjectSettings(path)
	local fileLines = {}
	for line in io.lines(path) do
		fileLines[#fileLines + 1] = line
	end

	if #fileLines == 5 then
		return fileLines
	end

	vim.api.nvim_err_writeln(
		"ftp-redux: .conn file should contain exactly five lines:\nprotocol, host, user, pass, root dir"
	)
	return false
end

function M.getProjectRoot(path)
	if vim.fn.filereadable(path .. "/.conn") ~= 0 then
		return path
	end --check if dir has .conn file
	while true do
		local index = path:match("^.*()/") --try to match last forward slash
		if index == nil then
			break
		end

		path = path:sub(0, index - 1)
		if vim.fn.filereadable(path .. "/.conn") ~= 0 then
			return path
		end --check if dir has .conn file
	end

	return false
end

function M.getRelativePath(root, path)
	return path:gsub(root, "")
end

return M
