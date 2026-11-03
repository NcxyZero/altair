local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ClientActionRegistry = require(ReplicatedStorage.shared.reflex.ClientActionRegistry)
local Reflex = require(ReplicatedStorage.package.Reflex)

export type Producer = Reflex.Producer<State, Actions>

export type State = {
	clickRippleEnabled: boolean,
	hideOtherPlayers: boolean,
	mapDetailsEnabled: boolean,
	musicVolume: number,
	sfxVolume: number,
	shadowsEnabled: boolean,
	uiScale: number,
	graphicsQuality: number,
	showFPS: boolean,
}

type Actions = {
	setClickRippleEnabled: (enabled: boolean) -> State,
	setHideOtherPlayers: (enabled: boolean) -> State,
	setMapDetailsEnabled: (enabled: boolean) -> State,
	setMusicVolume: (volume: number) -> State,
	setSFXVolume: (volume: number) -> State,
	setShadowsEnabled: (enabled: boolean) -> State,
	setUIScale: (scale: number) -> State,
	setGraphicsQuality: (quality: number) -> State,
	toggleFPS: () -> State,
	setShowFPS: (show: boolean) -> State,
	resetSettings: () -> State,
}

local CLIENT_ACTIONS: { [string]: ClientActionRegistry.Validator } = {
	resetSettings = ClientActionRegistry.NoArguments,
	setClickRippleEnabled = ClientActionRegistry.BooleanArguments,
	setGraphicsQuality = ClientActionRegistry.NumberArguments(1, 10),
	setHideOtherPlayers = ClientActionRegistry.BooleanArguments,
	setMapDetailsEnabled = ClientActionRegistry.BooleanArguments,
	setMusicVolume = ClientActionRegistry.NumberArguments(0, 1),
	setSFXVolume = ClientActionRegistry.NumberArguments(0, 1),
	setShadowsEnabled = ClientActionRegistry.BooleanArguments,
	setShowFPS = ClientActionRegistry.BooleanArguments,
	setUIScale = ClientActionRegistry.NumberArguments(0.5, 2),
}

local DEFAULT_STATE: State = {
	clickRippleEnabled = true,
	hideOtherPlayers = false,
	mapDetailsEnabled = true,
	musicVolume = 0.5,
	sfxVolume = 0.5,
	shadowsEnabled = true,
	uiScale = 1,
	graphicsQuality = 5,
	showFPS = false,
}

function CreateProducer(initialState: State): Producer
	local producer: Producer = Reflex.createProducer(initialState, {
		setClickRippleEnabled = function(oldState: State, enabled: boolean): State
			local state: State = table.clone(oldState)
			state.clickRippleEnabled = enabled == true

			return state
		end,

		setHideOtherPlayers = function(oldState: State, enabled: boolean): State
			local state: State = table.clone(oldState)
			state.hideOtherPlayers = enabled == true

			return state
		end,

		setMapDetailsEnabled = function(oldState: State, enabled: boolean): State
			local state: State = table.clone(oldState)
			state.mapDetailsEnabled = enabled == true

			return state
		end,

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

		setShadowsEnabled = function(oldState: State, enabled: boolean): State
			local state: State = table.clone(oldState)
			state.shadowsEnabled = enabled == true

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
	CLIENT_ACTIONS = CLIENT_ACTIONS,
	CreateProducer = CreateProducer,
	DEFAULT_STATE = DEFAULT_STATE,
}
