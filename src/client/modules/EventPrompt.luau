local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SocialService = game:GetService("SocialService")

local GameConfig = require(ReplicatedStorage.shared.config.GameConfig)
local InitializerTypes = require(ReplicatedStorage.shared.types.InitializerTypes)
local Logger = require(ReplicatedStorage.util.Core.Logger)
local Maid = require(ReplicatedStorage.package.Maid)
local UpdateSchedule = require(ReplicatedStorage.shared.modules.UpdateSchedule)

export type EventPrompt = {
	ApplyAvailability: (self: EventPrompt) -> (),
	Destroy: (self: EventPrompt) -> (),
	Prompt: (self: EventPrompt) -> (),
	RefreshStatus: (self: EventPrompt) -> (),
	Update: (self: EventPrompt) -> (),
	new: (instance: Instance, path: InitializerTypes.ClientPath) -> EventPrompt?,
	__index: EventPrompt,
	event: UpdateSchedule.ScheduledUpdate?,
	destroyed: boolean,
	isPrompting: boolean,
	isRefreshing: boolean,
	lastScheduleRefresh: number,
	lastStatusRefresh: number,
	path: InitializerTypes.ClientPath,
	revision: number,
	tag: string,
	type: string,
	instance: Attachment | BasePart,
	prompt: ProximityPrompt,
	status: Enum.RsvpStatus?,
	maid: Maid.Maid,
}

local EventPrompt: EventPrompt = {} :: any
EventPrompt.__index = EventPrompt
EventPrompt.tag = script.Name
EventPrompt.type = "tag"

local CONFIG = GameConfig.ui.eventPrompt

function EventPrompt.new(instance: Instance, path: InitializerTypes.ClientPath): EventPrompt?
	if not instance:IsA("Attachment") and not instance:IsA("BasePart") then
		Logger.warn("EventPrompt requires an Attachment or BasePart")

		return
	end

	local self: EventPrompt = setmetatable({}, EventPrompt) :: any
	self.destroyed = false
	self.instance = instance
	self.isPrompting = false
	self.isRefreshing = false
	self.lastScheduleRefresh = -math.huge
	self.lastStatusRefresh = -math.huge
	self.maid = Maid.new()
	self.path = path
	self.revision = 0

	local prompt: ProximityPrompt = Instance.new("ProximityPrompt")
	prompt.Name = "FollowEventPrompt"
	prompt.ActionText = CONFIG.actionText
	prompt.Enabled = false
	prompt.MaxActivationDistance = CONFIG.maximumDistance
	prompt.RequiresLineOfSight = false
	prompt.Parent = instance
	self.prompt = prompt
	self.maid:GiveTask(prompt)
	self.maid:GiveTask(prompt.Triggered:Connect(function(player: Player): ()
		if player == Players.LocalPlayer then
			self:Prompt()
		end
	end))
	self.maid:GiveTask(RunService.Heartbeat:Connect(function(): ()
		if os.clock() - self.lastScheduleRefresh >= CONFIG.scheduleRefreshInterval then
			self:Update()
		end
	end))
	self:Update()

	return self
end

function EventPrompt:ApplyAvailability(): ()
	if self.destroyed then
		return
	end

	local event: UpdateSchedule.ScheduledUpdate? = self.event
	self.prompt.Enabled = event ~= nil
		and event.startsAt > DateTime.now().UnixTimestampMillis / 1_000
		and self.status ~= nil
		and self.status ~= Enum.RsvpStatus.Going
		and not self.isPrompting
end

function EventPrompt:Update(): ()
	if self.destroyed then
		return
	end

	self.lastScheduleRefresh = os.clock()
	local event: UpdateSchedule.ScheduledUpdate? = UpdateSchedule.GetNextEvent()
	local previous: UpdateSchedule.ScheduledUpdate? = self.event
	local changed: boolean = (event == nil) ~= (previous == nil)
		or (
			event ~= nil
			and previous ~= nil
			and (
				event.promptId ~= previous.promptId
				or event.startsAt ~= previous.startsAt
				or event.endsAt ~= previous.endsAt
			)
		)
	self.event = event
	if changed then
		self.revision += 1
		self.status = nil
		self.lastStatusRefresh = -math.huge
	end

	self.prompt.ObjectText = event and event.update.title or ""
	self:ApplyAvailability()
	if
		not event
		or self.isPrompting
		or self.isRefreshing
		or os.clock() - self.lastStatusRefresh < CONFIG.statusRefreshInterval
	then
		return
	end

	self.isRefreshing = true
	self.maid.statusRefresh = task.spawn(function(): ()
		self:RefreshStatus()
	end)
end

function EventPrompt:RefreshStatus(): ()
	local event: UpdateSchedule.ScheduledUpdate = self.event :: any
	if not event then
		self.isRefreshing = false

		return
	end

	local revision: number = self.revision
	local success: boolean, status: any = pcall(function(): Enum.RsvpStatus
		return SocialService:GetEventRsvpStatusAsync(event.promptId)
	end)
	self.isRefreshing = false
	if self.destroyed or self.revision ~= revision then
		return
	end

	self.lastStatusRefresh = os.clock()
	if success then
		self.status = status
	else
		self.status = nil
		Logger.warn(`Could not load event RSVP status: {status}`)
	end

	self:ApplyAvailability()
end

function EventPrompt:Prompt(): ()
	if self.destroyed or self.isPrompting then
		return
	end

	self:Update()
	local event: UpdateSchedule.ScheduledUpdate = self.event :: any
	if not event or not self.prompt.Enabled then
		return
	end

	self.isPrompting = true
	self.revision += 1
	self:ApplyAvailability()
	local revision: number = self.revision
	local success: boolean, status: any = pcall(function(): Enum.RsvpStatus
		return SocialService:PromptRsvpToEventAsync(event.promptId)
	end)
	self.isPrompting = false
	if self.destroyed or self.revision ~= revision then
		return
	end

	self.lastStatusRefresh = os.clock()
	if success then
		self.status = status
	else
		Logger.warn(`Could not open event RSVP prompt: {status}`)
	end

	self:ApplyAvailability()
end

function EventPrompt:Destroy(): ()
	self.destroyed = true
	self.revision += 1
	self.maid:DoCleaning()
end

return EventPrompt
