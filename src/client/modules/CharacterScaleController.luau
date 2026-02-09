local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GetBridge = require(ReplicatedStorage.util.GetBridge)
local Logger = require(ReplicatedStorage.util.Logger)
local Maid = require(ReplicatedStorage.package.Maid)

export type CharacterScaleController = {
	type: string,
	maid: Maid.Maid,
	lastDesiredScale: number?,
	scheduled: boolean,
	pendingDesiredScale: number?,
	Init: (self: CharacterScaleController) -> (),
}

local CharacterScaleController: CharacterScaleController = {} :: any
CharacterScaleController.type = "controller"
CharacterScaleController.maid = Maid.new()
CharacterScaleController.lastDesiredScale = nil
CharacterScaleController.scheduled = false
CharacterScaleController.pendingDesiredScale = nil

local function approxEqual(a: number, b: number): boolean
	return math.abs(a - b) < 1e-3
end

local function applyScale(desiredScale: number): ()
	local player: Player? = Players.LocalPlayer
	if not player then
		return
	end

	local character: Model? = player.Character
	if not character then
		return
	end

	xpcall(function(): ()
		local currentScale: number = character:GetScale()
		if approxEqual(currentScale, desiredScale) then
			return
		end

		local root: BasePart? = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local savedCFrame: CFrame?
		local savedLinear: Vector3?
		local savedAngular: Vector3?

		if root then
			savedCFrame = root.CFrame
			savedLinear = root.AssemblyLinearVelocity
			savedAngular = root.AssemblyAngularVelocity
		else
			savedCFrame = character:GetPivot()
		end

		character:ScaleTo(desiredScale)

		if root and savedCFrame then
			root.CFrame = savedCFrame

			if savedLinear then
				root.AssemblyLinearVelocity = savedLinear
			end
			if savedAngular then
				root.AssemblyAngularVelocity = savedAngular
			end
		elseif savedCFrame then
			character:PivotTo(savedCFrame)
		end
	end, Logger.warn)
end

local function scheduleApply(self: CharacterScaleController, desiredScale: number): ()
	self.pendingDesiredScale = desiredScale
	if self.scheduled then
		return
	end

	self.scheduled = true

	task.defer(function(): ()
		self.scheduled = false

		local target: number? = self.pendingDesiredScale
		self.pendingDesiredScale = nil

		if not target then
			return
		end

		CharacterScaleController.lastDesiredScale = target

		applyScale(target)
	end)
end

function CharacterScaleController:Init(): ()
	local bridge = GetBridge("CharacterScale")

	self.maid:GiveTask(bridge:Connect(function(desiredScale: number): ()
		if type(desiredScale) ~= "number" then
			return
		end

		scheduleApply(self, desiredScale)
	end))

	self.maid:GiveTask(Players.LocalPlayer.CharacterAdded:Connect(function(_character: Model): ()
		local last: number? = self.lastDesiredScale
		if last then
			scheduleApply(self, last)
		end
	end))
end

return CharacterScaleController
