return {
	Name = "notify",
	Aliases = { "ntf", "notif" },
	Description = "Sending a message as notification",
	Group = "Admin",
	Args = {
		{
			Name = "players",
			Type = "players",
			Description = "The players to send to",
		},
		{
			Name = "message",
			Type = "string",
			Description = "The message to send",
		},
		{
			Name = "duration",
			Type = "number",
			Description = "Duration in seconds of the notification. Defaults to 5 seconds",
			Optional = true,
		},
		{
			Name = "color",
			Type = "string",
			Description = "Optional color (name like 'red' or hex like #RRGGBB)",
			Optional = true,
		},
	},
}
