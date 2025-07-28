export type Character = Model & {
	PrimaryPart: BasePart,
	Humanoid: Humanoid & {
		Animator: Animator,
	},
	Head: BasePart,
	HumanoidRootPart: BasePart,
}

return table.freeze({})
