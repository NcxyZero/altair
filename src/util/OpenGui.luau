local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local LocalPlayer = require(ReplicatedStorage.util.LocalPlayer)

export type OpenGui = {
	Open: (self: OpenGui, UIModule: ModuleScript & any) -> (),
	Close: (self: OpenGui, UIModule: ModuleScript & any) -> (),
	Handle: (self: OpenGui, UIModule: (ModuleScript & any)?, onOpen: (() -> ())?, onClose: (() -> ())?) -> (),
	Register: (self: OpenGui, UIModule: any) -> (),
	registered: { any },
}

local OpenGui: OpenGui = {} :: OpenGui
OpenGui.registered = {}

local info: TweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Back)

local guiBlur: BlurEffect = Instance.new("BlurEffect")
guiBlur.Size = 10
guiBlur.Enabled = false
guiBlur.Parent = workspace.CurrentCamera

local mainUI: ScreenGui = LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("MainUI")
mainUI:GetPropertyChangedSignal("Enabled"):Connect(function(): ()
	if mainUI.Enabled then
		guiBlur.Enabled = _G.CurrentlyOpen and _G.CurrentlyOpen.Visible or false
	else
		guiBlur.Enabled = false
	end
end)

local function OpenAnimation(UIModule: any): ()
	local UIElement: Frame = UIModule.instance or UIModule.tagclass.instance
	if not UIElement:GetAttribute("OgSize") then
		UIElement:SetAttribute("OgSize", UIElement.Size)
	end

	local ogSize: UDim2 = UIElement:GetAttribute("OgSize") :: UDim2
	UIElement.Size = UDim2.fromScale(ogSize.X.Scale * 0.8, ogSize.Y.Scale * 0.8)
	UIElement.Visible = true

	TweenService:Create(workspace.CurrentCamera, info, { FieldOfView = 40 }):Play()
	TweenService:Create(UIElement, info, { Size = UIElement:GetAttribute("OgSize") }):Play()

	if UIModule.OnOpen then
		UIModule:OnOpen()
	end
end

local function CloseAnimation(UIModule: any): ()
	local UIElement: any = UIModule
	if not UIElement then
		UIElement = _G.CurrentlyOpen
	end

	UIElement = UIModule.instance or UIModule.tagclass.instance

	if not UIElement:GetAttribute("OgSize") then
		UIElement:SetAttribute("OgSize", UIElement.Size)
	end

	local ogSize: UDim2 = UIElement:GetAttribute("OgSize") :: UDim2
	TweenService:Create(workspace.CurrentCamera, TweenInfo.new(0.15, Enum.EasingStyle.Back), { FieldOfView = 60 })
		:Play()

	TweenService:Create(UIElement, TweenInfo.new(0.1, Enum.EasingStyle.Linear), {
		Size = UDim2.fromScale(ogSize.X.Scale * 0.8, ogSize.Y.Scale * 0.8),
	}):Play()

	UIElement.Visible = false
end

function OpenGui:Register(UIModule: any)
	(UIModule.instance or UIModule.tagclass.instance).Destroying:Connect(function(): ()
		local found: number? = table.find(self.registered, UIModule)

		if found then
			table.remove(self.registered, found)
		end
	end)

	table.insert(self.registered, UIModule)
end

function OpenGui:Open(UIModule: any): ()
	for _index: number, object: ModuleScript in self.registered do
		if object == UIModule then
			continue
		end

		CloseAnimation(object)
	end

	guiBlur.Enabled = true

	OpenAnimation(UIModule)
end

function OpenGui:Close(UIModule: ModuleScript & any): ()
	CloseAnimation(UIModule)

	guiBlur.Enabled = false
end

return OpenGui
