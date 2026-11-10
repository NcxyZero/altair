local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local APIDictionaries = require(ReplicatedStorage.shared.types.APIDictionaries)
local Bridgenet2 = require(ReplicatedStorage.package.Bridgenet2)
local Conditions = require(ReplicatedStorage.shared.modules.Conditions)
local CooldownManager = require(ReplicatedStorage.shared.modules.CooldownManager)
local GameConfig = require(ReplicatedStorage.shared.config.GameConfig)
local GetBridge = require(ReplicatedStorage.util.Core.GetBridge)
local InitializerTypes = require(ReplicatedStorage.shared.types.InitializerTypes)
local Logger = require(ReplicatedStorage.util.Core.Logger)
local Maid = require(ReplicatedStorage.package.Maid)
local MonetizationConfig = require(ReplicatedStorage.shared.config.MonetizationConfig)
local MonetizationExecs = require(ServerScriptService.server.serverConfig.MonetizationExecs)
local Promise = require(ReplicatedStorage.package.Promise)
local SecurePlayerAsync = require(ReplicatedStorage.util.Core.SecurePlayerAsync)
local ServerData = require(ServerScriptService.server.modules.ServerData)

local Notify = GetBridge("Notification")

-- MonetizationExecs.offers hook; receiptInfo is nil when the offer comes from a redeemed code
type OfferExec = (player: Player, offerName: string, receiptInfo: APIDictionaries.receiptInfo?) -> ()

export type ServerMonetization = {
	index: number?,
	type: string?,
	path: InitializerTypes.ServerPath,
	idIndexedMonetizationReference: { passes: { [string]: string }, products: { name: string, dataName: string? } },
	Start: (self: ServerMonetization) -> (),
	Init: (self: ServerMonetization) -> (),
	PlayerAdded: (self: ServerMonetization, player: Player) -> (),
	CheckGamePass: (self: ServerMonetization, player: Player, name: string) -> boolean,
	CheckOffer: (self: ServerMonetization, player: Player, name: string) -> boolean,
	GrantOffer: (
		self: ServerMonetization,
		player: Player,
		producer: any,
		offerName: string,
		receiptInfo: APIDictionaries.receiptInfo?
	) -> (),
	GrantReceipt: (
		self: ServerMonetization,
		receiptInfo: APIDictionaries.receiptInfo
	) -> Enum.ProductPurchaseDecision,
	ProceedGamePassPurchaseAsync: (
		self: ServerMonetization,
		player: Player,
		id: number
	) -> Promise.TypedPromise<boolean>,
	ProceedDevProductPurchaseAsync: (
		self: ServerMonetization,
		player: Player,
		id: number
	) -> Promise.TypedPromise<boolean>,
	PromptGamePassByNameAsync: (
		self: ServerMonetization,
		player: Player,
		name: string
	) -> Promise.TypedPromise<boolean>,
	PromptDevProductByNameAsync: (
		self: ServerMonetization,
		player: Player,
		name: string,
		productName: string?
	) -> Promise.TypedPromise<boolean>,
	PromptGamePassByDataAsync: (
		self: ServerMonetization,
		player: Player,
		set: MonetizationConfig.Data
	) -> Promise.TypedPromise<boolean>,
	PromptDevProductByDataAsync: (
		self: ServerMonetization,
		player: Player,
		set: MonetizationConfig.Data
	) -> Promise.TypedPromise<boolean>,
}

local ServerMonetization: ServerMonetization = {} :: ServerMonetization
ServerMonetization.type = "controller"
ServerMonetization.index = 2
ServerMonetization.idIndexedMonetizationReference = {} :: any

local SUPPORT_NOTIFICATION_COLOR: Color3 = Color3.new(0.85, 0.5, 0.9)
local PURCHASE_FAILURE_NOTIFICATION_COLOR: Color3 = Color3.fromRGB(255, 110, 110) -- colour of refused purchase notices
local GAMEPASS_OWNERSHIP_RETRY_COUNT: number = 3
local GAMEPASS_OWNERSHIP_RETRY_DELAY_SECONDS: number = 1
local GAMEPASS_PURCHASE_CONFIRM_ATTEMPTS: number = 12 -- ownership checks after a reported pass purchase; Roblox caches UserOwnsGamePassAsync, so the first ones can still say false
local GAMEPASS_PURCHASE_CONFIRM_DELAY_SECONDS: number = 5 -- seconds between those checks
local MAXIMUM_SAVED_PURCHASE_IDS: number = 50 -- PurchaseIds kept in the profile MetaTag; the oldest is dropped first
local PURCHASE_ID_META_TAG: string = "purchaseIds" -- ProfileService MetaTag whose saved copy confirms that a grant reached the DataStore
local PURCHASE_REQUEST_COOLDOWN: number = 0.75 -- minimum seconds between two purchase requests of one player; clients wait 1 s
local PURCHASE_REQUEST_COOLDOWN_KEY: string = "MonetizationPrompt" -- CooldownManager key of purchase requests
local VIP_ATTRIBUTE: string = "IsVIP" -- player attribute that mirrors ownership of the VIP game pass
local VIP_PASS_NAME: string = "VIP" -- MonetizationConfig.passes name that sets the VIP attribute

local processingPurchaseIds: { [string]: boolean } = {} -- receipts being granted or waiting for their save (up to one autosave); a concurrent call is retried later
local confirmingGamePasses: { [string]: boolean } = {} -- "<userId>:<passName>" of reported pass purchases whose ownership is being confirmed

local function notifyPurchaseRefused(player: Player, text: string): ()
	Notify:Fire(Bridgenet2.Players({ player }), {
		kind = "error",
		text = text,
		seconds = 4,
		color = PURCHASE_FAILURE_NOTIFICATION_COLOR,
	})
end

local function notifyLimitedPurchaseFailure(player: Player, reason: string?): ()
	local text: string = reason == "sold_out" and "This item is sold out!"
		or reason == "purchase_pending" and "Finish your current purchase first."
		or "This item is temporarily unavailable."

	notifyPurchaseRefused(player, text)
end

local function applyGamePassOwnership(player: Player, producer: any, passName: string, showNotification: boolean): ()
	if producer.secureAddGamePass then
		producer.secureAddGamePass(passName)
	end

	if passName == VIP_PASS_NAME then
		player:SetAttribute(VIP_ATTRIBUTE, true)
	end

	if not ServerData:SyncPlayerProfile(player) then
		Logger.warn(`Failed to sync game-pass grant passName={passName} player={player.Name}`)
	end

	if showNotification then
		Notify:Fire(Bridgenet2.Players({ player }), {
			text = "Thanks for your support!",
			seconds = 4,
			color = SUPPORT_NOTIFICATION_COLOR,
		})
	end
end

local function ownsGamePassWithRetry(
	player: Player,
	passName: string,
	passId: number,
	attempts: number?,
	delaySeconds: number?
): boolean
	local attemptCount: number = attempts or GAMEPASS_OWNERSHIP_RETRY_COUNT
	local retryDelay: number = delaySeconds or GAMEPASS_OWNERSHIP_RETRY_DELAY_SECONDS
	local attempt: number = 1
	local lastError: any = nil
	while attempt <= attemptCount and player.Parent do
		local success: boolean, ownsOrError: any = pcall(function(): boolean
			return MarketplaceService:UserOwnsGamePassAsync(player.UserId, passId)
		end)

		if success and ownsOrError == true then
			return true
		end

		if not success then
			lastError = ownsOrError
		end

		if attempt < attemptCount then
			task.wait(retryDelay)
		end

		attempt += 1
	end

	if lastError ~= nil then
		Logger.warn(
			`ServerMonetization: UserOwnsGamePassAsync failed for player={player.Name} passName={passName} passId={passId} error={tostring(
				lastError
			)}`
		)
	end

	return false
end

-- Roblox caches UserOwnsGamePassAsync, so right after a purchase it can still say false: the check repeats for about a
-- minute, and a pass it never confirms is granted on the next join (PlayerAdded). Studio test purchases create no
-- ownership, so there the prompt's report is enough.
local function confirmAndApplyGamePass(player: Player, passName: string, passId: number): ()
	local producer: any = ServerData:GetPlayerProducerAsync(player):expect()
	local state: any = producer:getState()
	if state.monetization and state.monetization.passes and state.monetization.passes[passName] == true then
		return
	end

	local confirmed: boolean = RunService:IsStudio()
		or ownsGamePassWithRetry(
			player,
			passName,
			passId,
			GAMEPASS_PURCHASE_CONFIRM_ATTEMPTS,
			GAMEPASS_PURCHASE_CONFIRM_DELAY_SECONDS
		)
	if not confirmed then
		Logger.warn(`ServerMonetization: unconfirmed purchase of passName={passName} by player={player.Name}`)

		return
	end

	if player.Parent then
		applyGamePassOwnership(player, producer, passName, true)
	end
end

local function grantReportedGamePass(player: Player, passName: string, passId: number): ()
	local confirmationKey: string = `{player.UserId}:{passName}`
	if confirmingGamePasses[confirmationKey] then
		return
	end

	confirmingGamePasses[confirmationKey] = true

	local success: boolean, errorMessage: any = pcall(confirmAndApplyGamePass, player, passName, passId)
	confirmingGamePasses[confirmationKey] = nil

	if not success then
		Logger.warn(`ServerMonetization: granting passName={passName} to player={player.Name} failed: {errorMessage}`)
	end
end

local function hasPurchaseId(metaTags: any, purchaseId: string): boolean
	local purchaseIds: any = metaTags and metaTags[PURCHASE_ID_META_TAG]

	return type(purchaseIds) == "table" and table.find(purchaseIds, purchaseId) ~= nil
end

-- Roblox never delivers an acknowledged receipt again, so the grant must be in the DataStore first: adds purchaseId to
-- the profile MetaTag, asks for a save and yields until MetaTagsLatest (the last saved MetaTags) holds it. A profile
-- released first returns NotProcessedYet. ProfileService 2.1.5 signals have no Wait, so MetaTagsLatest is polled.
local function acknowledgeWhenSaved(profileStore: any, purchaseId: string): Enum.ProductPurchaseDecision
	if not hasPurchaseId(profileStore.MetaData.MetaTags, purchaseId) then
		local savedPurchaseIds: any = profileStore.MetaData.MetaTags[PURCHASE_ID_META_TAG]
		local purchaseIds: { string } = type(savedPurchaseIds) == "table" and table.clone(savedPurchaseIds) or {}

		table.insert(purchaseIds, purchaseId)

		while #purchaseIds > MAXIMUM_SAVED_PURCHASE_IDS do
			table.remove(purchaseIds, 1)
		end

		profileStore:SetMetaTag(PURCHASE_ID_META_TAG, purchaseIds)
	end

	if profileStore:IsActive() and not hasPurchaseId(profileStore.MetaData.MetaTagsLatest, purchaseId) then
		profileStore:Save()
	end

	while profileStore:IsActive() do
		if hasPurchaseId(profileStore.MetaData.MetaTagsLatest, purchaseId) then
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end

		task.wait()
	end

	return Enum.ProductPurchaseDecision.NotProcessedYet
end

function ServerMonetization:ProceedGamePassPurchaseAsync(player: Player, id: number): Promise.TypedPromise<boolean>
	return SecurePlayerAsync(
		player,
		Promise.new(function(resolve: (boolean) -> (), _reject: () -> (), onCancel: ((() -> ())?) -> ()): ()
			if not player then
				return onCancel()
			end

			local maid: Maid.Maid = Maid.new()
			onCancel(function(): ()
				maid:DoCleaning()
			end)

			maid:GiveTask(
				MarketplaceService.PromptGamePassPurchaseFinished:Connect(
					function(eventPlayer: Player, gamePassId: number, wasPurchased: boolean): ()
						if eventPlayer == player and gamePassId == id then
							maid:DoCleaning()
							resolve(wasPurchased)
						end
					end
				)
			)

			MarketplaceService:PromptGamePassPurchase(player, id)

			return
		end)
	):catch(warn)
end

function ServerMonetization:ProceedDevProductPurchaseAsync(player: Player, id: number): Promise.TypedPromise<boolean>
	return SecurePlayerAsync(
		player,
		Promise.new(function(resolve: (boolean) -> (), _reject: () -> (), onCancel: ((() -> ())?) -> ()): ()
			if not player then
				return onCancel()
			end

			local maid: Maid.Maid = Maid.new()
			onCancel(function(): ()
				maid:DoCleaning()
			end)

			maid:GiveTask(
				MarketplaceService.PromptProductPurchaseFinished:Connect(
					function(userId: number, productId: number, isPurchased: boolean): ()
						if userId == player.UserId and productId == id then
							maid:DoCleaning()
							resolve(isPurchased)
						end
					end
				)
			)

			MarketplaceService:PromptProductPurchase(player, id)

			return
		end)
	):catch(warn)
end

function ServerMonetization:PromptGamePassByNameAsync(player: Player, name: string): Promise.TypedPromise<boolean>
	return Promise.new(function(resolve: (boolean) -> (), reject: (string) -> ()): ()
		local passId: number = MonetizationConfig.passes[name]
		if not passId then
			reject(`"{name}" is not a valid member of MonetizationConfig.passes`)
			return
		end

		local producer: any = ServerData:GetPlayerProducerAsync(player):expect()
		local state: any = producer:getState()
		local alreadyOwned: boolean = state.monetization
				and state.monetization.passes
				and state.monetization.passes[name] == true
			or false
		if alreadyOwned then
			notifyPurchaseRefused(player, "You already own this!")
			resolve(false)

			return
		end

		-- The PromptGamePassPurchaseFinished handler in Init grants the pass once the purchase is confirmed
		local status: boolean, value: boolean =
			SecurePlayerAsync(player, self:ProceedGamePassPurchaseAsync(player, passId)):await()

		resolve(status and value)
	end):catch(warn)
end

function ServerMonetization:PromptDevProductByNameAsync(
	player: Player,
	name: string,
	productName: string?
): Promise.TypedPromise<boolean>
	return Promise.new(function(resolve: (boolean) -> (), reject: (string) -> ()): ()
		local product: MonetizationConfig.DevProduct & any = MonetizationConfig.products[name]
		if not product then
			reject(`"{name}" is not a valid member of MonetizationConfig.products`)

			return
		end

		local justId: number? = type(product) == "number" and product or nil
		local data = type(product) ~= "number"
				and (productName and product.data and product.data[productName] or product)
			or nil
		if not justId and not data then
			reject(`"{productName}" is not a valid member of MonetizationConfig.products["{name}"]`)

			return
		end

		local promptId: number = justId or data.id
		if not promptId then
			reject(
				`No product id in MonetizationConfig.products["{name}"]{productName and `.data["{productName}"]` or ""}`
			)

			return
		end

		local configuredOffers: any = data and (data.offer or data.offers or product.offer or product.offers) or nil
		local offers: { string } = type(configuredOffers) == "string" and { configuredOffers }
			or type(configuredOffers) == "table" and configuredOffers
			or {}
		local monetizationState: any = #offers > 0
				and ServerData:GetPlayerProducerAsync(player):expect():getState().monetization
			or nil
		local ownedOffers: any = monetizationState and monetizationState.offers or {}
		for _index: number, offerName: string in offers do
			if ownedOffers[offerName] == true then
				notifyPurchaseRefused(player, "You already own this!")
				reject(`Offer "{offerName}" is already owned`)

				return
			end

			if ownedOffers[offerName] == nil and not GameConfig.core.monetizationOfferCreationAllowed then
				reject(`Offer "{offerName}" is not declared in the monetization profile offers`)

				return
			end
		end

		local isLimited: boolean = GameConfig.game.limitedItems[name] ~= nil
		local limitedController: any = self.path.controller.LimitedStockController
		local reserved: boolean = false
		if isLimited then
			if not limitedController then
				notifyLimitedPurchaseFailure(player, "unavailable")
				resolve(false)

				return
			end

			local accepted: boolean, reason: string? = limitedController:ReserveProduct(player, name)
			if not accepted then
				notifyLimitedPurchaseFailure(player, reason)
				resolve(false)

				return
			end

			reserved = true
		end

		local status: boolean, value: boolean =
			SecurePlayerAsync(player, self:ProceedDevProductPurchaseAsync(player, promptId)):await()

		if reserved then
			if status and value then
				limitedController:CommitReservation(player, name)
			else
				limitedController:ReleaseReservation(player, name)
			end
		end

		resolve(status and value)
	end):catch(warn)
end

function ServerMonetization:PromptGamePassByDataAsync(
	player: Player,
	set: MonetizationConfig.Data
): Promise.TypedPromise<boolean>
	return Promise.new(function(resolve: (boolean) -> (), reject: (string) -> ()): ()
		local id: number = type(set) == "number" and set or set.id
		if not id then
			reject(`Id property not found in "{set}"`)

			return
		end

		local status: boolean, value: boolean =
			SecurePlayerAsync(player, self:ProceedGamePassPurchaseAsync(player, id)):await()
		resolve(status and value)
	end):catch(warn)
end

function ServerMonetization:PromptDevProductByDataAsync(
	player: Player,
	set: MonetizationConfig.Data
): Promise.TypedPromise<boolean>
	return Promise.new(function(resolve: (boolean) -> (), reject: (string) -> ()): ()
		local id: number = type(set) == "number" and set or set.id
		if not id then
			reject(`Id property not found in "{set}"`)

			return
		end

		local status: boolean, value: boolean =
			SecurePlayerAsync(player, self:ProceedDevProductPurchaseAsync(player, id)):await()
		resolve(status and value)
	end):catch(warn)
end

function ServerMonetization:CheckGamePass(player: Player, name: string): boolean
	return Conditions:CheckCondition(player, "passes", name)
end

function ServerMonetization:PlayerAdded(player: Player): ()
	player:SetAttribute(VIP_ATTRIBUTE, false)

	task.spawn(function(): ()
		local producer = ServerData:GetPlayerProducerAsync(player):expect()
		local state = producer:getState()
		local storedPasses: any = state.monetization and state.monetization.passes
		for name: string, passId: number in MonetizationConfig.passes :: MonetizationConfig.GamePassSet do
			local owns: boolean = ownsGamePassWithRetry(player, name, passId)
			local storedOwns: boolean = storedPasses and storedPasses[name] == true
			if owns or storedOwns then
				applyGamePassOwnership(player, producer, name, false)
			end
		end
	end)
end

function ServerMonetization:CheckOffer(player: Player, name: string): boolean
	return Conditions:CheckCondition(player, "offers", name)
end

function ServerMonetization:GrantOffer(
	player: Player,
	producer: any,
	offerName: string,
	receiptInfo: APIDictionaries.receiptInfo?
): ()
	producer.secureAddOffer(offerName)

	local offerExec: OfferExec? = (MonetizationExecs.offers :: any)[offerName]
	if offerExec then
		offerExec(player, offerName, receiptInfo)
	end
end

function ServerMonetization:GrantReceipt(receiptInfo: APIDictionaries.receiptInfo): Enum.ProductPurchaseDecision
	local player: Player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local productId: string = tostring(receiptInfo.ProductId)
	local data = self.idIndexedMonetizationReference.products[productId]
	if not data then
		Logger.warn(`No idIndexed data for dev product (id: {productId})`)

		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local config = MonetizationConfig.products[data.name]
	local entryConfig = data.dataName
			and config
			and config.data
			and config.data[data.dataName]
			and config.data[data.dataName]
		or nil
	if not config then
		Logger.warn(
			`No dev product found in config with name: {data.name}{data.dataName and ` and entry name: {data.dataName}` or ""}`
		)

		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local productConfig: any = type(config) == "table" and config or {}
	local purchaseId: string = tostring(receiptInfo.PurchaseId)
	local alreadyGranted: boolean = false
	local profileStore: any = nil
	local success: boolean, errorMessage: any = pcall(function(): ()
		local profile: ServerData.ServerPlayerProfile =
			SecurePlayerAsync(player, ServerData:WaitForPlayerProfile(player)):expect()
		local producer: any = profile.producer
		local monetizationState: any = producer:getState().monetization
		local grantedPurchaseIds: any = monetizationState and monetizationState.purchaseIds

		profileStore = profile.profileStore

		-- a PurchaseId already in the profile or in its MetaTag was granted before, so that receipt is not granted again
		alreadyGranted = type(grantedPurchaseIds) == "table" and table.find(grantedPurchaseIds, purchaseId) ~= nil
			or hasPurchaseId(profileStore.MetaData.MetaTags, purchaseId)
		if alreadyGranted then
			return
		end

		local offers = (entryConfig and (entryConfig.offer or entryConfig.offers))
			or productConfig.offer
			or productConfig.offers
		offers = offers and type(offers) == "string" and { offers } or offers or {}

		local ownedOffers: any = monetizationState and monetizationState.offers or {}
		for _index: number, offerName: string in offers do
			if ownedOffers[offerName] == nil and not GameConfig.core.monetizationOfferCreationAllowed then
				error(`Offer "{offerName}" is not declared in the monetization profile offers`)
			end
		end

		local execs = (entryConfig and (entryConfig.exec or entryConfig.execs))
			or productConfig.exec
			or productConfig.execs
		execs = execs and type(execs) ~= "table" and { execs } or execs or {}
		for _index: number, execNameOrFunction: string | (...any) -> any in execs do
			local exec = type(execNameOrFunction) == "string" and MonetizationExecs.execs[execNameOrFunction]
				or type(execNameOrFunction) == "function" and execNameOrFunction
			if not exec then
				Logger.warn(`No exec found with name: {execNameOrFunction}`)
				continue
			end

			local grantResult: unknown = exec(player, data, config, receiptInfo)
			if grantResult == false then
				error(`Dev product grant rejected by exec: {tostring(execNameOrFunction)}`)
			end
		end

		for _index: number, offerName: string in offers do
			self:GrantOffer(player, producer, offerName, receiptInfo)
		end

		-- recorded only after every exec and offer succeeded, so a rejected receipt is retried in full
		producer.secureAddPurchaseId(purchaseId)

		if not ServerData:SyncPlayerProfile(player) then
			error("Failed to sync the granted purchase to the player profile")
		end
	end)
	if not success then
		Logger.warn(`Failed to grant dev product id={productId} to {player.Name}: {errorMessage}`)

		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	if alreadyGranted then
		return acknowledgeWhenSaved(profileStore, purchaseId)
	end

	local limitedController: any = self.path.controller.LimitedStockController
	if limitedController and limitedController:IsLimitedProduct(data.name) then
		limitedController:CompletePurchase(player, data.name)
	end

	Notify:Fire(Bridgenet2.Players({ player }), {
		text = "Thanks for your support!",
		seconds = 4,
		color = SUPPORT_NOTIFICATION_COLOR,
	})

	return acknowledgeWhenSaved(profileStore, purchaseId)
end

function ServerMonetization:Start(): ()
	MarketplaceService.ProcessReceipt = function(receiptInfo: APIDictionaries.receiptInfo): Enum.ProductPurchaseDecision
		local purchaseId: string = tostring(receiptInfo.PurchaseId)
		if processingPurchaseIds[purchaseId] then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end

		processingPurchaseIds[purchaseId] = true

		local success: boolean, decision: any = pcall(self.GrantReceipt, self, receiptInfo)
		processingPurchaseIds[purchaseId] = nil
		if not success then
			Logger.warn(`Failed to process receipt purchaseId={purchaseId}: {decision}`)

			return Enum.ProductPurchaseDecision.NotProcessedYet
		end

		return decision
	end
end

function ServerMonetization:Init(): ()
	GetBridge("MonetizationPrompt"):Connect(
		function(player: Player, data: { name: string, isGamePass: boolean?, productName: string? } | any): ()
			if not CooldownManager:IsReady(player, PURCHASE_REQUEST_COOLDOWN_KEY) then
				return
			end

			CooldownManager:Set(player, PURCHASE_REQUEST_COOLDOWN_KEY, PURCHASE_REQUEST_COOLDOWN)

			if typeof(data) ~= "table" then
				return
			end

			local name: any = data.name
			if typeof(name) ~= "string" then
				return
			end

			local productName: any = data.productName
			if productName ~= nil and typeof(productName) ~= "string" then
				productName = nil
			end

			local isGamePass: boolean = data.isGamePass == true
			local request: Promise.TypedPromise<boolean>
			if isGamePass then
				request = self:PromptGamePassByNameAsync(player, name)
			else
				request = self:PromptDevProductByNameAsync(player, name, productName)
			end

			local resolvedSuccess: boolean = false
			local resolvedError: any = nil

			request
				:andThen(function(status: boolean): ()
					resolvedSuccess = status == true
				end)
				:catch(function(err: any): ()
					resolvedSuccess = false
					resolvedError = err
				end)
				:finally(function(): ()
					GetBridge("MonetizationPrompt"):Fire(player, {
						name = name,
						isGamePass = isGamePass,
						productName = productName,
						success = resolvedSuccess,
						completed = true,
						error = resolvedError,
					})
				end)
		end
	)

	self.idIndexedMonetizationReference.passes = {}
	for name: string, id: number in MonetizationConfig.passes :: MonetizationConfig.GamePassSet do
		self.idIndexedMonetizationReference.passes[tostring(id)] = name
	end

	self.idIndexedMonetizationReference.products = {}
	for name: string, data: MonetizationConfig.DevProductData & any in MonetizationConfig.products :: any do
		local products = self.idIndexedMonetizationReference.products
		local id: string? = type(data) == "number" and data or data.id
		id = id and tostring(id) or nil
		if id then
			products[id] = {
				name = name,
			}
		elseif type(data) == "table" and data.data then
			for dataEntryName: string, entryData: MonetizationConfig.Data & any in data.data :: any do
				id = entryData.id and tostring(entryData.id) or nil
				if not id then
					Logger.warn(`Invalid DevProductData for "{dataEntryName}" in "{name}", no id found!`)

					continue
				end

				if products[id] then
					local oldData = { products[id].name, products[id].dataName }
					local newData = { name, dataEntryName }

					Logger.warn(
						`Dev product with id {id} is already indexed!`
							.. ` Overwriting "{table.concat(oldData, `", "`)}" with "{table.concat(newData, `", "`)}"...`
					)
				end

				products[id] = {
					name = name,
					dataName = dataEntryName,
				}
			end
		else
			Logger.warn(`Invalid DevProductData for "{name}", no id or data found!`)
		end
	end

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(
		function(player: Player, passId: number, wasPurchased: boolean): ()
			if not wasPurchased then
				return
			end

			local passName: string? = self.idIndexedMonetizationReference.passes[tostring(passId)]
			if passName then
				grantReportedGamePass(player, passName, passId)
			end
		end
	)
end

return ServerMonetization
