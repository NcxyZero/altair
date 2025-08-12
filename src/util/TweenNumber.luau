local TweenService = game:GetService("TweenService")

local tweenNumber = {}
tweenNumber.__index = tweenNumber

function tweenNumber.new(animationTime: number, startingValue: number)
	local newTweenNumber = {}
	setmetatable(newTweenNumber, tweenNumber)

	newTweenNumber.desiredValue = if startingValue then startingValue else 0
	newTweenNumber.tweenTime = animationTime
	newTweenNumber.Number = Instance.new("NumberValue")
	newTweenNumber.Number.Value = if startingValue then startingValue else 0
	newTweenNumber.Stopped = false
	newTweenNumber.StartingValue = startingValue

	return newTweenNumber
end

function tweenNumber:ChangeTweenTime(animationTime: number)
	self.tweenTime = animationTime
end

function tweenNumber:Add(value: number, onTweenEnd: () -> ())
	self.Stopped = false
	self.desiredValue += value

	local tween = TweenService:Create(self.Number, TweenInfo.new(self.tweenTime), { Value = self.desiredValue })
	tween:Play()
	tween.Completed:Connect(function()
		if self.Stopped then
			return
		end

		onTweenEnd()
	end)
end

function tweenNumber:Set(newValue: number, onTweenEnd: () -> ())
	self.Stopped = false
	self.desiredValue = newValue

	local tween = TweenService:Create(self.Number, TweenInfo.new(self.tweenTime), { Value = self.desiredValue })
	tween:Play()
	tween.Completed:Connect(function()
		if self.Stopped then
			return
		end

		onTweenEnd()
	end)
end

function tweenNumber:Reset(animatable: boolean)
	self.Stopped = false
	self.desiredValue = 0

	if animatable then
		TweenService:Create(self.Number, TweenInfo.new(self.tweenTime), { Value = self.desiredValue }):Play()
	else
		self.Number.Value = 0
	end
end

function tweenNumber:ResetToStarting(animatable: boolean)
	self.Stopped = false
	self.desiredValue = self.StartingValue

	if animatable then
		TweenService:Create(self.Number, TweenInfo.new(self.tweenTime), { Value = self.desiredValue }):Play()
	else
		self.Number.Value = self.StartingValue
	end
end

function tweenNumber:Stop(animatable: boolean)
	self.Stopped = true
	TweenService:Create(self.Number, TweenInfo.new(0), { Value = self.Number.Value }):Play()
end

function tweenNumber:OnChange(onChangeFunction: (newValue: number) -> ())
	self.Number.Changed:Connect(function()
		onChangeFunction(self.Number.Value)
	end)
end

function tweenNumber:Destroy()
	self.Number:Destroy()
	setmetatable(self, nil)
	self = nil
end

return tweenNumber
