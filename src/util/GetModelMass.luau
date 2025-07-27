local function getModelMass(model: Model): number
	local mass: number = 0

	for _index: number, v: Instance in ipairs(model:GetDescendants()) do
		if v:IsA("BasePart") and not v.Massless then
			mass += v:GetMass()
		end
	end

	return mass
end

return getModelMass
