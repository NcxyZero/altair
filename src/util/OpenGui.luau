local current

return function(show: any, hide: any)
	if current and typeof(current) == "function" then
		current()
	end

	current = hide

	if typeof(show) == "function" then
		show()
	end
end
