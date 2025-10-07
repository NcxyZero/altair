--!nocheck
local RunService = game:GetService("RunService")
local Logger = {}

local function getSourceInfo(): string
	if not debug or not debug.info then
		return "[Debug unavailable] "
	end

	for level = 2, 8 do
		local success, info = pcall(debug.info, level, "sl")

		if success and info then
			local source: string?
			local line: number = 0

			if type(info) == "table" then
				source = info.source
				line = info.line or 0
			elseif type(info) == "string" then
				source = info
			end

			if source and type(source) == "string" and source ~= "" then
				local filename: string = source:match("[^/\\]*$") or source

				filename = filename:gsub("^.*%.", "")
				if filename == "" then
					filename = source
				end

				if filename and filename ~= "" and not filename:match("Logger") then
					local condition: boolean = line > 0
					(condition and "[%s:%d] " or "[%s] "):format(filename, condition and line or nil)
				end
			end
		end
	end

	local success, info = pcall(debug.info, 3, "s")
	if success and info and type(info) == "string" and info ~= "" then
		local filename: string = info:match("[^/\\]*$") or info
		if filename ~= "" and not filename:match("Logger") then
			return ("[%s] "):format(filename)
		end
	end

	return "[Unknown] "
end

Logger.warn = function(...: string): ()
	if not RunService:IsStudio() then
		return
	end

	local sourceInfo: string = getSourceInfo()
	warn(sourceInfo .. table.concat({ ... }, ", "))
end

Logger.print = function(...: string): ()
	if not RunService:IsStudio() then
		return
	end

	local sourceInfo: string = getSourceInfo()
	print(sourceInfo .. table.concat({ ... }, ", "))
end

Logger.error = function(...: string): ()
	if not RunService:IsStudio() then
		return
	end

	local sourceInfo: string = getSourceInfo()
	error(sourceInfo .. table.concat({ ... }, ", "))
end

Logger.assert = function(value: boolean?, ...: string): ()
	if not RunService:IsStudio() then
		return
	end

	if not value then
		local sourceInfo: string = getSourceInfo()
		assert(value, sourceInfo .. table.concat({ ... }, ", "))
	else
		assert(value, table.concat({ ... }, ", "))
	end
end

return Logger
