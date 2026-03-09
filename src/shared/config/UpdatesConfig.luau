export type Update = {
	id: string,
	title: string,
	date: number,
	heading: string,
	description: string,
	image: string?,
}

export type UpdatesConfig = { Update }

local UpdatesConfig: UpdatesConfig = {
	{
		id = "Release",
		title = "Release",
		date = DateTime.fromUniversalTime(2026, 2, 9, 0, 0, 0).UnixTimestampMillis,
		heading = "🛠️ Changes",
		description = "\n🎉 Game Released! 🎉\n\n500,000+ things to get!\n\nEnjoy New Game 🥳",
		image = "rbxassetid://0",
	},
}

return UpdatesConfig
