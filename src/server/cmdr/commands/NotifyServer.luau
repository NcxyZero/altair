local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Bridgenet2 = require(ReplicatedStorage.package.Bridgenet2)
local ConvertHexToInt = require(ReplicatedStorage.util.ConvertHexToInt)
local GetBridge = require(ReplicatedStorage.util.GetBridge)

local bridge = GetBridge("Notification")

local COLOR_NAMES: { [string]: Color3 } = {
	red = Color3.new(1, 0, 0),
	green = Color3.new(0, 1, 0),
	blue = Color3.new(0, 0, 1),
	white = Color3.new(1, 1, 1),
	black = Color3.new(),
	yellow = Color3.new(1, 1, 0),
	cyan = Color3.new(0, 1, 1),
	magenta = Color3.new(1, 0, 1),
	orange = Color3.new(1, 0.5, 0),
	purple = Color3.new(0.5, 0, 0.5),
	pink = Color3.new(1, 0.4, 0.7),
}

local function parseHexPair(hex: string, startIndex: number): number
	local a: string = hex:sub(startIndex, startIndex)
	local b: string = hex:sub(startIndex + 1, startIndex + 1)

	local hi: number = ConvertHexToInt(a)
	local lo: number = ConvertHexToInt(b)

	return hi * 16 + lo
end

local function parseColor3(colorString: string?): Color3?
	if not colorString then
		return
	end

	local key: string = colorString:lower()

	if COLOR_NAMES[key] then
		return COLOR_NAMES[key]
	end

	if key:sub(1, 1) == "#" and #key == 7 then
		local r255: number = parseHexPair(key, 2)
		local g255: number = parseHexPair(key, 4)
		local b255: number = parseHexPair(key, 6)

		return Color3.new(r255 / 255, g255 / 255, b255 / 255)
	end

	return
end

return function(_context, players: { Player }, message: string, seconds: number?, color: string?): string
	local color3: Color3? = parseColor3(color)

	bridge:Fire(Bridgenet2.Players(players), { text = message, seconds = seconds or 5, color = color3 })

	return `Notification sent for {seconds or 5} seconds.`
end
