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

	local function capitalize(letter: string): string
		local char: string = utf8.char(utf8.codepoint(letter))

		return chars[char] or char:lower()
	end

	return input:gsub("[%z\1-\127\194-\244][\128-\191]*", capitalize):gsub(" ", replaceWhitespaceWith or " ")
end
