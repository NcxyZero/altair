return function(context: any, player: Player?): string
	local target: Player = player or context.Executor

	target:SetAttribute("FreecamEnabled", true)

	return `Enabled freecam for {target.Name}`
end
