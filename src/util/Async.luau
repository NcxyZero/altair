local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Promise = require(ReplicatedStorage.package.Promise)

local function async<T..., A...>(callback: (A...) -> T...): (A...) -> Promise.TypedPromise<any>
	return function(...: any): Promise.TypedPromise<any>
		local arguments: { any } = { ... }

		return Promise.new(function(resolve: (any) -> (), reject: (...any) -> ()): ()
			local success: boolean, data: any = pcall(function(): T...
				return callback(unpack(arguments))
			end)

			if success then
				resolve(data)
			else
				reject(data)
			end
		end)
	end
end

return async
