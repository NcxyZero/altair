type promptData = {
	ActionText: string?,
	HoldDuration: number?,
	KeyboardKeyCode: Enum.KeyCode?,
	MaxActivationDistance: number?,
	ObjectText: string?,
	RequiresLineOfSight: boolean?,

	Triggered: () -> (),
}

return function(instance: Instance, data: promptData): ProximityPrompt
	local prompt: ProximityPrompt = Instance.new("ProximityPrompt")
	prompt.ActionText = data.ActionText or ""
	prompt.HoldDuration = data.HoldDuration or 0
	prompt.KeyboardKeyCode = data.KeyboardKeyCode or Enum.KeyCode.E
	prompt.MaxActivationDistance = data.MaxActivationDistance or 10
	prompt.ObjectText = data.ObjectText or ""
	prompt.RequiresLineOfSight = data.RequiresLineOfSight or false
	prompt.Parent = instance

	prompt.Triggered:Connect(data.Triggered)

	return prompt
end
