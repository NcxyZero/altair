export type EffectGuiConfig = {
	Fade: {
		TweenInfo: TweenInfo,
	},
	Select: {
		TweenInfo: TweenInfo,
	},
	MoneyPulse: {
		ExpandTweenInfo: TweenInfo,
		ReturnTweenInfo: TweenInfo,
		MaxScale: number,
	},
	Bounce: {
		TweenInfo: TweenInfo,
		Scale: number,
	},
	Flash: {
		TweenInfo: TweenInfo,
		GoalTransparency: number,
	},
}

local EffectGuiConfig: EffectGuiConfig = {
	Fade = {
		TweenInfo = TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
	},
	Select = {
		TweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
	},
	MoneyPulse = {
		ExpandTweenInfo = TweenInfo.new(0.08, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		ReturnTweenInfo = TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
		MaxScale = 1.18,
	},
	Bounce = {
		TweenInfo = TweenInfo.new(0.35, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out),
		Scale = 1.1,
	},
	Flash = {
		TweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
		GoalTransparency = 0.1,
	},
}

return EffectGuiConfig
