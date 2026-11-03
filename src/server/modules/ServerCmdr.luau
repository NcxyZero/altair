local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Cmdr = require(ReplicatedStorage.package.Cmdr)
local InitializerTypes = require(ReplicatedStorage.shared.types.InitializerTypes)
local Logger = require(ReplicatedStorage.util.Core.Logger)

export type Default = {
	index: number?,
	type: string?,
	path: InitializerTypes.ServerPath,
	Init: (self: Default) -> (),
}

local ServerCmdr: Default = {} :: Default
ServerCmdr.type = "controller"

local REGISTERED_ATTRIBUTE: string = "Registered" -- CmdrClient attribute set last: the module count of Commands and Types

-- server parts of Cmdr's var and var= in its built-in Utility commands; see startVarDataStoreChecks
local VAR_SERVER_MODULE_NAMES: { string } = { "varServer", "varSetServer" }

local cmdrFolder: Folder & any = ServerScriptService.server:WaitForChild("cmdr")

-- Cmdr's var and var= check Cmdr's DataStore once, when their server parts are first required, and a call that
-- arrives before that check ends waits in a coroutine queue whose answer never reaches the RemoteFunction, so the
-- client waits forever. Requiring them when this module loads starts the check long before Init registers Cmdr and
-- a client that waits for REGISTERED_ATTRIBUTE sends its first var (Cmdr's init-run line does at once).
local function startVarDataStoreChecks(): ()
	local utility: Instance? = Cmdr.DefaultCommandsFolder:FindFirstChild("Utility")
	if not utility then
		return
	end

	for _index: number, moduleName: string in VAR_SERVER_MODULE_NAMES do
		local varModule: Instance? = utility:FindFirstChild(moduleName)
		if varModule and varModule:IsA("ModuleScript") then
			require(varModule :: any)
		end
	end
end

-- Cmdr's client registers only the commands, types and hooks that ReplicatedStorage.CmdrClient holds when it is
-- required, so ClientCmdr requires it only once it has received as many modules as REGISTERED_ATTRIBUTE says.
function ServerCmdr:Init(): ()
	local success: boolean, message: unknown = xpcall(function(): ()
		Cmdr:RegisterHooksIn(cmdrFolder.hooks)
		Cmdr:RegisterTypesIn(cmdrFolder.types)
		Cmdr:RegisterDefaultCommands()
		Cmdr:RegisterCommandsIn(cmdrFolder.commands)
	end, debug.traceback)

	-- also after a failure, so clients load what was registered instead of waiting for the attribute forever
	local replicatedRoot: any = Cmdr.ReplicatedRoot
	local moduleCount: number = #replicatedRoot.Commands:GetChildren() + #replicatedRoot.Types:GetChildren()

	replicatedRoot:SetAttribute(REGISTERED_ATTRIBUTE, moduleCount)

	if not success then
		Logger.warn(`Cmdr registration failed: {message}`)
	end
end

startVarDataStoreChecks()

return ServerCmdr
