local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local InitializerTypes = require(ReplicatedStorage.shared.types.InitializerTypes)
local Logger = require(ReplicatedStorage.util.Core.Logger)
local Maid = require(ReplicatedStorage.package.Maid)

export type BillboardDistanceAnimation = {
	ApplyScale: (self: BillboardDistanceAnimation, scale: number) -> (),
	Destroy: (self: BillboardDistanceAnimation) -> (),
	Update: (self: BillboardDistanceAnimation, cameraPosition: Vector3) -> (),
	new: (instance: Instance, path: InitializerTypes.ClientPath) -> BillboardDistanceAnimation?,
	__index: BillboardDistanceAnimation,
	baseSize: UDim2,
	currentScale: number,
	path: InitializerTypes.ClientPath,
	tag: string,
	type: string,
	billboardGui: BillboardGui,
	guiObject: GuiObject,
	maid: Maid.Maid,
}

local BillboardDistanceAnimation: BillboardDistanceAnimation = {} :: any
BillboardDistanceAnimation.__index = BillboardDistanceAnimation
BillboardDistanceAnimation.tag = script.Name
BillboardDistanceAnimation.type = "tag"

local DEFAULT_TRANSITION_FRACTION: number = 0.2 -- portion of MaxDistance used to scale the billboard in and out
local MAXIMUM_TRANSITION_DISTANCE: number = 12 -- prevents large MaxDistance values from producing very long transitions
local MINIMUM_TRANSITION_DISTANCE: number = 5 -- keeps the transition visible on ordinary stand billboards
local REQUIRED_INSTANCE_POLL_INTERVAL: number = 0.05
local REQUIRED_INSTANCE_WAIT_TIMEOUT: number = 5
local SCALE_EPSILON: number = 0.001
local ACTIVE: { [BillboardDistanceAnimation]: boolean } = {}

local updateConnection: RBXScriptConnection?

local function getInstancePosition(instance: Instance?): Vector3?
	if not instance then
		return
	end

	if instance:IsA("Attachment") then
		return instance.WorldPosition
	end

	if instance:IsA("BasePart") then
		return instance.Position
	end

	if instance:IsA("Model") then
		return instance:GetPivot().Position
	end

	return
end

local function findGuiObject(instance: Instance): GuiObject?
	local guiObject: GuiObject = instance:FindFirstChild("Frame") :: any
	if not guiObject or not guiObject:IsA("GuiObject") then
		guiObject = instance:FindFirstChildWhichIsA("GuiObject") :: any
	end

	return guiObject
end

local function waitForGuiObject(instance: Instance): GuiObject?
	local deadline: number = os.clock() + REQUIRED_INSTANCE_WAIT_TIMEOUT
	local hasEnteredDataModel: boolean = instance:IsDescendantOf(game)
	local guiObject: GuiObject? = findGuiObject(instance)
	while not guiObject do
		if not CollectionService:HasTag(instance, BillboardDistanceAnimation.tag) then
			return
		end

		local isInDataModel: boolean = instance:IsDescendantOf(game)
		if hasEnteredDataModel and not isInDataModel then
			return
		end
		if not hasEnteredDataModel and isInDataModel then
			hasEnteredDataModel = true
			deadline = os.clock() + REQUIRED_INSTANCE_WAIT_TIMEOUT
		end
		if not hasEnteredDataModel and os.clock() >= deadline then
			return
		end
		if hasEnteredDataModel and not workspace.StreamingEnabled and os.clock() >= deadline then
			return
		end

		task.wait(REQUIRED_INSTANCE_POLL_INTERVAL)
		guiObject = findGuiObject(instance)
	end

	return guiObject
end

local function getBillboardPosition(billboardGui: BillboardGui): Vector3?
	local adorneePosition: Vector3? = getInstancePosition(billboardGui.Adornee)
	if adorneePosition then
		return adorneePosition
	end

	local parentPosition: Vector3? = getInstancePosition(billboardGui.Parent)
	if parentPosition then
		return parentPosition
	end

	local ancestorPart: BasePart? = billboardGui:FindFirstAncestorWhichIsA("BasePart")

	return ancestorPart and ancestorPart.Position or nil
end

local function getTransitionDistance(billboardGui: BillboardGui, maxDistance: number): number
	local attributeValue: unknown = billboardGui:GetAttribute("DistanceAnimationRange")
	if
		type(attributeValue) == "number"
		and attributeValue == attributeValue
		and math.abs(attributeValue) ~= math.huge
	then
		return math.clamp(attributeValue, 0, maxDistance)
	end

	local defaultDistance: number =
		math.clamp(maxDistance * DEFAULT_TRANSITION_FRACTION, MINIMUM_TRANSITION_DISTANCE, MAXIMUM_TRANSITION_DISTANCE)

	return math.min(defaultDistance, maxDistance)
end

local function getScale(distance: number, maxDistance: number, transitionDistance: number): number
	if maxDistance <= 0 then
		return 1
	end

	if transitionDistance <= 0 then
		return distance < maxDistance and 1 or 0
	end

	local alpha: number = math.clamp((maxDistance - distance) / transitionDistance, 0, 1)

	return alpha * alpha * (3 - (2 * alpha))
end

local function scaleSize(size: UDim2, scale: number): UDim2
	return UDim2.new(size.X.Scale * scale, size.X.Offset * scale, size.Y.Scale * scale, size.Y.Offset * scale)
end

local function stopUpdateLoopIfEmpty(): ()
	if not updateConnection or next(ACTIVE) then
		return
	end

	updateConnection:Disconnect()
	updateConnection = nil
end

local function ensureUpdateLoop(): ()
	if updateConnection then
		return
	end

	updateConnection = RunService.PreRender:Connect(function(): ()
		local camera: Camera? = workspace.CurrentCamera
		if not camera then
			return
		end

		local cameraPosition: Vector3 = camera.CFrame.Position
		-- the cast avoids a Luau false positive when the typed keys of ACTIVE are iterated
		for tracked: BillboardDistanceAnimation in ACTIVE :: any do
			tracked:Update(cameraPosition)
		end
	end)
end

function BillboardDistanceAnimation.new(
	instance: Instance,
	path: InitializerTypes.ClientPath
): BillboardDistanceAnimation?
	if not instance:IsA("BillboardGui") then
		Logger.warn(`BillboardDistanceAnimation tag requires a BillboardGui, got {instance:GetFullName()}`)

		return
	end

	-- skips billboards untagged while waitForGuiObject yielded, since nothing would destroy them
	local guiObject: GuiObject = waitForGuiObject(instance) :: any
	local isTracked: boolean = instance:IsDescendantOf(game)
		and CollectionService:HasTag(instance, BillboardDistanceAnimation.tag)
	if not isTracked then
		return
	end

	if not guiObject then
		Logger.warn(`BillboardDistanceAnimation requires a GuiObject child: {instance:GetFullName()}`)

		return
	end

	local self: BillboardDistanceAnimation = setmetatable({}, BillboardDistanceAnimation) :: any
	self.baseSize = guiObject.Size
	self.billboardGui = instance
	self.currentScale = -1
	self.guiObject = guiObject
	self.maid = Maid.new()
	self.path = path

	ACTIVE[self] = true
	ensureUpdateLoop()

	local camera: Camera? = workspace.CurrentCamera
	if camera then
		self:Update(camera.CFrame.Position)
	else
		self:ApplyScale(1)
	end

	return self
end

function BillboardDistanceAnimation:ApplyScale(scale: number): ()
	local normalizedScale: number = math.clamp(scale, 0, 1)
	if math.abs(normalizedScale - self.currentScale) <= SCALE_EPSILON then
		return
	end

	self.currentScale = normalizedScale
	self.guiObject.Size = scaleSize(self.baseSize, normalizedScale)
end

function BillboardDistanceAnimation:Update(cameraPosition: Vector3): ()
	local adornee: Instance? = self.billboardGui.Adornee
	if not self.billboardGui:IsDescendantOf(workspace) and not (adornee and adornee:IsDescendantOf(workspace)) then
		self:ApplyScale(1)

		return
	end

	local billboardPosition: Vector3? = getBillboardPosition(self.billboardGui)
	if not billboardPosition then
		self:ApplyScale(1)

		return
	end

	local maxDistance: number = math.max(self.billboardGui.MaxDistance, 0)
	local transitionDistance: number = getTransitionDistance(self.billboardGui, maxDistance)
	local distance: number = (cameraPosition - billboardPosition).Magnitude

	self:ApplyScale(getScale(distance, maxDistance, transitionDistance))
end

function BillboardDistanceAnimation:Destroy(): ()
	ACTIVE[self] = nil
	self:ApplyScale(1)
	self.maid:DoCleaning()

	stopUpdateLoopIfEmpty()
end

return BillboardDistanceAnimation
