return function(instance: Instance): CFrame?
	return instance:IsA("BasePart") and instance.CFrame or instance:IsA("Model") and instance:GetPivot() or nil
end
