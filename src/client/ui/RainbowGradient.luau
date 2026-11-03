local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Maid = require(ReplicatedStorage.package.Maid)

export type RainbowGradient = {
	Destroy: (self: RainbowGradient) -> (),
	Render: (self: RainbowGradient, deltaTime: number) -> (),
	baseColor: ColorSequence,
	baseKeypoints: { ColorSequenceKeypoint },
	instance: UIGradient,
	maid: Maid.Maid,
	progress: number,
	sampleCount: number,
	speed: number,
	tag: string,
	type: string,
	__index: RainbowGradient,
	new: (instance: UIGradient) -> RainbowGradient,
}

local RainbowGradient: RainbowGradient = {} :: any
RainbowGradient.__index = RainbowGradient
RainbowGradient.tag = script.Name
RainbowGradient.type = "local_tag"

local DEFAULT_SPEED: number = 0.35 -- gradient lengths scrolled per second without a Speed attribute
local MAXIMUM_KEYPOINT_COUNT: number = 20 -- upper bound of resampled keypoints per frame
local MINIMUM_KEYPOINT_COUNT: number = 12 -- lower bound of resampled keypoints per frame

-- rainbow used when the authored gradient has a single colour
local DEFAULT_COLOR: ColorSequence = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 55, 55)),
	ColorSequenceKeypoint.new(0.17, Color3.fromRGB(255, 185, 55)),
	ColorSequenceKeypoint.new(0.33, Color3.fromRGB(255, 255, 55)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(55, 255, 95)),
	ColorSequenceKeypoint.new(0.67, Color3.fromRGB(55, 185, 255)),
	ColorSequenceKeypoint.new(0.83, Color3.fromRGB(170, 85, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 55, 185)),
})

local function isSingleColor(color: ColorSequence): boolean
	local keypoints: { ColorSequenceKeypoint } = color.Keypoints
	local firstColor: Color3 = keypoints[1].Value

	for index: number = 2, #keypoints do
		if keypoints[index].Value ~= firstColor then
			return false
		end
	end

	return true
end

local function getColorAtPosition(keypoints: { ColorSequenceKeypoint }, position: number): Color3
	local firstKeypoint: ColorSequenceKeypoint = keypoints[1]
	if position <= firstKeypoint.Time then
		return firstKeypoint.Value
	end

	for index: number = 2, #keypoints do
		local rightKeypoint: ColorSequenceKeypoint = keypoints[index]
		if position > rightKeypoint.Time then
			continue
		end

		local leftKeypoint: ColorSequenceKeypoint = keypoints[index - 1]
		local duration: number = rightKeypoint.Time - leftKeypoint.Time
		local alpha: number = duration > 0 and (position - leftKeypoint.Time) / duration or 0

		return leftKeypoint.Value:Lerp(rightKeypoint.Value, alpha)
	end

	return keypoints[#keypoints].Value
end

function RainbowGradient.new(instance: UIGradient): RainbowGradient
	local animatedColor: ColorSequence = isSingleColor(instance.Color) and DEFAULT_COLOR or instance.Color
	local self: RainbowGradient = setmetatable({}, RainbowGradient) :: any
	self.baseColor = instance.Color
	self.baseKeypoints = animatedColor.Keypoints
	self.instance = instance
	self.maid = Maid.new()
	self.progress = 0
	self.sampleCount = math.clamp(#self.baseKeypoints * 3, MINIMUM_KEYPOINT_COUNT, MAXIMUM_KEYPOINT_COUNT)

	local speedAttribute: unknown = instance:GetAttribute("Speed")
	self.speed = typeof(speedAttribute) == "number" and math.max(speedAttribute, 0) / 100 or DEFAULT_SPEED

	return self
end

function RainbowGradient:Render(deltaTime: number): ()
	self.progress = (self.progress + (math.max(deltaTime, 0) * self.speed)) % 1

	local colors: { ColorSequenceKeypoint } = {}
	for index: number = 1, self.sampleCount do
		local position: number = (index - 1) / (self.sampleCount - 1)
		local sourcePosition: number = (position + self.progress) % 1
		colors[index] = ColorSequenceKeypoint.new(position, getColorAtPosition(self.baseKeypoints, sourcePosition))
	end

	self.instance.Color = ColorSequence.new(colors)
end

function RainbowGradient:Destroy(): ()
	self.instance.Color = self.baseColor

	self.maid:DoCleaning()
end

return RainbowGradient
