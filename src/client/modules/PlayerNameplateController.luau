local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local InitializerTypes = require(ReplicatedStorage.shared.types.InitializerTypes)
local Logger = require(ReplicatedStorage.util.Logger)
local Maid = require(ReplicatedStorage.package.Maid)

export type Default = {
	index: number?,
	type: string?,
	path: InitializerTypes.ClientPath,
	Init: (self: Default) -> (),
}

local PlayerNameplateController: Default = {} :: Default
PlayerNameplateController.type = "controller"

local template: BillboardGui? = ReplicatedStorage.shared.model:WaitForChild("PlayerBGUI", 5)
local maidByPlayer: { [Player]: Maid.Maid } = {}

local function updateName(player: Player, label: TextLabel?): ()
	if not label then
		return
	end

	label.Text = player.DisplayName
end

local function updateLevel(player: Player, label: TextLabel?): ()
	if not label then
		return
	end

	local levelAny: any = player:GetAttribute("Level")
	local level: number = type(levelAny) == "number" and levelAny or 1

	label.Text = `Lvl {math.max(1, math.floor(level))}`
end

local function attachNameplate(player: Player, character: Model, maid: Maid.Maid): ()
	local humanoidRootPart: BasePart? = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoidRootPart then
		local humanoidRootPartAny: Instance? = character:WaitForChild("HumanoidRootPart", 10)
		if humanoidRootPartAny and humanoidRootPartAny:IsA("BasePart") then
			humanoidRootPart = humanoidRootPartAny
		end
	end
	if not humanoidRootPart then
		return
	end

	local existing: BillboardGui? = humanoidRootPart:FindFirstChild("PlayerBGUI") :: BillboardGui?
	if existing and existing:IsA("BillboardGui") then
		existing:Destroy()
	end

	local nameplate: BillboardGui = template and template:Clone()
	nameplate.Name = "PlayerBGUI"
	nameplate.Adornee = humanoidRootPart
	nameplate.Parent = humanoidRootPart

	maid:GiveTask(function(): ()
		if nameplate and nameplate.Parent then
			nameplate:Destroy()
		end
	end)

	local nameLabel: TextLabel? = nameplate:FindFirstChild("PlayerName") :: TextLabel?
	local levelLabel: TextLabel? = nameplate:FindFirstChild("Level") :: TextLabel?

	updateName(player, nameLabel)
	updateLevel(player, levelLabel)

	maid:GiveTask(player:GetAttributeChangedSignal("Level"):Connect(function(): ()
		updateLevel(player, levelLabel)
	end))

	maid:GiveTask(player:GetPropertyChangedSignal("DisplayName"):Connect(function(): ()
		updateName(player, nameLabel)
	end))
end

local function hookPlayer(player: Player): ()
	if maidByPlayer[player] then
		maidByPlayer[player]:DoCleaning()
	end

	local maid: Maid.Maid = Maid.new()
	maidByPlayer[player] = maid
	local characterMaid: Maid.Maid

	local function onCharacterAdded(character: Model): ()
		if characterMaid then
			characterMaid:DoCleaning()
		end
		characterMaid = Maid.new()

		maid:GiveTask(characterMaid)
		attachNameplate(player, character, characterMaid)
	end

	maid:GiveTask(player.CharacterAdded:Connect(onCharacterAdded))

	if player.Character then
		onCharacterAdded(player.Character)
	end
end

function PlayerNameplateController:Init(): ()
	if not template then
		Logger.print("Failed to find PlayerBGUI template, nameplates will not be created")

		return
	end

	Players.PlayerAdded:Connect(hookPlayer)

	Players.PlayerRemoving:Connect(function(player: Player): ()
		local maid: Maid.Maid? = maidByPlayer[player]
		if maid then
			maid:DoCleaning()
			maidByPlayer[player] = nil
		end
	end)

	for _index: number, player: Player in Players:GetPlayers() do
		hookPlayer(player)
	end
end

return PlayerNameplateController
