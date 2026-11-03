return function(context: any, player: Player?): string
	local target: Player = player or context.Executor
	local enabled: boolean = target:GetAttribute("FreecamEnabled") == true

	target:SetAttribute("FreecamEnabled", not enabled)

	return `{if enabled then "Disabled" else "Enabled"} freecam for {target.Name}`
end
