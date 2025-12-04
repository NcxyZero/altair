local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local PlayerGui = require(ReplicatedStorage.util.PlayerGui)

export type ClickRipple = {
	enabled: boolean,
	container: ScreenGui?,
	Enable: (self: ClickRipple) -> (),
	Disable: (self: ClickRipple) -> (),
	IsEnabled: (self: ClickRipple) -> boolean,
	FireAtPosition: (self: ClickRipple, position: Vector2) -> (),
}

local ClickRipple: ClickRipple = {} :: any

ClickRipple.enabled = false
ClickRipple.container = nil

local function ensureContainer(): ScreenGui
	local existing: Instance? = PlayerGui:GetChild("ClickRipple")
	if existing and existing:IsA("ScreenGui") then
		return existing
	end

	local gui: ScreenGui = Instance.new("ScreenGui") :: any
	gui.Name = "ClickRipple"
	gui.DisplayOrder = 999
	gui.IgnoreGuiInset = false
	gui.ResetOnSpawn = false
	gui.Parent = PlayerGui:Wait()

	return gui
end

function ClickRipple:IsEnabled(): boolean
	return self.enabled
end

function ClickRipple:Enable(): ()
	self.enabled = true
	if not self.container then
		self.container = ensureContainer()
	end
end

function ClickRipple:Disable(): ()
	self.enabled = false
end

function ClickRipple:FireAtPosition(position: Vector2): ()
	if not self.enabled then
		return
	end

	local container: ScreenGui = self.container or ensureContainer()
	self.container = container

	local frame: Frame = Instance.new("Frame") :: any
	frame.Name = "Ripple"
	frame.AnchorPoint = Vector2.one * 0.5
	frame.BackgroundColor3 = Color3.new(1, 1, 1)
	frame.BackgroundTransparency = 0.4
	frame.BorderSizePixel = 0
	frame.Position = UDim2.fromOffset(position.X, position.Y)
	frame.Size = UDim2.fromOffset(8, 8)
	frame.ZIndex = 999
	frame.Parent = container

	local corner: UICorner = Instance.new("UICorner") :: any
	corner.Name = "Corner"
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = frame

	local stroke: UIStroke = Instance.new("UIStroke") :: any
	stroke.Name = "Stroke"
	stroke.Color = Color3.new(1, 1, 1)
	stroke.Thickness = 1
	stroke.Transparency = 0.25
	stroke.Parent = frame

	local duration: number = 0.25
	local targetSize: number =
		math.clamp(math.max(container.AbsoluteSize.X, container.AbsoluteSize.Y) * 0.2, 120 / 2, 220 / 2)
	local tweenInfo: TweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

	local sizeTween: Tween = TweenService:Create(frame, tweenInfo, {
		Size = UDim2.fromOffset(targetSize, targetSize),
		BackgroundTransparency = 1,
	})

	local strokeTween: Tween = TweenService:Create(stroke, tweenInfo, {
		Transparency = 1,
	})

	sizeTween:Play()
	strokeTween:Play()

	sizeTween.Completed:Connect(function(): ()
		frame:Destroy()
	end)
end

return ClickRipple
