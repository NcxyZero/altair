local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Reflex = require(ReplicatedStorage.package.Reflex)

export type Producer = Reflex.Producer<State, Actions>

export type State = {
	serverStartTime: number,
	activePlayers: number,
	focus: Player?,
}

type Actions = {
	setActivePlayers: (count: number) -> (),
	incrementActivePlayers: () -> (),
	decrementActivePlayers: () -> (),
	secureFocusOn: (player: Player?) -> (),
}

local DEFAULT_STATE: State = {
	serverStartTime = os.time(),
	activePlayers = 0,
	focus = nil,
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

		secureFocusOn = function(oldState: State, player: Player?)
			local state = table.clone(oldState)
			state.focus = player

			return state
		end,
	})

	return producer
end

return {
	CreateProducer = CreateProducer,
	DEFAULT_STATE = DEFAULT_STATE,
}
