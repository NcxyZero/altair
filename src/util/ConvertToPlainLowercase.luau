return function(input: string): string
	local chars: { [string]: string } = {
		["ą"] = "a",
		["ć"] = "c",
		["ę"] = "e",
		["ł"] = "l",
		["ń"] = "n",
		["ó"] = "o",
		["ś"] = "s",
		["ź"] = "z",
		["ż"] = "z",
		["Ą"] = "a",
		["Ć"] = "c",
		["Ę"] = "e",
		["Ł"] = "l",
		["Ń"] = "n",
		["Ó"] = "o",
		["Ś"] = "s",
		["Ź"] = "z",
		["Ż"] = "z",
	}

	return input
		:gsub("[%z\1-\127\194-\244][\128-\191]*", function(c: string): string
			return chars[c] or c
		end)
		:lower()
		:gsub(" ", "_")
end
