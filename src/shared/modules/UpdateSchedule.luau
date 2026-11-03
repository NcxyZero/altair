local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SocialService = game:GetService("SocialService")

local GameConfig = require(ReplicatedStorage.shared.config.GameConfig)
local Logger = require(ReplicatedStorage.util.Core.Logger)
local Maid = require(ReplicatedStorage.package.Maid)
local UpdatesConfig = require(ReplicatedStorage.shared.config.UpdatesConfig)

export type ScheduledUpdate = {
	endsAt: number,
	promptId: string,
	startsAt: number,
	update: UpdatesConfig.Update,
}

export type UpdateSchedule = {
	GetNextEvent: (now: number?) -> ScheduledUpdate?,
	Refresh: () -> (),
	SelectNextEvent: (events: { ScheduledUpdate }, now: number) -> ScheduledUpdate?,
	hasLoaded: boolean,
	isRefreshing: boolean,
	lastError: string?,
}

local UpdateSchedule: UpdateSchedule = {
	hasLoaded = false,
	isRefreshing = false,
} :: any

local CONFIG: typeof(GameConfig.ui.eventPrompt) = GameConfig.ui.eventPrompt
local cachedEvents: { ScheduledUpdate } = {}
local nextRefreshAt: number = -math.huge
local maid: Maid.Maid = Maid.new()

local function getTimestamp(value: any): number
	return DateTime.fromUniversalTime(
		value.Year,
		value.Month,
		value.Day,
		value.Hour,
		value.Minute,
		value.Second,
		value.Millisecond or 0
	).UnixTimestampMillis / 1_000
end

local function getEventText(displayText: any, text: any, fallback: string): string
	if type(displayText) == "string" and displayText ~= "" then
		return displayText
	end
	if type(text) == "string" and text ~= "" then
		return text
	end

	return fallback
end

local function parseEvent(event: any): ScheduledUpdate?
	if
		type(event) ~= "table"
		or type(event.Id) ~= "string"
		or not event.Id:match("^%d+$")
		or event.HasStarted
		or event.HasEnded
		or event.Status ~= Enum.ExperienceEventStatus.Active
	then
		return
	end

	local startsAt: number = getTimestamp(event.StartTime)
	local endsAt: number = getTimestamp(event.EndTime)
	if endsAt <= startsAt then
		return
	end

	local thumbnailId: any = type(event.ThumbnailIds) == "table" and event.ThumbnailIds[1]
	local image: string? = type(thumbnailId) == "number" and thumbnailId > 0 and `rbxassetid://{thumbnailId}` or nil

	return {
		endsAt = endsAt,
		promptId = event.Id,
		startsAt = startsAt,
		update = {
			id = event.Id,
			title = getEventText(event.DisplayTitle, event.Title, "Upcoming Event"),
			date = startsAt * 1_000,
			heading = getEventText(event.DisplaySubtitle, event.Subtitle, ""),
			description = getEventText(event.DisplayDescription, event.Description, ""),
			image = image,
		},
	}
end

function UpdateSchedule.SelectNextEvent(events: { ScheduledUpdate }, now: number): ScheduledUpdate?
	local nextEvent: ScheduledUpdate?
	for _, event: ScheduledUpdate in events do
		if event.startsAt <= now or event.endsAt <= now then
			continue
		end
		if not nextEvent or event.startsAt < nextEvent.startsAt then
			nextEvent = event
		end
	end

	return nextEvent
end

function UpdateSchedule.Refresh(): ()
	if UpdateSchedule.isRefreshing or os.clock() < nextRefreshAt then
		return
	end
	UpdateSchedule.isRefreshing = true
	local refreshThread: thread = task.spawn(function(): ()
		local success: boolean, result: any = pcall(function(): any
			return SocialService:GetUpcomingExperienceEventsAsync()
		end)
		UpdateSchedule.isRefreshing = false
		if not success or type(result) ~= "table" then
			UpdateSchedule.lastError = tostring(result)
			nextRefreshAt = os.clock() + CONFIG.apiRetryInterval

			Logger.warn(`Could not load experience events: {result}`)

			return
		end

		local events: { ScheduledUpdate } = {}
		for _, event: any in result do
			local parsed: boolean, scheduled: any = pcall(parseEvent, event)
			if parsed and scheduled then
				table.insert(events, scheduled)
			end
		end
		cachedEvents = events
		nextRefreshAt = os.clock() + CONFIG.apiRefreshInterval
		UpdateSchedule.hasLoaded = true
		UpdateSchedule.lastError = nil
	end)
	maid.refresh = function(): ()
		if coroutine.status(refreshThread) ~= "dead" then
			task.cancel(refreshThread)
		end
	end
end

function UpdateSchedule.GetNextEvent(now: number?): ScheduledUpdate?
	UpdateSchedule.Refresh()

	return UpdateSchedule.SelectNextEvent(cachedEvents, now or DateTime.now().UnixTimestampMillis / 1_000)
end

return UpdateSchedule
