local TweenService = game:GetService("TweenService")

export type TweenNumber = {
	new: (animationTime: number, startingValue: number) -> TweenNumber,
	ChangeTweenTime: (self: TweenNumber, animationTime: number) -> (),
	Add: (self: TweenNumber, value: number, onTweenEnd: () -> ()) -> (),
	Set: (self: TweenNumber, newValue: number, onTweenEnd: () -> ()) -> (),
	Reset: (self: TweenNumber, animatable: boolean) -> (),
	ResetToStarting: (self: TweenNumber, animatable: boolean) -> (),
	Stop: (self: TweenNumber, animatable: boolean) -> (),
	OnChange: (self: TweenNumber, onChangeFunction: (newValue: number) -> ()) -> (),
	Destroy: (self: TweenNumber) -> (),
	Number: NumberValue,
	desiredValue: number,
	tweenTime: number,
	Stopped: boolean,
	StartingValue: number,
	__index: TweenNumber,
}

local tweenNumber: TweenNumber = {} :: any
tweenNumber.__index = tweenNumber

function tweenNumber.new(animationTime: number, startingValue: number): TweenNumber
	local newTweenNumber = {}

	setmetatable(newTweenNumber, tweenNumber)

	newTweenNumber.desiredValue = startingValue and startingValue or 0
	newTweenNumber.tweenTime = animationTime
	newTweenNumber.Number = Instance.new("NumberValue")
	newTweenNumber.Number.Value = startingValue and startingValue or 0
	newTweenNumber.Stopped = false
	newTweenNumber.StartingValue = startingValue

	return newTweenNumber :: any
end

function tweenNumber:ChangeTweenTime(animationTime: number): ()
	self.tweenTime = animationTime
end

function tweenNumber:Add(value: number, onTweenEnd: () -> ()): ()
	self.Stopped = false
	self.desiredValue += value

	local tween = TweenService:Create(self.Number, TweenInfo.new(self.tweenTime), { Value = self.desiredValue })
	tween:Play()
	tween.Completed:Connect(function(): ()
		if self.Stopped then
			return
		end

		onTweenEnd()
	end)
end

function tweenNumber:Set(newValue: number, onTweenEnd: () -> ()): ()
	self.Stopped = false
	self.desiredValue = newValue

	local tween = TweenService:Create(self.Number, TweenInfo.new(self.tweenTime), { Value = self.desiredValue })
	tween:Play()
	tween.Completed:Connect(function(): ()
		if self.Stopped then
			return
		end

		onTweenEnd()
	end)
end

function tweenNumber:Reset(animatable: boolean): ()
	self.Stopped = false
	self.desiredValue = 0

	if animatable then
		TweenService:Create(self.Number, TweenInfo.new(self.tweenTime), { Value = self.desiredValue }):Play()
	else
		self.Number.Value = 0
	end
end

function tweenNumber:ResetToStarting(animatable: boolean): ()
	self.Stopped = false
	self.desiredValue = self.StartingValue

	if animatable then
		TweenService:Create(self.Number, TweenInfo.new(self.tweenTime), { Value = self.desiredValue }):Play()
	else
		self.Number.Value = self.StartingValue
	end
end

function tweenNumber:Stop(_animatable: boolean): ()
	self.Stopped = true

	TweenService:Create(self.Number, TweenInfo.new(0), { Value = self.Number.Value }):Play()
end

function tweenNumber:OnChange(onChangeFunction: (newValue: number) -> ()): ()
	self.Number.Changed:Connect(function(): ()
		onChangeFunction(self.Number.Value)
	end)
end

function tweenNumber:Destroy(): ()
	self.Number:Destroy()

	setmetatable(self, nil)

	self = nil
end

return tweenNumber
