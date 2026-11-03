local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.shared.config.GameConfig)
local RainbowGradient = require(ReplicatedStorage.client.ui.RainbowGradient)

export type MagmaGradient = RainbowGradient.RainbowGradient & { baseRotation: number }

local MagmaGradient: MagmaGradient = {} :: any
MagmaGradient.__index = MagmaGradient
MagmaGradient.tag = script.Name
MagmaGradient.type = "local_tag"
MagmaGradient.Render = RainbowGradient.Render

function MagmaGradient.new(instance: UIGradient): MagmaGradient
	local originalColor: ColorSequence = instance.Color
	local originalRotation: number = instance.Rotation

	instance.Color = GameConfig.ui.magmaGradient.color
	instance.Rotation = 90

	local self: MagmaGradient = setmetatable(RainbowGradient.new(instance), MagmaGradient) :: any
	self.baseColor = originalColor
	self.baseRotation = originalRotation

	if typeof(instance:GetAttribute("Speed")) ~= "number" then
		self.speed = GameConfig.ui.magmaGradient.speed
	end

	return self
end

function MagmaGradient:Destroy(): ()
	self.instance.Rotation = self.baseRotation

	RainbowGradient.Destroy(self)
end

return MagmaGradient
