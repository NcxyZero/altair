local SocialService = game:GetService("SocialService")

return function(sendingPlayer: Player): boolean
	local success, canSend = pcall(function(): boolean
		return SocialService:CanSendGameInviteAsync(sendingPlayer)
	end)

	return success and canSend
end
