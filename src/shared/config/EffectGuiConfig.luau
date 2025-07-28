export type EffectGuiConfig = {
	Fade: {
		TweenInfo: TweenInfo,
	},
}

local EffectGuiConfig: EffectGuiConfig = {
	Fade = {
		TweenInfo = TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
	},
}

return EffectGuiConfig
