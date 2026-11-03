local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local GameConfig = require(ReplicatedStorage.shared.config.GameConfig)
local GetBridge = require(ReplicatedStorage.util.Core.GetBridge)
local InitializerTypes = require(ReplicatedStorage.shared.types.InitializerTypes)
local Logger = require(ReplicatedStorage.util.Core.Logger)
local Maid = require(ReplicatedStorage.package.Maid)
local SFX = require(ReplicatedStorage.util.Core.SFX)

export type NotificationPayload = {
	channel: string?,
	color: Color3?,
	from: unknown?,
	kind: string?,
	notificationType: string?,
	seconds: number?,
	template: string?,
	text: string?,
	title: string?,
	to: unknown?,
}

type TransparencyTarget = {
	instance: Instance,
	properties: { [string]: number },
}

type NotificationEntry = {
	fadingOut: boolean,
	frame: Frame,
	kind: string,
	lifecycleMaid: Maid.Maid,
	phaseMaid: Maid.Maid,
	revision: number,
	targets: { TransparencyTarget },
}

export type NotificationUI = {
	Destroy: (self: NotificationUI) -> (),
	Dismiss: (self: NotificationUI, entry: NotificationEntry) -> (),
	PlaySound: (self: NotificationUI) -> (),
	Push: (self: NotificationUI, payload: NotificationPayload) -> (),
	Refresh: (self: NotificationUI, entry: NotificationEntry, payload: NotificationPayload) -> boolean,
	ResetLifetime: (self: NotificationUI, entry: NotificationEntry, payload: NotificationPayload) -> (),
	Send: (payload: NotificationPayload) -> (),
	new: (instance: Frame, path: InitializerTypes.ClientPath) -> NotificationUI?,
	__index: NotificationUI,
	entriesByKind: { [string]: NotificationEntry },
	templates: { [string]: Frame },
	channel: string,
	lastSoundTick: number,
	nextSequence: number,
	tag: string,
	type: string,
	instance: Frame,
	notificationSound: Sound?,
	path: InitializerTypes.ClientPath,
	maid: Maid.Maid,
}

local NotificationUI: NotificationUI = {} :: any
NotificationUI.__index = NotificationUI
NotificationUI.tag = script.Name
NotificationUI.type = "local_tag"

local BOTTOM_CHANNEL: string = "bottom" -- channel of payloads and containers that ask for "bottom"
local ERROR_TEMPLATE_NAME: string = "ErrorTemplate" -- optional template of the error kind
local MAXIMUM_PENDING_PAYLOADS: number = 20 -- Send() payloads kept while their channel has no container
local NOTIFICATION_BRIDGE: any = GetBridge("Notification") -- server notifications; payloads without text are ignored
local NOTIFICATION_TEMPLATE_NAME: string = "NotificationTemplate" -- required template of every other kind
local TOP_CHANNEL: string = "top" -- default channel

-- GameConfig.ui.notifications tunables
local CONFIG: typeof(GameConfig.ui.notifications) = GameConfig.ui.notifications

local activeNotificationUIs: { [string]: NotificationUI } = {} -- container that receives Send() payloads, by channel
local pendingPayloads: { NotificationPayload } = {} -- Send() payloads waiting for a container of their channel

local function getFiniteNumber(value: unknown): number?
	if type(value) ~= "number" or value ~= value or math.abs(value) == math.huge then
		return
	end

	return value
end

local function getKind(payload: NotificationPayload): string
	local rawKind: unknown = payload.kind or payload.notificationType or payload.template
	if type(rawKind) ~= "string" then
		return "notification"
	end

	local normalized: string = rawKind:lower():gsub("[^%w]", "")

	return (normalized == "error" or normalized == "errortemplate") and "error" or "notification"
end

local function normalizeChannel(value: unknown): string
	return type(value) == "string" and value:lower() == BOTTOM_CHANNEL and BOTTOM_CHANNEL or TOP_CHANNEL
end

local function getChannel(payload: NotificationPayload): string
	return normalizeChannel(payload.channel)
end

local function getTemplateName(kind: string): string
	return kind == "error" and ERROR_TEMPLATE_NAME or NOTIFICATION_TEMPLATE_NAME
end

local function usesPayloadColor(templates: { [string]: Frame }, kind: string): boolean
	return templates[getTemplateName(kind)] == templates[NOTIFICATION_TEMPLATE_NAME]
end

local function getPayloadText(payload: NotificationPayload): string?
	if type(payload.text) == "string" and payload.text ~= "" then
		return payload.text
	end

	if payload.from ~= nil and payload.to ~= nil then
		return `{payload.from} > {payload.to}`
	end

	if type(payload.title) == "string" and payload.title ~= "" then
		return payload.title
	end

	return
end

local function getDirectTextLabels(frame: Frame): { TextLabel }
	local labels: { TextLabel } = {}
	for _index: number, child: Instance in frame:GetChildren() do
		if child:IsA("TextLabel") then
			table.insert(labels, child)
		end
	end

	table.sort(labels, function(left: TextLabel, right: TextLabel): boolean
		if left.Position.Y.Scale == right.Position.Y.Scale then
			return left.Position.Y.Offset < right.Position.Y.Offset
		end

		return left.Position.Y.Scale < right.Position.Y.Scale
	end)

	return labels
end

local function setText(label: TextLabel, text: string): ()
	label.Text = text

	for _index: number, descendant: Instance in label:GetDescendants() do
		if descendant:IsA("TextLabel") then
			descendant.Text = text
		end
	end
end

local function applyPayload(frame: Frame, usesColor: boolean, payload: NotificationPayload): boolean
	local labels: { TextLabel } = getDirectTextLabels(frame)
	if #labels < 1 then
		return false
	end

	local text: string = getPayloadText(payload) :: string
	if not text then
		return false
	end

	local label: TextLabel = labels[1]

	setText(label, text)

	-- An authored ErrorTemplate keeps its colors; NotificationTemplate clones (error fallback too) use payload.color.
	if not usesColor then
		return true
	end

	local defaultColor: unknown = label:GetAttribute("DefaultNotificationTextColor3")
	if typeof(defaultColor) ~= "Color3" then
		defaultColor = label.TextColor3

		label:SetAttribute("DefaultNotificationTextColor3", defaultColor)
	end

	label.TextColor3 = if typeof(payload.color) == "Color3" then payload.color else defaultColor :: Color3

	return true
end

local function createNotificationFrame(
	templates: { [string]: Frame },
	kind: string,
	payload: NotificationPayload
): Frame?
	local template: Frame = templates[getTemplateName(kind)]
	if not template then
		return
	end

	local frame: Frame = template:Clone()
	if not applyPayload(frame, usesPayloadColor(templates, kind), payload) then
		frame:Destroy()

		return
	end

	return frame
end

local function collectTransparencyTargets(root: GuiObject): { TransparencyTarget }
	local targets: { TransparencyTarget } = {}
	local instances: { Instance } = { root }
	for _index: number, descendant: Instance in root:GetDescendants() do
		table.insert(instances, descendant)
	end

	for _index: number, instance: Instance in instances do
		local properties: { [string]: number } = {}
		if instance:IsA("GuiObject") then
			properties.BackgroundTransparency = instance.BackgroundTransparency
		end

		if instance:IsA("TextLabel") or instance:IsA("TextButton") or instance:IsA("TextBox") then
			properties.TextStrokeTransparency = instance.TextStrokeTransparency
			properties.TextTransparency = instance.TextTransparency
		elseif instance:IsA("ImageLabel") or instance:IsA("ImageButton") then
			properties.ImageTransparency = instance.ImageTransparency
		elseif instance:IsA("UIStroke") then
			properties.Transparency = instance.Transparency
		end

		if next(properties) then
			table.insert(targets, {
				instance = instance,
				properties = properties,
			})
		end
	end

	return targets
end

local function setTransparent(targets: { TransparencyTarget }): ()
	for _index: number, target: TransparencyTarget in targets do
		for propertyName: string in target.properties do
			(target.instance :: any)[propertyName] = 1
		end
	end
end

local function tweenTargets(targets: { TransparencyTarget }, duration: number, show: boolean, maid: Maid.Maid): ()
	local tweenInfo: TweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	for _index: number, target: TransparencyTarget in targets do
		if not target.instance.Parent then
			continue
		end

		local goals: { [string]: number } = {}
		for propertyName: string, authoredValue: number in target.properties do
			goals[propertyName] = show and authoredValue or 1
		end

		local tween: Tween = TweenService:Create(target.instance, tweenInfo, goals)
		maid:GiveTask(tween)
		tween:Play()
	end
end

function NotificationUI.new(instance: Frame, path: InitializerTypes.ClientPath): NotificationUI?
	local notificationTemplate: Frame = instance:FindFirstChild(NOTIFICATION_TEMPLATE_NAME) :: any
	if not notificationTemplate or not notificationTemplate:IsA("Frame") then
		Logger.warn(`NotificationUI is missing {NOTIFICATION_TEMPLATE_NAME}`)

		return
	end

	local errorTemplate: Frame = instance:FindFirstChild(ERROR_TEMPLATE_NAME) :: any
	if not errorTemplate or not errorTemplate:IsA("Frame") then
		errorTemplate = notificationTemplate
	end

	notificationTemplate.Visible = false

	errorTemplate.Visible = false

	local self: NotificationUI = setmetatable({}, NotificationUI) :: any
	self.channel = normalizeChannel(instance:GetAttribute("NotificationChannel"))
	self.entriesByKind = {}
	self.instance = instance
	self.lastSoundTick = -math.huge
	self.maid = Maid.new()
	self.nextSequence = 0
	self.path = path
	self.templates = {
		[ERROR_TEMPLATE_NAME] = errorTemplate,
		[NOTIFICATION_TEMPLATE_NAME] = notificationTemplate,
	}

	local soundId: number = math.max(CONFIG.soundId // 1, 0)
	if soundId > 0 then
		local notificationSound: Sound = Instance.new("Sound")
		notificationSound.Name = "Notification"
		notificationSound.PlaybackSpeed = math.max(CONFIG.soundPlaybackSpeed, 0.01)
		notificationSound.SoundId = `rbxassetid://{soundId}`
		notificationSound.Volume = math.max(CONFIG.soundVolume, 0)
		notificationSound.Parent = SoundService

		SFX.Bind(notificationSound)

		self.notificationSound = notificationSound

		self.maid:GiveTask(notificationSound)
	end

	self.maid:GiveTask(NOTIFICATION_BRIDGE:Connect(function(payload: unknown): ()
		if type(payload) == "table" then
			self:Push(payload :: NotificationPayload)
		end
	end))

	activeNotificationUIs[self.channel] = self

	local queuedPayloads: { NotificationPayload } = pendingPayloads
	pendingPayloads = {}

	for _index: number, payload: NotificationPayload in queuedPayloads do
		if getChannel(payload) == self.channel then
			self:Push(payload)
		else
			table.insert(pendingPayloads, payload)
		end
	end

	return self
end

function NotificationUI.Send(payload: NotificationPayload): ()
	local active: NotificationUI = activeNotificationUIs[getChannel(payload)]
	if active and active.instance.Parent then
		active:Push(payload)

		return
	end

	table.insert(pendingPayloads, payload)

	if #pendingPayloads > MAXIMUM_PENDING_PAYLOADS then
		table.remove(pendingPayloads, 1)
	end
end

function NotificationUI:Push(payload: NotificationPayload): ()
	if getChannel(payload) ~= self.channel or not getPayloadText(payload) then
		return
	end

	local kind: string = getKind(payload)
	local existingEntry: NotificationEntry = self.entriesByKind[kind]
	if existingEntry then
		if existingEntry.frame.Parent then
			self:Refresh(existingEntry, payload)

			return
		end

		self.maid[existingEntry] = nil
	end

	local frame: Frame = createNotificationFrame(self.templates, kind, payload) :: Frame
	if not frame then
		return
	end

	self.nextSequence += 1

	frame.Name = "Notification"
	frame.LayoutOrder = self.channel == BOTTOM_CHANNEL and self.nextSequence or -self.nextSequence
	frame.Visible = false

	local targets: { TransparencyTarget } = collectTransparencyTargets(frame)

	setTransparent(targets)

	frame.Parent = self.instance
	frame.Visible = true

	local entry: NotificationEntry = {
		fadingOut = false,
		frame = frame,
		kind = kind,
		lifecycleMaid = Maid.new(),
		phaseMaid = Maid.new(),
		revision = 0,
		targets = targets,
	}

	self.entriesByKind[kind] = entry
	self.maid[entry] = function(): ()
		if self.entriesByKind[entry.kind] == entry then
			self.entriesByKind[entry.kind] = nil
		end

		entry.phaseMaid:DoCleaning()
		entry.lifecycleMaid:DoCleaning()
		entry.frame:Destroy()
	end

	self:PlaySound()

	tweenTargets(targets, CONFIG.fadeInTime, true, entry.phaseMaid)

	self:ResetLifetime(entry, payload)
end

function NotificationUI:Refresh(entry: NotificationEntry, payload: NotificationPayload): boolean
	if not applyPayload(entry.frame, usesPayloadColor(self.templates, entry.kind), payload) then
		return false
	end

	entry.phaseMaid:DoCleaning()

	entry.fadingOut = false

	self.nextSequence += 1

	entry.frame.LayoutOrder = self.channel == BOTTOM_CHANNEL and self.nextSequence or -self.nextSequence

	tweenTargets(entry.targets, CONFIG.fadeInTime, true, entry.phaseMaid)

	self:ResetLifetime(entry, payload)
	self:PlaySound()

	return true
end

function NotificationUI:PlaySound(): ()
	local now: number = os.clock()
	if not self.notificationSound or now - self.lastSoundTick < CONFIG.fadeInTime then
		return
	end

	self.lastSoundTick = now

	SoundService:PlayLocalSound(self.notificationSound)
end

function NotificationUI:ResetLifetime(entry: NotificationEntry, payload: NotificationPayload): ()
	entry.lifecycleMaid:DoCleaning()

	entry.revision += 1

	local requestedDuration: number = getFiniteNumber(payload.seconds) or CONFIG.defaultDuration
	local visibleDuration: number = math.clamp(requestedDuration, CONFIG.minimumDuration, CONFIG.maximumDuration)
	local revision: number = entry.revision
	local lifetimeThread: thread = task.spawn(function(): ()
		task.wait(CONFIG.fadeInTime + visibleDuration)
		task.defer(function(): ()
			if entry.revision == revision and not entry.fadingOut and entry.frame.Parent then
				self:Dismiss(entry)
			end
		end)
	end)

	entry.lifecycleMaid:GiveTask(function(): ()
		pcall(task.cancel, lifetimeThread)
	end)
end

function NotificationUI:Dismiss(entry: NotificationEntry): ()
	if entry.fadingOut then
		return
	end

	entry.fadingOut = true

	entry.phaseMaid:DoCleaning()

	tweenTargets(entry.targets, CONFIG.fadeOutTime, false, entry.phaseMaid)

	local revision: number = entry.revision
	local dismissalThread: thread = task.spawn(function(): ()
		task.wait(CONFIG.fadeOutTime)
		task.defer(function(): ()
			if entry.revision == revision and entry.fadingOut then
				self.maid[entry] = nil
			end
		end)
	end)

	entry.lifecycleMaid:GiveTask(function(): ()
		pcall(task.cancel, dismissalThread)
	end)
end

function NotificationUI:Destroy(): ()
	if activeNotificationUIs[self.channel] == self then
		activeNotificationUIs[self.channel] = nil
	end

	self.maid:DoCleaning()

	table.clear(self.entriesByKind)
end

return NotificationUI
