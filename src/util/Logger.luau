--!nocheck
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RunService = game:GetService("RunService")
local TestService = game:GetService("TestService")

local GameConfig = require(ReplicatedStorage.shared.config.GameConfig)

export type Logger = {
	warn: (...string) -> (),
	print: (...string) -> (),
	error: (...string) -> (),
	errorStack: (...string) -> (),
	assert: (boolean?, ...string) -> (),
}

local Logger: Logger = {} :: any

local DEBUG_LOG_LOGGER: boolean = false

local kindFunctions = {
	["print"] = print,
	["warn"] = warn,
	["error"] = function(...: string): ()
		TestService:Error(` ( {RunService:IsServer() and "Server" or "Client"} )  ` .. table.concat({ ... }, ", "))
	end,
	["errorStack"] = function(...: string): ()
		error(table.concat({ ... }, ", "), 0)
	end,
}

local function debugLog(...: string): ()
	if DEBUG_LOG_LOGGER then
		print(">> LOGGER DEBUG >>", ...)
	end
end

local function formatPrefix(name: string, line: number): string
	if line > 0 then
		return ("[ %s:%d ]  "):format(name, line)
	end

	return ("[ %s ]  "):format(name)
end

local function cleanFilenameFromSource(source: string): string
	return source:match("[^/\\]*$") or source
end

local function checkLoggingAllowance(): boolean
	return RunService:IsStudio() and GameConfig.debug.loggerShowInStudio
		or not RunService:IsStudio() and GameConfig.debug.loggerShowInGame
end

local function tryFrame(level: number): string?
	debugLog("tryFrame: level", tostring(level))

	local ok: boolean, sourceAny: string, lineAny: number = pcall(debug.info, level, "sl")
	if not ok then
		debugLog("tryFrame: debug.info failed", tostring(level))

		return nil
	end

	local sourceStr: string? = nil
	if type(sourceAny) == "string" then
		sourceStr = sourceAny
	end

	local line: number = 0
	if type(lineAny) == "number" then
		line = lineAny
	else
		local okLine: boolean, lineNum: number = pcall(debug.info, level, "l")
		if okLine and type(lineNum) == "number" then
			line = lineNum
		end
	end

	if not sourceStr or sourceStr == "" then
		debugLog("tryFrame: empty source", tostring(level))

		return nil
	end

	local filename: string = cleanFilenameFromSource(sourceStr)
	if filename == "" then
		filename = sourceStr
	end

	if filename ~= "" and not filename:match("Logger") then
		debugLog("tryFrame: using filename", filename, "line", tostring(line))

		return formatPrefix(filename, line)
	end

	debugLog("tryFrame: skipped frame", tostring(level))

	return nil
end

local function getSourceInfo(): string
	debugLog("getSourceInfo: scanning stack")

	if not debug or not debug.info then
		debugLog("getSourceInfo: debug not available")

		return "[ Debug unavailable ] "
	end

	for level: number = 2, 8 do
		local prefix: string? = tryFrame(level)
		if prefix then
			debugLog("getSourceInfo: found prefix at level", tostring(level), prefix)

			return prefix
		end
	end

	local ok: boolean, s: string = pcall(debug.info, 3, "s")
	if ok and type(s) == "string" and s ~= "" then
		local filename: string = cleanFilenameFromSource(s)
		if filename ~= "" and not filename:match("Logger") then
			local fallback: string = formatPrefix(filename, 0)

			debugLog("getSourceInfo: fallback to filename", fallback)

			return fallback
		end
	end

	debugLog("getSourceInfo: unknown source")

	return "[ Unknown ] "
end

local function emit(kind: string, parts: { string }): ()
	if not checkLoggingAllowance() then
		return
	end

	debugLog("emit:", kind, "called")

	if not RunService:IsStudio() then
		debugLog("emit:", kind, "skipped (not Studio)")

		return
	end

	local sourceInfo: string = getSourceInfo()
	local message: string = table.concat(parts, " ")

	debugLog("emit:", kind, "source:", sourceInfo, "message:", message)

	message = sourceInfo .. message

	local kindExec = kindFunctions[kind]
	if not kindExec then
		error(`Unknown kind "{kind}" for log:\n> {message}`)
	end

	kindExec(message)
end

Logger.warn = function(...: string): ()
	emit("warn", { ... })
end

Logger.print = function(...: string): ()
	emit("print", { ... })
end

Logger.error = function(...: string): ()
	emit("error", { ... })
end

Logger.errorStack = function(...: string): ()
	emit("errorStack", { ... })
end

Logger.assert = function(value: boolean?, ...: string): ()
	if not checkLoggingAllowance() then
		return
	end

	debugLog("assert called")

	if not RunService:IsStudio() then
		debugLog("assert skipped (not Studio)")
		return
	end

	if not value then
		local sourceInfo: string = getSourceInfo()
		local msg: string = table.concat({ ... }, " ")

		debugLog("assert failed:", sourceInfo, msg)
		assert(value, sourceInfo .. msg)
	else
		debugLog("assert passed")
		assert(value, table.concat({ ... }, " "))
	end
end

return Logger
