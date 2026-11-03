local ContentProvider = game:GetService("ContentProvider")
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local StarterGui = game:GetService("StarterGui")

local LocalPlayer: Player = Players.LocalPlayer
local playerGui: PlayerGui = LocalPlayer:WaitForChild("PlayerGui") :: PlayerGui

local CLIENT_BOOTSTRAP_READY_ATTRIBUTE: string = "ClientBootstrapReady" -- set to true by src/exec/main.client.luau
local CLIENT_BOOTSTRAP_TIMEOUT_SECONDS: number = 25 -- longest wait for the client initializer after the data wait
local CONTROLS_RESTORE_ATTEMPTS: number = 5 -- attempts to re-enable the PlayerModule controls
local CONTROLS_RESTORE_DELAY_SECONDS: number = 0.1 -- delay between the PlayerModule controls attempts
local DATA_LOAD_TIMEOUT_SECONDS: number = 25 -- longest wait for the player data
local ESSENTIAL_PRELOAD_TIMEOUT_SECONDS: number = 2 -- head start of the LoadingUI assets before other preloads
local FREEZE_ACTION: string = "LoadingFreezeMovement" -- own action, so releasing it never unfreezes other systems
local GAMEPLAY_GUI_TIMEOUT_SECONDS: number = 25 -- longest wait for the gameplay ScreenGuis before preloading them
local LOADING_GUI_NAME: string = "LoadingUI" -- ReplicatedFirst template; other PlayerGui copies are destroyed
local LOADING_RELEASED_ATTRIBUTE: string = "LoadingReleased" -- set to true on the local player as the last release step
local MAX_CORE_GUI_ATTEMPTS: number = 200 -- attempts to apply the CoreGui state
local PLAYER_MODULE_TIMEOUT_SECONDS: number = 25 -- longest wait for the PlayerModule in PlayerScripts
local PRELOAD_BATCH_SIZE: number = 8 -- assets per background PreloadAsync call
local RETRY_DELAY_SECONDS: number = 0.05 -- delay between the CoreGui attempts

-- gameplay ScreenGuis hidden while the loading screen is shown
local GAMEPLAY_GUI_NAMES: { [string]: boolean } = {
	MainUI = true,
}

local essentialPreloadPending: boolean = false -- true while the LoadingUI assets are preloading
local loadingActive: boolean = true -- false once the loading locks are released
local topbarPlusEnabled: boolean = true -- last requested TopbarPlus visibility
local topbarPlusLoadStarted: boolean = false -- true once TopbarPlus is being required

local hiddenGameplayGuis: { [ScreenGui]: boolean } = {} -- authored Enabled values of the hidden gameplay ScreenGuis
local preloadedInstances: { [Instance]: boolean } = {} -- preloaded instances, cleared after the background preload

local gameplayGuiConnection: RBXScriptConnection? -- plain connection, because packages may not be replicated yet
local loadingGui: ScreenGui?
local playerControls: any
local topbarPlus: any

local function getErrorTraceback(rawError: unknown): string
	return debug.traceback(tostring(rawError))
end

local function sinkPlayerAction(): Enum.ContextActionResult
	return Enum.ContextActionResult.Sink
end

local function setCharacterControlsEnabled(enabled: boolean): ()
	if enabled then
		ContextActionService:UnbindAction(FREEZE_ACTION)

		return
	end

	ContextActionService:BindActionAtPriority(
		FREEZE_ACTION,
		sinkPlayerAction,
		false,
		Enum.ContextActionPriority.High.Value,
		unpack(Enum.PlayerActions:GetEnumItems())
	)
end

local function disablePlayerModuleControls(): ()
	local playerScripts: PlayerScripts = LocalPlayer:WaitForChild("PlayerScripts") :: PlayerScripts
	local playerModule: ModuleScript = playerScripts:WaitForChild("PlayerModule", PLAYER_MODULE_TIMEOUT_SECONDS) :: any
	if not playerModule or not loadingActive then
		return
	end

	local success: boolean, result: any = pcall(require, playerModule)
	if not success then
		warn(`Failed to load the PlayerModule while locking the loading controls: {result}`)

		return
	end

	if type(result) ~= "table" or type(result.GetControls) ~= "function" or not loadingActive then
		return
	end

	playerControls = result:GetControls()

	playerControls:Disable()
end

local function enablePlayerModuleControls(): ()
	if not playerControls then
		return
	end

	for attempt: number = 1, CONTROLS_RESTORE_ATTEMPTS do
		local success: boolean, errorMessage: unknown = pcall(function(): ()
			playerControls:Enable()
		end)
		if success then
			return
		end

		if attempt == CONTROLS_RESTORE_ATTEMPTS then
			warn(`Failed to restore the PlayerModule controls after loading: {errorMessage}`)

			return
		end

		task.wait(CONTROLS_RESTORE_DELAY_SECONDS)
	end
end

local function loadTopbarPlus(): ()
	if not game:IsLoaded() then
		game.Loaded:Wait()
	end

	local packageFolder: Instance? = ReplicatedStorage:FindFirstChild("package")
	local topbarPlusModule: Instance = packageFolder and packageFolder:FindFirstChild("topbarplus") :: any
	if not topbarPlusModule or not topbarPlusModule:IsA("ModuleScript") then
		return
	end

	local success: boolean, result: any = pcall(require, topbarPlusModule)
	if not success or type(result) ~= "table" or type(result.setTopbarEnabled) ~= "function" then
		warn(`Failed to load TopbarPlus while hiding it during loading: {result}`)

		return
	end

	topbarPlus = result

	topbarPlus.setTopbarEnabled(topbarPlusEnabled)
end

local function setTopbarPlusEnabled(enabled: boolean): ()
	topbarPlusEnabled = enabled

	if topbarPlus then
		topbarPlus.setTopbarEnabled(enabled)

		return
	end

	if topbarPlusLoadStarted then
		return
	end

	topbarPlusLoadStarted = true

	task.spawn(loadTopbarPlus)
end

local function setCoreGuiEnabled(enabled: boolean): boolean
	return xpcall(function(): ()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, enabled)

		if enabled then
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
		end
	end, warn)
end

local function applyCoreGuiState(enabled: boolean): ()
	setTopbarPlusEnabled(enabled)

	for _attempt: number = 1, MAX_CORE_GUI_ATTEMPTS do
		if not enabled and not loadingActive then
			return
		end

		if setCoreGuiEnabled(enabled) then
			return
		end

		task.wait(RETRY_DELAY_SECONDS)
	end
end

local function hideGameplayGui(instance: Instance): ()
	if
		not instance:IsA("ScreenGui")
		or not GAMEPLAY_GUI_NAMES[instance.Name]
		or hiddenGameplayGuis[instance] ~= nil
	then
		return
	end

	hiddenGameplayGuis[instance] = instance.Enabled

	instance.Enabled = false
end

local function hideGameplayGuis(): ()
	for _index: number, child: Instance in playerGui:GetChildren() do
		hideGameplayGui(child)
	end
end

local function restoreGameplayGuis(): ()
	for screenGui: ScreenGui, enabled: boolean in hiddenGameplayGuis do
		screenGui.Enabled = enabled
	end

	table.clear(hiddenGameplayGuis)
end

local function isLoadingGuiCopy(instance: Instance): boolean
	return instance ~= loadingGui and instance.Name == LOADING_GUI_NAME and instance:IsA("ScreenGui")
end

local function destroyLoadingGuiCopies(): ()
	for _index: number, child: Instance in playerGui:GetChildren() do
		if isLoadingGuiCopy(child) then
			child:Destroy()
		end
	end
end

local function onPlayerGuiChildAdded(child: Instance): ()
	if not loadingActive then
		return
	end

	-- A copy that arrives later, for example from StarterGui, would otherwise stay on screen after the release. The
	-- destroy is deferred, because an instance cannot be reparented while it is being parented.
	if isLoadingGuiCopy(child) then
		task.defer(child.Destroy, child)

		return
	end

	hideGameplayGui(child)
end

local function getOrCloneLoadingGui(): ScreenGui?
	local template: Instance? = ReplicatedFirst:FindFirstChild(LOADING_GUI_NAME)
	if template and template:IsA("ScreenGui") then
		local clone: ScreenGui = template:Clone()
		clone.ResetOnSpawn = false
		clone.Parent = playerGui

		return clone
	end

	local existing: Instance? = playerGui:FindFirstChild(LOADING_GUI_NAME)
	if not existing or not existing:IsA("ScreenGui") then
		return
	end

	existing.ResetOnSpawn = false

	return existing
end

local function isPreloadableInstance(instance: Instance): boolean
	return instance:IsA("ImageLabel")
		or instance:IsA("ImageButton")
		or instance:IsA("Decal")
		or instance:IsA("Texture")
		or instance:IsA("MeshPart")
		or instance:IsA("SpecialMesh")
		or instance:IsA("Sound")
		or instance:IsA("Animation")
		or instance:IsA("ParticleEmitter")
		or instance:IsA("Beam")
		or instance:IsA("Trail")
		or instance:IsA("SurfaceAppearance")
end

local function collectPreloadTargets(root: Instance): { Instance }
	local targets: { Instance } = {}

	for _index: number, descendant: Instance in root:GetDescendants() do
		if preloadedInstances[descendant] or not isPreloadableInstance(descendant) then
			continue
		end

		preloadedInstances[descendant] = true

		table.insert(targets, descendant)
	end

	return targets
end

local function preloadTargets(targets: { Instance }, batchSize: number): ()
	for startIndex: number = 1, #targets, batchSize do
		local batch: { Instance } = {}

		for targetIndex: number = startIndex, math.min(startIndex + batchSize - 1, #targets) do
			table.insert(batch, targets[targetIndex])
		end

		local success: boolean, errorMessage: unknown = xpcall(function(): ()
			ContentProvider:PreloadAsync(batch)
		end, getErrorTraceback)
		if not success then
			warn(`Failed to preload a loading asset batch: {errorMessage}`)
		end

		task.wait()
	end
end

local function preloadLoadingGui(shownLoadingGui: ScreenGui): ()
	local targets: { Instance } = collectPreloadTargets(shownLoadingGui)

	preloadTargets(targets, math.max(#targets, 1))

	essentialPreloadPending = false
end

local function preloadBackgroundAssets(): ()
	local essentialDeadline: number = os.clock() + ESSENTIAL_PRELOAD_TIMEOUT_SECONDS
	while essentialPreloadPending and os.clock() < essentialDeadline do
		task.wait()
	end

	if not game:IsLoaded() then
		game.Loaded:Wait()
	end

	for guiName: string, _isGameplayGui: boolean in GAMEPLAY_GUI_NAMES do
		playerGui:WaitForChild(guiName, GAMEPLAY_GUI_TIMEOUT_SECONDS)
	end

	preloadTargets(collectPreloadTargets(playerGui), PRELOAD_BATCH_SIZE)

	-- Runtime templates and sounds as well, so their first use does not wait for their assets.
	local sharedFolder: Instance? = ReplicatedStorage:FindFirstChild("shared")
	local modelFolder: Instance? = sharedFolder and sharedFolder:FindFirstChild("model")
	if modelFolder then
		preloadTargets(collectPreloadTargets(modelFolder), PRELOAD_BATCH_SIZE)
	end

	preloadTargets(collectPreloadTargets(SoundService), PRELOAD_BATCH_SIZE)

	table.clear(preloadedInstances)
end

local function showLoadingGui(): ()
	loadingGui = getOrCloneLoadingGui()
	if not loadingGui then
		return
	end

	loadingGui.Enabled = true

	ReplicatedFirst:RemoveDefaultLoadingScreen()

	destroyLoadingGuiCopies()
	hideGameplayGuis()

	gameplayGuiConnection = playerGui.ChildAdded:Connect(onPlayerGuiChildAdded)

	essentialPreloadPending = true

	task.spawn(preloadLoadingGui, loadingGui)
end

local function waitForPlayerData(): ()
	local success: boolean, errorMessage: unknown = xpcall(function(): ()
		local ClientData = require(ReplicatedStorage.client.modules.ClientData)

		ClientData:GetPlayerProducerAsync():timeout(DATA_LOAD_TIMEOUT_SECONDS):expect()
	end, getErrorTraceback)
	if not success then
		warn(`Player data did not load before the loading screen was released: {errorMessage}`)
	end
end

local function waitForTrueAttribute(instance: Instance, attributeName: string, timeout: number): boolean
	local deadline: number = os.clock() + timeout
	while instance:GetAttribute(attributeName) ~= true do
		if os.clock() >= deadline then
			return false
		end

		task.wait()
	end

	return true
end

local function waitForClientBootstrap(): ()
	if waitForTrueAttribute(LocalPlayer, CLIENT_BOOTSTRAP_READY_ATTRIBUTE, CLIENT_BOOTSTRAP_TIMEOUT_SECONDS) then
		return
	end

	warn(
		`{CLIENT_BOOTSTRAP_READY_ATTRIBUTE} was not set within {CLIENT_BOOTSTRAP_TIMEOUT_SECONDS} seconds; a client controller may be yielding in Init or Start`
	)
end

local function runLoading(): ()
	local showSuccess: boolean, showError: unknown = xpcall(showLoadingGui, getErrorTraceback)
	if not showSuccess then
		warn(`Failed to show ReplicatedFirst.LoadingUI: {showError}`)
	end

	setCharacterControlsEnabled(false)

	task.spawn(disablePlayerModuleControls)
	task.spawn(applyCoreGuiState, false)
	task.spawn(preloadBackgroundAssets)

	if not game:IsLoaded() then
		game.Loaded:Wait()
	end

	waitForPlayerData()
	waitForClientBootstrap()
end

local function releaseLoading(): ()
	loadingActive = false

	setCharacterControlsEnabled(true)
	enablePlayerModuleControls()

	if gameplayGuiConnection then
		gameplayGuiConnection:Disconnect()
	end

	restoreGameplayGuis()
	destroyLoadingGuiCopies()

	if loadingGui then
		loadingGui:Destroy()
	end

	applyCoreGuiState(true)
end

local function firePlayerReady(): ()
	local success: boolean, errorMessage: unknown = xpcall(function(): ()
		local GetBridge = require(ReplicatedStorage:WaitForChild("util"):WaitForChild("Core"):WaitForChild("GetBridge"))

		GetBridge("PlayerReady"):Fire()
	end, getErrorTraceback)
	if not success then
		warn(`Failed to fire PlayerReady: {errorMessage}`)
	end
end

local loadingSuccess: boolean, loadingError: unknown = xpcall(runLoading, getErrorTraceback)
if not loadingSuccess then
	warn(`Loading failed before the client was ready: {loadingError}`)
end

local releaseSuccess: boolean, releaseError: unknown = xpcall(releaseLoading, getErrorTraceback)
if not releaseSuccess then
	warn(`Failed to release the loading locks: {releaseError}`)
end

LocalPlayer:SetAttribute(LOADING_RELEASED_ATTRIBUTE, true)

firePlayerReady()
