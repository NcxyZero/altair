local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Reflex = require(ReplicatedStorage.package.Reflex)

export type Producer = Reflex.Producer<State, Actions>

export type State = {
	serverStartTime: number,
	activePlayers: number,
	focus: Player?,
	limitedItems: { [string]: number },
}

type Actions = {
	setActivePlayers: (count: number) -> State,
	incrementActivePlayers: () -> State,
	decrementActivePlayers: () -> State,
	secureFocusOn: (player: Player?) -> State,
	secureSetStock: (itemKey: string, amount: number) -> State,
}

local DEFAULT_STATE: State = {
	serverStartTime = os.time(),
	activePlayers = 0,
	focus = nil,
	limitedItems = {},
}

function CreateProducer(initialState: State): Producer
	local producer: Producer = Reflex.createProducer(initialState, {
		setActivePlayers = function(oldState: State, count: number): State
			local state = table.clone(oldState)

			state.activePlayers = count

			return state
		end,

		incrementActivePlayers = function(oldState: State): State
			local state = table.clone(oldState)

			state.activePlayers += 1

			return state
		end,

		decrementActivePlayers = function(oldState: State): State
			local state = table.clone(oldState)

			state.activePlayers = math.max(0, state.activePlayers - 1)

			return state
		end,

		secureFocusOn = function(oldState: State, player: Player?): State
			local state = table.clone(oldState)
			state.focus = player

			return state
		end,

		secureSetStock = function(oldState: State, itemKey: string, amount: number): State
			local limitedItems: { [string]: number } = table.clone(oldState.limitedItems)
			limitedItems[itemKey] = math.max(0, (tonumber(amount) or 0) // 1)

			local state: State = table.clone(oldState)
			state.limitedItems = limitedItems

			return state
		end,
	})

	return producer
end

return {
	CreateProducer = CreateProducer,
	DEFAULT_STATE = DEFAULT_STATE,
}
