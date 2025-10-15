return {
	Name = "AddMoney",
	Aliases = { "addmoney", "moneyadd" },
	Description = "Add money to player account.",
	Group = "Admin",
	Args = {
		{
			Name = "players",
			Type = "players",
			Description = "The players to send to",
		},
		{
			Name = "amount",
			Type = "number",
			Description = "Amount of money to add",
		},
	},
}
