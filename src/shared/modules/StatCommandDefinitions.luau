export type CommandDefinition = {
	Aliases: { string },
	Args: { any },
	Description: string,
	Group: string,
	Name: string,
}

export type StatCommandDefinitions = {
	Create: (name: string, aliases: { string }, operation: string, statName: string) -> CommandDefinition,
}

local StatCommandDefinitions: StatCommandDefinitions = {} :: any

function StatCommandDefinitions.Create(
	name: string,
	aliases: { string },
	operation: string,
	statName: string
): CommandDefinition
	return {
		Name = name,
		Aliases = aliases,
		Description = `{operation} a player's {statName}.`,
		Group = "Admin",
		Args = {
			{
				Name = "players",
				Type = "players",
				Description = "Players whose persistent stat should be changed.",
			},
			{
				Name = "amount",
				Type = "nonNegativeInteger",
				Description = "Non-negative whole amount.",
			},
		},
	}
end

return StatCommandDefinitions
