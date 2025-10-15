local formatValue = {}

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

function formatValue.SuffixFormat(int: number): string
	for i = 1, #suffixes do
		if tonumber(int) < 10 ^ (i * 3) then
			return math.floor(int / ((10 ^ ((i - 1) * 3)) / 100)) / 100 .. suffixes[i]
		end
	end

	return tostring(int)
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
	for _index: number, v: number in PowerList do
		MyString ..= string.char((int // v) + 33)
		int -= (int // v) * v
	end

	return MyString
end

return formatValue
