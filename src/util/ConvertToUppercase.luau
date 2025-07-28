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

	local function capitalize(letter: string): string
		local char: string = utf8.char(utf8.codepoint(letter))

		return chars[char] or char:upper()
	end

	return input:gsub("[%z\1-\127\194-\244][\128-\191]*", capitalize):gsub(" ", replaceWhitespaceWith or " ")
end
