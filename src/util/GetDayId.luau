return function(): string
	local date = os.date("!*t")
	return `{date.yday}:{date.year}`
end
