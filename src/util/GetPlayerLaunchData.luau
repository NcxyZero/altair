local HttpService = game:GetService("HttpService")

return function(player: Player, attemptLimit: number?, retryDelay: number?): string?
	attemptLimit = attemptLimit or 10
	retryDelay = retryDelay or 1

	local launchData: string?

	for _index = 1, attemptLimit :: number do
		task.wait(retryDelay)

		local joinData = player:GetJoinData()

		if joinData.LaunchData ~= "" then
			launchData = joinData.LaunchData

			break
		end
	end

	if launchData then
		return HttpService:JSONDecode(launchData)
	end

	return
end
