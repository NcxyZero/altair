return {
	Name = "disableFreecam",
	Aliases = { "disablefreecam" },
	Description = "Disable freecam for a player.",
	Group = "Admin",
	Args = {
		{
			Name = "player",
			Type = "player",
			Description = "Player to disable freecam for. Defaults to you.",
			Optional = true,
		},
	},
}
