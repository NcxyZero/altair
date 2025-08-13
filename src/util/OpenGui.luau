local TweenService = game:GetService("TweenService")

export type OpenGui = {
	Open: (self: OpenGui, UIModule: ModuleScript & any) -> (),
	Close: (self: OpenGui, UIModule: ModuleScript & any) -> (),
	Handle: (self: OpenGui, UIModule: (ModuleScript & any)?, onOpen: (() -> ())?, onClose: (() -> ())?) -> (),
	current: ModuleScript & any,
}

local OpenGui: OpenGui = {} :: OpenGui

local CurrentlyOpen: (ModuleScript & any)?

local function OpenAnimation(UIModule: ModuleScript & any): ()
	local UIElement: Frame = UIModule.MainFrame
	if not UIElement:GetAttribute("OgSize") then
		UIElement:SetAttribute("OgSize", UIElement.Size)
	end

	local ogSize: UDim2 = UIElement:GetAttribute("OgSize") :: UDim2
	UIElement.Size = UDim2.fromScale(ogSize.X.Scale * 0.8, ogSize.Y.Scale * 0.8)
	UIElement.Visible = true

	TweenService
		:Create(UIElement, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Size = UIElement:GetAttribute("OgSize") })
		:Play()
	CurrentlyOpen = UIModule

	if UIModule["OnOpen"] then
		UIModule:OnOpen()
	end
end

local function CloseAnimation(UIModule: ModuleScript & any): ()
	local UIElement: ModuleScript & any = UIModule
	if not UIElement then
		UIElement = CurrentlyOpen :: any
	end

	UIElement = UIElement.MainFrame

	if not UIElement:GetAttribute("OgSize") then
		UIElement:SetAttribute("OgSize", UIElement.Size)
	end

	local ogSize: UDim2 = UIElement:GetAttribute("OgSize") :: UDim2
	TweenService:Create(UIElement, TweenInfo.new(0.1, Enum.EasingStyle.Linear), {
		Size = UDim2.fromScale(ogSize.X.Scale * 0.8, ogSize.Y.Scale * 0.8),
	}):Play()

	task.wait(0.1)
	CurrentlyOpen = nil
	UIElement.Visible = false
end

function OpenGui:Open(UIModule: ModuleScript & any): ()
	if CurrentlyOpen and CurrentlyOpen ~= UIModule then
		CloseAnimation(CurrentlyOpen)
		OpenAnimation(UIModule)
	elseif CurrentlyOpen == UIModule then
		CloseAnimation(UIModule)
	else
		OpenAnimation(UIModule)
	end
end

function OpenGui:Close(UIModule: ModuleScript & any): ()
	if CurrentlyOpen then
		CloseAnimation(UIModule)
	end
end

function OpenGui:Handle(id: any, show: any, hide: any): ()
	pcall(function(): ()
		if self.current.exec and typeof(self.current.exec) == "function" then
			self.current.exec()
		end
	end)

	self.current.id = id
	self.current.exec = hide

	if typeof(show) == "function" then
		show()
	end
end

return OpenGui
