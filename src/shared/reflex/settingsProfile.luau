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
	local producer = Reflex.createProducer(initialState, {
		setMusicVolume = function(state, volume: number)
			state.musicVolume = math.clamp(volume, 0, 1)
			return state
		end,

		setSFXVolume = function(state, volume: number)
			state.sfxVolume = math.clamp(volume, 0, 1)
			return state
		end,

		setUIScale = function(state, scale: number)
			state.uiScale = math.clamp(scale, 0.5, 2)
			return state
		end,

		setGraphicsQuality = function(state, quality: number)
			state.graphicsQuality = math.clamp(quality, 1, 10)
			return state
		end,

		toggleFPS = function(state)
			state.showFPS = not state.showFPS
			return state
		end,

		setShowFPS = function(state, show: boolean)
			state.showFPS = show
			return state
		end,

		resetSettings = function()
			return table.clone(DEFAULT_STATE)
		end,
	}) :: Producer

	return producer
end

return {
	CreateProducer = CreateProducer,
	DEFAULT_STATE = DEFAULT_STATE,
}
