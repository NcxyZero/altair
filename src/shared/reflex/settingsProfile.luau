local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Reflex = require(ReplicatedStorage.package.Reflex)

export type Producer = Reflex.Producer<State, Actions>

export type State = {
	musicVolume: number,
	sfxVolume: number,
	uiScale: number,
	graphicsQuality: number,
	showFPS: boolean,
}

type Actions = {
	setMusicVolume: (volume: number) -> State,
	setSFXVolume: (volume: number) -> State,
	setUIScale: (scale: number) -> State,
	setGraphicsQuality: (quality: number) -> State,
	toggleFPS: () -> State,
	setShowFPS: (show: boolean) -> State,
	resetSettings: () -> State,
}

local DEFAULT_STATE: State = {
	musicVolume = 0.5,
	sfxVolume = 0.5,
	uiScale = 1,
	graphicsQuality = 5,
	showFPS = false,
}

function CreateProducer(initialState: State): Producer
	local producer: Producer = Reflex.createProducer(initialState, {
		setMusicVolume = function(oldState: State, volume: number): State
			local state = table.clone(oldState)
			state.musicVolume = math.clamp(volume, 0, 1)

			return state
		end,

		setSFXVolume = function(oldState: State, volume: number): State
			local state = table.clone(oldState)

			state.sfxVolume = math.clamp(volume, 0, 1)

			return state
		end,

		setUIScale = function(oldState: State, scale: number): State
			local state = table.clone(oldState)

			state.uiScale = math.clamp(scale, 0.5, 2)

			return state
		end,

		setGraphicsQuality = function(oldState: State, quality: number): State
			local state = table.clone(oldState)

			state.graphicsQuality = math.clamp(quality, 1, 10)

			return state
		end,

		toggleFPS = function(oldState: State): State
			local state = table.clone(oldState)

			state.showFPS = not state.showFPS

			return state
		end,

		setShowFPS = function(oldState: State, show: boolean): State
			local state = table.clone(oldState)

			state.showFPS = show

			return state
		end,

		resetSettings = function(): State
			return table.clone(DEFAULT_STATE)
		end,
	})

	return producer
end

return {
	CreateProducer = CreateProducer,
	DEFAULT_STATE = DEFAULT_STATE,
}
