return function(input: string, replaceWhitespaceWith: string?): string
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

	local function capitalize(word: string): string
		local first: string = word:sub(1, 1)
		local rest: string = word:sub(2)

		first = upperChars[first] or first:upper()

		return first .. rest:lower()
	end

	local words: { string } = {}
	for word: string in input:gmatch("%S+") do
		table.insert(words, word)
	end

	for i: number, word: string in ipairs(words) do
		if i == 1 then
			words[i] = word:lower():gsub("[%z\1-\127\194-\244][\128-\191]*", function(c: string): string
				return lowerChars[c] or c
			end)
		else
			words[i] = capitalize(word)
		end
	end

	return input:gsub("(%S+)", capitalize):gsub(" ", replaceWhitespaceWith or " ")
end
