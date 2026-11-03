local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StatCommandDefinitions = require(ReplicatedStorage.shared.modules.StatCommandDefinitions)

return StatCommandDefinitions.Create("SetRebirths", { "setrebirth", "rebirthsset", "rebirthset" }, "Set", "rebirths")
