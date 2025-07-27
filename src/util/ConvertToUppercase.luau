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

	return input
		:gsub("[%z\1-\127\194-\244][\128-\191]*", function(c: string): string
			return chars[c] or c
		end)
		:upper()
		:gsub(" ", replaceWhitespaceWith or " ")
end
