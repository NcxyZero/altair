local Players = game:GetService("Players")

return function(text: string): string
	text = text:gsub("@userId", Players.LocalPlayer.UserId)
	text = text:gsub("@username", Players.LocalPlayer.Name)
	text = text:gsub("@displayname", Players.LocalPlayer.DisplayName)

	return text
end
