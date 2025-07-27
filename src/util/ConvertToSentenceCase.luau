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
		local first: string = word:sub(1, 1)
		local rest: string = word:sub(2)

		first = chars[first] or first:upper()

		return first .. rest:lower()
	end

	return capitalize(input):gsub(" ", replaceWhitespaceWith or " ")
end
