local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Logger = require(ReplicatedStorage.util.Logger)

local MonetizationExecs = {
	offers = {
		Offer1 = function(): ()
			Logger.print("Offer1 executed")
		end,
	},
	execs = {
		Exec1 = function(): ()
			Logger.print("Exec1 executed")
		end,
	},
}

return MonetizationExecs
