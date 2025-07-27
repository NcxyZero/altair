return function(input: string, replaceWhitespaceWith: string?): string
	local chars: { [string]: string } = {
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

	return input
		:gsub("[%z\1-\127\194-\244][\128-\191]*", function(c: string): string
			return chars[c] or c
		end)
		:lower()
		:gsub(" ", replaceWhitespaceWith or " ")
end
