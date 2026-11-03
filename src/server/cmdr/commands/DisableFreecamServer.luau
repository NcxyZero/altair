return function(context: any, player: Player?): string
	local target: Player = player or context.Executor

	target:SetAttribute("FreecamEnabled", false)

	return `Disabled freecam for {target.Name}`
end
