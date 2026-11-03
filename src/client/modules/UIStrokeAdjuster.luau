local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local GameConfig = require(ReplicatedStorage.shared.config.GameConfig)
local Maid = require(ReplicatedStorage.package.Maid)

type StrokeEntry = {
	gui: ScreenGui | BillboardGui,
	originalThickness: number,
}

export type UIStrokeAdjuster = {
	BindCamera: (self: UIStrokeAdjuster) -> (),
	Destroy: (self: UIStrokeAdjuster) -> (),
	Init: (self: UIStrokeAdjuster) -> (),
	RefreshStroke: (self: UIStrokeAdjuster, stroke: UIStroke) -> (),
	RemoveStroke: (self: UIStrokeAdjuster, stroke: UIStroke) -> (),
	Render: (self: UIStrokeAdjuster, deltaTime: number) -> (),
	TagBillboardGui: (self: UIStrokeAdjuster, gui: BillboardGui) -> (),
	TagScreenGui: (self: UIStrokeAdjuster, gui: ScreenGui) -> (),
	TrackHierarchy: (self: UIStrokeAdjuster, root: Instance) -> (),
	TrackStroke: (self: UIStrokeAdjuster, instance: Instance) -> (),
	UpdateStroke: (self: UIStrokeAdjuster, stroke: UIStroke, entry: StrokeEntry) -> (),
	UpdateStrokes: (self: UIStrokeAdjuster) -> (),
	strokes: { [UIStroke]: StrokeEntry },
	watchedStrokes: { [UIStroke]: boolean },
	accumulator: number,
	index: number,
	type: string,
	camera: Camera?,
	playerGui: PlayerGui?,
	cameraMaid: Maid.Maid,
	maid: Maid.Maid,
}

local UIStrokeAdjuster: UIStrokeAdjuster = {
	strokes = {},
	watchedStrokes = {},
	accumulator = 0,
	index = 1,
	type = "controller",
	cameraMaid = Maid.new(),
	maid = Maid.new(),
} :: any

local CONFIG = GameConfig.ui.strokeAdjuster
local ORIGINAL_THICKNESS_ATTRIBUTE: string = "OriginalThickness"

local function getGui(stroke: UIStroke): (ScreenGui | BillboardGui)?
	if stroke:FindFirstAncestorWhichIsA("SurfaceGui") then
		return
	end
	local gui: Instance? = stroke:FindFirstAncestorWhichIsA("BillboardGui")
		or stroke:FindFirstAncestorWhichIsA("ScreenGui")
	if not gui then
		return
	end

	local ancestor: Instance? = stroke
	while ancestor do
		if
			ancestor:GetAttribute("IgnoreUIStrokeAdjuster") == true
			or table.find(CONFIG.excludedGuiNames, ancestor.Name)
		then
			return
		end
		ancestor = ancestor.Parent
	end

	return gui :: any
end

local function getOrigin(instance: Instance?): Vector3?
	if not instance then
		return
	end
	if instance:IsA("BasePart") then
		return instance.Position
	elseif instance:IsA("Attachment") then
		return instance.WorldPosition
	elseif instance:IsA("Model") then
		return instance:GetPivot().Position
	end

	return
end

function UIStrokeAdjuster:RemoveStroke(stroke: UIStroke): ()
	local entry: StrokeEntry? = self.strokes[stroke]
	self.strokes[stroke] = nil
	self.watchedStrokes[stroke] = nil
	self.maid[stroke] = nil
	if entry and stroke.Parent then
		stroke.Thickness = entry.originalThickness
	end
end

function UIStrokeAdjuster:RefreshStroke(stroke: UIStroke): ()
	local gui: (ScreenGui | BillboardGui)? = getGui(stroke)
	local inPlayerGui: boolean = self.playerGui ~= nil and stroke:IsDescendantOf(self.playerGui)
	if not (inPlayerGui or stroke:IsDescendantOf(Workspace)) then
		self:RemoveStroke(stroke)

		return
	end
	local entry: StrokeEntry = self.strokes[stroke] :: any
	if not gui then
		if entry then
			stroke.Thickness = entry.originalThickness
			self.strokes[stroke] = nil
		end

		return
	end
	if not entry then
		local originalThickness: any = stroke:GetAttribute(ORIGINAL_THICKNESS_ATTRIBUTE)
		if
			type(originalThickness) ~= "number"
			or originalThickness ~= originalThickness
			or math.abs(originalThickness) == math.huge
		then
			originalThickness = stroke.Thickness
			stroke:SetAttribute(ORIGINAL_THICKNESS_ATTRIBUTE, originalThickness)
		end

		entry = { gui = gui, originalThickness = originalThickness }
		self.strokes[stroke] = entry
	end

	entry.gui = gui
	self:UpdateStroke(stroke, entry)
end

function UIStrokeAdjuster:TrackStroke(instance: Instance): ()
	if not instance:IsA("UIStroke") or self.watchedStrokes[instance] then
		return
	end
	local inPlayerGui: boolean = self.playerGui ~= nil and instance:IsDescendantOf(self.playerGui)
	if not (inPlayerGui or instance:IsDescendantOf(Workspace)) then
		return
	end

	self.watchedStrokes[instance] = true
	local strokeMaid: Maid.Maid = Maid.new()
	self.maid[instance] = strokeMaid
	strokeMaid:GiveTask(instance.AncestryChanged:Connect(function(): ()
		self:RefreshStroke(instance)
	end))
	strokeMaid:GiveTask(instance.Destroying:Connect(function(): ()
		self:RemoveStroke(instance)
	end))
	self:RefreshStroke(instance)
end

function UIStrokeAdjuster:TrackHierarchy(root: Instance): ()
	self:TrackStroke(root)
	for _index: number, descendant: Instance in root:GetDescendants() do
		self:TrackStroke(descendant)
	end
	self:UpdateStrokes()
end

function UIStrokeAdjuster:TagBillboardGui(gui: BillboardGui): ()
	CollectionService:AddTag(gui, "Billboard")
	self:TrackHierarchy(gui)
end

function UIStrokeAdjuster:TagScreenGui(gui: ScreenGui): ()
	CollectionService:AddTag(gui, "ScreenGui")
	self:TrackHierarchy(gui)
end

function UIStrokeAdjuster:UpdateStroke(stroke: UIStroke, entry: StrokeEntry): ()
	local camera: Camera = self.camera :: any
	if not camera then
		return
	end

	local viewport: Vector2 = camera.ViewportSize
	local reference: Vector2 = CONFIG.referenceViewportSize
	local ratio: number = math.min(viewport.X, viewport.Y) / math.min(reference.X, reference.Y)
	if ratio <= 0 then
		return
	end

	local gui: ScreenGui | BillboardGui = entry.gui
	if gui:IsA("BillboardGui") then
		local origin: Vector3? = getOrigin(gui.Adornee or gui.Parent)
		if not origin then
			return
		end

		local distance: number = (camera.CFrame.Position - origin).Magnitude
		if gui.MaxDistance > 0 and distance > gui.MaxDistance then
			return
		end

		local referenceDistance: number = tonumber(gui:GetAttribute("Distance")) or CONFIG.defaultBillboardDistance
		ratio *= referenceDistance / math.max(distance, CONFIG.minimumBillboardDistance)
	end
	stroke.Thickness = entry.originalThickness * ratio
end

function UIStrokeAdjuster:UpdateStrokes(): ()
	for stroke: UIStroke, entry: StrokeEntry in self.strokes do
		self:UpdateStroke(stroke, entry)
	end
end

function UIStrokeAdjuster:BindCamera(): ()
	self.cameraMaid:DoCleaning()
	self.camera = Workspace.CurrentCamera
	local camera: Camera = self.camera :: any
	if not camera then
		return
	end

	self.cameraMaid:GiveTask(camera:GetPropertyChangedSignal("ViewportSize"):Connect(function(): ()
		self:UpdateStrokes()
	end))
	self:UpdateStrokes()
end

function UIStrokeAdjuster:Init(): ()
	self:Destroy()
	self.maid = Maid.new()
	self.cameraMaid = Maid.new()
	self.maid:GiveTask(self.cameraMaid)
	self.playerGui = Players.LocalPlayer:WaitForChild("PlayerGui") :: PlayerGui

	self.maid:GiveTask(Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function(): ()
		self:BindCamera()
	end))
	self:BindCamera()
	for _index: number, root: Instance in { self.playerGui :: PlayerGui, Workspace } do
		self.maid:GiveTask(root.DescendantAdded:Connect(function(instance: Instance): ()
			self:TrackStroke(instance)
		end))
		self.maid:GiveTask(root.DescendantRemoving:Connect(function(instance: Instance): ()
			if instance:IsA("UIStroke") then
				self:RemoveStroke(instance)
			end
		end))
		self:TrackHierarchy(root)
	end
end

function UIStrokeAdjuster:Render(deltaTime: number): ()
	self.accumulator += deltaTime
	if self.accumulator < CONFIG.billboardUpdateInterval then
		return
	end

	self.accumulator = 0
	self:UpdateStrokes()
end

function UIStrokeAdjuster:Destroy(): ()
	for stroke: UIStroke in self.watchedStrokes do
		self:RemoveStroke(stroke)
	end
	self.maid:DoCleaning()
	self.cameraMaid:DoCleaning()
	self.camera = nil
	self.playerGui = nil
	self.accumulator = 0
end

return UIStrokeAdjuster
