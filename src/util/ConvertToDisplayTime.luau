local ReplicatedStorage = game:GetService("ReplicatedStorage")

local IsValidUTF8 = require(ReplicatedStorage.util.IsValidUTF8)

function format(int: number): string
	return ("%02i"):format(int)
end

return function(seconds: number, displayType: string, customSeparator: string?): string
	if not seconds or not displayType or not IsValidUTF8(displayType) then
		error("Seconds and valid type must be provided for displayTime function")
	end

	local types: { [string]: boolean } = { s = false, m = false, h = false, d = false }

	for _index: number, codepoint: number in utf8.codes(displayType) do
		types[utf8.char(codepoint)] = true
	end

	local toDisplay: { string } = { format(seconds) }
	local minutes: number, hours: number, days: number

	if types["m"] then
		minutes = (seconds - seconds % 60) / 60
		seconds = seconds - minutes * 60

		table.insert(toDisplay, 1, format(minutes))
	end

	if types["h"] then
		hours = (minutes - minutes % 60) / 60
		minutes = minutes - hours * 60

		table.insert(toDisplay, 1, format(hours))
	end

	if types["d"] then
		days = hours / 24
		hours = hours % 24

		table.insert(toDisplay, 1, format(days))
	end

	return table.concat(toDisplay, customSeparator or ":")
end
