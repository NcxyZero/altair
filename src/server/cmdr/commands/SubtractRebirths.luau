local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StatCommandDefinitions = require(ReplicatedStorage.shared.modules.StatCommandDefinitions)

return StatCommandDefinitions.Create("SubtractRebirths", {
	"subtractrebirths",
	"subtractrebirth",
	"substractrebirths",
	"substractrebirth",
	"removerebirths",
	"removerebirth",
	"rebirthssubtract",
	"rebirthssubstract",
}, "Subtract", "rebirths")
