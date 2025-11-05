local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Logger = require(ReplicatedStorage.util.Logger)
local Maid = require(ReplicatedStorage.package.Maid)
local Promise = require(ReplicatedStorage.package.Promise)

local function secureCharacterAsync<T>(player: Player, ...: Promise.TypedPromise<T>): Promise.TypedPromise<T | any>
	local maid: Maid.Maid = Maid.new()

	local securePlayerPromise: Promise.TypedPromise<any> = Promise.new(
		function(_resolve: () -> (), reject: () -> ()): ()
			maid:GiveTask(player.CharacterRemoving:Connect(function(_model: Model): ()
				Logger.print(`Character removing!`)
				maid:DoCleaning()
				reject()
			end))
		end
	)

	return Promise.race({ securePlayerPromise, ... }):finallyCall(maid.DoCleaning, maid)
end

return secureCharacterAsync
