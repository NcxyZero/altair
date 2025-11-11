return function(instance: Instance, cFrame: CFrame): ()
	if instance:IsA("BasePart") then
		instance.CFrame = cFrame
	elseif instance:IsA("Model") then
		instance:PivotTo(cFrame)
	end
end
