local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local APIDictionaries = require(ReplicatedStorage.shared.types.APIDictionaries)
local Conditions = require(ReplicatedStorage.shared.modules.Conditions)
local InitializerTypes = require(ReplicatedStorage.shared.types.InitializerTypes)
local Logger = require(ReplicatedStorage.util.Logger)
local Maid = require(ReplicatedStorage.package.Maid)
local MonetizationConfig = require(ReplicatedStorage.shared.config.MonetizationConfig)
local MonetizationExecs = require(ServerScriptService.server.serverConfig.MonetizationExecs)
local Promise = require(ReplicatedStorage.package.Promise)
local SecurePlayerAsync = require(ReplicatedStorage.util.SecurePlayerAsync)
local ServerData = require(ServerScriptService.server.modules.ServerData)

export type ServerMonetization = {
	index: number?,
	type: string?,
	path: InitializerTypes.ServerPath,
	idIndexedMonetizationReference: { passes: { [string]: string }, products: { name: string, dataName: string? } },
	Start: (self: ServerMonetization) -> (),
	Init: (self: ServerMonetization) -> (),
	CheckGamePass: (self: ServerMonetization, player: Player, name: string) -> boolean,
	CheckOffer: (self: ServerMonetization, player: Player, name: string) -> boolean,
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

function ServerMonetization:ProceedGamePassPurchaseAsync(player: Player, id: number): Promise.TypedPromise<boolean>
	return Promise.new(function(resolve: (boolean) -> (), _reject: () -> (), onCancel: (() -> ()) -> ()): ()
		MarketplaceService:PromptGamePassPurchase(player, id)

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
	end):catch(warn)
end

function ServerMonetization:ProceedDevProductPurchaseAsync(player: Player, id: number): Promise.TypedPromise<boolean>
	return Promise.new(function(resolve: (boolean) -> (), _reject: () -> (), onCancel: (() -> ()) -> ()): ()
		MarketplaceService:PromptProductPurchase(player, id)

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
	end):catch(warn)
end

function ServerMonetization:PromptGamePassByNameAsync(player: Player, name: string): Promise.TypedPromise<boolean>
	return Promise.new(function(resolve: (boolean) -> (), reject: (string) -> ()): ()
		local passId: number = MonetizationConfig.passes[name]
		if not passId then
			reject(`"{name}" is not a valid member of MonetizationConfig.passes`)
			return
		end

		local status: boolean, _value: boolean =
			SecurePlayerAsync(player, self:ProceedGamePassPurchaseAsync(player, passId)):await()
		resolve(status)
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
		local data = productName and type(product) ~= "number" and (product.data[productName] or product) or nil
		if not justId and not data then
			reject(`"{productName}" is not a valid member of MonetizationConfig.products["{name}"]`)
			return
		end

		local status: boolean, _value: boolean =
			SecurePlayerAsync(player, self:ProceedDevProductPurchaseAsync(player, justId or data.id)):await()
		resolve(status)
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

		local status: boolean, _value: boolean =
			SecurePlayerAsync(player, self:ProceedGamePassPurchaseAsync(player, id)):await()
		resolve(status)
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

		local status: boolean, _value: boolean =
			SecurePlayerAsync(player, self:ProceedDevProductPurchaseAsync(player, id)):await()
		resolve(status)
	end):catch(warn)
end

function ServerMonetization:CheckGamePass(player: Player, name: string): boolean
	return Conditions:CheckCondition(player, "passes", name)
end

function ServerMonetization:CheckOffer(player: Player, name: string): boolean
	return Conditions:CheckCondition(player, "offers", name)
end

function ServerMonetization:Start(): ()
	MarketplaceService.ProcessReceipt = function(receiptInfo: APIDictionaries.receiptInfo): Enum.ProductPurchaseDecision
		local player: Player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
		if not player then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end

		task.defer(function(): ()
			local productId: string = tostring(receiptInfo.ProductId)
			local data = self.idIndexedMonetizationReference.products[productId]
			if not data then
				Logger.warn(`No idIndexed data for dev product (id: {productId})`)
				return
			end

			local config = MonetizationConfig.products[data.name]
			--local entryConfig = data.dataName and config[data.dataName] or config
			if not config then
				Logger.warn(
					`No dev product found in config with name: {data.name}{data.dataName and ` and entry name: {data.dataName}` or ""}`
				)
				return
			end

			local execs = config.exec or config.execs
			execs = execs and type(execs) ~= "table" and { execs } or execs or {}
			for _index: number, execNameOrFunction: string | (...any) -> () in execs do
				local exec = type(execNameOrFunction) == "string" and MonetizationExecs.execs[execNameOrFunction]
					or type(execNameOrFunction) == "function" and execNameOrFunction
				if not exec then
					Logger.warn(`No exec found with name: {execNameOrFunction}`)
					continue
				end

				exec(player, data, config)
			end

			local offers = config.offer or config.offers
			offers = offers and type(offers) == "string" and { offers } or offers or {}
			local producer = ServerData:GetPlayerProducerAsync(player):expect()
			for _index: number, offerName: string in offers do
				producer.secureAddOffer(offerName)

				local offerExec: (() -> ())? = MonetizationExecs.offers[offerName]
				offerExec = offerExec and offerExec()
			end
		end)

		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
end

function ServerMonetization:Init(): ()
	self.idIndexedMonetizationReference.passes = {}
	for name: string, id: number in MonetizationConfig.passes do
		self.idIndexedMonetizationReference.passes[tostring(id)] = name
	end

	self.idIndexedMonetizationReference.products = {}
	for name: string, data: MonetizationConfig.DevProductData & any in MonetizationConfig.products do
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
end

return ServerMonetization
