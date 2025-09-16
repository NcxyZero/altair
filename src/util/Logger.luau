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
					if line > 0 then
						return string.format("[%s:%d] ", filename, line)
					else
						return string.format("[%s] ", filename)
					end
				end
			end
		end
	end

	local success, info = pcall(debug.info, 3, "s")
	if success and info and type(info) == "string" and info ~= "" then
		local filename = info:match("[^/\\]*$") or info
		if filename ~= "" and not filename:match("Logger") then
			return string.format("[%s] ", filename)
		end
	end

	return "[Unknown] "
end

Logger.warn = function(message: string): ()
	if not RunService:IsStudio() then
		return
	end

	local sourceInfo: string = getSourceInfo()
	warn(sourceInfo .. message)
end

Logger.print = function(message: string): ()
	if not RunService:IsStudio() then
		return
	end

	local sourceInfo: string = getSourceInfo()
	print(sourceInfo .. message)
end

Logger.error = function(message: string): ()
	if not RunService:IsStudio() then
		return
	end

	local sourceInfo: string = getSourceInfo()
	error(sourceInfo .. message)
end

Logger.assert = function(value: boolean?, message: string): ()
	if not RunService:IsStudio() then
		return
	end

	if not value then
		local sourceInfo: string = getSourceInfo()
		assert(value, sourceInfo .. message)
	else
		assert(value, message)
	end
end

return Logger
