type promptData = {
	ActionText: string?,
	HoldDuration: number?,
	KeyboardKeyCode: Enum.KeyCode?,
	MaxActivationDistance: number?,
	ObjectText: string?,
	RequiresLineOfSight: boolean?,
	Triggered: (() -> ())?,
}?

return function(instance: Instance, data: promptData): ProximityPrompt
	local prompt: ProximityPrompt = Instance.new("ProximityPrompt")
	prompt.ActionText = data and data.ActionText or ""
	prompt.HoldDuration = data and data.HoldDuration or 0
	prompt.KeyboardKeyCode = data and data.KeyboardKeyCode or Enum.KeyCode.E
	prompt.MaxActivationDistance = data and data.MaxActivationDistance or 10
	prompt.ObjectText = data and data.ObjectText or ""
	prompt.RequiresLineOfSight = data and data.RequiresLineOfSight or false
	prompt.Parent = instance

	if data then
		prompt.Triggered:Connect(data and data.Triggered)
	end

	return prompt
end
