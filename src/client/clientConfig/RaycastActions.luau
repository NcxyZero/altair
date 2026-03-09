local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local BasicJumpAnimation = require(ReplicatedStorage.shared.modules.BasicJumpAnimation)
local ClientData = require(ReplicatedStorage.client.modules.ClientData)
local CooldownManager = require(ReplicatedStorage.shared.modules.CooldownManager)
local FishConfig = require(ReplicatedStorage.shared.config.FishConfig)
local GetBridge = require(ReplicatedStorage.util.GetBridge)
local LocalPlayer = require(ReplicatedStorage.util.LocalPlayer)
local Logger = require(ReplicatedStorage.util.Logger)
local MonetizationConfig = require(ReplicatedStorage.shared.config.MonetizationConfig)
local OpenGui = require(ReplicatedStorage.util.OpenGui)
local RodsConfig = require(ReplicatedStorage.shared.config.RodsConfig)
local TagManager = require(ReplicatedStorage.shared.modules.TagManager)

local LockBridge = GetBridge("LockBridge")
local MonetizationPrompt = GetBridge("MonetizationPrompt")

local function onLockBridge(payload: any): ()
	if typeof(payload) ~= "table" then
		return
	end

	local action: any = payload.action
	if action ~= "locked" then
		return
	end

	local localEffects: Instance? = SoundService:FindFirstChild("LocalEffects")
	local laserGateSound: Sound? = localEffects and localEffects:FindFirstChild("LaserGate") :: any
	if laserGateSound and laserGateSound:IsA("Sound") then
		SoundService:PlayLocalSound(laserGateSound)
	else
		Logger.warn("RaycastActions: SoundService.LocalEffects.LaserGate missing or not a Sound")
	end
end

LockBridge:Connect(onLockBridge)

local function getLimitedItemEntry(name: string?, productName: string?): (string?, any?)
	local itemsConfig = MonetizationConfig.products and MonetizationConfig.products.Items
	local data: any = itemsConfig and itemsConfig.data
	if type(data) ~= "table" then
		return
	end

	if type(productName) == "string" and data[productName] then
		return productName, data[productName]
	end

	if type(name) == "string" and data[name] then
		return name, data[name]
	end

	local lookup: string? = if type(productName) == "string"
		then productName
		else type(name) == "string" and name or nil
	if not lookup then
		return
	end

	for key: string, entry: any in data do
		if type(entry) == "table" then
			local itemName: any = entry.item
			local stockItemName: any = entry.stockItemName
			if itemName == lookup or stockItemName == lookup then
				return key, entry
			end
		end
	end

	return
end

local function getOfferName(entry: any?): string?
	local offers: any = entry and (entry.offer or entry.offers)
	if type(offers) == "string" and offers ~= "" then
		return offers
	end
	if type(offers) == "table" then
		for index: number = 1, #offers do
			local offerName: any = offers[index]
			if type(offerName) == "string" and offerName ~= "" then
				return offerName
			end
		end
	end

	return
end

local function isLimitedRodEntry(itemKey: string?, entry: any?): boolean
	if not itemKey or not entry then
		return false
	end

	local isLimited: boolean = entry.limited == true or entry.Limited == true
	if not isLimited then
		return false
	end

	if FishConfig[itemKey] then
		return false
	end

	return RodsConfig[itemKey] ~= nil
end

local function isOfferOwned(offerName: string?): boolean
	if not offerName then
		return false
	end

	local producer: any = ClientData.playerProducer
	if not producer then
		return false
	end

	local offers: any = producer:getState().monetization.offers
	return offers and offers[offerName] == true or false
end

local function safeRequireUiModule(uiName: string, actionName: string): any?
	local clientFolder: Instance? = ReplicatedStorage:FindFirstChild("client")
	local uiFolder: Instance? = clientFolder and clientFolder:FindFirstChild("ui")
	if not uiFolder then
		Logger.warn(`No UI folder found in ReplicatedStorage for action {actionName}!`)

		return
	end

	local moduleScript: Instance? = uiFolder:FindFirstChild(uiName)
	if not moduleScript then
		Logger.warn(`No UI ModuleScript found with name "{uiName}" for action {actionName}!`)

		return
	end

	if not moduleScript:IsA("ModuleScript") then
		Logger.warn(
			`UI object "{uiName}" is not a ModuleScript (got {moduleScript.ClassName}) for action {actionName}!`
		)
		return
	end

	local ok: boolean, result: any = xpcall(require, Logger.warn, moduleScript)
	if not ok then
		Logger.warn(`Failed to require UI module "{uiName}" for action {actionName}: {result}`)
		return
	end

	return result
end

local RaycastActions = {
	Notification = function(instance: Instance, leaving: boolean?): boolean?
		if leaving then
			return
		end

		local raycastActionValue: string = instance:GetAttribute("RaycastActionValue") :: string
		if not raycastActionValue then
			Logger.warn(`No RaycastActionValue attribute found on instance "{instance}" for action Notification!`)

			return
		end

		if not CooldownManager:IsReady("Notification") then
			return
		end
		CooldownManager:Set("Notification", (instance:GetAttribute("seconds") :: number) + 2 or 5)

		local payload: any = {
			text = raycastActionValue,
		}

		for key: string, value: any in instance:GetAttributes() do
			if key:find("^RaycastAction") then
				continue
			end

			payload[key] = value
		end

		GetBridge("Notification"):Fire(payload)

		return true
	end,

	OpenWindow = function(instance: Instance, leaving: boolean?): boolean?
		local raycastActionValue: string = instance:GetAttribute("RaycastActionValue") :: string
		if not raycastActionValue then
			Logger.warn(`No RaycastActionValue attribute found on instance "{instance}" for action OpenWindow!`)
			return
		end

		local module: any? = safeRequireUiModule(raycastActionValue, "OpenWindow")
		if not module then
			return
		end

		local target: any = TagManager:FindLocalTagClass(raycastActionValue) or module

		local openArg: any = instance:GetAttribute("RaycastActionArg")

		if not leaving then
			OpenGui:Open(target, openArg)

			return true
		else
			OpenGui:Close(target)

			return false
		end
	end,

	PromptPurchase = function(instance: Instance, leaving: boolean?): boolean?
		if leaving then
			return
		end

		local name: string = instance:GetAttribute("RaycastActionValue") :: string
		if not name then
			Logger.warn(`No RaycastActionValue attribute found on instance "{instance}" for action PromptPurchase!`)

			return
		end

		local productName: string? = instance:GetAttribute("RaycastActionArg") :: any
		local isGamePass: boolean = instance:GetAttribute("IsGamePass") == true
		if not isGamePass then
			local itemKey: string?, entry: any? = getLimitedItemEntry(name, productName)
			if isLimitedRodEntry(itemKey, entry) then
				local offerName: string? = getOfferName(entry)
				if isOfferOwned(offerName) then
					if CollectionService:HasTag(instance, "RaycastDetect") then
						CollectionService:RemoveTag(instance, "RaycastDetect")
					end

					return
				end
			end
		end

		if not CooldownManager:IsReady("PromptPurchase") then
			return
		end
		CooldownManager:Set("PromptPurchase", 1)

		MonetizationPrompt:Fire({
			name = name,
			productName = productName,
			isGamePass = isGamePass,
		})

		return true
	end,
}

return RaycastActions
