export type Reward = {
	money: number,
	offerName: string?,
}

export type RedeemCodeConfig = {
	errorColor: Color3,
	rewards: { [string]: Reward },
	successColor: Color3,
}

-- keyed by uppercase code because input is upper-cased, for example EXAMPLE = { money = 100 }
local rewards: { [string]: Reward } = {}

local RedeemCodeConfig: RedeemCodeConfig = {
	errorColor = Color3.fromRGB(255, 110, 110),
	rewards = rewards,
	successColor = Color3.fromRGB(175, 255, 175),
}

return table.freeze(RedeemCodeConfig)
