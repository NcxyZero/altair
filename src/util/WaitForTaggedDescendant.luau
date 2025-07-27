local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Maid = require(ReplicatedStorage.package.Maid)
local Promise = require(ReplicatedStorage.package.Promise)

local function waitForTaggedDescendant<T>(
	ancestor: Instance,
	desiredTag: string,
	className: string?
): Promise.TypedPromise<T>
	return Promise.new(function(resolve: (T) -> (), _reject: () -> (), onCancel: ((() -> ())?) -> boolean): ()
		local taggedElements: { T } = CollectionService:GetTagged(desiredTag)

		if className then
			for _index: number, v: T in taggedElements do
				if (v :: T & Instance):IsA(className) and (v :: T & Instance):IsDescendantOf(ancestor) then
					resolve(v :: T)

					return
				end
			end

			local maid = Maid.new()
			onCancel(function(): ()
				maid:Destroy()
			end)

			maid:GiveTask(CollectionService:GetInstanceAddedSignal(desiredTag):Connect(function(v: T): ()
				if (v :: T & Instance):IsA(className) and (v :: T & Instance):IsDescendantOf(ancestor) then
					maid:Destroy()
					resolve(v :: T)

					return
				end
			end))
		else
			for _index: number, v: T in taggedElements do
				if (v :: T & Instance):IsDescendantOf(ancestor) then
					resolve(v :: T)

					return
				end
			end

			local maid = Maid.new()
			onCancel(function(): ()
				maid:Destroy()
			end)

			maid:GiveTask(CollectionService:GetInstanceAddedSignal(desiredTag):Connect(function(v: T): ()
				if not (v :: T & Instance):IsDescendantOf(ancestor) then
					return
				end
				maid:Destroy()
				resolve(v :: T)

				return
			end))
		end
	end)
end

return waitForTaggedDescendant
