local Players = game:GetService("Players")

local PlayerGui = {}

function PlayerGui:Get(player: Player?): PlayerGui
	return (player or Players.LocalPlayer):FindFirstChildWhichIsA("PlayerGui")
end

function PlayerGui:GetChild(name: string, player: Player?): PlayerGui
	return self:Get(player):FindFirstChild(name)
end

function PlayerGui:Wait(player: Player?): PlayerGui
	return (player or Players.LocalPlayer):WaitForChild("PlayerGui")
end

function PlayerGui:WaitFor(name: string, player: Player?): PlayerGui
	return self:Wait(player):WaitForChild(name)
end

return PlayerGui
