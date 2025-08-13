local CalculateTargetMass = {}

function CalculateTargetMass.SetPartMass(part, targetMass)
	if not part:IsA("BasePart") then
		error("The provided instance is not a BasePart")
	end

	local volume = part.Mass
	local requiredDensity = targetMass / volume

	part.CustomPhysicalProperties = PhysicalProperties.new(
		requiredDensity,
		part.CustomPhysicalProperties.Friction,
		part.CustomPhysicalProperties.Elasticity,
		part.CustomPhysicalProperties.FrictionWeight,
		part.CustomPhysicalProperties.ElasticityWeight
	)
end

function CalculateTargetMass.SetModelMass(model, targetMass)
	local totalVolume = 0
	local parts = {}

	-- Calculate the total volume of all parts in the model
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			totalVolume += part.Mass
			table.insert(parts, part)
		end
	end

	-- Calculate the required density to achieve the target mass
	local requiredDensity = targetMass / totalVolume

	-- Set the CustomPhysicalProperties for each part to achieve the target mass
	for _, part in ipairs(parts) do
		part.CustomPhysicalProperties = PhysicalProperties.new(
			requiredDensity,
			part.CustomPhysicalProperties.Friction,
			part.CustomPhysicalProperties.Elasticity,
			part.CustomPhysicalProperties.FrictionWeight,
			part.CustomPhysicalProperties.ElasticityWeight
		)
	end
end

return CalculateTargetMass
