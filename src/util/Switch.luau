return function(default: any)
	local callbacks = {}
	local switch = {}
	local metatable = {}

	metatable.__call = function(_, key: any): ()
		local callback = callbacks[key]
		if callback then
			callback()
		elseif typeof(default) == "function" then
			default()
		end
	end

	metatable.__newindex = function(_, key: any, value: () -> ()): ()
		callbacks[key] = value
	end

	setmetatable(switch, metatable)

	return switch
end
