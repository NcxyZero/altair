local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Maid = require(ReplicatedStorage.package.Maid)

export type CameraNudge = {
	Nudge: (self: CameraNudge, amplitude: number?, fovDeltaDeg: number?) -> (),
	StartRef: (self: CameraNudge, maid: Maid.Maid?) -> () -> (),
	StopAll: (self: CameraNudge) -> (),
}

local CameraNudge: CameraNudge = {} :: any

local APPROACH_RATE: number = 10
local BIND_NAME: string = "CameraNudge_Offset"
local DEFAULT_AMPLITUDE: number = 0.004 * 2
local DEFAULT_FOV_DELTA_DEG: number = 0.6 * 2
local MAX_AMPLITUDE: number = 0.01 * 2
local MAX_FOV_DELTA_DEG: number = 2 * 2
local PITCH_RATIO: number = 0.6 * 2
local RETURN_DECAY: number = 1.5 * 2

local appliedFovDeltaDeg: number = 0
local appliedOffset: CFrame = CFrame.new()
local currentAngles: Vector2 = Vector2.zero
local currentFovDeltaDeg: number = 0
local maid: Maid.Maid = Maid.new()
local refCount: number = 0
local rng: Random = Random.new()
local running: boolean = false
local targetAngles: Vector2 = Vector2.zero
local targetFovDeltaDeg: number = 0

local function buildOffsetFromAngles(angles: Vector2): CFrame
	local pitchCFrame: CFrame = CFrame.fromAxisAngle(Vector3.xAxis, angles.X)
	local yawCFrame: CFrame = CFrame.fromAxisAngle(Vector3.yAxis, angles.Y)

	return pitchCFrame * yawCFrame
end

local function stepCamera(deltaTime: number): ()
	local camera: Camera? = workspace.CurrentCamera
	if not camera then
		return
	end

	local back: number = math.clamp(RETURN_DECAY * deltaTime, 0, 1)
	targetAngles = targetAngles * (1 - back)

	local approach: number = math.clamp(APPROACH_RATE * deltaTime, 0, 1)
	currentAngles = currentAngles + (targetAngles - currentAngles) * approach
	currentFovDeltaDeg += (targetFovDeltaDeg - currentFovDeltaDeg) * approach

	local offsetNow: CFrame = buildOffsetFromAngles(currentAngles)

	local base: CFrame = camera.CFrame * appliedOffset:Inverse()
	camera.CFrame = base * offsetNow
	appliedOffset = offsetNow

	local baseFov: number = camera.FieldOfView - appliedFovDeltaDeg
	local newFovDeltaDeg: number = currentFovDeltaDeg
	camera.FieldOfView = baseFov + newFovDeltaDeg
	appliedFovDeltaDeg = newFovDeltaDeg
end

local function ensureStarted(): ()
	if running then
		return
	end
	running = true

	local priority: number = Enum.RenderPriority.Camera.Value + 1
	RunService:BindToRenderStep(BIND_NAME, priority, function(deltaTime: number): ()
		stepCamera(deltaTime)
	end)

	maid:GiveTask(function(): ()
		if not running then
			return
		end
		running = false

		local camera: Camera? = workspace.CurrentCamera
		if camera then
			local base: CFrame = camera.CFrame * appliedOffset:Inverse()
			camera.CFrame = base

			local baseFov: number = camera.FieldOfView - appliedFovDeltaDeg
			camera.FieldOfView = baseFov
		end

		appliedOffset = CFrame.new()
		targetAngles = Vector2.zero
		currentAngles = Vector2.zero
		targetFovDeltaDeg = 0
		currentFovDeltaDeg = 0
		appliedFovDeltaDeg = 0

		RunService:UnbindFromRenderStep(BIND_NAME)
	end)
end

function CameraNudge:StartRef(attachMaid: Maid.Maid?): () -> ()
	refCount += 1
	if refCount == 1 then
		ensureStarted()
	end

	local released: boolean = false
	local function release(): ()
		if released then
			return
		end
		released = true

		refCount -= 1
		if refCount <= 0 then
			refCount = 0

			maid:DoCleaning()
		end
	end

	if attachMaid then
		attachMaid:GiveTask(release)
	end

	return release
end

function CameraNudge:StopAll(): ()
	refCount = 0

	maid:DoCleaning()
end

function CameraNudge:Nudge(amplitude: number?, fovDeltaDeg: number?): ()
	local amp: number = type(amplitude) == "number" and amplitude or DEFAULT_AMPLITUDE
	if amp > MAX_AMPLITUDE then
		amp = MAX_AMPLITUDE
	end
	if amp < 0 then
		amp = 0
	end

	local yaw: number = (rng:NextNumber() * 2 - 1) * amp
	local pitch: number = (rng:NextNumber() * 2 - 1) * (amp * PITCH_RATIO)

	targetAngles = Vector2.new(pitch, yaw)

	local fovAmpDeg: number = type(fovDeltaDeg) == "number" and fovDeltaDeg or DEFAULT_FOV_DELTA_DEG
	if fovAmpDeg > MAX_FOV_DELTA_DEG then
		fovAmpDeg = MAX_FOV_DELTA_DEG
	end
	if fovAmpDeg < 0 then
		fovAmpDeg = 0
	end

	targetFovDeltaDeg = -fovAmpDeg
end

return CameraNudge
