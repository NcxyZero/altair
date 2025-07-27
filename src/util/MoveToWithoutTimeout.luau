local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Maid = require(ReplicatedStorage.package.Maid)
local Promise = require(ReplicatedStorage.package.Promise)

local function moveToWithoutTimeout(humanoid: Humanoid, targetPoint: Vector3): Promise.Promise
	return Promise.new(function(resolve: () -> ()): ()
		local targetReached: boolean = false
		local maid: Maid.Maid = Maid.new()

		maid:GiveTask(humanoid.MoveToFinished:Connect(function(_reached: boolean): ()
			targetReached = true

			maid:Destroy()
			resolve()
		end))

		humanoid:MoveTo(targetPoint)

		task.spawn(function(): ()
			while not targetReached do
				if not (humanoid and humanoid.Parent) then
					break
				end

				if humanoid.WalkToPoint ~= targetPoint then
					break
				end

				humanoid:MoveTo(targetPoint)
				task.wait(6)
			end

			maid:Destroy()
		end)
	end)
end

return moveToWithoutTimeout
