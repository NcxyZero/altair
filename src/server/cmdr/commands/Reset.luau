return {
	Name = "Reset",
	Aliases = { "reset" },
	Description = "reset player data",
	Group = "Admin",
	Args = {
		{
			Name = "players",
			Type = "players",
			Description = "Players to reset",
		},
	},
}
