local DEFAULT_MESSAGE: string = "The test message."

return function(_context, message: string?): string
	return message or DEFAULT_MESSAGE
end
