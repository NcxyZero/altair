return function(model: Model & { PrimaryPart: Instance & any }): ()
	for _index: number, basePart: any in model:GetDescendants() do
		if basePart ~= model.PrimaryPart and basePart:IsA("BasePart") and not basePart:FindFirstChild("Weld") then
			local weld = Instance.new("Weld")
			weld.Part0 = model.PrimaryPart
			weld.Part1 = basePart

			weld.C0 = model.PrimaryPart.CFrame:Inverse() * basePart.CFrame
			weld.C1 = CFrame.new()

			weld.Parent = basePart
			basePart.Anchored = false
		end
	end
end
