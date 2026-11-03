local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.shared.config.GameConfig)
local InitializerTypes = require(ReplicatedStorage.shared.types.InitializerTypes)
local Maid = require(ReplicatedStorage.package.Maid)

export type BillboardVisibilityController = {
	Apply: (self: BillboardVisibilityController, instance: Instance) -> (),
	Destroy: (self: BillboardVisibilityController) -> (),
	Init: (self: BillboardVisibilityController) -> (),
	path: InitializerTypes.ClientPath,
	type: string,
	maid: Maid.Maid,
}

local BillboardVisibilityController: BillboardVisibilityController = {} :: any
BillboardVisibilityController.type = "controller"
BillboardVisibilityController.maid = Maid.new()

local BASE_DISTANCE_ATTRIBUTE: string = "VisibilityBaseMaxDistance" -- authored MaxDistance, keeps reapplying idempotent
local CONFIGURED_ATTRIBUTE: string = "VisibilityDistanceConfigured" -- opts a billboard out of the multiplier

-- MaxDistance multipliers, by CollectionService tag of a billboard ancestor
local CONFIG: typeof(GameConfig.ui.billboardVisibility) = GameConfig.ui.billboardVisibility

local function getMultiplier(instance: Instance): number
	local ancestor: Instance? = instance.Parent
	while ancestor do
		for _index: number, tag: string in ancestor:GetTags() do
			local multiplier: number? = CONFIG.tagMultipliers[tag]
			if multiplier then
				return multiplier
			end
		end

		ancestor = ancestor.Parent
	end

	return CONFIG.defaultMultiplier
end

function BillboardVisibilityController:Apply(instance: Instance): ()
	if not instance:IsA("BillboardGui") or instance:GetAttribute(CONFIGURED_ATTRIBUTE) then
		return
	end

	local baseDistance: any = instance:GetAttribute(BASE_DISTANCE_ATTRIBUTE)
	if type(baseDistance) ~= "number" then
		baseDistance = instance.MaxDistance

		instance:SetAttribute(BASE_DISTANCE_ATTRIBUTE, baseDistance)
	end

	if baseDistance ~= baseDistance or baseDistance <= 0 or baseDistance == math.huge then
		return
	end

	instance.MaxDistance = baseDistance * getMultiplier(instance)
end

function BillboardVisibilityController:Init(): ()
	self.maid:DoCleaning()

	-- a neutral config changes no billboard, so skip watching every Workspace descendant
	if CONFIG.defaultMultiplier == 1 and not next(CONFIG.tagMultipliers) then
		return
	end

	local playerGui: PlayerGui = Players.LocalPlayer:WaitForChild("PlayerGui") :: PlayerGui
	for _index: number, root: Instance in { workspace, playerGui } do
		self.maid:GiveTask(root.DescendantAdded:Connect(function(instance: Instance): ()
			self:Apply(instance)
		end))

		for _descendantIndex: number, instance: Instance in root:GetDescendants() do
			self:Apply(instance)
		end
	end
end

function BillboardVisibilityController:Destroy(): ()
	self.maid:DoCleaning()
end

return BillboardVisibilityController
