return function(input: string, replaceWhitespaceWith: string?): string
	local chars: { [string]: string } = {
		["ą"] = "Ą",
		["ć"] = "Ć",
		["ę"] = "Ę",
		["ł"] = "Ł",
		["ń"] = "Ń",
		["ó"] = "Ó",
		["ś"] = "Ś",
		["ź"] = "Ź",
		["ż"] = "Ż",
	}

	local function capitalize(word: string): string
		local firstCode: number = utf8.codepoint(word, 1)
		if not firstCode then
			return word
		end

		local first: string = utf8.char(firstCode)
		local rest: string = word:sub(utf8.offset(word, 2) or #word + 1)

		first = chars[first] or first:upper()

		return first .. rest:lower()
	end

	return input:gsub("(%S+)", capitalize):gsub(" ", replaceWhitespaceWith or " ")
end
