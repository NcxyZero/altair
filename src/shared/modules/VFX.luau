local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CalculateTargetMass = require(ReplicatedStorage.util.CalculateTargetMass)

local VFX = {}

function VFX:ImpactBasePartFromPosition(
	basePart: BasePart,
	position: Vector3,
	HowMany: number,
	ClearFunction: ((BasePart) -> ())?,
	randomPartSize: boolean?
)
	local CreatedModels: { BasePart } = {}
	for _index = 1, HowMany do
		local RandomX = math.random(-30, 30)
		local RandomZ = math.random(-30, 30)

		local MovabelPart = basePart:Clone()
		MovabelPart.CollisionGroup = "NPC"
		MovabelPart.Size = randomPartSize
				and basePart.Size * Vector3.new(
					math.random(10, 30) / 10,
					math.random(10, 30) / 10,
					math.random(10, 30) / 10
				)
			or basePart.Size
		CalculateTargetMass.SetPartMass(MovabelPart, 3)

		MovabelPart.CFrame = CFrame.new(position) * CFrame.new(0, 1, 0)
		MovabelPart.Parent = workspace
		table.insert(CreatedModels, MovabelPart)

		MovabelPart:ApplyImpulse(Vector3.new(RandomX, math.random(60, 80), RandomZ))
		if ClearFunction then
			task.spawn(function(): ()
				ClearFunction(MovabelPart)
			end)
		end
	end

	return CreatedModels
end

function VFX:ShakeModel(model: Model, roughness: number, duration: number): ()
	local originalCFrame: CFrame = model:GetPivot()
	local elapsed: number = 0
	local heartbeatConn: RBXScriptConnection

	heartbeatConn = game:GetService("RunService").Heartbeat:Connect(function(dt: number): ()
		elapsed += dt
		if elapsed > duration then
			heartbeatConn:Disconnect()
			model:PivotTo(originalCFrame)
			return
		end
		local offset = Vector3.new(
			(math.random() - 0.5) * 2 * roughness,
			(math.random() - 0.5) * 2 * roughness,
			(math.random() - 0.5) * 2 * roughness
		)
		model:PivotTo(originalCFrame * CFrame.new(offset))
	end)
end

return VFX
