local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.shared.config.GameConfig)

local PlayerCollisions = {}
PlayerCollisions.type = "controller"

local function addToPlayerCollision(part: BasePart): ()
	if not part:IsA("BasePart") then
		return
	end

	pcall(function(): ()
		PhysicsService:RegisterCollisionGroup("Player")
		PhysicsService:CollisionGroupSetCollidable("Player", "Player", false)
	end)

	part.CollisionGroup = "Player"
end

local function setupCharacter(character: Model): ()
	for _index: number, descendant: Instance in ipairs(character:GetDescendants()) do
		if descendant:IsA("BasePart") then
			addToPlayerCollision(descendant)
		end
	end

	character.DescendantAdded:Connect(function(descendant: Instance): ()
		if descendant:IsA("BasePart") then
			addToPlayerCollision(descendant)
		end
	end)
end

function PlayerCollisions:Init(): ()
	--
end

function PlayerCollisions:PlayerAdded(player: Player): ()
	if not GameConfig.core.playerCollisionsDisabled then
		return
	end

	player.CharacterAdded:Connect(function(character: Model): ()
		character:WaitForChild("HumanoidRootPart")
		setupCharacter(character)
	end)

	if player.Character then
		setupCharacter(player.Character)
	end
end

return PlayerCollisions
