return {
	Name = "enableFreecam",
	Aliases = { "enablefreecam" },
	Description = "Enable freecam for a player.",
	Group = "Admin",
	Args = {
		{
			Name = "player",
			Type = "player",
			Description = "Player to enable freecam for. Defaults to you.",
			Optional = true,
		},
	},
}
