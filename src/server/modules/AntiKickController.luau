local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

local GameConfig = require(ReplicatedStorage.shared.config.GameConfig)
local GetBridge = require(ReplicatedStorage.util.Core.GetBridge)
local InitializerTypes = require(ReplicatedStorage.shared.types.InitializerTypes)
local Logger = require(ReplicatedStorage.util.Core.Logger)
local Maid = require(ReplicatedStorage.package.Maid)

type RejoinState = {
	fallbackTried: boolean,
	requestedAt: number,
	teleporting: boolean,
}

export type AntiKickController = {
	FindServer: (self: AntiKickController) -> string?,
	GetResumeCFrame: (self: AntiKickController, player: Player) -> CFrame?,
	HandleTeleportFailure: (
		self: AntiKickController,
		player: Player,
		teleportResult: Enum.TeleportResult,
		errorMessage: string,
		placeId: number,
		options: TeleportOptions?
	) -> (),
	Init: (self: AntiKickController) -> (),
	PlayerAdded: (self: AntiKickController, player: Player) -> (),
	PlayerRemoving: (self: AntiKickController, player: Player) -> (),
	Rejoin: (self: AntiKickController, player: Player) -> (),
	states: { [Player]: RejoinState },
	path: InitializerTypes.ServerPath,
	type: string,
	maid: Maid.Maid,
}

local AntiKickController: AntiKickController = {
	states = {},
	type = "controller",
	maid = Maid.new(),
} :: any

local CONFIG = GameConfig.game.antiKick
local FLOODED_RETRY_DELAY: number = 15 -- seconds before the fallback teleport after Roblox refused one as Flooded
local REJOIN_BRIDGE: any = GetBridge("AntiIdleRejoin")

-- A reserved server only takes players with its access code, so a rejoin there could never succeed.
local function isReservedServer(): boolean
	return game.PrivateServerId ~= "" and game.PrivateServerOwnerId == 0
end

local function packVector(vector: Vector3): { number }
	return { vector.X, vector.Y, vector.Z }
end

local function parseVector(value: unknown): Vector3?
	if type(value) ~= "table" then
		return
	end
	local components: { [number]: any } = value :: any

	for index: number = 1, 3 do
		local component: unknown = components[index]
		if type(component) ~= "number" or component ~= component or math.abs(component) > 1_000_000 then
			return
		end
	end

	return Vector3.new(components[1], components[2], components[3])
end

function AntiKickController:FindServer(): string?
	if game.PrivateServerId ~= "" then
		return game.JobId
	end

	-- Hops to a random public server of this place, falling back to a same-place teleport.
	local success: boolean, result: any = pcall(function(): any
		local response: string = HttpService:GetAsync(
			`https://games.roproxy.com/v1/games/{game.PlaceId}/servers/Public?sortOrder=Desc&limit=100`
		)

		return HttpService:JSONDecode(response)
	end)
	if not success or type(result) ~= "table" or type(result.data) ~= "table" then
		return
	end

	local servers: { string } = {}
	for _index: number, server: any in result.data do
		if
			type(server) == "table"
			and type(server.id) == "string"
			and server.id ~= game.JobId
			and type(server.playing) == "number"
			and type(server.maxPlayers) == "number"
			and server.playing < server.maxPlayers
		then
			table.insert(servers, server.id)
		end
	end

	return #servers > 0 and servers[math.random(1, #servers)] or nil
end

function AntiKickController:Rejoin(player: Player): ()
	if not CONFIG.enabled or isReservedServer() then
		return
	end

	local state: RejoinState? = self.states[player]
	local now: number = os.clock()
	if
		player.Parent ~= Players or (state and (state.teleporting or now - state.requestedAt < CONFIG.requestCooldown))
	then
		return
	end

	local character: Model? = player.Character
	local root: BasePart = character and character:FindFirstChild("HumanoidRootPart") :: any
	if not root then
		return
	end

	local serverData: any = self.path.controller.ServerData
	if not serverData or not serverData:SyncPlayerProfile(player) then
		return
	end

	local newState: RejoinState = { fallbackTried = false, requestedAt = now, teleporting = true }
	self.states[player] = newState
	if RunService:IsStudio() then
		newState.teleporting = false

		return
	end

	local options: TeleportOptions = Instance.new("TeleportOptions")
	options:SetTeleportData({
		antiKickResume = true,
		position = packVector(root.Position),
		lookVector = packVector(root.CFrame.LookVector),
	})
	local serverId: string? = self:FindServer()
	if serverId then
		options.ServerInstanceId = serverId
	end
	if player.Parent ~= Players then
		return
	end

	local success: boolean, errorMessage: unknown = pcall(function(): ()
		TeleportService:TeleportAsync(game.PlaceId, { player }, options)
	end)
	if not success and serverId and game.PrivateServerId == "" then
		newState.fallbackTried = true

		options.ServerInstanceId = ""

		success, errorMessage = pcall(function(): ()
			TeleportService:TeleportAsync(game.PlaceId, { player }, options)
		end)
	end
	if not success then
		newState.teleporting = false

		Logger.warn(`Anti-idle rejoin failed: {errorMessage}`)
	end
end

function AntiKickController:GetResumeCFrame(player: Player): CFrame?
	if not CONFIG.enabled then
		return
	end

	local success: boolean, joinData: any = pcall(player.GetJoinData, player)
	local data: any = success and joinData and joinData.TeleportData
	if not data or type(data) ~= "table" or data.antiKickResume ~= true or joinData.SourcePlaceId ~= game.PlaceId then
		return
	end

	local position: Vector3 = parseVector(data.position) :: any
	local lookVector: Vector3 = parseVector(data.lookVector) :: any
	if not position or not lookVector or lookVector.Magnitude < 0.001 then
		return
	end

	return CFrame.lookAt(position, position + lookVector.Unit)
end

function AntiKickController:PlayerAdded(player: Player): ()
	local target: CFrame = self:GetResumeCFrame(player) :: any
	if not target then
		return
	end

	local serverData: any = self.path.controller.ServerData
	serverData:GetPlayerProducerAsync(player):expect()
	if player.Parent ~= Players then
		return
	end

	local character: Model = player.Character or player.CharacterAdded:Wait()
	local root: BasePart = character:WaitForChild("HumanoidRootPart", 10) :: any
	if not root or player.Parent ~= Players then
		return
	end

	-- Character pivots differ from root pivots on scaled avatars.
	character:PivotTo(target * root.CFrame:ToObjectSpace(character:GetPivot()))
	root.AssemblyAngularVelocity = Vector3.zero
	root.AssemblyLinearVelocity = Vector3.zero
end

function AntiKickController:PlayerRemoving(player: Player): ()
	self.states[player] = nil
end

-- A targeted teleport can still fail after TeleportAsync returned (the server filled up or closed); the rejoin then
-- gets one try with any server of the place. Any other failure ends the pending rejoin.
function AntiKickController:HandleTeleportFailure(
	player: Player,
	teleportResult: Enum.TeleportResult,
	errorMessage: string,
	placeId: number,
	options: TeleportOptions?
): ()
	local state: RejoinState? = self.states[player]
	if not state or not state.teleporting then
		return
	end

	local teleportData: any = options and options:GetTeleportData()
	if placeId ~= game.PlaceId or type(teleportData) ~= "table" or teleportData.antiKickResume ~= true then
		state.teleporting = false

		return
	end

	if not options or options.ServerInstanceId == "" or game.PrivateServerId ~= "" or state.fallbackTried then
		state.teleporting = false

		Logger.warn(`Anti-idle rejoin failed ({teleportResult.Name}): {errorMessage}`)

		return
	end

	state.fallbackTried = true

	if teleportResult == Enum.TeleportResult.Flooded then
		task.wait(FLOODED_RETRY_DELAY)
	end

	if player.Parent ~= Players or self.states[player] ~= state then
		return
	end

	options.ServerInstanceId = ""

	local success: boolean, retryErrorMessage: unknown = pcall(function(): ()
		TeleportService:TeleportAsync(game.PlaceId, { player }, options)
	end)
	if not success then
		state.teleporting = false

		Logger.warn(`Anti-idle rejoin failed: {retryErrorMessage}`)
	end
end

function AntiKickController:Init(): ()
	self.maid:DoCleaning()

	if not CONFIG.enabled then
		return
	end

	self.maid:GiveTask(REJOIN_BRIDGE:Connect(function(player: Player): ()
		self:Rejoin(player)
	end))
	self.maid:GiveTask(
		TeleportService.TeleportInitFailed:Connect(
			function(
				player: Player,
				teleportResult: Enum.TeleportResult,
				errorMessage: string,
				placeId: number,
				options: TeleportOptions?
			): ()
				self:HandleTeleportFailure(player, teleportResult, errorMessage, placeId, options)
			end
		)
	)
end

return AntiKickController
