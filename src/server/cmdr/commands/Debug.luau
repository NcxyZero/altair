return {
	Name = "debug",
	Aliases = { "deb" },
	Description = "Sending a message in output.",
	Group = "Admin",
	Args = {
		{
			Name = "message",
			Type = "string",
			Description = "The message to send.",
			Optional = true,
		},
	},
}
