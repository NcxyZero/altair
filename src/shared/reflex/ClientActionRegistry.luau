export type Arguments = { [number]: any }
export type Validator = (arguments: Arguments) -> boolean
export type Registry = { [string]: Validator | false }

export type ClientActionRegistry = {
	BooleanArguments: (arguments: Arguments) -> boolean,
	Build: (profileModules: { [string]: any }) -> Registry,
	NoArguments: (arguments: Arguments) -> boolean,
	NumberArguments: (minimum: number, maximum: number) -> Validator,
	Resolve: (registry: Registry, payload: unknown) -> (string?, Arguments?, string?),
}

local ClientActionRegistry: ClientActionRegistry = {} :: ClientActionRegistry

local MAXIMUM_ACTION_NAME_LENGTH: number = 64
local MAXIMUM_ARGUMENT_COUNT: number = 8

local function getArgumentCount(arguments: Arguments): number?
	local count: number = 0

	for key: any in arguments do
		if type(key) ~= "number" or key < 1 or key % 1 ~= 0 then
			return
		end

		count += 1
		if count > MAXIMUM_ARGUMENT_COUNT then
			return
		end
	end

	for index: number = 1, count do
		if rawget(arguments, index) == nil then
			return
		end
	end

	return count
end

function ClientActionRegistry.BooleanArguments(arguments: Arguments): boolean
	return getArgumentCount(arguments) == 1 and type(arguments[1]) == "boolean"
end

function ClientActionRegistry.Build(profileModules: { [string]: any }): Registry
	local registry: Registry = {}

	for _profileName: string, profileModule: any in profileModules do
		local clientActions: any = profileModule.CLIENT_ACTIONS
		if type(clientActions) ~= "table" then
			continue
		end

		for actionName: any, validator: any in clientActions do
			if type(actionName) ~= "string" or type(validator) ~= "function" then
				continue
			end

			if registry[actionName] ~= nil then
				registry[actionName] = false
			else
				registry[actionName] = validator
			end
		end
	end

	return registry
end

function ClientActionRegistry.NoArguments(arguments: Arguments): boolean
	return getArgumentCount(arguments) == 0
end

function ClientActionRegistry.NumberArguments(minimum: number, maximum: number): Validator
	return function(arguments: Arguments): boolean
		if getArgumentCount(arguments) ~= 1 then
			return false
		end

		local value: any = arguments[1]
		if type(value) ~= "number" or value ~= value or math.abs(value) == math.huge then
			return false
		end

		return value >= minimum and value <= maximum
	end
end

function ClientActionRegistry.Resolve(registry: Registry, payload: unknown): (string?, Arguments?, string?)
	if type(payload) ~= "table" then
		return nil, nil, "payload_not_table"
	end

	local data: { [any]: any } = payload :: any
	for key: any in data do
		if key ~= "name" and key ~= "arguments" then
			return nil, nil, "payload_has_unknown_key"
		end
	end

	local actionName: any = data.name
	if type(actionName) ~= "string" or #actionName == 0 or #actionName > MAXIMUM_ACTION_NAME_LENGTH then
		return nil, nil, "invalid_action_name"
	end

	local arguments: any = data.arguments
	if type(arguments) ~= "table" or getArgumentCount(arguments) == nil then
		return nil, nil, "invalid_arguments"
	end

	local validator: Validator | false? = registry[actionName]
	if validator == nil then
		return nil, nil, "action_not_registered"
	end
	if validator == false then
		return nil, nil, "duplicate_action_registration"
	end

	local success: boolean, accepted: any = pcall(validator, arguments)
	if not success then
		return nil, nil, "validator_error"
	end
	if accepted ~= true then
		return nil, nil, "arguments_rejected"
	end

	return actionName, arguments, nil
end

return table.freeze(ClientActionRegistry)
