local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CreatePrompt = require(ReplicatedStorage.util.CreatePrompt)
local InitializerTypes = require(ReplicatedStorage.shared.types.InitializerTypes)
local Logger = require(ReplicatedStorage.util.Logger)
local Maid = require(ReplicatedStorage.package.Maid)
local PromptActions = require(ReplicatedStorage.client.clientConfig.PromptActions)

export type PromptRecord = {
	created: boolean,
	maid: Maid.Maid,
	prompt: ProximityPrompt,
}

export type PromptController = {
	CreatePrompt: (self: PromptController, instance: Instance) -> (),
	Destroy: (self: PromptController) -> (),
	Init: (self: PromptController) -> (),
	RemovePrompt: (self: PromptController, instance: Instance) -> (),
	promptInstances: { Instance },
	promptRecords: { [Instance]: PromptRecord },
	path: InitializerTypes.ClientPath?,
	type: string,
	maid: Maid.Maid,
}

local PromptController: PromptController = {
	promptInstances = {},
	promptRecords = {},
	type = "controller",
	maid = Maid.new(),
} :: PromptController

local PROMPT_TAG: string = "PromptDetect"
local PROMPT_ACTION_ATTRIBUTE: string = "PromptAction"

local function getPromptHost(instance: Instance): (BasePart | Attachment)?
	if instance:IsA("BasePart") or instance:IsA("Attachment") then
		return instance
	end

	if instance:IsA("Model") then
		local primaryPart: BasePart? = instance.PrimaryPart
		if primaryPart then
			return primaryPart
		end
	end

	return instance:FindFirstChildWhichIsA("BasePart", true)
end

function PromptController:CreatePrompt(instance: Instance): ()
	if self.promptRecords[instance] then
		return
	end

	local actionName: string = instance:GetAttribute(PROMPT_ACTION_ATTRIBUTE) :: any
	if not actionName then
		Logger.warn(`No {PROMPT_ACTION_ATTRIBUTE} attribute found on PromptDetect instance "{instance}"`)

		return
	end

	local action: ((Instance, Player?) -> ())? = PromptActions[actionName]
	if not action then
		Logger.warn(
			`No PromptAction found in PromptActions config for name "{actionName}" on PromptDetect instance "{instance}"`
		)

		return
	end

	local actionHandler: (Instance, Player?) -> () = action :: (Instance, Player?) -> ()

	local host: (BasePart | Attachment)? = getPromptHost(instance)
	if not host then
		Logger.warn(`No host part found for PromptDetect instance "{instance}"`)

		return
	end

	local prompt: ProximityPrompt? = host:FindFirstChildWhichIsA("ProximityPrompt")
	local created: boolean = false
	if not prompt then
		local actionText: string? = instance:GetAttribute("PromptActionText") :: any
		local holdDuration: number? = instance:GetAttribute("PromptHoldDuration") :: any
		local keyboardKeyCode: Enum.KeyCode? = instance:GetAttribute("PromptKeyCode") :: any
		local maxActivationDistance: number? = instance:GetAttribute("PromptMaxActivationDistance") :: any
		local objectText: string? = instance:GetAttribute("PromptObjectText") :: any
		local requiresLineOfSight: boolean? = instance:GetAttribute("PromptRequiresLineOfSight") :: any

		prompt = CreatePrompt(host, {
			ActionText = actionText,
			HoldDuration = holdDuration,
			KeyboardKeyCode = keyboardKeyCode,
			MaxActivationDistance = maxActivationDistance,
			ObjectText = objectText,
			RequiresLineOfSight = requiresLineOfSight,
		})
		created = true
	end

	if not prompt then
		return
	end

	local recordMaid: Maid.Maid = Maid.new()
	recordMaid:GiveTask(prompt.Triggered:Connect(function(player: Player): ()
		actionHandler(instance, player)
	end))

	self.promptRecords[instance] = {
		created = created,
		maid = recordMaid,
		prompt = prompt,
	}

	self.maid:GiveTask(recordMaid)

	if created then
		self.maid:GiveTask(prompt)
	end

	table.insert(self.promptInstances, instance)
end

function PromptController:RemovePrompt(instance: Instance): ()
	local record: PromptRecord? = self.promptRecords[instance]
	if not record then
		return
	end

	record.maid:DoCleaning()

	if record.created and record.prompt then
		record.prompt:Destroy()
	end

	local index: number? = table.find(self.promptInstances, instance)
	if index then
		table.remove(self.promptInstances, index)
	end

	self.promptRecords[instance] = nil :: any
end

function PromptController:Init(): ()
	self.maid = Maid.new()
	self.promptInstances = {}
	self.promptRecords = {}

	local function onAdded(instance: Instance): ()
		self:CreatePrompt(instance)
	end

	local function onRemoved(instance: Instance): ()
		self:RemovePrompt(instance)
	end

	for _index: number, inst: Instance in CollectionService:GetTagged(PROMPT_TAG) do
		onAdded(inst)
	end

	self.maid:GiveTask(CollectionService:GetInstanceAddedSignal(PROMPT_TAG):Connect(onAdded))
	self.maid:GiveTask(CollectionService:GetInstanceRemovedSignal(PROMPT_TAG):Connect(onRemoved))
end

function PromptController:Destroy(): ()
	for _index: number, instance: Instance in self.promptInstances do
		self:RemovePrompt(instance)
	end

	if self.maid then
		self.maid:DoCleaning()
	end
end

return PromptController
