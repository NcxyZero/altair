local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Maid = require(ReplicatedStorage.package.Maid)
local Promise = require(ReplicatedStorage.package.Promise)

return function<T>(desiredTag: string, className: string): Promise.TypedPromise<T>
	return Promise.new(function(resolve: (T) -> (), _reject: () -> (), onCancel: ((() -> ())?) -> boolean): ()
		local taggedElements: { T } = CollectionService:GetTagged(desiredTag)

		if className then
			for _index: number, v: T in taggedElements do
				if (v :: T & Instance):IsA(className) then
					resolve(v)

					return
				end
			end

			local maid = Maid.new()
			onCancel(function(): ()
				maid:Destroy()
			end)

			maid:GiveTask(CollectionService:GetInstanceAddedSignal(desiredTag):Connect(function(v: T): ()
				if (v :: T & Instance):IsA(className) then
					maid:Destroy()
					resolve(v)

					return
				end
			end))
		else
			if taggedElements[1] then
				resolve(taggedElements[1] :: T)
				return
			end

			local maid = Maid.new()
			onCancel(function(): ()
				maid:Destroy()
			end)

			maid:GiveTask(CollectionService:GetInstanceAddedSignal(desiredTag):Connect(function(v: T): ()
				maid:Destroy()
				resolve(v :: T)
				return
			end))
		end
	end)
end
