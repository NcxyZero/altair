return function(str: string): string
	return str
		:gsub("&", "&amp;") -- MUST come first!
		:gsub("<", "&lt;")
		:gsub(">", "&gt;")
		:gsub('"', "&quot;")
		:gsub("'", "&apos;")
end
