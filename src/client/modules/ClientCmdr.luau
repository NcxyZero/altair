local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cmdr = require(ReplicatedStorage:WaitForChild("CmdrClient") :: any)
local GameConfig = require(ReplicatedStorage.shared.config.GameConfig)
local LocalPlayer = require(ReplicatedStorage.util.LocalPlayer)

local roleData: { groupId: number?, rank: number } = GameConfig.roles[GameConfig.cmdr.role]
local requiredGroup: number = roleData.groupId or game.CreatorType == Enum.CreatorType.Group and game.CreatorId or 0
local requiredRank: number = game.CreatorType == Enum.CreatorType.User and 0 or roleData.rank

Cmdr:SetActivationKeys(GameConfig.cmdr.activationKeys)
Cmdr:SetEnabled(LocalPlayer:GetRankInGroup(requiredGroup) >= requiredRank)

return table.freeze({})
