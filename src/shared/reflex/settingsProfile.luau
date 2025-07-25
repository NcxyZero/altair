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
	setMusicVolume: (volume: number) -> (),
	setSFXVolume: (volume: number) -> (),
	setUIScale: (scale: number) -> (),
	setGraphicsQuality: (quality: number) -> (),
	toggleFPS: () -> (),
	setShowFPS: (show: boolean) -> (),
	resetSettings: () -> (),
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
		setMusicVolume = function(state: State, volume: number): State
			state.musicVolume = math.clamp(volume, 0, 1)

			return state
		end,

		setSFXVolume = function(state: State, volume: number): State
			state.sfxVolume = math.clamp(volume, 0, 1)

			return state
		end,

		setUIScale = function(state: State, scale: number): State
			state.uiScale = math.clamp(scale, 0.5, 2)

			return state
		end,

		setGraphicsQuality = function(state: State, quality: number): State
			state.graphicsQuality = math.clamp(quality, 1, 10)

			return state
		end,

		toggleFPS = function(state: State): State
			state.showFPS = not state.showFPS

			return state
		end,

		setShowFPS = function(state: State, show: boolean): State
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
