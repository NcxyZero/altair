return function(input: string, lowerRest: boolean?, replaceWhitespaceWith: string?): string
	local upperChars: { [string]: string } = {
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

	local lowerChars: { [string]: string } = {
		["Ą"] = "ą",
		["Ć"] = "ć",
		["Ę"] = "ę",
		["Ł"] = "ł",
		["Ń"] = "ń",
		["Ó"] = "ó",
		["Ś"] = "ś",
		["Ź"] = "ź",
		["Ż"] = "ż",
	}

	local firstTime: boolean = true
	local function capitalize(word: string): string
		local firstCode: number = utf8.codepoint(word, 1)
		if not firstCode then
			return word
		end

		local first: string = utf8.char(firstCode)
		local rest: string = word:sub(utf8.offset(word, 2) or #word + 1)

		first = firstTime and (lowerChars[first] or first:lower()) or (upperChars[first] or first:upper())
		firstTime = false

		return first .. (lowerRest and rest:lower() or rest)
	end

	return input:gsub("(%S+)", capitalize):gsub(" ", replaceWhitespaceWith or " ")
end
