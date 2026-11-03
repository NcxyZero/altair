return {
	Name = "toggleFreecam",
	Aliases = { "togglefreecam" },
	Description = "Toggle freecam for a player.",
	Group = "Admin",
	Args = {
		{
			Name = "player",
			Type = "player",
			Description = "Player to toggle freecam for. Defaults to you.",
			Optional = true,
		},
	},
}
