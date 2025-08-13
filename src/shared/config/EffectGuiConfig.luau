export type EffectGuiConfig = {
	Fade: {
		TweenInfo: TweenInfo,
	},
	Select: {
		TweenInfo: TweenInfo,
	},
}

local EffectGuiConfig: EffectGuiConfig = {
	Fade = {
		TweenInfo = TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
	},
	Select = {
		TweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
	},
}

return EffectGuiConfig
