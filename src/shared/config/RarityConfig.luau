local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ConvertToSentenceCase = require(ReplicatedStorage.util.ConvertToSentenceCase)

export type RarityConfig = {
	colors: { [string]: Color3 },
	getColor: (rarity: string) -> Color3,
}

local COLORS: { [string]: Color3 } = {
	Common = Color3.fromRGB(220, 220, 220),
	Uncommon = Color3.fromRGB(110, 220, 110),
	Rare = Color3.fromRGB(90, 150, 255),
	Epic = Color3.fromRGB(190, 90, 255),
	Legendary = Color3.fromRGB(255, 200, 80),
}

local RarityConfig: RarityConfig = {
	colors = COLORS,
	getColor = function(rarity: string): Color3
		if type(rarity) ~= "string" then
			return Color3.new(1, 1, 1)
		end

		return COLORS[ConvertToSentenceCase(rarity)] or Color3.new(1, 1, 1)
	end,
}

return table.freeze(RarityConfig)
