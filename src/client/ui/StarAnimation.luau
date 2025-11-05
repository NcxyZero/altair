local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local InitializerTypes = require(ReplicatedStorage.shared.types.InitializerTypes)
local Promise = require(ReplicatedStorage.package.Promise)

export type Default = {
	type: string,
	tag: string,
	path: InitializerTypes.ClientPath,
	instance: GuiObject,
	starTemplate: ImageLabel & { UIScale: UIScale },
	loopPromise: Promise.TypedPromise<>,
	__index: Default,
	new: (instance: TextLabel, path: InitializerTypes.ClientPath) -> Default,
	BuildTemplateStar: (self: Default) -> (),
	Animate: (self: Default) -> (),
	Destroy: (self: Default) -> (),
}

local StarAnimation: Default = {} :: Default
StarAnimation.__index = StarAnimation
StarAnimation.type = "local_tag"
StarAnimation.tag = "StarAnimation"

function StarAnimation.new(instance: TextLabel, path: InitializerTypes.ClientPath): Default
	local self = setmetatable({}, StarAnimation)
	self.instance = instance
	self.path = path

	self:BuildTemplateStar()
	self:Animate()

	return self
end

function StarAnimation:BuildTemplateStar(): ()
	local star: ImageLabel = Instance.new("ImageLabel")
	star.Name = "Star"
	star.AnchorPoint = Vector2.one / 2
	star.BackgroundTransparency = 1
	star.Image = "rbxassetid://103083834528516"
	star.Interactable = false
	star.Position = UDim2.fromScale(0.5, 0.5)
	star.Size = UDim2.fromScale(0.15, 0.15)
	star.ZIndex = 6
	star.Parent = self.instance

	star.Visible = false
	self.starTemplate = star

	local uIAspectRatioConstraint: UIAspectRatioConstraint = Instance.new("UIAspectRatioConstraint")
	uIAspectRatioConstraint.Parent = star

	local uIScale: UIScale = Instance.new("UIScale")
	uIScale.Scale = 0
	uIScale.Parent = star
end

function StarAnimation:Animate(): ()
	self.loopPromise = Promise.retryWithDelay(function(): Promise.TypedPromise<>
		return Promise.new(function(_resolve: () -> (), reject: () -> ()): ()
			local star: ImageLabel & { UIScale: UIScale } = self.starTemplate:Clone()
			star.Visible = true
			star.Parent = self.instance

			local newPosition: UDim2 = UDim2.fromScale(math.random(1, 10) / 10, math.random(1, 10) / 10)
			local newScale: number = math.random(7, 10) / 10

			star.UIScale.Scale = 0
			star.Position = newPosition

			do
				local tween: Tween = TweenService:Create(
					star,
					TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut, 0, true, 0.5),
					{ ImageTransparency = 1 }
				)
				tween:Play()
			end

			do
				local tween: Tween = TweenService:Create(
					star.UIScale,
					TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut, 0, true, 0),
					{ Scale = newScale }
				)
				tween:Play()
				tween.Completed:Once(function(): ()
					star:Destroy()
				end)
			end

			reject()
		end)
	end, math.huge, math.random(8, 15) / 10)
end

function StarAnimation:Destroy(): ()
	if self.loopPromise then
		self.loopPromise:cancel()
	end
end

return StarAnimation
