local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local InitializerTypes = require(ReplicatedStorage.shared.types.InitializerTypes)
local Maid = require(ReplicatedStorage.package.Maid)
local UpdateSchedule = require(ReplicatedStorage.shared.modules.UpdateSchedule)

export type EventBoard = {
	Destroy: (self: EventBoard) -> (),
	Update: (self: EventBoard) -> (),
	new: (instance: BasePart, path: InitializerTypes.ClientPath) -> EventBoard?,
	__index: EventBoard,
	destroyed: boolean,
	lastUpdateAt: number,
	path: InitializerTypes.ClientPath,
	tag: string,
	type: string,
	instance: BasePart,
	maid: Maid.Maid,
}

local EventBoard: EventBoard = {} :: any
EventBoard.__index = EventBoard
EventBoard.tag = script.Name
EventBoard.type = "tag"

local function setText(label: TextLabel, text: string): ()
	label.Text = text
	for _, descendant: Instance in label:GetDescendants() do
		if descendant:IsA("TextLabel") then
			descendant.Text = text
		end
	end
end

local function formatCountdown(seconds: number): string
	local remaining: number = math.max(math.ceil(seconds), 0)
	local days: number = remaining // 86_400
	local hours: number = remaining % 86_400 // 3_600
	local minutes: number = remaining % 3_600 // 60
	local leftover: number = remaining % 60
	if days > 0 then
		return `{days} Days {hours} Hours {minutes} Mins`
	end
	if hours > 0 then
		return `{hours} Hours {minutes} Mins {leftover} Secs`
	end

	return `{minutes} Mins {leftover} Secs`
end

function EventBoard.new(instance: BasePart, path: InitializerTypes.ClientPath): EventBoard?
	if not instance:IsA("BasePart") then
		return
	end

	local self: EventBoard = setmetatable({}, EventBoard) :: any
	self.destroyed = false
	self.instance = instance
	self.lastUpdateAt = -math.huge
	self.maid = Maid.new()
	self.path = path

	self.maid:GiveTask(instance.DescendantAdded:Connect(function(): ()
		self:Update()
	end))
	self.maid:GiveTask(RunService.Heartbeat:Connect(function(): ()
		if os.clock() - self.lastUpdateAt >= 1 then
			self:Update()
		end
	end))
	self:Update()

	return self
end

-- Both GUIs stay hidden while the events load, after a load error and while no event is upcoming.
function EventBoard:Update(): ()
	if self.destroyed then
		return
	end

	self.lastUpdateAt = os.clock()

	local event: UpdateSchedule.ScheduledUpdate? = UpdateSchedule.GetNextEvent()
	local surface: SurfaceGui = self.instance:FindFirstChild("EventSurface") :: any
	if surface then
		surface.Enabled = event ~= nil
	end

	local billboard: BillboardGui = self.instance:FindFirstChildWhichIsA("BillboardGui") :: any
	if billboard then
		billboard.Enabled = event ~= nil
	end

	if not event then
		return
	end

	local image: ImageLabel = surface and surface:FindFirstChild("EventImage") :: any
	if image then
		image.Image = event.update.image or ""
		image.Visible = image.Image ~= ""
	end

	local message: TextLabel = surface and surface:FindFirstChild("Status") :: any
	if message then
		message.Text = event.update.title
		message.Visible = not image or not image.Visible
	end

	local title: TextLabel = billboard and billboard:FindFirstChild("EventTitle", true) :: any
	if title then
		setText(title, `Follow {event.update.title}!`)
	end

	local countdown: TextLabel = billboard and billboard:FindFirstChild("Countdown", true) :: any
	if countdown then
		setText(countdown, formatCountdown(event.startsAt - DateTime.now().UnixTimestampMillis / 1_000))
	end
end

function EventBoard:Destroy(): ()
	self.destroyed = true
	self.maid:DoCleaning()
end

return EventBoard
