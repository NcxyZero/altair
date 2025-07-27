local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Promise = require(ReplicatedStorage.package.Promise)
local Reflex = require(ReplicatedStorage.package.Reflex)

return function<State, Dispatchers, Comparison>(producer: Reflex.Producer<any, any>, getSlice: (state: State) -> Comparison): Promise.Promise
	return Promise.new(function(resolve: () -> ()): ()
		local unsubscribe: () -> ...any

		unsubscribe = producer:subscribe(getSlice, function(): ()
			unsubscribe()
			resolve()
		end)
	end)
end
