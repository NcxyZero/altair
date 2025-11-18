local GroupService = game:GetService("GroupService")
local LogService = game:GetService("LogService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")
local TextService = game:GetService("TextService")
local UserInputService = game:GetService("UserInputService")

local CreateInstance = require(ReplicatedStorage.util.CreateInstance)
local EscapeRichText = require(ReplicatedStorage.util.EscapeRichText)
local IsPlayerOnMobile = require(ReplicatedStorage.util.IsPlayerOnMobile)
local Signal = require(ReplicatedStorage.package.Signal)
local WaitForGameToLoad = require(ReplicatedStorage.util.WaitForGameToLoad)

export type DevLogger = {
	__index: DevLogger,
	type: string,
	BuildGui: (self: DevLogger) -> ScreenGui,
	RefreshTextLog: (self: DevLogger) -> (),
	HandleLog: (self: DevLogger, message: string, messageType: Enum.MessageType) -> (),
	Show: (self: DevLogger) -> (),
	Hide: (self: DevLogger) -> (),
	Init: (self: DevLogger) -> (),
	MessageColors: { [number]: Color3 },
	Messages: { string },
	LastRefresh: { [number]: number },
	MessageDisplayTime: number,
	GroupRankRequired: number,
	ui: ScreenGui & {
		ScrollingFrame: ScrollingFrame & {
			UIListLayout: UIListLayout,
			TextLabel: TextLabel,
		},
	},
	scrollingFrame: ScrollingFrame & {
		UIListLayout: UIListLayout,
		TextLabel: TextLabel,
	},
	uiListLayout: UIListLayout,
	textLabel: TextLabel,
	loaded: boolean,
	loadedSignal: Signal.Signal<>,
}

local DevLogger: DevLogger = {} :: any
DevLogger.__index = DevLogger
DevLogger.type = "controller"

DevLogger.MessageColors = {
	[0] = Color3.fromRGB(204, 204, 204),
	[1] = Color3.fromRGB(0, 139, 219),
	[2] = Color3.fromRGB(255, 115, 21),
	[3] = Color3.fromRGB(255, 0, 0),
	[4] = Color3.fromRGB(255, 215, 0), -- Custom
}

DevLogger.Messages = {}
DevLogger.LastRefresh = {}
DevLogger.MessageDisplayTime = 10
DevLogger.GroupRankRequired = 225

function DevLogger:BuildGui(): ScreenGui
	local screenGui: ScreenGui = CreateInstance("ScreenGui", Players.LocalPlayer.PlayerGui, "DevLogDisplay", {
		ZIndexBehavior = Enum.ZIndexBehavior.Global,
		DisplayOrder = 100_000,
	})
	local scrollingFrame: ScrollingFrame = CreateInstance("ScrollingFrame", screenGui, {
		Active = false,
		AnchorPoint = Vector2.new(0, 1),
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 1,
		Interactable = false,
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.fromScale(0.4, 0.4),
		ClipsDescendants = false,
		CanvasSize = UDim2.fromScale(0, 0),
		ScrollBarImageColor3 = Color3.fromRGB(255, 255, 255),
		Selectable = false,
	})
	CreateInstance("UIListLayout", scrollingFrame)
	CreateInstance("TextLabel", scrollingFrame, {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		FontFace = Font.fromEnum(Enum.Font.Ubuntu),
		RichText = true,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextSize = 25,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Bottom,
	})

	return screenGui
end

function DevLogger:RefreshTextLog(): ()
	if not self.textLabel then
		return
	end

	local function getNewString(): string
		return #self.Messages == 0 and ""
			or table.concat(self.Messages, "\n")
				.. `\n<i><font size="15" color="#{DevLogger.MessageColors[4]:ToHex()}">Toggle visibility: '=' key or by command '/devlog' in chat</font></i>`
	end

	local newString: string = getNewString()
	while #newString >= 20000 or #self.Messages > 5 do
		table.remove(self.Messages, 1)
		table.remove(self.LastRefresh, 1)

		newString = getNewString()

		task.wait()
	end

	local params: GetTextBoundsParams = Instance.new("GetTextBoundsParams")
	params.Text = newString
	params.Font = self.textLabel.FontFace
	params.Size = self.textLabel.TextSize
	params.RichText = true
	local size: Vector2 = TextService:GetTextBoundsAsync(params)

	self.textLabel.Text = newString
	self.scrollingFrame.Transparency = #newString > 0 and 0.75 or 1
	self.scrollingFrame.CanvasSize = UDim2.new(self.scrollingFrame.CanvasSize.X, UDim.new(0, size.Y))
	self.scrollingFrame.CanvasPosition = Vector2.yAxis * self.scrollingFrame.CanvasSize.Y.Offset
end

function DevLogger:HandleLog(message: string, messageType: Enum.MessageType): ()
	if messageType.Value < 2 then
		return
	end

	local messageString: string =
		`<font color="#{self.MessageColors[messageType.Value]:ToHex()}">{EscapeRichText(message)}</font>`
	local messageIndex: number? = table.find(self.Messages, messageString)
	if not messageIndex then
		for i: number, value: string in self.Messages do
			if value:find(messageString, 1, true) then
				messageIndex = i
				break
			end
		end
	end

	if messageIndex then
		local _base: string?, amount: string? = self.Messages[messageIndex]:match("^(.-)%s*%(x(%d+)%)%s*")
		self.Messages[messageIndex] = `{messageString} <b> (x{amount and tonumber(amount) :: number + 1 or 2}) </b>`
		self.LastRefresh[messageIndex] = os.clock()
	else
		table.insert(self.Messages, messageString)

		task.spawn(function(): ()
			local index: number = #self.Messages
			self.LastRefresh[index] = os.clock()

			while true do
				local diff: number = ((self.LastRefresh[index] or 0) + self.MessageDisplayTime) - os.clock()
				if diff > 0 then
					task.wait(diff)
				else
					break
				end
			end

			table.remove(self.LastRefresh, index)
			table.remove(self.Messages, index)
			self:RefreshTextLog()
		end)
	end

	self:RefreshTextLog()
end

function DevLogger:Show(): ()
	self.ui.Enabled = true
end

function DevLogger:Hide(): ()
	self.ui.Enabled = false
end

function DevLogger:Init(): ()
	if
		workspace:GetAttribute("SHOW_DEV_LOGS") == false
		or Players.LocalPlayer:GetRankInGroup(game.CreatorId) < self.GroupRankRequired
	then
		return
	end

	self.loadedSignal = Signal.new()

	task.spawn(function(): ()
		self.ui = Players.LocalPlayer.PlayerGui:FindFirstChild("DevLogDisplay") or self:BuildGui()
		self.scrollingFrame = self.ui:WaitForChild("ScrollingFrame")
		self.uiListLayout = self.scrollingFrame:WaitForChild("UIListLayout")
		self.textLabel = self.scrollingFrame:WaitForChild("TextLabel")

		self.ui.Enabled = not IsPlayerOnMobile()
		self.loaded = true
		self.loadedSignal:Fire()

		self:RefreshTextLog()
	end)

	LogService.MessageOut:Connect(function(message: string, messageType: Enum.MessageType): ()
		xpcall(function(): ()
			self:HandleLog(message, messageType)
		end, function(errorString: string): ()
			print(`[DevLogger MessageOut Error]: {errorString}`)
		end)
	end)

	task.defer(function(): ()
		while true do
			for index: number, _message: string in self.Messages do
				local diff: number = ((self.LastRefresh[index] or 0) + self.MessageDisplayTime) - os.clock()
				if diff <= 0 then
					table.remove(self.LastRefresh, index)
					table.remove(self.Messages, index)
				end
			end

			self:RefreshTextLog()
			task.wait(5)
		end
	end)

	if not self.loaded then
		self.loadedSignal:Wait()
	end

	UserInputService.InputBegan:Connect(function(InputObject: InputObject, GameProccessedEvent: boolean): ()
		if not GameProccessedEvent and InputObject.KeyCode == Enum.KeyCode.Equals then
			self.ui.Enabled = not self.ui.Enabled
		end
	end)

	local command: TextChatCommand = Instance.new("TextChatCommand")
	command.Name = "DevLoggerToggler"
	command.PrimaryAlias = "/devlog"
	command.Parent = TextChatService

	command.Triggered:Connect(function(): ()
		self.ui.Enabled = not self.ui.Enabled
	end)

	RunService.Stepped:Wait()
	WaitForGameToLoad()

	if game.CreatorType == Enum.CreatorType.Group then
		local groupInfo = GroupService:GetGroupInfoAsync(game.CreatorId)
		if not groupInfo then
			return
		end

		local roles: { string } = {}
		for _index: number, data in groupInfo.Roles do
			if data.Rank < self.GroupRankRequired then
				continue
			end

			table.insert(roles, data.Name)
		end

		self:HandleLog(
			`The logger is visible to the specified roles: {table.concat(roles, ", ")}. On mobile devices, the console is hidden by default.`,
			{ Value = 4 },
			15
		)
	else
		self:HandleLog(`The console is only visible to the game creator.`, { Value = 4 })
	end
end

return DevLogger
