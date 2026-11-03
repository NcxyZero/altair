local formatValue = {}

local DECIMAL_SEPARATOR: string = "." -- decimal mark used by SuffixFormat, for example "1.5K"

local suffixes: { string } = {
	"",
	"K",
	"M",
	"B",
	"T",
	"Qd",
	"Qn",
	"Sx",
	"Sp",
	"O",
	"N",
	"De",
	"Ud",
	"DD",
	"Tre",
	"Qua",
	"Qui",
	"SE",
	"ST",
	"OC",
	"NV",
	"VIG",
	"CE",
	"CT",
}

function formatValue.SuffixFormat(int: number, preserveSmallDecimal: boolean?): string
	local value: number = tonumber(int) or 0
	if value ~= value or math.abs(value) == math.huge then
		return "0"
	end

	-- rounded before the branch is chosen, so 999.95 reaches the suffix path as 1000 and becomes "1K"
	if preserveSmallDecimal and math.abs(value) < 1_000 then
		value = math.round(value * 10) / 10
	end

	-- small negative values round to negative zero, which would print as "-0"
	if value == 0 then
		return "0"
	end

	local absoluteValue: number = math.abs(value)
	if absoluteValue < 1_000 then
		if preserveSmallDecimal then
			return (tostring(value):gsub("%.0$", ""):gsub("%.", DECIMAL_SEPARATOR))
		end

		return tostring(value // 1)
	end

	local suffixIndex: number = math.min((math.log10(absoluteValue) // 3) + 1, #suffixes)
	local divisor: number = 1_000 ^ (suffixIndex - 1)
	local shortenedValue: number = ((value / divisor) * 10 + 0.5) // 1 / 10
	local formattedValue: string = tostring(shortenedValue):gsub("%.0$", ""):gsub("%.", DECIMAL_SEPARATOR)

	if math.abs(shortenedValue) >= 1_000 and suffixIndex < #suffixes then
		suffixIndex += 1
		formattedValue =
			tostring(((value / (divisor * 1_000)) * 10 + 0.5) // 1 / 10):gsub("%.0$", ""):gsub("%.", DECIMAL_SEPARATOR)
	end

	return formattedValue .. suffixes[suffixIndex]
end

function formatValue.StringToNumber(str: string): number
	if str == "" then
		return 0
	end

	local StringTable: { string } = {}
	for i = 1, #str do
		table.insert(StringTable, str:sub(i, i))
	end

	local EndNumber: number = 0
	local Iterator: number = 0
	for i = #StringTable, 1, -1 do
		local AsciiNumber: number = StringTable[i]:byte()
		EndNumber += (AsciiNumber - 33) * 94 ^ Iterator
		Iterator += 1
	end

	return EndNumber
end

function formatValue.NumberToString(int: number): string
	if int == 0 then
		return "!"
	end

	local PowerList: { number } = { 1 }
	local Iterator: number = 1
	while PowerList[1] <= int do
		table.insert(PowerList, 1, 94 ^ Iterator)
		Iterator += 1
	end
	table.remove(PowerList, 1)

	Iterator = 1

	local MyString: string = ""
	for _index: number, value: number in PowerList do
		MyString ..= string.char((int // value) + 33)
		int -= (int // value) * value
	end

	return MyString
end

return formatValue
