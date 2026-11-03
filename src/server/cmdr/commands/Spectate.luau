return {
	Name = "spectate",
	Description = "Follow a player's character with your camera. Hide UI unless keepHUD is true.",
	Group = "Admin",
	Args = {
		{
			Name = "player",
			Type = "player",
			Description = "Player for the camera to follow. Select yourself to restore your camera.",
		},
		{
			Name = "keepHUD",
			Type = "boolean",
			Description = "Keep UI visible while spectating. Defaults to false.",
			Optional = true,
		},
	},
}
