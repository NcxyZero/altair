local SocialService = game:GetService("SocialService")

return function(sendingPlayer: Player): boolean
	local success: boolean, canSend: boolean = xpcall(function(): boolean
		return SocialService:CanSendGameInviteAsync(sendingPlayer)
	end, warn)

	return success and canSend
end
