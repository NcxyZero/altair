local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local LocalPlayer = require(ReplicatedStorage.util.LocalPlayer)

export type OpenGui = {
	Open: (self: OpenGui, UIModule: ModuleScript & any, openArg: any?) -> (),
	Close: (self: OpenGui, UIModule: ModuleScript & any, closeArg: any?) -> (),
	CloseCurrent: (self: OpenGui) -> boolean,
	Toggle: (self: OpenGui, UIModule: ModuleScript & any, openArg: any?) -> (),
	Register: (self: OpenGui, UIModule: any) -> (),
	registered: { any },
	openNormal: { [Instance]: any },
	openAlwaysOnTop: { [Instance]: any },
}

local OpenGui: OpenGui = {} :: OpenGui
OpenGui.registered = {}

-- Track open UI windows.
-- Normal windows behave like a single-stack: opening one closes other normal windows.
-- Windows with `AlwaysOnTop` attribute do not close other windows.
OpenGui.openNormal = {} :: { [Instance]: any }
OpenGui.openAlwaysOnTop = {} :: { [Instance]: any }

local info: TweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Back)

local guiBlur: BlurEffect = Instance.new("BlurEffect")
guiBlur.Size = 10
guiBlur.Enabled = false
guiBlur.Parent = workspace.CurrentCamera

local playerGui: PlayerGui = LocalPlayer:WaitForChild("PlayerGui") :: PlayerGui
local mainUI: ScreenGui = playerGui:FindFirstChild("MainUI") :: ScreenGui
local mainUIConnection: RBXScriptConnection?
if not mainUI then
	print("OpenGui: MainUI not found in PlayerGui. Waiting for it to appear.")
end

local function getUIElement(UIModule: any): Frame
	return (UIModule.instance or UIModule.tagclass.instance) :: any
end

local function isAlwaysOnTop(UIModule: any): boolean
	local element: Frame = getUIElement(UIModule)
	return element:GetAttribute("AlwaysOnTop") == true
end

local function wantsBlur(UIModule: any): boolean
	local element: Frame = getUIElement(UIModule)
	local attr: any = element:GetAttribute("EnableBlur")
	if typeof(attr) == "boolean" then
		return attr
	end

	-- Default behavior:
	-- - normal windows blur
	-- - AlwaysOnTop windows do NOT blur unless explicitly enabled
	return not isAlwaysOnTop(UIModule)
end

local function updateBlur(): ()
	if not mainUI or not mainUI.Enabled then
		guiBlur.Enabled = false

		return
	end

	for _element: Instance, module: any in OpenGui.openNormal do
		if wantsBlur(module) then
			guiBlur.Enabled = true

			return
		end
	end

	for _element: Instance, module: any in OpenGui.openAlwaysOnTop do
		if wantsBlur(module) then
			guiBlur.Enabled = true

			return
		end
	end

	guiBlur.Enabled = false
end

local function bindMainUI(gui: ScreenGui): ()
	mainUI = gui
	if mainUIConnection then
		mainUIConnection:Disconnect()
		mainUIConnection = nil
	end

	mainUIConnection = mainUI:GetPropertyChangedSignal("Enabled"):Connect(function(): ()
		updateBlur()
	end)

	updateBlur()
end

if mainUI then
	bindMainUI(mainUI)
end

playerGui.ChildAdded:Connect(function(child: Instance): ()
	if child:IsA("ScreenGui") and child.Name == "MainUI" then
		bindMainUI(child)
	end
end)

local function OpenAnimation(UIModule: any, openArg: any?): ()
	local UIElement: Frame = getUIElement(UIModule)
	if not UIElement:GetAttribute("OgSize") then
		UIElement:SetAttribute("OgSize", UIElement.Size)
	end

	local ogSize: UDim2 = UIElement:GetAttribute("OgSize") :: UDim2
	UIElement.Size = UDim2.fromScale(ogSize.X.Scale * 0.8, ogSize.Y.Scale * 0.8)
	UIElement.Visible = true

	TweenService:Create(workspace.CurrentCamera, info, { FieldOfView = 40 }):Play()
	TweenService:Create(UIElement, info, { Size = UIElement:GetAttribute("OgSize") }):Play()

	if UIModule.OnOpen then
		UIModule:OnOpen(openArg)
	end
end

local function CloseAnimation(UIModule: any, closeArg: any?): ()
	if not UIModule then
		return
	end

	local UIElement: Frame = getUIElement(UIModule)
	if not UIElement:GetAttribute("OgSize") then
		UIElement:SetAttribute("OgSize", UIElement.Size)
	end

	local ogSize: UDim2 = UIElement:GetAttribute("OgSize") :: UDim2
	TweenService:Create(workspace.CurrentCamera, TweenInfo.new(0.15, Enum.EasingStyle.Back), { FieldOfView = 60 })
		:Play()

	TweenService:Create(UIElement, TweenInfo.new(0.1, Enum.EasingStyle.Linear), {
		Size = UDim2.fromScale(ogSize.X.Scale * 0.8, ogSize.Y.Scale * 0.8),
	}):Play()

	if UIModule.OnClose then
		UIModule:OnClose(closeArg)
	end

	UIElement.Visible = false
end

function OpenGui:Register(UIModule: any): ()
	local element: Frame = getUIElement(UIModule)
	element.Destroying:Connect(function(): ()
		local found: number? = table.find(self.registered, UIModule)

		if found then
			table.remove(self.registered, found)
		end

		self.openNormal[element] = nil
		self.openAlwaysOnTop[element] = nil
		updateBlur()
	end)

	table.insert(self.registered, UIModule)
end

function OpenGui:Open(UIModule: any, openArg: any?): ()
	local element: Frame = getUIElement(UIModule)

	if isAlwaysOnTop(UIModule) then
		self.openAlwaysOnTop[element] = UIModule

		OpenAnimation(UIModule, openArg)
		updateBlur()

		return
	end

	-- normal UI: close other normal windows
	local openElements: { Instance } = {}
	for otherElement: Instance, _module: any in self.openNormal do
		table.insert(openElements, otherElement)
	end

	for index: number = 1, #openElements do
		local otherElement: Instance = openElements[index]
		local otherModule: any = self.openNormal[otherElement]
		if otherModule and otherElement ~= element then
			CloseAnimation(otherModule)
		end

		self.openNormal[otherElement] = nil
	end

	-- Also close any visible normal UI that might not be tracked yet (e.g. legacy opens)
	for _index: number, other: any in self.registered do
		if other == UIModule then
			continue
		end

		if isAlwaysOnTop(other) then
			continue
		end

		local otherElement: Frame = getUIElement(other)
		if otherElement == element then
			continue
		end

		if otherElement.Visible then
			CloseAnimation(other)
		end

		self.openNormal[otherElement] = nil
	end

	self.openNormal[element] = UIModule

	OpenAnimation(UIModule, openArg)
	updateBlur()
end

function OpenGui:Close(UIModule: ModuleScript & any, closeArg: any?): ()
	local element: Frame = getUIElement(UIModule)
	CloseAnimation(UIModule, closeArg)

	self.openNormal[element] = nil
	self.openAlwaysOnTop[element] = nil

	updateBlur()
end

function OpenGui:CloseCurrent(): boolean
	for _element: Instance, module: any in self.openNormal do
		self:Close(module)

		return true
	end

	for _index: number, other: any in self.registered do
		if isAlwaysOnTop(other) then
			continue
		end

		local element: Frame = getUIElement(other)
		if element.Visible then
			self:Close(other)

			return true
		end
	end

	return false
end

function OpenGui:Toggle(UIModule: ModuleScript & any, openArg: any?): ()
	local UIElement: Frame = getUIElement(UIModule)
	if not UIElement.Visible then
		self:Open(UIModule, openArg)

		return
	end

	self:Close(UIModule)
end

return OpenGui
