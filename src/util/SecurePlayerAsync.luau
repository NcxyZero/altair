local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Logger = require(ReplicatedStorage.util.Logger)
local Maid = require(ReplicatedStorage.package.Maid)
local Promise = require(ReplicatedStorage.package.Promise)

local function securePlayerAsync<T>(player: Player, ...: Promise.TypedPromise<T>): Promise.TypedPromise<T | any>
	if not player then
		return Promise.reject("SecurePlayerAsync - Player is nil! Rejecting...")
	end

	local maid: Maid.Maid = Maid.new()

	local securePlayerPromise: Promise.TypedPromise<any> = Promise.new(
		function(_resolve: () -> (), reject: () -> ()): ()
			maid:GiveTask(Players.PlayerRemoving:Connect(function(leavingPlayer: Player): ()
				if leavingPlayer == player then
					Logger.print(`Player {player.Name} left!`)
					maid:DoCleaning()
					reject()
				end
			end))
		end
	)

	return Promise.race({ securePlayerPromise, ... }):finallyCall(maid.DoCleaning, maid)
end

return securePlayerAsync
