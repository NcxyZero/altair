local RunService = game:GetService("RunService")
local Logger = {}

Logger.warn = function(message: string)
	if not RunService:IsStudio() then
		return
	end

	warn(message)
end

Logger.print = function(message: string)
	if not RunService:IsStudio() then
		return
	end

	print(message)
end

Logger.error = function(message: string)
	if not RunService:IsStudio() then
		return
	end

	error(message)
end

Logger.assert = function(value: boolean?, message: string)
	if not RunService:IsStudio() then
		return
	end

	assert(value, message)
end

return Logger
