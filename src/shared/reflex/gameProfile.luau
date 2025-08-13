local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Reflex = require(ReplicatedStorage.package.Reflex)

export type Producer = Reflex.Producer<State, Actions>

export type State = {
	serverStartTime: number,
	activePlayers: number,
}

type Actions = {
	setActivePlayers: (count: number) -> (),
	incrementActivePlayers: () -> (),
	decrementActivePlayers: () -> (),
}

local DEFAULT_STATE: State = {
	serverStartTime = os.time(),
	activePlayers = 0,
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
	})

	return producer
end

return {
	CreateProducer = CreateProducer,
	DEFAULT_STATE = DEFAULT_STATE,
}
