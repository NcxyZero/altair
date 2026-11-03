local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local InitializerTypes = require(ReplicatedStorage.shared.types.InitializerTypes)
local Maid = require(ReplicatedStorage.package.Maid)

export type PlayerObservationController = {
	ConnectCharacter: (self: PlayerObservationController, player: Player, character: Model) -> (),
	Init: (self: PlayerObservationController) -> (),
	PlayerAdded: (self: PlayerObservationController, player: Player) -> (),
	PlayerRemoving: (self: PlayerObservationController, player: Player) -> (),
	RefreshStreamingFocus: (self: PlayerObservationController, observer: Player) -> (),
	RefreshTarget: (self: PlayerObservationController, target: Player) -> (),
	SetSpectate: (
		self: PlayerObservationController,
		observer: Player,
		target: Player?,
		keepHUD: boolean?
	) -> (boolean, string),
	focusedParts: { [Player]: { [BasePart]: boolean } },
	path: InitializerTypes.ServerPath,
	playerMaids: { [Player]: Maid.Maid },
	spectates: { [Player]: Player },
	index: number,
	type: string,
	maid: Maid.Maid,
}

local PlayerObservationController: PlayerObservationController = {} :: any
PlayerObservationController.focusedParts = {}
PlayerObservationController.playerMaids = {}
PlayerObservationController.spectates = {}
PlayerObservationController.index = 2
PlayerObservationController.type = "controller"
PlayerObservationController.maid = Maid.new()

function PlayerObservationController:RefreshStreamingFocus(observer: Player): ()
	local desiredParts: { [BasePart]: boolean } = {}
	local target: Player? = self.spectates[observer]
	local character: Model? = target and target.Character
	local root: BasePart = character and character:FindFirstChild("HumanoidRootPart") :: any
	if root and root:IsA("BasePart") and root:IsDescendantOf(Workspace) then
		desiredParts[root] = true
	end

	local previousParts: { [BasePart]: boolean } = self.focusedParts[observer] or {}
	for part: BasePart in previousParts do
		if not desiredParts[part] then
			observer:RemoveReplicationFocus(part)
		end
	end

	for part: BasePart in desiredParts do
		if not previousParts[part] then
			observer:AddReplicationFocus(part)
		end
	end

	self.focusedParts[observer] = next(desiredParts) and desiredParts or nil
end

function PlayerObservationController:SetSpectate(
	observer: Player,
	target: Player?,
	keepHUD: boolean?
): (boolean, string)
	if target == observer then
		target = nil
	end
	if target and (target.Parent ~= Players or observer.Parent ~= Players) then
		return false, "Choose another player on this server."
	end

	self.spectates[observer] = target
	if target then
		observer:SetAttribute("SpectateKeepHUD", keepHUD == true)
	else
		observer:SetAttribute("SpectateKeepHUD", nil)
	end
	observer:SetAttribute("SpectateUserId", target and target.UserId or nil)

	self:RefreshStreamingFocus(observer)

	return true, target and `Spectating {target.Name}.` or "Restored your camera."
end

function PlayerObservationController:RefreshTarget(target: Player): ()
	for observer: Player, spectateTarget: Player in self.spectates do
		if spectateTarget == target then
			self:RefreshStreamingFocus(observer)
		end
	end
end

function PlayerObservationController:ConnectCharacter(player: Player, character: Model): ()
	local playerMaid: Maid.Maid = self.playerMaids[player] :: any
	if not playerMaid then
		return
	end

	local characterMaid: Maid.Maid = Maid.new()
	playerMaid.Character = characterMaid
	characterMaid:GiveTask(character.ChildAdded:Connect(function(child: Instance): ()
		if child.Name == "HumanoidRootPart" then
			self:RefreshTarget(player)
		end
	end))
	characterMaid:GiveTask(character.ChildRemoved:Connect(function(child: Instance): ()
		if child.Name == "HumanoidRootPart" then
			self:RefreshTarget(player)
		end
	end))

	self:RefreshTarget(player)
end

function PlayerObservationController:PlayerAdded(player: Player): ()
	local previousMaid: Maid.Maid? = self.playerMaids[player]
	if previousMaid then
		previousMaid:DoCleaning()
	end

	local playerMaid: Maid.Maid = Maid.new()
	self.playerMaids[player] = playerMaid

	playerMaid:GiveTask(player.CharacterAdded:Connect(function(character: Model): ()
		self:ConnectCharacter(player, character)
	end))
	playerMaid:GiveTask(player.CharacterRemoving:Connect(function(): ()
		task.defer(self.RefreshTarget, self, player)
	end))

	if player.Character then
		self:ConnectCharacter(player, player.Character)
	end
end

function PlayerObservationController:PlayerRemoving(player: Player): ()
	self:SetSpectate(player, nil)

	for observer: Player, target: Player in self.spectates do
		if target == player then
			self:SetSpectate(observer, nil)
		end
	end

	local playerMaid: Maid.Maid? = self.playerMaids[player]
	if playerMaid then
		playerMaid:DoCleaning()
	end

	self.playerMaids[player] = nil
end

function PlayerObservationController:Init(): ()
	self.maid:DoCleaning()
	self.maid:GiveTask(function(): ()
		for player: Player in self.playerMaids do
			self:PlayerRemoving(player)
		end
	end)
end

return PlayerObservationController
