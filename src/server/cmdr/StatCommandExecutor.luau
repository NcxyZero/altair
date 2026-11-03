local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ConvertCurrency = require(ReplicatedStorage.util.Core.ConvertCurrency)
local ServerData = require(ServerScriptService.server.modules.ServerData)

export type Operation = "add" | "set" | "subtract"
export type StatKey = "money" | "rebirths"

type StatConfig = {
	readValue: ((storedValue: any) -> number)?,
	actions: { [Operation]: string },
	displayName: string,
	stateKey: string,
	stateSlice: string,
}

type MutationResult = {
	value: number,
}

export type StatCommandExecutor = {
	AddRebirths: (context: any, players: { Player }, amount: number) -> string,
	Execute: (statKey: StatKey, operation: Operation, players: { Player }, amount: number) -> string,
	SetRebirths: (context: any, players: { Player }, amount: number) -> string,
	SubtractRebirths: (context: any, players: { Player }, amount: number) -> string,
}

local StatCommandExecutor: StatCommandExecutor = {} :: any

local MAXIMUM_SAFE_INTEGER: number = 9_007_199_254_740_991 -- 2^53 - 1, the largest integer a number stores exactly

-- Profile actions and stored state per stat; an operation without an action is rejected.
local STAT_CONFIGS: { [StatKey]: StatConfig } = {
	money = {
		readValue = ConvertCurrency.StringToNumber,
		actions = {
			add = "secureAddMoney",
			subtract = "secureSpendMoney",
		},
		displayName = "Money",
		stateKey = "money",
		stateSlice = "player",
	},
	rebirths = {
		actions = {
			add = "secureAddRebirth",
			set = "secureSetRebirth",
			subtract = "secureSubtractRebirth",
		},
		displayName = "Rebirths",
		stateKey = "rebirth",
		stateSlice = "player",
	},
}

function StatCommandExecutor.Execute(
	statKey: StatKey,
	operation: Operation,
	players: { Player },
	amount: number
): string
	if
		type(amount) ~= "number"
		or amount ~= amount
		or math.abs(amount) == math.huge
		or amount ~= amount // 1
		or amount < 0
		or amount > MAXIMUM_SAFE_INTEGER
	then
		return `Amount must be a whole number from 0 to {MAXIMUM_SAFE_INTEGER}.`
	end
	if #players == 0 then
		return "No players selected."
	end

	local statConfig: StatConfig = STAT_CONFIGS[statKey]
	local actionName: string = statConfig.actions[operation]
	if not actionName then
		return `{statConfig.displayName} does not support the {operation} operation.`
	end

	local results: { string } = {}

	for _index: number, player: Player in players do
		if player.Parent ~= Players then
			table.insert(results, `{player.Name}: player left the server`)

			continue
		end

		local success: boolean, resultOrError: any = pcall(function(): MutationResult
			local profile: ServerData.ServerPlayerProfile = ServerData:GetPlayerProfile(player) :: any
			if not profile then
				error("profile is not loaded", 0)
			end

			local producer: any = profile.producer
			local action: any = producer[actionName]
			if type(action) ~= "function" then
				error(`Profile action {actionName} is unavailable`, 0)
			end

			action(amount)

			local rootState: any = producer:getState()
			local stateSlice: any = rootState[statConfig.stateSlice]
			local storedValue: any = stateSlice and stateSlice[statConfig.stateKey]
			local readValue: ((storedValue: any) -> number)? = statConfig.readValue
			local value: number = if readValue then readValue(storedValue) else tonumber(storedValue) or 0

			return {
				value = value,
			}
		end)

		if success then
			local result: MutationResult = resultOrError

			table.insert(results, `{player.Name}: {statConfig.displayName} = {result.value}`)
		else
			table.insert(results, `{player.Name}: failed ({resultOrError})`)
		end
	end

	return table.concat(results, "\n")
end

function StatCommandExecutor.AddRebirths(_context: any, players: { Player }, amount: number): string
	return StatCommandExecutor.Execute("rebirths", "add", players, amount)
end

function StatCommandExecutor.SetRebirths(_context: any, players: { Player }, amount: number): string
	return StatCommandExecutor.Execute("rebirths", "set", players, amount)
end

function StatCommandExecutor.SubtractRebirths(_context: any, players: { Player }, amount: number): string
	return StatCommandExecutor.Execute("rebirths", "subtract", players, amount)
end

return StatCommandExecutor
