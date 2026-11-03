local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local GetBridge = require(ReplicatedStorage.util.Core.GetBridge)
local InitializerTypes = require(ReplicatedStorage.shared.types.InitializerTypes)
local Logger = require(ReplicatedStorage.util.Core.Logger)
local Maid = require(ReplicatedStorage.package.Maid)
local OpenGui = require(ReplicatedStorage.util.Core.OpenGui)

export type ShopUI = {
	Destroy: (self: ShopUI) -> (),
	OnClose: (self: ShopUI) -> (),
	OnOpen: (self: ShopUI, openArg: any?) -> (),
	SetupCodes: (self: ShopUI) -> (),
	SetupPreviewCameras: (self: ShopUI) -> (),
	SubmitCode: (self: ShopUI) -> (),
	new: (instance: Frame, path: InitializerTypes.ClientPath) -> ShopUI?,
	__index: ShopUI,
	openRequestId: number,
	tag: string,
	type: string,
	codeTextBox: TextBox?,
	instance: Frame,
	scrollTween: Tween?,
	path: InitializerTypes.ClientPath,
	maid: Maid.Maid,
}

local ShopUI: ShopUI = {} :: any
ShopUI.__index = ShopUI
ShopUI.tag = script.Name
ShopUI.type = "local_tag"

local SECTION_TITLE_PREFIX: string = "Title" -- OnOpen(openArg) scrolls Container to its child named Title{openArg}

-- tween that scrolls Container to the deep-linked section
local SCROLL_TWEEN_INFO: TweenInfo = TweenInfo.new(0.45, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

local REDEEM_CODE_BRIDGE: any = GetBridge("RedeemCode") -- sends entered codes to RedeemCodeController

function ShopUI.new(instance: Frame, path: InitializerTypes.ClientPath): ShopUI?
	if not instance:IsA("Frame") then
		Logger.warn(`ShopUI tag requires a Frame, got {instance.ClassName}`)

		return
	end

	local self: ShopUI = setmetatable({}, ShopUI) :: any
	self.instance = instance
	self.maid = Maid.new()
	self.openRequestId = 0
	self.path = path

	self:SetupPreviewCameras()
	self:SetupCodes()

	OpenGui:Register(self)

	return self
end

function ShopUI:SetupPreviewCameras(): ()
	for _index: number, viewport: Instance in self.instance:GetDescendants() do
		if not viewport:IsA("ViewportFrame") then
			continue
		end

		local cameraCFrame: unknown = viewport:GetAttribute("PreviewCameraCFrame")
		if typeof(cameraCFrame) ~= "CFrame" then
			continue
		end

		local fieldOfView: unknown = viewport:GetAttribute("PreviewCameraFieldOfView")

		local camera: Camera = Instance.new("Camera")
		camera.Name = "ShopPreviewCamera"
		camera.CFrame = cameraCFrame
		camera.FieldOfView = type(fieldOfView) == "number" and math.clamp(fieldOfView, 1, 120) or 45
		camera.Parent = viewport

		viewport.CurrentCamera = camera

		self.maid:GiveTask(camera)
	end
end

function ShopUI:SetupCodes(): ()
	local codesContainer: Instance = self.instance:FindFirstChild("Codes", true) :: Instance
	if not codesContainer or not codesContainer:IsA("GuiObject") then
		return
	end

	local codeTextBox: Instance? = codesContainer:FindFirstChild("EnterCode")
	local redeemButton: Instance? = codesContainer:FindFirstChild("Buy")
	if not codeTextBox or not codeTextBox:IsA("TextBox") or not redeemButton or not redeemButton:IsA("GuiButton") then
		Logger.warn("ShopUI Codes is missing EnterCode or Buy")

		return
	end

	codeTextBox.ClearTextOnFocus = true

	self.codeTextBox = codeTextBox

	self.maid:GiveTask(redeemButton.MouseButton1Down:Connect(function(): ()
		self:SubmitCode()
	end))
	self.maid:GiveTask(codeTextBox.FocusLost:Connect(function(enterPressed: boolean): ()
		if enterPressed then
			self:SubmitCode()
		end
	end))
end

function ShopUI:OnOpen(openArg: any?): ()
	self.openRequestId += 1

	local requestId: number = self.openRequestId

	if self.scrollTween then
		self.scrollTween:Cancel()
		self.scrollTween = nil
	end

	if type(openArg) ~= "string" or openArg == "" then
		return
	end

	task.spawn(function(): ()
		local containerInstance: Instance? = self.instance:FindFirstChild("Container")
		local titleInstance: Instance? = containerInstance
			and containerInstance:FindFirstChild(`{SECTION_TITLE_PREFIX}{openArg}`)
		if
			not containerInstance
			or not containerInstance:IsA("ScrollingFrame")
			or not titleInstance
			or not titleInstance:IsA("GuiObject")
		then
			return
		end

		local openSize: any = self.instance:GetAttribute("OgSize")
		if typeof(openSize) ~= "UDim2" then
			return
		end

		while self.instance.Size ~= openSize do
			RunService.RenderStepped:Wait()
			if self.openRequestId ~= requestId or not self.instance.Visible then
				return
			end
		end

		local container: ScrollingFrame = containerInstance :: ScrollingFrame
		local title: GuiObject = titleInstance :: GuiObject
		local previousCanvasSize: Vector2 = container.AbsoluteCanvasSize
		local stableFrames: number = 0
		while stableFrames < 2 do
			RunService.RenderStepped:Wait()
			if self.openRequestId ~= requestId or not self.instance.Visible then
				return
			end

			local currentCanvasSize: Vector2 = container.AbsoluteCanvasSize
			if currentCanvasSize == previousCanvasSize then
				stableFrames += 1
			else
				previousCanvasSize = currentCanvasSize
				stableFrames = 0
			end
		end

		local targetPosition: number = container.CanvasPosition.Y
			+ title.AbsolutePosition.Y
			- container.AbsolutePosition.Y
		local maxCanvasPosition: number = math.max(0, container.AbsoluteCanvasSize.Y - container.AbsoluteSize.Y)
		local targetCanvasPosition: Vector2 =
			Vector2.new(container.CanvasPosition.X, math.clamp(targetPosition, 0, maxCanvasPosition))

		local scrollTween: Tween = TweenService:Create(container, SCROLL_TWEEN_INFO, {
			CanvasPosition = targetCanvasPosition,
		})

		self.scrollTween = scrollTween

		scrollTween.Completed:Once(function(): ()
			if self.scrollTween == scrollTween then
				self.scrollTween = nil
			end
		end)
		scrollTween:Play()
	end)
end

function ShopUI:OnClose(): ()
	self.openRequestId += 1

	if self.scrollTween then
		self.scrollTween:Cancel()
		self.scrollTween = nil
	end
end

function ShopUI:SubmitCode(): ()
	local codeTextBox: TextBox = self.codeTextBox :: TextBox
	if not codeTextBox then
		return
	end

	local code: string = codeTextBox.Text:gsub("^%s*(.-)%s*$", "%1")
	if code == "" then
		return
	end

	codeTextBox.Text = ""

	REDEEM_CODE_BRIDGE:Fire(code)
end

function ShopUI:Destroy(): ()
	self.openRequestId += 1

	self.maid:DoCleaning()

	if self.scrollTween then
		self.scrollTween:Cancel()
		self.scrollTween = nil
	end

	self.codeTextBox = nil
end

return ShopUI
