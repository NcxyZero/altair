local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StatCommandDefinitions = require(ReplicatedStorage.shared.modules.StatCommandDefinitions)

return StatCommandDefinitions.Create("AddRebirths", { "addrebirth", "rebirthsadd", "rebirthadd" }, "Add", "rebirths")
