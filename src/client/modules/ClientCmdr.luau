local GroupService = game:GetService("GroupService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GameConfig = require(ReplicatedStorage.shared.config.GameConfig)
local IsPlayerOnMobile = require(ReplicatedStorage.util.Core.IsPlayerOnMobile)
local LocalPlayer = require(ReplicatedStorage.util.Core.LocalPlayer)
local Logger = require(ReplicatedStorage.util.Core.Logger)
local Maid = require(ReplicatedStorage.package.Maid)
local TopbarPlus = require(ReplicatedStorage.package.topbarplus)

type IconConnection = {
	Disconnect: (self: IconConnection) -> (),
}

type IconSelectionSignal = {
	Connect: (self: IconSelectionSignal, callback: (...any) -> ()) -> IconConnection,
}

-- TopbarPlus 3.4.0 omits these runtime members from its exported Icon type.
type TopbarIcon = TopbarPlus.Icon & {
	deselected: IconSelectionSignal,
	isSelected: boolean,
	selected: IconSelectionSignal,
}

export type ClientCmdr = {
	Destroy: (self: ClientCmdr) -> (),
	Init: (self: ClientCmdr) -> (),
	SetUpAsync: (self: ClientCmdr, setupId: number) -> (),
	SyncIcon: (self: ClientCmdr, window: GuiObject) -> (),
	type: string,
	icon: TopbarIcon?,
	maid: Maid.Maid,
}

local ClientCmdr: ClientCmdr = {
	type = "controller",
	maid = Maid.new(),
} :: any

local CMDR_CLIENT_NAME: string = "CmdrClient" -- ModuleScript that Cmdr's server module puts into ReplicatedStorage
local REGISTERED_ATTRIBUTE: string = "Registered" -- set on CmdrClient by ServerCmdr: its module count once registered
local REGISTRATION_WARNING_SECONDS: number = 30 -- a client still waiting for the registration warns once after this

local roleData: { groupId: number?, rank: number } = GameConfig.roles[GameConfig.cmdr.role]
local requiredGroup: number = roleData.groupId or game.CreatorType == Enum.CreatorType.Group and game.CreatorId or 0
local requiredRank: number = roleData.rank -- also in user-owned games, where non-members of the group have rank 0

local currentSetupId: number = 0 -- raised by every Init and Destroy, so a setup that is still waiting stops

local cmdr: any -- Cmdr's client once loadCmdr has required it

local function canUseCmdr(): boolean
	if RunService:IsStudio() or table.find(GameConfig.cmdr.players, LocalPlayer.UserId) then
		return true
	end
	if requiredGroup == 0 then
		return game.CreatorType == Enum.CreatorType.User and LocalPlayer.UserId == game.CreatorId
	end

	local success: boolean, rank: any = pcall(function(): number
		local membership: { IsMember: boolean, Roles: { { Rank: number } } } =
			GroupService:GetRolesInGroupAsync(LocalPlayer.UserId, requiredGroup)
		if not membership.IsMember then
			return 0
		end

		local highestRank: number = 0
		for _index: number, role: { Rank: number } in membership.Roles do
			highestRank = math.max(highestRank, role.Rank)
		end

		return highestRank
	end)

	return success and rank >= requiredRank
end

-- CmdrClient once ServerCmdr has registered everything and this client has received every module it counted.
local function findRegisteredCmdrClient(): ModuleScript?
	local cmdrClient: ModuleScript = ReplicatedStorage:FindFirstChild(CMDR_CLIENT_NAME) :: any
	if not cmdrClient then
		return
	end

	local moduleCount: unknown = cmdrClient:GetAttribute(REGISTERED_ATTRIBUTE)
	local commands: Instance = cmdrClient:FindFirstChild("Commands") :: any
	local types: Instance = cmdrClient:FindFirstChild("Types") :: any
	if type(moduleCount) ~= "number" or not commands or not types then
		return
	end

	if #commands:GetChildren() + #types:GetChildren() < moduleCount then
		return
	end

	return cmdrClient
end

-- Cmdr's client registers only the commands, types and hooks that CmdrClient holds when it is required, so the
-- require waits for the server's registration. Cmdr starts disabled; SetUpAsync enables it for authorized players.
local function loadCmdr(): any
	local warningTime: number = os.clock() + REGISTRATION_WARNING_SECONDS
	local warned: boolean = false

	local cmdrClient: ModuleScript? = findRegisteredCmdrClient()
	while not cmdr and not cmdrClient do
		if not warned and os.clock() >= warningTime then
			Logger.warn(
				`Cmdr is not loaded after {REGISTRATION_WARNING_SECONDS} s: ServerCmdr has not finished registering in ReplicatedStorage.{CMDR_CLIENT_NAME}; the console loads once it has`
			)

			warned = true
		end

		task.wait()

		cmdrClient = findRegisteredCmdrClient()
	end

	if not cmdr then
		cmdr = require(cmdrClient :: any)

		cmdr:SetEnabled(false)
	end

	return cmdr
end

function ClientCmdr:Destroy(): ()
	currentSetupId += 1
	self.icon = nil

	self.maid:DoCleaning()

	if not cmdr then
		return
	end

	cmdr:SetEnabled(false)
	cmdr:Hide()
end

-- Runs in its own thread, so the client startup never waits for the server's Cmdr registration.
function ClientCmdr:SetUpAsync(setupId: number): ()
	local loadedCmdr: any = loadCmdr()
	local enabled: boolean = canUseCmdr()
	if setupId ~= currentSetupId then
		return
	end

	loadedCmdr:SetActivationKeys(GameConfig.cmdr.activationKeys)
	loadedCmdr:SetEnabled(enabled)
	loadedCmdr:SetHideOnLostFocus(false)
	if not enabled then
		return
	end

	local window: GuiObject = LocalPlayer.PlayerGui:WaitForChild("Cmdr"):WaitForChild("Frame") :: GuiObject
	if setupId ~= currentSetupId then
		return
	end

	local icon: TopbarIcon = TopbarPlus.new() :: TopbarIcon
	self.icon = icon

	icon:align("Right")
	icon:setCaption("Cmdr")
	icon:setImage("rbxassetid://80607447386923")
	icon:setName("Cmdr")
	if IsPlayerOnMobile() then
		icon:setLabel("Cmdr")
	end

	self.maid:GiveTask(icon.selected:Connect(function(): ()
		if not window.Visible then
			loadedCmdr:Show()
		end
	end))
	self.maid:GiveTask(icon.deselected:Connect(function(): ()
		if window.Visible then
			loadedCmdr:Hide()
		end
	end))
	self.maid:GiveTask(window:GetPropertyChangedSignal("Visible"):Connect(function(): ()
		self:SyncIcon(window)
	end))
	self.maid:GiveTask(function(): ()
		icon:destroy()
	end)

	self:SyncIcon(window)
end

function ClientCmdr:SyncIcon(window: GuiObject): ()
	local icon: TopbarIcon = self.icon :: any
	if not icon or icon.isSelected == window.Visible then
		return
	end
	if window.Visible then
		icon:select()
	else
		icon:deselect()
	end
end

function ClientCmdr:Init(): ()
	self:Destroy()

	task.spawn(self.SetUpAsync, self, currentSetupId)
end

return ClientCmdr
