return {
	Name = "SubtractMoney",
	Aliases = { "removemoney", "moneyremove", "subtractmoney", "moneysubtract" },
	Description = "Subtract money from player account.",
	Group = "Admin",
	Args = {
		{
			Name = "players",
			Type = "players",
			Description = "The players to subtract from",
		},
		{
			Name = "amount",
			Type = "number",
			Description = "Amount of money to subtract",
		},
	},
}
