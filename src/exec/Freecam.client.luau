--!nonstrict
------------------------------------------------------------------------
-- FreeCameraIAS
-- Cinematic free camera for spectating and video production.
--
-- Default keybindings:
--
-- WASD / Thumbstick1 to move camera forward, left, backward, right
-- MouseButton2 / Thumbstick2 to rotate camera
-- Q,E / L2,R2 to move camera up, down
-- Z,C / L1,R1 to tilt camera left, right (double-tap to reset tilt)
-- Scroll / ButtonX,ButtonY to zoom FOV
-- P / ButtonR3 hold to preview Point Lock, release to lock (press again to unlock)
-- R / ButtonL3 to reset camera pose, FOV, and roll
--
-- Mode overlay (Up/DPadUp to show, Down/DPadDown to cycle modes):
--   Axis modes  → hold Left/Right to adjust continuously
--   Toggle modes → tap Left or Right to flip on/off
--   Cycle modes  → tap Left/Right to step through list
--   Action modes → tap Left or Right to fire once
-- Modes: Movement [group: Speed, Stiffness],
--        Rotation [group: Speed, Stiffness],
--        Roll [group: Speed, Stiffness],
--        Field of View [group: Speed, Stiffness],
--        Custom Post Processing [group: Enable, DoF fields, Bloom fields, Blur fields,
--          Color Correction fields, Sun Rays fields, Color Grading fields],
--        Player Lock [group: Enable, Target],
--        Point Lock [group: Enable],
--        UI [group: Screen GUIs, Leaderboard, Watermark],
--        Controls [info: binds],
--        Reset Freecam [action]
------------------------------------------------------------------------

local pi = math.pi
local clamp = math.clamp
local exp = math.exp
local rad = math.rad
local sqrt = math.sqrt
local tan = math.tan

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local StarterPlayer = game:GetService("StarterPlayer")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

------------------------------------------------------------------------

local Constants = {
	AttributeName = "FreecamEnabled",

	Thumbstick = {
		Curvature = 2.0,
	},

	DoubleTap = {
		Threshold = 0.25,
		Debounce = 0.1,
	},

	PlayerLock = {
		DefaultZoom = 20,
		MinZoom = 5,
		MaxZoom = 50,
		DefaultHeight = 0,
		HeightRange = 10,
	},

	PointLock = {
		DefaultZoom = 20,
		MinZoom = 5,
		MaxZoom = 50,
		DefaultHeight = 0,
		HeightRange = 10,
		RayLength = 2048,
	},

	Movement = {
		Gain = Vector3.new(1, 1, 1) * 64,
		AdjSpeed = 0.75,
		MinSpeed = 0.01,
		MaxSpeed = 4.0,
		ShiftMul = 0.25,
		Stiffness = 1.5,
		AdjStiffness = 0.75,
		MinStiffness = 0.01,
		MaxStiffness = 10.0,
	},

	Pan = {
		Gain = Vector2.new(0.75, 1) * 8,
		MouseScale = Vector2.new(pi / (64 * 60), -(pi / (64 * 60))),
		TrackpadScale = Vector2.new(pi * 14 / (64 * 60), -(pi * 14 / (64 * 60))),
		GamepadScale = Vector2.new(pi / 8, pi / 8),
		AdjSpeed = 0.75,
		MinSpeed = 0.01,
		MaxSpeed = 4.0,
		Stiffness = 1.0,
		AdjStiffness = 0.75,
		MinStiffness = 0.01,
		MaxStiffness = 10.0,
	},

	Fov = {
		Gain = 300,
		WheelScale = -0.01667,
		PinchScale = -0.008,
		GamepadScale = 0.25,
		AdjSpeed = 0.75,
		MinSpeed = 0.01,
		MaxSpeed = 4.0,
		Stiffness = 4.0,
		AdjStiffness = 0.75,
		MinStiffness = 0.01,
		MaxStiffness = 10.0,
	},

	Roll = {
		Gain = -pi / 2,
		AdjSpeed = 0.75,
		MinSpeed = 0.01,
		MaxSpeed = 4.0,
		Stiffness = 1.0,
		AdjStiffness = 0.75,
		MinStiffness = 0.01,
		MaxStiffness = 10.0,
	},

	DoF = {
		FarIntensity = { Adj = 0.1, Min = 0.0, Max = 1.0 },
		NearIntensity = { Adj = 0.1, Min = 0.0, Max = 1.0 },
		FocusDistance = { Adj = 20.0, Min = 0.0, Max = 200.0 },
		FocusRadius = { Adj = 5.0, Min = 0.0, Max = 50.0 },
	},

	Bloom = {
		Intensity = { Adj = 0.05, Min = 0.0, Max = 1.0 },
		Size = { Adj = 2.0, Min = 0.0, Max = 56.0 },
		Threshold = {
			Adj = 0.05,
			Min = 0.8,
			Max = 4.0,
		},
	},

	Blur = {
		Size = { Adj = 2.0, Min = 0.0, Max = 56.0 },
	},

	ColorCorrection = {
		Brightness = { Adj = 0.05, Min = -1.0, Max = 1.0 },
		Contrast = { Adj = 0.05, Min = -1.0, Max = 1.0 },
		Saturation = { Adj = 0.05, Min = -1.0, Max = 1.0 },
	},

	SunRays = {
		Intensity = { Adj = 0.05, Min = 0.0, Max = 1.0 },
		Spread = { Adj = 0.05, Min = 0.0, Max = 1.0 },
	},

	Keys = {
		Pan = {
			Mouse = Enum.KeyCode.MouseDelta,
			Trackpad = Enum.KeyCode.TrackpadPan,
			Gamepad = Enum.KeyCode.Thumbstick2,
		},

		MovementMove = {
			Keyboard = { Up = Enum.KeyCode.W, Down = Enum.KeyCode.S, Left = Enum.KeyCode.A, Right = Enum.KeyCode.D },
			Gamepad = Enum.KeyCode.Thumbstick1,
		},

		MovementElevate = {
			Keyboard = { Up = Enum.KeyCode.E, Down = Enum.KeyCode.Q },
			Gamepad = { Up = Enum.KeyCode.ButtonR2, Down = Enum.KeyCode.ButtonL2 },
		},

		ModeSelect = {
			Toggle = { Keyboard = Enum.KeyCode.Up, Gamepad = Enum.KeyCode.DPadUp },
			Next = { Keyboard = Enum.KeyCode.Down, Gamepad = Enum.KeyCode.DPadDown },
			Axis = {
				Up = { Keyboard = Enum.KeyCode.Right, Gamepad = Enum.KeyCode.DPadRight },
				Down = { Keyboard = Enum.KeyCode.Left, Gamepad = Enum.KeyCode.DPadLeft },
			},
		},

		Fov = {
			Mouse = Enum.KeyCode.MouseWheel,
			TrackpadPinch = Enum.KeyCode.TrackpadPinch,
			Gamepad = { Up = Enum.KeyCode.ButtonX, Down = Enum.KeyCode.ButtonY },
		},

		Tilt = {
			Keyboard = { Up = Enum.KeyCode.C, Down = Enum.KeyCode.Z },
			Gamepad = { Up = Enum.KeyCode.ButtonR1, Down = Enum.KeyCode.ButtonL1 },
		},

		Shift = {
			KeyboardPrimary = Enum.KeyCode.LeftShift,
			KeyboardSecondary = Enum.KeyCode.RightShift,
		},

		PointLock = {
			Keyboard = Enum.KeyCode.P,
			Gamepad = Enum.KeyCode.ButtonR3,
		},

		Reset = {
			Keyboard = Enum.KeyCode.R,
			Gamepad = Enum.KeyCode.ButtonL3,
		},
	},
}

Constants.Actions = {
	Pan = {
		name = "PanAction",
		type = Enum.InputActionType.Direction2D,
		bindings = {
			{ keyCode = Constants.Keys.Pan.Mouse, vector2Scale = Constants.Pan.MouseScale },
			{ keyCode = Constants.Keys.Pan.Trackpad, vector2Scale = Constants.Pan.TrackpadScale },
			{
				keyCode = Constants.Keys.Pan.Gamepad,
				responseCurve = Constants.Thumbstick.Curvature,
				vector2Scale = Constants.Pan.GamepadScale,
			},
		},
	},
	MovementMove = {
		name = "MovementMoveAction",
		type = Enum.InputActionType.Direction2D,
		bindings = {
			{
				up = Constants.Keys.MovementMove.Keyboard.Up,
				down = Constants.Keys.MovementMove.Keyboard.Down,
				left = Constants.Keys.MovementMove.Keyboard.Left,
				right = Constants.Keys.MovementMove.Keyboard.Right,
			},
			{ keyCode = Constants.Keys.MovementMove.Gamepad, responseCurve = Constants.Thumbstick.Curvature },
		},
	},
	MovementElevate = {
		name = "MovementElevateAction",
		type = Enum.InputActionType.Direction1D,
		bindings = {
			{ up = Constants.Keys.MovementElevate.Keyboard.Up, down = Constants.Keys.MovementElevate.Keyboard.Down },
			{ up = Constants.Keys.MovementElevate.Gamepad.Up, down = Constants.Keys.MovementElevate.Gamepad.Down },
		},
	},
	Fov = {
		name = "FovAction",
		type = Enum.InputActionType.Direction1D,
		bindings = {
			{ keyCode = Constants.Keys.Fov.Mouse, scale = Constants.Fov.WheelScale },
			{ keyCode = Constants.Keys.Fov.TrackpadPinch, scale = Constants.Fov.PinchScale },
			{
				up = Constants.Keys.Fov.Gamepad.Up,
				down = Constants.Keys.Fov.Gamepad.Down,
				scale = Constants.Fov.GamepadScale,
			},
		},
	},
	Tilt = {
		name = "TiltAction",
		type = Enum.InputActionType.Direction1D,
		bindings = {
			{ up = Constants.Keys.Tilt.Keyboard.Up, down = Constants.Keys.Tilt.Keyboard.Down },
			{ up = Constants.Keys.Tilt.Gamepad.Up, down = Constants.Keys.Tilt.Gamepad.Down },
		},
	},
	Shift = {
		name = "ShiftAction",
		type = Enum.InputActionType.Bool,
		bindings = {
			{ keyCode = Constants.Keys.Shift.KeyboardPrimary },
			{ keyCode = Constants.Keys.Shift.KeyboardSecondary },
		},
	},
	ModeToggle = {
		name = "ModeToggleAction",
		type = Enum.InputActionType.Bool,
		bindings = {
			{ keyCode = Constants.Keys.ModeSelect.Toggle.Keyboard },
			{ keyCode = Constants.Keys.ModeSelect.Toggle.Gamepad },
		},
	},
	ModeNext = {
		name = "ModeNextAction",
		type = Enum.InputActionType.Bool,
		bindings = {
			{ keyCode = Constants.Keys.ModeSelect.Next.Keyboard },
			{ keyCode = Constants.Keys.ModeSelect.Next.Gamepad },
		},
	},
	ModeRight = {
		name = "ModeRightAction",
		type = Enum.InputActionType.Bool,
		bindings = {
			{ keyCode = Constants.Keys.ModeSelect.Axis.Up.Gamepad },
		},
	},
	ModeLeft = {
		name = "ModeLeftAction",
		type = Enum.InputActionType.Bool,
		bindings = {
			{ keyCode = Constants.Keys.ModeSelect.Axis.Down.Gamepad },
		},
	},
	PointLock = {
		name = "PointLockAction",
		type = Enum.InputActionType.Bool,
		bindings = {
			{ keyCode = Constants.Keys.PointLock.Keyboard },
			{ keyCode = Constants.Keys.PointLock.Gamepad },
		},
	},
	Reset = {
		name = "ResetAction",
		type = Enum.InputActionType.Bool,
		bindings = {
			{ keyCode = Constants.Keys.Reset.Keyboard },
			{ keyCode = Constants.Keys.Reset.Gamepad },
		},
	},
}

local FREECAM_INPUT_PRIORITY = 2000

------------------------------------------------------------------------

local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then
	Players:GetPropertyChangedSignal("LocalPlayer"):Wait()
	LocalPlayer = Players.LocalPlayer
end

local freecamGui = nil

local Camera = Workspace.CurrentCamera
Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	local newCamera = Workspace.CurrentCamera
	if newCamera then
		Camera = newCamera
	end
end)

local FreecamDepthOfField = nil
local FreecamBloom = nil
local FreecamBlur = nil
local FreecamColorCorrection = nil
local FreecamSunRays = nil
local FreecamColorGrading = nil

local savedEffects = {
	DepthOfField = {
		Enabled = false,
		FarIntensity = 0.75,
		NearIntensity = 0.75,
		FocusDistance = 0.05,
		InFocusRadius = 10.0,
	},
	Bloom = { Enabled = false, Intensity = 0.4, Size = 24.0, Threshold = 0.95 },
	Blur = { Enabled = false, Size = 24.0 },
	ColorCorrection = {
		Enabled = false,
		Brightness = 0.0,
		Contrast = 0.0,
		Saturation = 0.0,
		TintColor = Color3.new(1, 1, 1),
	},
	SunRays = { Enabled = false, Intensity = 0.25, Spread = 1.0 },
	ColorGrading = { Enabled = false, TonemapperPreset = Enum.TonemapperPreset.Default },
}

local PlayerState = nil

-----------------------------------------------------------------------

local function makeEffectOverride(className, excludeFn)
	local suppressed = {}
	local camConn, lightConn

	local function disable()
		for _, e in ipairs(suppressed) do
			if e.Parent then
				e.Enabled = true
			end
		end
		if camConn then
			camConn:Disconnect()
			camConn = nil
		end
		if lightConn then
			lightConn:Disconnect()
			lightConn = nil
		end
		suppressed = {}
	end

	local function trySuppress(e)
		if e:IsA(className) and e.Enabled and (not excludeFn or not excludeFn(e)) then
			suppressed[#suppressed + 1] = e
			e.Enabled = false
		end
	end

	local function enable()
		suppressed = {}
		for _, e in ipairs(Camera:GetChildren()) do
			trySuppress(e)
		end
		for _, e in ipairs(Lighting:GetChildren()) do
			trySuppress(e)
		end
		camConn = Camera.ChildAdded:Connect(function(child)
			trySuppress(child)
		end)
		lightConn = Lighting.ChildAdded:Connect(function(child)
			trySuppress(child)
		end)
	end

	return enable, disable
end

-- suppress all post-processing effect instances other than ones that begin with "Freecam"
local masterEffectsEnabled = false
local enableMasterEffects, disableMasterEffects = makeEffectOverride("PostEffect", function(e)
	return e.Name:sub(1, 7) == "Freecam"
end)

local effectDefs

local function doToggleMasterEffects()
	masterEffectsEnabled = not masterEffectsEnabled
	if masterEffectsEnabled then
		enableMasterEffects()
	else
		disableMasterEffects()
		for _, def in ipairs(effectDefs) do
			local e = def.get()
			if e then
				e.Enabled = false
			end
		end
	end
end

local function doToggleDoF()
	if not masterEffectsEnabled then
		return
	end
	local e = FreecamDepthOfField
	if e then
		e.Enabled = not e.Enabled
	end
end
local function doToggleBloom()
	if not masterEffectsEnabled then
		return
	end
	local e = FreecamBloom
	if e then
		e.Enabled = not e.Enabled
	end
end
local function doToggleBlur()
	if not masterEffectsEnabled then
		return
	end
	local e = FreecamBlur
	if e then
		e.Enabled = not e.Enabled
	end
end
local function doToggleColorCorrection()
	if not masterEffectsEnabled then
		return
	end
	local e = FreecamColorCorrection
	if e then
		e.Enabled = not e.Enabled
	end
end
local function doToggleSunRays()
	if not masterEffectsEnabled then
		return
	end
	local e = FreecamSunRays
	if e then
		e.Enabled = not e.Enabled
	end
end
local function doToggleColorGrading()
	if not masterEffectsEnabled then
		return
	end
	local e = FreecamColorGrading
	if e then
		e.Enabled = not e.Enabled
	end
end

effectDefs = {
	{
		key = "DepthOfField",
		class = "DepthOfFieldEffect",
		get = function()
			return FreecamDepthOfField
		end,
		set = function(v)
			FreecamDepthOfField = v
		end,
		props = { "FarIntensity", "NearIntensity", "FocusDistance", "InFocusRadius" },
	},
	{
		key = "Bloom",
		class = "BloomEffect",
		get = function()
			return FreecamBloom
		end,
		set = function(v)
			FreecamBloom = v
		end,
		props = { "Intensity", "Size", "Threshold" },
	},
	{
		key = "Blur",
		class = "BlurEffect",
		get = function()
			return FreecamBlur
		end,
		set = function(v)
			FreecamBlur = v
		end,
		props = { "Size" },
	},
	{
		key = "ColorCorrection",
		class = "ColorCorrectionEffect",
		get = function()
			return FreecamColorCorrection
		end,
		set = function(v)
			FreecamColorCorrection = v
		end,
		props = { "Brightness", "Contrast", "Saturation", "TintColor" },
	},
	{
		key = "SunRays",
		class = "SunRaysEffect",
		get = function()
			return FreecamSunRays
		end,
		set = function(v)
			FreecamSunRays = v
		end,
		props = { "Intensity", "Spread" },
	},
	{
		key = "ColorGrading",
		class = "ColorGradingEffect",
		parent = Lighting,
		get = function()
			return FreecamColorGrading
		end,
		set = function(v)
			FreecamColorGrading = v
		end,
		props = { "TonemapperPreset" },
	},
}

local playerGuiConnection = nil
local playerAddedConnection = nil
local playerRemovingConnection = nil

local playerLockEnabled = false
local playerLockZoom = Constants.PlayerLock.DefaultZoom
local playerLockHeight = Constants.PlayerLock.DefaultHeight
local playerList = {}
local currentTargetIndex = 1
local rootPart = nil

local pointLockEnabled = false
local pointLockZoom = Constants.PointLock.DefaultZoom
local pointLockHeight = Constants.PointLock.DefaultHeight
local pointLockAttachment = nil
local pointLockAncestryConnection = nil
local pointLockHoldPreview = false

local function isPointLockAttachmentAlive(): boolean
	return pointLockAttachment ~= nil and pointLockAttachment.Parent ~= nil and pointLockAttachment:IsDescendantOf(game)
end

local function clearPointLock(): ()
	pointLockEnabled = false
	if pointLockAncestryConnection then
		pointLockAncestryConnection:Disconnect()
		pointLockAncestryConnection = nil
	end

	local attachment = pointLockAttachment
	pointLockAttachment = nil
	if attachment and attachment.Parent then
		attachment:Destroy()
	end
end

local POINT_LOCK_PREVIEW_COLOR = Color3.fromHex("9CCAFF")
local POINT_LOCK_PREVIEW_RADIUS = 0.125
local pointLockPreviewPart = nil
local pointLockPreviewHighlight = nil

local function getPointLockRaycastResult(originCFrame: CFrame?): RaycastResult?
	local cameraCFrame = originCFrame or Camera.CFrame
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	local exclude = {}
	local character = LocalPlayer.Character
	if character then
		exclude[#exclude + 1] = character
	end
	if pointLockPreviewPart then
		exclude[#exclude + 1] = pointLockPreviewPart
	end
	raycastParams.FilterDescendantsInstances = exclude

	return Workspace:Raycast(
		cameraCFrame.Position,
		cameraCFrame.LookVector * Constants.PointLock.RayLength,
		raycastParams
	)
end

local function hidePointLockPreview(): ()
	if pointLockPreviewHighlight then
		pointLockPreviewHighlight.Enabled = false
		pointLockPreviewHighlight.FillTransparency = 1
	end
	if pointLockPreviewPart then
		pointLockPreviewPart.Transparency = 1
	end
end

local function destroyPointLockPreview(): ()
	if pointLockPreviewPart then
		pointLockPreviewPart:Destroy()
		pointLockPreviewPart = nil
	end
	pointLockPreviewHighlight = nil
end

local function ensurePointLockPreview(): Part
	local camera = Camera
	if pointLockPreviewPart and pointLockPreviewPart.Parent then
		if pointLockPreviewPart.Parent ~= camera then
			pointLockPreviewPart.Parent = camera
		end

		return pointLockPreviewPart
	end

	destroyPointLockPreview()

	local part = Instance.new("Part")
	part.Name = "FreecamPointLockPreview"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Color = POINT_LOCK_PREVIEW_COLOR
	part.Locked = true
	part.Material = Enum.Material.SmoothPlastic
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.one * (POINT_LOCK_PREVIEW_RADIUS * 2)
	part.Transparency = 1

	local highlight = Instance.new("Highlight")
	highlight.Name = "Highlight"
	highlight.Adornee = part
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Enabled = false
	highlight.FillColor = POINT_LOCK_PREVIEW_COLOR
	highlight.FillTransparency = 1
	highlight.OutlineColor = POINT_LOCK_PREVIEW_COLOR
	highlight.OutlineTransparency = 1
	highlight.Parent = part

	part.Parent = camera
	pointLockPreviewPart = part
	pointLockPreviewHighlight = highlight

	return part
end

local screenGuisEnabled = false
local leaderboardEnabled = false
local watermarkEnabled = false

local watermark = nil

local stiffness = {
	movement = Constants.Movement.Stiffness,
	pan = Constants.Pan.Stiffness,
	fov = Constants.Fov.Stiffness,
	roll = Constants.Roll.Stiffness,
}

------------------------------------------------------------------------

local Spring = {}
do
	Spring.__index = Spring

	function Spring.new(freq, pos)
		local self = setmetatable({}, Spring)
		self.f = freq
		self.p = pos
		self.v = pos * 0
		return self
	end

	function Spring:Update(dt, goal)
		local f = self.f * 2 * pi
		local p0 = self.p
		local v0 = self.v
		local offset = goal - p0
		local decay = exp(-f * dt)
		local p1 = goal + (v0 * dt - offset * (f * dt + 1)) * decay
		local v1 = (f * dt * (offset * f - v0) + v0) * decay
		self.p = p1
		self.v = v1
		return p1
	end

	function Spring:SetFreq(freq)
		self.f = freq
	end

	function Spring:Reset(pos)
		self.p = pos
		self.v = pos * 0
	end
end

------------------------------------------------------------------------

local cameraPos = Vector3.new()
local cameraRot = Vector3.new()
local cameraFov = 0
local initialCameraPos = Vector3.zero
local initialCameraRot = Vector3.zero
local initialCameraFov = 70

local movementSpring = Spring.new(stiffness.movement, Vector3.new())
local panSpring = Spring.new(stiffness.pan, Vector2.new())
local fovSpring = Spring.new(stiffness.fov, 0)
local rollSpring = Spring.new(stiffness.roll, 0)

------------------------------------------------------------------------

local Input = {}
do
	local actions = {}

	local speed = {
		movement = 1,
		pan = 1,
		fov = 1,
		roll = 1,
	}

	local tiltSuppressed = false
	local tiltReset = nil

	local modeActive = false
	local modeIndex = 1
	local navigationStack = {}
	local leafSelected = false
	local monitorItemSelected = false

	------------------------------------------------------------------------
	local function findPlayerLockRootPart(switchDirection)
		if not playerList or #playerList < 1 then
			return nil
		end
		for _ = 1, #playerList do
			currentTargetIndex = ((currentTargetIndex - 1) + switchDirection) % #playerList + 1
			local targetPlayer = playerList[currentTargetIndex]
			local targetCharacter = targetPlayer and targetPlayer.Character
			if targetCharacter then
				local humanoid = targetCharacter:FindFirstChildOfClass("Humanoid")
				if humanoid and humanoid.RootPart then
					return humanoid.RootPart
				end
			end
			if switchDirection == 0 then
				switchDirection = 1
			end
		end
		playerLockEnabled = false
		return nil
	end

	local TINT_COLORS = {
		{ name = "Custom", color = nil },
		{ name = "White", color = Color3.new(1, 1, 1) },
		{ name = "Warm", color = Color3.fromRGB(255, 230, 200) },
		{ name = "Cool", color = Color3.fromRGB(200, 220, 255) },
		{ name = "Red", color = Color3.new(1, 0, 0) },
		{ name = "Green", color = Color3.new(0, 1, 0) },
		{ name = "Blue", color = Color3.new(0, 0, 1) },
		{ name = "Yellow", color = Color3.new(1, 1, 0) },
		{ name = "Cyan", color = Color3.new(0, 1, 1) },
		{ name = "Magenta", color = Color3.new(1, 0, 1) },
		{ name = "Orange", color = Color3.fromRGB(255, 140, 0) },
		{ name = "Purple", color = Color3.fromRGB(128, 0, 255) },
	}
	local CUSTOM_TINT_INDEX = 1
	local tintColorIndex = 1
	local customTintColor = Color3.new(1, 1, 1)

	local function doTogglePlayerLock()
		playerLockEnabled = not playerLockEnabled
		if playerLockEnabled then
			clearPointLock()
			playerLockZoom = Constants.PlayerLock.DefaultZoom
			playerLockHeight = Constants.PlayerLock.DefaultHeight
			rootPart = findPlayerLockRootPart(0)
		end
	end

	local function doTogglePointLock()
		if pointLockEnabled then
			clearPointLock()
			hidePointLockPreview()
			return
		end

		local result = getPointLockRaycastResult()
		if not result then
			return
		end

		playerLockEnabled = false

		local attachment = Instance.new("Attachment")
		attachment.Name = "FreecamPointLock"
		attachment.Parent = result.Instance
		attachment.WorldCFrame = CFrame.new(result.Position)

		pointLockAttachment = attachment
		pointLockEnabled = true
		pointLockZoom = Constants.PointLock.DefaultZoom
		pointLockHeight = Constants.PointLock.DefaultHeight
		hidePointLockPreview()
		pointLockAncestryConnection = attachment.AncestryChanged:Connect(function(): ()
			if not isPointLockAttachmentAlive() then
				clearPointLock()
			end
		end)
	end

	local function doToggleScreenGuis()
		screenGuisEnabled = not screenGuisEnabled
		if PlayerState then
			for _, gui in pairs(PlayerState.getScreenGuis()) do
				if gui.Parent and gui ~= freecamGui then
					gui.Enabled = screenGuisEnabled
				end
			end
		end
	end

	local function doToggleLeaderboard()
		leaderboardEnabled = not leaderboardEnabled
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, leaderboardEnabled)
	end

	local function doToggleWatermark()
		watermarkEnabled = not watermarkEnabled
		if watermark then
			watermark.Visible = watermarkEnabled
		end
	end

	local function doResetFreecam()
		playerLockEnabled = false
		clearPointLock()
		playerLockZoom = Constants.PlayerLock.DefaultZoom
		playerLockHeight = Constants.PlayerLock.DefaultHeight
		pointLockZoom = Constants.PointLock.DefaultZoom
		pointLockHeight = Constants.PointLock.DefaultHeight

		cameraPos = initialCameraPos
		cameraRot = initialCameraRot
		cameraFov = initialCameraFov

		speed.movement = 1
		speed.pan = 1
		speed.fov = 1
		speed.roll = 1

		stiffness.movement = Constants.Movement.Stiffness
		stiffness.pan = Constants.Pan.Stiffness
		stiffness.fov = Constants.Fov.Stiffness
		stiffness.roll = Constants.Roll.Stiffness

		movementSpring:SetFreq(stiffness.movement)
		panSpring:SetFreq(stiffness.pan)
		fovSpring:SetFreq(stiffness.fov)
		rollSpring:SetFreq(stiffness.roll)
		movementSpring:Reset(Vector3.zero)
		panSpring:Reset(Vector2.zero)
		fovSpring:Reset(0)
		rollSpring:Reset(0)

		local resetCFrame = CFrame.new(cameraPos) * CFrame.fromOrientation(cameraRot.x, cameraRot.y, cameraRot.z)
		Camera.CFrame = resetCFrame
		Camera.Focus = resetCFrame
		Camera.FieldOfView = cameraFov
	end

	------------------------------------------------------------------------
	-- mode table: contains every adjustable/toggleable/cycled/fired feature
	-- type = "axis"   -> hold Left/Right to adjust a continuous value
	-- type = "toggle" -> tap Left/Right to toggle a boolean
	-- type = "cycle"  -> tap Left/Right to step through an ordered list
	-- type = "action" -> tap Left/Right to fire an action
	-- type = "group"  -> tap Left/Right to enter the sub-mode list; tap Up to exit back to top level
	local function makeEffectGroup(name, toggleFn, getInstance, axisSpecs, extraModes)
		local groupModes = {
			{
				type = "toggle",
				name = "Enable",
				toggle = toggleFn,
				isEnabled = function()
					local e = getInstance()
					return e and e.Enabled
				end,
			},
		}
		for _, spec in ipairs(axisSpecs or {}) do
			groupModes[#groupModes + 1] = {
				type = "axis",
				name = spec.name,
				adj = spec.adjCfg.Adj,
				min = spec.adjCfg.Min,
				max = spec.adjCfg.Max,
				format = spec.adjCfg.Format or (spec.adjCfg.Adj >= 1 and "%.0f" or "%.2f"),
				get = function()
					local e = getInstance()
					return e and e[spec.prop] or 0
				end,
				set = function(v)
					local e = getInstance()
					if e then
						e[spec.prop] = v
					end
				end,
			}
		end
		for _, m in ipairs(extraModes or {}) do
			groupModes[#groupModes + 1] = m
		end
		return { type = "group", name = name, modes = groupModes }
	end

	local function makeTintChannel(chan)
		return {
			type = "axis",
			name = "Tint " .. chan,
			adj = 64,
			min = 0.0,
			max = 255.0,
			format = "%.0f",
			get = function()
				local c = FreecamColorCorrection and FreecamColorCorrection.TintColor or customTintColor
				return c[chan] * 255
			end,
			set = function(v)
				local c = FreecamColorCorrection and FreecamColorCorrection.TintColor or customTintColor
				local r, g, b = c.R, c.G, c.B
				if chan == "R" then
					r = v / 255
				elseif chan == "G" then
					g = v / 255
				else
					b = v / 255
				end
				customTintColor = Color3.new(r, g, b)
				tintColorIndex = CUSTOM_TINT_INDEX
				if FreecamColorCorrection then
					FreecamColorCorrection.TintColor = customTintColor
				end
			end,
		}
	end

	local function buildCustomEffectsGroup()
		local group = {
			type = "group",
			name = "Custom Post Processing",
			modes = {
				{
					type = "toggle",
					name = "Enable",
					toggle = doToggleMasterEffects,
					isEnabled = function()
						return masterEffectsEnabled
					end,
				},
				makeEffectGroup("Depth of Field", doToggleDoF, function()
					return FreecamDepthOfField
				end, {
					{ name = "Far", adjCfg = Constants.DoF.FarIntensity, prop = "FarIntensity" },
					{ name = "Near", adjCfg = Constants.DoF.NearIntensity, prop = "NearIntensity" },
					{ name = "Focus Distance", adjCfg = Constants.DoF.FocusDistance, prop = "FocusDistance" },
					{ name = "Focus Radius", adjCfg = Constants.DoF.FocusRadius, prop = "InFocusRadius" },
				}),
				makeEffectGroup("Bloom", doToggleBloom, function()
					return FreecamBloom
				end, {
					{ name = "Intensity", adjCfg = Constants.Bloom.Intensity, prop = "Intensity" },
					{ name = "Size", adjCfg = Constants.Bloom.Size, prop = "Size" },
					{ name = "Threshold", adjCfg = Constants.Bloom.Threshold, prop = "Threshold" },
				}),
				makeEffectGroup("Blur", doToggleBlur, function()
					return FreecamBlur
				end, {
					{ name = "Size", adjCfg = Constants.Blur.Size, prop = "Size" },
				}),
				makeEffectGroup("Color Correction", doToggleColorCorrection, function()
					return FreecamColorCorrection
				end, {
					{ name = "Brightness", adjCfg = Constants.ColorCorrection.Brightness, prop = "Brightness" },
					{ name = "Contrast", adjCfg = Constants.ColorCorrection.Contrast, prop = "Contrast" },
					{ name = "Saturation", adjCfg = Constants.ColorCorrection.Saturation, prop = "Saturation" },
				}, {
					{
						type = "cycle",
						name = "Tint",
						items = function()
							return TINT_COLORS
						end,
						getIndex = function()
							return tintColorIndex
						end,
						setIndex = function(i)
							tintColorIndex = i
							if FreecamColorCorrection then
								if i == CUSTOM_TINT_INDEX then
									FreecamColorCorrection.TintColor = customTintColor
								else
									local col = TINT_COLORS[i].color
									FreecamColorCorrection.TintColor = col
								end
							end
						end,
						displayItem = function(entry)
							return entry.name
						end,
					},
					makeTintChannel("R"),
					makeTintChannel("G"),
					makeTintChannel("B"),
				}),
				makeEffectGroup("Sun Rays", doToggleSunRays, function()
					return FreecamSunRays
				end, {
					{ name = "Intensity", adjCfg = Constants.SunRays.Intensity, prop = "Intensity" },
					{ name = "Spread", adjCfg = Constants.SunRays.Spread, prop = "Spread" },
				}),
				makeEffectGroup(
					"Color Grading",
					doToggleColorGrading,
					function()
						return FreecamColorGrading
					end,
					nil,
					{
						{
							type = "cycle",
							name = "Tonemap",
							items = function()
								return { Enum.TonemapperPreset.Default, Enum.TonemapperPreset.Retro }
							end,
							getIndex = function()
								if
									FreecamColorGrading
									and FreecamColorGrading.TonemapperPreset == Enum.TonemapperPreset.Retro
								then
									return 2
								end
								return 1
							end,
							setIndex = function(i)
								if FreecamColorGrading then
									local presets = { Enum.TonemapperPreset.Default, Enum.TonemapperPreset.Retro }
									FreecamColorGrading.TonemapperPreset = presets[i]
								end
							end,
							displayItem = function(p)
								return p.Name
							end,
						},
					}
				),
			},
		}

		for i = 2, #group.modes do
			group.modes[i].disabled = function()
				return not masterEffectsEnabled
			end
		end

		return group
	end

	local function makeSpeedStiffnessGroup(name, constTable, speedKey, stiffKey, spring)
		return {
			type = "group",
			name = name,
			modes = {
				{
					type = "axis",
					name = "Speed",
					adj = constTable.AdjSpeed,
					min = constTable.MinSpeed,
					max = constTable.MaxSpeed,
					format = "%.2f",
					get = function()
						return speed[speedKey]
					end,
					set = function(v)
						speed[speedKey] = v
					end,
				},
				{
					type = "axis",
					name = "Stiffness",
					adj = constTable.AdjStiffness,
					min = constTable.MinStiffness,
					max = constTable.MaxStiffness,
					format = "%.2f",
					get = function()
						return stiffness[stiffKey]
					end,
					set = function(v)
						stiffness[stiffKey] = v
						spring:SetFreq(v)
					end,
				},
			},
		}
	end

	local modes = {
		-- custom post-processing effects group
		buildCustomEffectsGroup(),
		-- player lock group
		{
			type = "group",
			name = "Player Lock",
			modes = {
				{
					type = "toggle",
					name = "Enable",
					toggle = doTogglePlayerLock,
					isEnabled = function()
						return playerLockEnabled
					end,
				},
				{
					type = "cycle",
					name = "Target",
					items = function()
						return playerList
					end,
					getIndex = function()
						return currentTargetIndex
					end,
					setIndex = function(i)
						currentTargetIndex = i
						local target = playerList[i]
						local char = target and target.Character
						if char then
							local hum = char:FindFirstChildOfClass("Humanoid")
							rootPart = hum and hum.RootPart or nil
						else
							rootPart = nil
						end
					end,
					displayItem = function(p)
						return p.Name
					end,
				},
			},
		},
		{
			type = "group",
			name = "Point Lock",
			modes = {
				{
					type = "toggle",
					name = "Enable",
					toggle = doTogglePointLock,
					isEnabled = function()
						return pointLockEnabled
					end,
				},
			},
		},
		{
			type = "group",
			name = "UI",
			modes = {
				{
					type = "toggle",
					name = "Screen GUIs",
					toggle = doToggleScreenGuis,
					isEnabled = function()
						return screenGuisEnabled
					end,
				},
				{
					type = "toggle",
					name = "Leaderboard",
					toggle = doToggleLeaderboard,
					isEnabled = function()
						return leaderboardEnabled
					end,
				},
				{
					type = "toggle",
					name = "Watermark",
					toggle = doToggleWatermark,
					isEnabled = function()
						return watermarkEnabled
					end,
				},
			},
		},
		-- basic speed + stiffness groups
		makeSpeedStiffnessGroup("Movement", Constants.Movement, "movement", "movement", movementSpring),
		makeSpeedStiffnessGroup("Field of View", Constants.Fov, "fov", "fov", fovSpring),
		makeSpeedStiffnessGroup("Roll", Constants.Roll, "roll", "roll", rollSpring),
		makeSpeedStiffnessGroup("Rotation", Constants.Pan, "pan", "pan", panSpring),
	}
	modes = { modes[5], modes[8], modes[7], modes[6], modes[1], modes[2], modes[3], modes[4] }
	modes[#modes + 1] = {
		type = "group",
		name = "Controls",
		modes = {
			{ type = "info", name = "Move", value = "WASD / LS" },
			{ type = "info", name = "Look", value = "Mouse / RS" },
			{ type = "info", name = "Height", value = "Q/E / L2/R2" },
			{ type = "info", name = "Tilt", value = "Z/C / L1/R1" },
			{ type = "info", name = "FOV", value = "Scroll / X/Y" },
			{ type = "info", name = "Slow", value = "Shift" },
			{ type = "info", name = "Point Lock", value = "P / R3" },
			{ type = "info", name = "Reset", value = "R / L3" },
			{ type = "info", name = "Menu", value = "\xE2\x86\x91/\xE2\x86\x93" },
			{ type = "info", name = "Adjust", value = "\xE2\x86\x90/\xE2\x86\x92" },
		},
	}
	modes[#modes + 1] = {
		type = "action",
		name = "Reset Freecam",
		action = doResetFreecam,
	}

	local function isDisabled(mode)
		return mode.disabled and mode.disabled()
	end

	local function nextEnabledIndex(list, current, direction)
		local count = #list
		for _ = 1, count do
			current = ((current - 1) + direction) % count + 1
			if not isDisabled(list[current]) then
				return current
			end
		end
		return current
	end

	local function currentMode()
		if #navigationStack > 0 then
			local frame = navigationStack[#navigationStack]
			return frame.modes[frame.index]
		end
		return modes[modeIndex]
	end

	------------------------------------------------------------------------
	-- IAS Instance Helpers

	local function createBinding(parent, cfg)
		local b = Instance.new("InputBinding")
		if cfg.keyCode then
			b.KeyCode = cfg.keyCode
		end
		if cfg.up then
			b.Up = cfg.up
		end
		if cfg.down then
			b.Down = cfg.down
		end
		if cfg.left then
			b.Left = cfg.left
		end
		if cfg.right then
			b.Right = cfg.right
		end
		if cfg.scale then
			b.Scale = cfg.scale
		end
		if cfg.vector2Scale then
			b.Vector2Scale = cfg.vector2Scale
		end
		if cfg.responseCurve then
			b.ResponseCurve = cfg.responseCurve
		end
		if cfg.primaryModifier then
			b.PrimaryModifier = cfg.primaryModifier
		end
		b.Parent = parent
		return b
	end

	local function createAction(context, cfg)
		local action = Instance.new("InputAction")
		action.Name = cfg.name
		action.Type = cfg.type
		action.Parent = context
		for _, bindingCfg in ipairs(cfg.bindings) do
			createBinding(action, bindingCfg)
		end
		return action
	end

	------------------------------------------------------------------------
	local function makeDoubleTapHandler(threshold, debounce, callback)
		local lastTime, lastFired = nil, 0
		local function detect(val)
			if math.abs(val) > 0.01 then
				local now = os.clock()
				if lastTime ~= nil and (now - lastTime) <= threshold then
					if (now - lastFired) >= debounce then
						callback()
						lastFired = now
					end
					lastTime = nil
				else
					lastTime = now
				end
			end
		end
		local function reset()
			lastTime = nil
		end
		return detect, reset
	end

	local function createIASContexts()
		local cfg = Constants.Actions

		local contextParent = Instance.new("Folder")
		contextParent.Name = "FreecamInput"
		contextParent.Parent = StarterPlayer
		contextParent = contextParent

		-- high priority input context to sink inputs before character / camera movement
		local freecamContext = Instance.new("InputContext")
		freecamContext.Name = "FreecamInputContext"
		freecamContext.Priority = FREECAM_INPUT_PRIORITY
		freecamContext.Sink = true
		freecamContext.Enabled = false
		freecamContext.Parent = contextParent
		Input._sinkContext = freecamContext

		actions.Pan = createAction(freecamContext, cfg.Pan)
		actions.MovementMove = createAction(freecamContext, cfg.MovementMove)
		actions.MovementElevate = createAction(freecamContext, cfg.MovementElevate)
		actions.Fov = createAction(freecamContext, cfg.Fov)
		actions.Shift = createAction(freecamContext, cfg.Shift)
		actions.PointLock = createAction(freecamContext, cfg.PointLock)
		actions.Reset = createAction(freecamContext, cfg.Reset)

		actions.Reset.StateChanged:Connect(function(pressed: boolean)
			if pressed then
				doResetFreecam()
			end
		end)

		actions.PointLock.StateChanged:Connect(function(pressed: boolean)
			if pressed then
				if pointLockEnabled then
					clearPointLock()
					pointLockHoldPreview = false
					hidePointLockPreview()
				else
					pointLockHoldPreview = true
				end
			elseif pointLockHoldPreview then
				pointLockHoldPreview = false
				if not pointLockEnabled then
					doTogglePointLock()
				end
			end
		end)

		local tiltAction = createAction(freecamContext, cfg.Tilt)
		actions.Tilt = tiltAction
		local tiltDetect
		tiltDetect, tiltReset = makeDoubleTapHandler(
			Constants.DoubleTap.Threshold,
			Constants.DoubleTap.Debounce,
			function()
				cameraRot = Vector3.new(cameraRot.x, cameraRot.y, 0)
				rollSpring:Reset(0)
				tiltSuppressed = true
			end
		)
		tiltAction.StateChanged:Connect(function(val: number)
			if tiltSuppressed then
				if math.abs(val) < 0.01 then
					tiltSuppressed = false
				end
				return
			end
			tiltDetect(val)
		end)

		local modeToggleAction = createAction(freecamContext, cfg.ModeToggle)
		modeToggleAction.StateChanged:Connect(function(pressed: boolean)
			if not pressed then
				return
			end

			if modeActive then
				if monitorItemSelected then
					monitorItemSelected = false
				elseif #navigationStack > 0 then
					local frame = navigationStack[#navigationStack]
					local prev = nextEnabledIndex(frame.modes, frame.index, -1)
					if prev < frame.index then
						frame.index = prev
					else
						navigationStack[#navigationStack] = nil
					end
				else
					local prev = nextEnabledIndex(modes, modeIndex, -1)
					if prev < modeIndex then
						modeIndex = prev
					else
						modeActive = false
					end
				end
			else
				modeActive = true
			end
		end)

		local modeNextAction = createAction(freecamContext, cfg.ModeNext)
		modeNextAction.StateChanged:Connect(function(pressed: boolean)
			if not pressed then
				return
			end

			if not modeActive then
				modeActive = true
			elseif monitorItemSelected then
				monitorItemSelected = false
			elseif #navigationStack > 0 then
				local frame = navigationStack[#navigationStack]
				frame.index = nextEnabledIndex(frame.modes, frame.index, 1)
			else
				modeIndex = nextEnabledIndex(modes, modeIndex, 1)
			end
		end)

		local function handleModeAxis(val: number)
			if not modeActive then
				return
			end

			local mode = currentMode()
			if monitorItemSelected then
				if mode.type == "toggle" then
					mode.toggle()
				elseif mode.type == "cycle" then
					local items = mode.items()
					if #items > 0 then
						if val > 0 then
							mode.setIndex(mode.getIndex() % #items + 1)
						else
							mode.setIndex((mode.getIndex() - 2) % #items + 1)
						end
					end
				elseif mode.type == "action" then
					mode.action()
				end
			elseif val > 0 then
				if not isDisabled(mode) then
					if mode.type == "group" then
						table.insert(navigationStack, { modes = mode.modes, index = 1, groupName = mode.name })
					elseif mode.type == "action" then
						mode.action()
					elseif mode.type ~= "info" then
						monitorItemSelected = true
					end
				end
			elseif val < 0 then
				monitorItemSelected = false
				if #navigationStack > 0 then
					navigationStack[#navigationStack] = nil
				else
					modeActive = false
				end
			end
		end

		actions.ModeRight = createAction(freecamContext, cfg.ModeRight)
		actions.ModeRight.StateChanged:Connect(function(pressed: boolean)
			if pressed then
				handleModeAxis(1)
			end
		end)

		actions.ModeLeft = createAction(freecamContext, cfg.ModeLeft)
		actions.ModeLeft.StateChanged:Connect(function(pressed: boolean)
			if pressed then
				handleModeAxis(-1)
			end
		end)

		UserInputService.InputBegan:Connect(function(input: InputObject)
			if not Input._sinkContext.Enabled then
				return
			end

			if input.KeyCode == Constants.Keys.ModeSelect.Axis.Up.Keyboard then
				handleModeAxis(1)
			elseif input.KeyCode == Constants.Keys.ModeSelect.Axis.Down.Keyboard then
				handleModeAxis(-1)
			end
		end)
	end

	createIASContexts()

	------------------------------------------------------------------------

	function Input.Movement()
		local move = actions.MovementMove:GetState()
		return Vector3.new(move.X, actions.MovementElevate:GetState(), move.Y)
			* (speed.movement * (actions.Shift:GetState() and Constants.Movement.ShiftMul or 1))
	end

	function Input.Pan()
		local s = actions.Pan:GetState()
		return Vector2.new(s.Y, -s.X) * speed.pan
	end

	function Input.Fov()
		return actions.Fov:GetState() * speed.fov
	end

	function Input.Roll()
		return (tiltSuppressed and 0 or actions.Tilt:GetState()) * speed.roll
	end

	function Input.ModeControl(dt)
		if not modeActive then
			return
		end

		if not monitorItemSelected then
			return
		end

		local mode = currentMode()
		if mode.type ~= "axis" then
			return
		end

		local rightPressed = actions.ModeRight:GetState()
			or UserInputService:IsKeyDown(Constants.Keys.ModeSelect.Axis.Up.Keyboard)
		local leftPressed = actions.ModeLeft:GetState()
			or UserInputService:IsKeyDown(Constants.Keys.ModeSelect.Axis.Down.Keyboard)
		local axis = (rightPressed and 1 or 0) - (leftPressed and 1 or 0)
		local delta = axis * mode.adj * dt
		if delta ~= 0 then
			mode.set(clamp(mode.get() + delta, mode.min, mode.max))
		end
	end

	function Input.StartCapture()
		Input._sinkContext.Enabled = true
	end

	function Input.StopCapture()
		Input._sinkContext.Enabled = false
		tiltSuppressed = false
		if tiltReset then
			tiltReset()
		end
		modeActive = false

		table.clear(navigationStack)
		monitorItemSelected = false
		leafSelected = false
	end

	function Input.getModeActive()
		return modeActive
	end

	function Input.getModeName()
		return currentMode().name
	end

	function Input.getModeBreadcrumb()
		if #navigationStack == 0 then
			return ""
		end
		local parts = {}
		for _, frame in ipairs(navigationStack) do
			table.insert(parts, frame.groupName)
		end
		return table.concat(parts, " › ")
	end
	function Input.getModeDisplay()
		local mode = currentMode()
		if mode.type == "group" then
			return ""
		elseif mode.type == "axis" then
			return string.format(mode.format or "%.2f", mode.get())
		elseif mode.type == "toggle" then
			return mode.isEnabled() and "ON" or "OFF"
		elseif mode.type == "cycle" then
			local items = mode.items()
			if #items == 0 then
				return "None"
			end
			local item = items[mode.getIndex()]
			return item and mode.displayItem(item) or "None"
		elseif mode.type == "action" then
			return "(fire)"
		elseif mode.type == "info" then
			return mode.value
		end
		return ""
	end

	function Input.getModeHint()
		local top = modes[modeIndex]

		local function lrVerb(t)
			if t == "axis" then
				return "Hold to adjust"
			elseif t == "toggle" then
				return "Tap to flip"
			elseif t == "cycle" then
				return "Tap to cycle"
			elseif t == "action" then
				return "Tap to fire"
			elseif t == "group" then
				return "Enter"
			end
			return nil
		end

		if #navigationStack > 0 then
			local frame = navigationStack[#navigationStack]
			local nextIndex = frame.index % #frame.modes + 1
			local nextName = frame.modes[nextIndex].name
			local nav = "[↑] Back  [↓] " .. nextName
			local verb = lrVerb(currentMode().type)
			return { nav = nav, action = verb and ("[←][→] " .. verb) or "" }
		elseif leafSelected then
			local verb = lrVerb(top.type)
			return { nav = "[↑] Back", action = verb and ("[←][→] " .. verb) or "" }
		else
			local t = top.type
			local dnVerb
			if t == "group" then
				dnVerb = "Enter"
			elseif t == "toggle" then
				dnVerb = "Flip"
			elseif t == "cycle" then
				dnVerb = "Cycle"
			elseif t == "action" then
				dnVerb = "Fire"
			elseif t == "axis" then
				dnVerb = "Adjust"
			else
				dnVerb = "Select"
			end
			local prev = modes[(modeIndex - 2) % #modes + 1].name
			local nextName = modes[modeIndex % #modes + 1].name
			return {
				nav = "[↑] Close  [↓] " .. dnVerb,
				action = "[←] " .. prev .. "  [→] " .. nextName,
			}
		end
	end
	function Input.getTintColorName()
		if tintColorIndex >= 1 and tintColorIndex <= #TINT_COLORS then
			return TINT_COLORS[tintColorIndex].name
		end
		return "Custom"
	end
	function Input.getActiveGroupName()
		if not modeActive or #navigationStack == 0 then
			return nil
		end
		return navigationStack[1].groupName
	end

	Input._navigationStack = navigationStack
	Input._modes = modes

	function Input._getModeIndex()
		return modeIndex
	end

	function Input._isMonitorItemSelected()
		return monitorItemSelected
	end
end

local function shouldShowPointLockPreview(): boolean
	if pointLockHoldPreview then
		return true
	end

	return Input.getActiveGroupName() == "Point Lock"
end

local function updatePointLockPreview(originCFrame: CFrame): ()
	if not shouldShowPointLockPreview() then
		hidePointLockPreview()

		return
	end

	local result = getPointLockRaycastResult(originCFrame)
	if not result then
		hidePointLockPreview()

		return
	end

	local part = ensurePointLockPreview()
	part.CFrame = CFrame.new(result.Position + result.Normal * POINT_LOCK_PREVIEW_RADIUS)
	part.Transparency = 0
	if pointLockPreviewHighlight then
		pointLockPreviewHighlight.FillTransparency = 0
		pointLockPreviewHighlight.Enabled = true
	end
end

------------------------------------------------------------------------

local monitorGui = nil
local monitorRows = {}
local MAX_MONITOR_ROWS = 12
local MONITOR_BACKGROUND = Color3.fromHex("2D343A")
local MONITOR_FOREGROUND = Color3.fromHex("F2ECE0")
local MONITOR_ACCENT = Color3.fromHex("9CCAFF")
local MONITOR_FOREGROUND_SOFT = MONITOR_FOREGROUND:Lerp(MONITOR_BACKGROUND, 0.22)
local MONITOR_FOREGROUND_MUTED = MONITOR_FOREGROUND:Lerp(MONITOR_BACKGROUND, 0.38)
local MONITOR_FOREGROUND_DIM = MONITOR_FOREGROUND:Lerp(MONITOR_BACKGROUND, 0.52)
local MONITOR_FOREGROUND_FAINT = MONITOR_FOREGROUND:Lerp(MONITOR_BACKGROUND, 0.64)
local MONITOR_FOREGROUND_DISABLED = MONITOR_FOREGROUND:Lerp(MONITOR_BACKGROUND, 0.74)
local MONITOR_FOREGROUND_DISABLED_VALUE = MONITOR_FOREGROUND:Lerp(MONITOR_BACKGROUND, 0.84)
local MONITOR_SHOWN_POSITION = UDim2.fromOffset(0, 0)
local MONITOR_SLIDE_PADDING = 32
local backgroundTweenInfo = TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local slideInTweenInfo = TweenInfo.new(0.1, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out)
local slideOutTweenInfo = TweenInfo.new(0.1, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out)

local function getMonitorHiddenPosition()
	local width = 240
	if monitorGui then
		local panelWidth = monitorGui.panel.AbsoluteSize.X
		if panelWidth >= 1 then
			width = panelWidth
		end
	end

	return UDim2.fromOffset(width + MONITOR_SLIDE_PADDING, 0)
end

local function cancelMonitorTween(key)
	local tween = monitorGui and monitorGui[key]
	if tween then
		tween:Cancel()
		monitorGui[key] = nil
	end
end

local function syncMonitorBackground(instant)
	if not monitorGui then
		return
	end

	local slideState = monitorGui.slideState
	if slideState == "hidden" or slideState == "closing" then
		return
	end

	local background = monitorGui.background
	local container = monitorGui.container
	local panel = monitorGui.panel
	local size = panel.AbsoluteSize
	if size.X < 1 and size.Y < 1 then
		return
	end

	local offset = panel.AbsolutePosition - container.AbsolutePosition
	local goal = {
		Position = UDim2.fromOffset(offset.X, offset.Y),
		Size = UDim2.fromOffset(size.X, size.Y),
	}

	if background.Size == goal.Size and background.Position == goal.Position then
		return
	end

	if instant or slideState ~= "open" then
		cancelMonitorTween("backgroundTween")
		background.Position = goal.Position
		background.Size = goal.Size

		return
	end

	cancelMonitorTween("backgroundTween")
	monitorGui.backgroundTween = TweenService:Create(background, backgroundTweenInfo, goal)
	monitorGui.backgroundTween:Play()
end

local function playMonitorSlideIn()
	if not monitorGui then
		return
	end
	if monitorGui.slideState == "open" or monitorGui.slideState == "opening" then
		return
	end

	local wasClosing = monitorGui.slideState == "closing"
	cancelMonitorTween("slideTween")
	monitorGui.slideState = "opening"
	monitorGui.container.Visible = true
	if not wasClosing then
		monitorGui.container.Position = getMonitorHiddenPosition()
	end
	syncMonitorBackground(true)

	local tween = TweenService:Create(monitorGui.container, slideInTweenInfo, {
		Position = MONITOR_SHOWN_POSITION,
	})
	monitorGui.slideTween = tween
	tween.Completed:Once(function(playbackState)
		if playbackState == Enum.PlaybackState.Completed and monitorGui then
			monitorGui.slideState = "open"
			monitorGui.slideTween = nil
		end
	end)
	tween:Play()
end

local function playMonitorSlideOut(instant)
	if not monitorGui then
		return
	end

	if monitorGui.slideState == "hidden" then
		return
	end

	if not instant and monitorGui.slideState == "closing" then
		return
	end

	cancelMonitorTween("slideTween")
	cancelMonitorTween("backgroundTween")

	if instant then
		monitorGui.container.Position = getMonitorHiddenPosition()
		monitorGui.container.Visible = false
		monitorGui.slideState = "hidden"
		monitorGui.slideTween = nil

		return
	end

	monitorGui.slideState = "closing"
	local tween = TweenService:Create(monitorGui.container, slideOutTweenInfo, {
		Position = getMonitorHiddenPosition(),
	})
	monitorGui.slideTween = tween
	tween.Completed:Once(function(playbackState)
		if playbackState == Enum.PlaybackState.Completed and monitorGui then
			monitorGui.container.Visible = false
			monitorGui.slideState = "hidden"
			monitorGui.slideTween = nil
		end
	end)
	tween:Play()
end

local function buildMonitorGui(parent: Instance?)
	local container = Instance.new("Frame")
	container.Name = "FreecamMonitor"
	container.BackgroundTransparency = 1
	container.BorderSizePixel = 0
	container.Position = UDim2.fromOffset(272, 0)
	container.Size = UDim2.fromScale(1, 1)
	container.Visible = false

	local background = Instance.new("Frame")
	background.Name = "FrameBackground"
	background.BackgroundColor3 = MONITOR_BACKGROUND
	background.BackgroundTransparency = 0.08
	background.BorderSizePixel = 0
	background.Position = UDim2.fromOffset(0, 0)
	background.Size = UDim2.fromOffset(0, 0)
	background.ZIndex = 1
	background.Parent = container

	local backgroundCorner = Instance.new("UICorner")
	backgroundCorner.CornerRadius = UDim.new(0, 12)
	backgroundCorner.Parent = background

	local panel = Instance.new("Frame")
	panel.Name = "FreecamMonitorPanel"
	panel.AnchorPoint = Vector2.new(1, 1)
	panel.AutomaticSize = Enum.AutomaticSize.Y
	panel.BackgroundTransparency = 1
	panel.BorderSizePixel = 0
	panel.Position = UDim2.new(1, -16, 1, -16)
	panel.Size = UDim2.fromOffset(240, 0)
	panel.ZIndex = 2

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 8)
	padding.PaddingBottom = UDim.new(0, 8)
	padding.PaddingLeft = UDim.new(0, 12)
	padding.PaddingRight = UDim.new(0, 12)
	padding.Parent = panel

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	layout.Padding = UDim.new(0, 1)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = panel

	local title = Instance.new("ImageLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Image = "rbxassetid://137957985795900"
	title.LayoutOrder = -1
	title.ScaleType = Enum.ScaleType.Fit
	title.Size = UDim2.fromOffset(16, 16)

	local titleAspectRatio = Instance.new("UIAspectRatioConstraint")
	titleAspectRatio.AspectRatio = 1
	titleAspectRatio.Parent = title

	title.Parent = panel

	-- breadcrumb header
	local breadcrumb = Instance.new("TextLabel")
	breadcrumb.Name = "Breadcrumb"
	breadcrumb.BackgroundTransparency = 1
	breadcrumb.TextColor3 = MONITOR_FOREGROUND_DIM
	breadcrumb.Font = Enum.Font.GothamMedium
	breadcrumb.TextSize = 11
	breadcrumb.TextXAlignment = Enum.TextXAlignment.Left
	breadcrumb.Size = UDim2.new(1, 0, 0, 16)
	breadcrumb.LayoutOrder = 0
	breadcrumb.Visible = false
	breadcrumb.Parent = panel

	-- item rows
	monitorRows = {}
	for i = 1, MAX_MONITOR_ROWS do
		local row = Instance.new("Frame")
		row.Name = "Row" .. i
		row.BackgroundColor3 = MONITOR_FOREGROUND
		row.BackgroundTransparency = 1
		row.BorderSizePixel = 0
		row.Size = UDim2.new(1, 0, 0, 22)
		row.LayoutOrder = i
		row.Visible = false

		local rowCorner = Instance.new("UICorner")
		rowCorner.CornerRadius = UDim.new(0, 4)
		rowCorner.Parent = row

		local rowPadding = Instance.new("UIPadding")
		rowPadding.PaddingLeft = UDim.new(0, 6)
		rowPadding.PaddingRight = UDim.new(0, 6)
		rowPadding.Parent = row

		local nameLabel = Instance.new("TextLabel")
		nameLabel.Name = "Name"
		nameLabel.BackgroundTransparency = 1
		nameLabel.TextColor3 = MONITOR_FOREGROUND
		nameLabel.Font = Enum.Font.GothamMedium
		nameLabel.TextSize = 14
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.Size = UDim2.fromScale(0.55, 1)
		nameLabel.Position = UDim2.new(0, 0, 0, 0)
		nameLabel.Parent = row

		local valueLabel = Instance.new("TextLabel")
		valueLabel.Name = "Value"
		valueLabel.BackgroundTransparency = 1
		valueLabel.TextColor3 = MONITOR_FOREGROUND_MUTED
		valueLabel.Font = Enum.Font.GothamMedium
		valueLabel.TextSize = 14
		valueLabel.TextXAlignment = Enum.TextXAlignment.Right
		valueLabel.Size = UDim2.fromScale(0.45, 1)
		valueLabel.Position = UDim2.fromScale(0.55, 0)
		valueLabel.Parent = row

		row.Parent = panel
		monitorRows[i] = { frame = row, nameLabel = nameLabel, valueLabel = valueLabel }
	end

	-- hint footer
	local hint = Instance.new("TextLabel")
	hint.Name = "Hint"
	hint.BackgroundTransparency = 1
	hint.TextColor3 = MONITOR_FOREGROUND_FAINT
	hint.Font = Enum.Font.Gotham
	hint.TextSize = 12
	hint.TextXAlignment = Enum.TextXAlignment.Left
	hint.Size = UDim2.new(1, 0, 0, 20)
	hint.LayoutOrder = MAX_MONITOR_ROWS + 1
	hint.Parent = panel

	panel.Parent = container
	container.Parent = parent

	monitorGui = {
		background = background,
		breadcrumb = breadcrumb,
		container = container,
		hint = hint,
		panel = panel,
		slideState = "hidden",
		title = title,
	}

	panel:GetPropertyChangedSignal("AbsolutePosition"):Connect(syncMonitorBackground)
	panel:GetPropertyChangedSignal("AbsoluteSize"):Connect(syncMonitorBackground)
end

local function getMonitorModeValue(mode)
	if mode.type == "group" then
		return "\xE2\x80\xBA" -- ›
	elseif mode.type == "toggle" then
		return mode.isEnabled() and "On" or "Off"
	elseif mode.type == "axis" then
		return string.format(mode.format or "%.2f", mode.get())
	elseif mode.type == "cycle" then
		local items = mode.items()
		if #items == 0 then
			return "--"
		end
		local item = items[mode.getIndex()]
		return item and mode.displayItem(item) or "--"
	elseif mode.type == "action" then
		return "\xE2\x80\xBA" -- ›
	elseif mode.type == "info" then
		return mode.value
	end
	return ""
end

local function getMonitorModeValueColor(mode, isCursor, isEditing)
	if mode.type == "toggle" then
		if mode.isEnabled() then
			return MONITOR_ACCENT
		else
			return MONITOR_FOREGROUND_DIM
		end
	end
	if isCursor and isEditing then
		return MONITOR_FOREGROUND
	end
	return MONITOR_FOREGROUND_MUTED
end

local function updateMonitorGui()
	if not monitorGui then
		return
	end
	if not Input.getModeActive() then
		playMonitorSlideOut()
		return
	end

	-- determine current list and selected index
	local modeList, selectedIndex
	if #Input._navigationStack > 0 then
		local frame = Input._navigationStack[#Input._navigationStack]
		modeList = frame.modes
		selectedIndex = frame.index
	else
		modeList = Input._modes
		selectedIndex = Input._getModeIndex()
	end

	-- breadcrumb
	local bc = Input.getModeBreadcrumb()
	monitorGui.title.Visible = bc == ""
	monitorGui.breadcrumb.Text = bc
	monitorGui.breadcrumb.Visible = bc ~= ""

	-- update rows
	local isEditing = Input._isMonitorItemSelected()
	local count = math.min(#modeList, MAX_MONITOR_ROWS)
	for i = 1, MAX_MONITOR_ROWS do
		local row = monitorRows[i]
		if i <= count then
			local mode = modeList[i]
			local isCursor = (i == selectedIndex)
			local dim = mode.disabled and mode.disabled()
			row.frame.Visible = true

			if isCursor and not dim then
				row.nameLabel.Text = "> " .. mode.name
				row.nameLabel.TextColor3 = MONITOR_FOREGROUND
				row.nameLabel.Font = Enum.Font.GothamMedium
				row.frame.BackgroundTransparency = isEditing and 0.88 or 1
			elseif dim then
				row.nameLabel.Text = "  " .. mode.name
				row.nameLabel.TextColor3 = MONITOR_FOREGROUND_DISABLED
				row.nameLabel.Font = Enum.Font.GothamMedium
				row.frame.BackgroundTransparency = 1
			else
				row.nameLabel.Text = "  " .. mode.name
				row.nameLabel.TextColor3 = MONITOR_FOREGROUND_SOFT
				row.nameLabel.Font = Enum.Font.GothamMedium
				row.frame.BackgroundTransparency = 1
			end

			row.valueLabel.Text = getMonitorModeValue(mode)
			row.valueLabel.TextColor3 = dim and MONITOR_FOREGROUND_DISABLED_VALUE
				or getMonitorModeValueColor(mode, isCursor, isEditing)
		else
			row.frame.Visible = false
		end
	end

	-- hint
	if isEditing then
		monitorGui.hint.Text = "\xE2\x86\x91\xE2\x86\x93 Exit selection   \xE2\x86\x90\xE2\x86\x92 Adjust"
	else
		monitorGui.hint.Text = "\xE2\x86\x91\xE2\x86\x93 Navigate   \xE2\x86\x92 Select   \xE2\x86\x90 Back"
	end

	if monitorGui.slideState == "hidden" or monitorGui.slideState == "closing" then
		playMonitorSlideIn()
	else
		syncMonitorBackground()
	end
end

local function StepFreecam(dt)
	Input.ModeControl(dt)

	local movement = movementSpring:Update(dt, Input.Movement())
	local pan = panSpring:Update(dt, Input.Pan())
	local fov = fovSpring:Update(dt, Input.Fov())
	local roll = rollSpring:Update(dt, Input.Roll())

	local zoomFactor = sqrt(tan(rad(70 / 2)) / tan(rad(cameraFov / 2)))

	cameraFov = clamp(cameraFov + fov * Constants.Fov.Gain * (dt / zoomFactor), 1, 120)

	local panVector: Vector2 = pan * Constants.Pan.Gain * (dt / zoomFactor)
	cameraRot = cameraRot + Vector3.new(panVector.X, panVector.Y, roll * Constants.Roll.Gain * (dt / zoomFactor))
	local function wrapAngle(a)
		a = a % (2 * pi)
		return a > pi and a - 2 * pi or a
	end
	cameraRot = Vector3.new(wrapAngle(cameraRot.x), wrapAngle(cameraRot.y), wrapAngle(cameraRot.z))
	local movementCameraLocal = Vector3.new(movement.X, movement.Y, -movement.Z)
	local cameraCFrame = CFrame.new(cameraPos)
		* CFrame.fromOrientation(cameraRot.x, cameraRot.y, cameraRot.z)
		* CFrame.new(movementCameraLocal * Constants.Movement.Gain * dt)

	if playerLockEnabled and rootPart and rootPart.Parent then
		local lock = Constants.PlayerLock
		local zoomDelta = -movement.Z * Constants.Movement.Gain.Z * dt
		local heightDelta = movement.Y * Constants.Movement.Gain.Y * dt
		playerLockZoom = clamp(playerLockZoom + zoomDelta, lock.MinZoom, lock.MaxZoom)
		playerLockHeight = clamp(playerLockHeight + heightDelta, -lock.HeightRange, lock.HeightRange)
		local targetCFrame = CFrame.new(rootPart.Position + Vector3.new(0, playerLockHeight, 0))
		local rotationCFrame = CFrame.fromOrientation(cameraRot.x, cameraRot.y, cameraRot.z)
		cameraCFrame = targetCFrame * rotationCFrame * CFrame.new(0, 0, playerLockZoom)
	elseif pointLockEnabled then
		if not isPointLockAttachmentAlive() then
			clearPointLock()
		else
			local lock = Constants.PointLock
			local zoomDelta = -movement.Z * Constants.Movement.Gain.Z * dt
			local heightDelta = movement.Y * Constants.Movement.Gain.Y * dt
			pointLockZoom = clamp(pointLockZoom + zoomDelta, lock.MinZoom, lock.MaxZoom)
			pointLockHeight = clamp(pointLockHeight + heightDelta, -lock.HeightRange, lock.HeightRange)
			local targetCFrame = CFrame.new(pointLockAttachment.WorldPosition + Vector3.new(0, pointLockHeight, 0))
			local rotationCFrame = CFrame.fromOrientation(cameraRot.x, cameraRot.y, cameraRot.z)
			cameraCFrame = targetCFrame * rotationCFrame * CFrame.new(0, 0, pointLockZoom)
		end
	end

	updateMonitorGui()

	cameraPos = cameraCFrame.Position
	Camera.CFrame = cameraCFrame
	Camera.Focus = cameraCFrame
	Camera.FieldOfView = cameraFov
	updatePointLockPreview(cameraCFrame)
end

local function FreezeCharacterMovement()
	local character = LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid:Move(Vector3.zero, true)
		humanoid.Jump = false
	end
end

------------------------------------------------------------------------

PlayerState = {}
do
	local mouseBehavior
	local mouseIconEnabled
	local cameraType
	local cameraFocus
	local cameraCFrame
	local cameraFieldOfView
	local screenGuis = {}
	local coreGuis = {
		Backpack = true,
		Chat = true,
		Health = true,
		PlayerList = true,
	}
	local setCores = {
		BadgesNotificationsActive = true,
		PointsNotificationsActive = true,
	}

	function PlayerState.Push()
		for name in pairs(coreGuis) do
			coreGuis[name] = StarterGui:GetCoreGuiEnabled(Enum.CoreGuiType[name])
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType[name], false)
		end
		for name in pairs(setCores) do
			setCores[name] = StarterGui:GetCore(name)
			StarterGui:SetCore(name, false)
		end
		local playergui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
		if playergui then
			for _, gui in pairs(playergui:GetChildren()) do
				if gui:IsA("ScreenGui") and gui.Enabled and gui.Name ~= "Cmdr" then
					screenGuis[#screenGuis + 1] = gui
					gui.Enabled = false
				end
			end
			playerGuiConnection = playergui.ChildAdded:Connect(function(child)
				if child:IsA("ScreenGui") and child.Enabled and child.Name ~= "Cmdr" then
					screenGuis[#screenGuis + 1] = child
					child.Enabled = screenGuisEnabled
				end
			end)
		end

		cameraFieldOfView = Camera.FieldOfView
		Camera.FieldOfView = 70

		cameraType = Camera.CameraType
		Camera.CameraType = Enum.CameraType.Custom

		cameraCFrame = Camera.CFrame
		cameraFocus = Camera.Focus

		mouseIconEnabled = UserInputService.MouseIconEnabled
		UserInputService.MouseIconEnabled = false

		mouseBehavior = Enum.MouseBehavior.Default
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	end

	function PlayerState.Pop()
		for name, isEnabled in pairs(coreGuis) do
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType[name], isEnabled)
		end
		for name, isEnabled in pairs(setCores) do
			StarterGui:SetCore(name, isEnabled)
		end
		for _, gui in pairs(screenGuis) do
			if gui.Parent and gui ~= freecamGui then
				gui.Enabled = true
			end
		end
		if playerGuiConnection then
			playerGuiConnection:Disconnect()
			playerGuiConnection = nil
		end
		screenGuis = {}

		Camera.FieldOfView = cameraFieldOfView
		cameraFieldOfView = nil
		Camera.CameraType = cameraType
		cameraType = nil
		Camera.CFrame = cameraCFrame
		cameraCFrame = nil
		Camera.Focus = cameraFocus
		cameraFocus = nil

		UserInputService.MouseIconEnabled = mouseIconEnabled
		mouseIconEnabled = nil
		UserInputService.MouseBehavior = mouseBehavior
		mouseBehavior = nil
	end

	function PlayerState.getScreenGuis()
		return screenGuis
	end
end

local function removePlayerFromList(player)
	for i, p in ipairs(playerList) do
		if p == player then
			table.remove(playerList, i)
			if currentTargetIndex == i and playerLockEnabled then
				playerLockEnabled = false
				currentTargetIndex = 1
			end
			if currentTargetIndex > i then
				currentTargetIndex = currentTargetIndex - 1
			end
			if currentTargetIndex > #playerList or currentTargetIndex < 1 then
				currentTargetIndex = 1
			end
			break
		end
	end
end

local function initializePlayerList()
	playerList = Players:GetPlayers()
	for i, p in ipairs(playerList) do
		if p == LocalPlayer then
			currentTargetIndex = i
			break
		end
	end
	playerAddedConnection = Players.PlayerAdded:Connect(function(player)
		table.insert(playerList, player)
	end)
	playerRemovingConnection = Players.PlayerRemoving:Connect(removePlayerFromList)
end

local function buildWatermark(parent: Instance): ()
	if watermark then
		watermark.Visible = watermarkEnabled
		return
	end

	local image = Instance.new("ImageLabel")
	image.Name = "Watermark"
	image.AnchorPoint = Vector2.new(0, 1)
	image.BackgroundTransparency = 1
	image.Image = "rbxassetid://127260696417920"
	image.Position = UDim2.new(0, 24, 1, -24)
	image.ScaleType = Enum.ScaleType.Fit
	image.Size = UDim2.fromScale(0.1, 0.1)
	image.Visible = watermarkEnabled

	local aspectRatio = Instance.new("UIAspectRatioConstraint")
	aspectRatio.AspectRatio = 1
	aspectRatio.Parent = image

	image.Parent = parent
	watermark = image
end

local CUSTOM_ATTRIBUTE = "CustomFreecam"

local function createFreecamGui(playerGui: PlayerGui): ScreenGui
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "Freecam"
	screenGui.Enabled = false
	screenGui.IgnoreGuiInset = false
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
	screenGui:SetAttribute(CUSTOM_ATTRIBUTE, true)
	screenGui.Parent = playerGui

	freecamGui = screenGui

	return screenGui
end

local function getCustomFreecamGui(playerGui: PlayerGui): ScreenGui?
	local existing = playerGui:FindFirstChild("Freecam")
	if not existing or not existing:IsA("ScreenGui") then
		return
	end

	if existing:GetAttribute(CUSTOM_ATTRIBUTE) ~= true then
		return
	end

	return existing
end

local function replaceStockFreecam(playerGui: PlayerGui, child: Instance): ()
	if child.Name ~= "Freecam" or not child:IsA("ScreenGui") then
		return
	end

	if child:GetAttribute(CUSTOM_ATTRIBUTE) == true then
		return
	end

	RunService.Heartbeat:Wait()

	child:Destroy()

	if getCustomFreecamGui(playerGui) then
		return
	end

	createFreecamGui(playerGui)
end

local function ensureFreecamGui(playerGui: PlayerGui): ScreenGui
	for _, child in playerGui:GetChildren() do
		replaceStockFreecam(playerGui, child)
	end

	local existing = getCustomFreecamGui(playerGui)
	if existing then
		freecamGui = existing

		return existing
	end

	return createFreecamGui(playerGui)
end

local function StartFreecam()
	initializePlayerList()

	local cf = Camera.CFrame
	cameraRot = Vector3.new(cf:ToEulerAnglesYXZ())
	cameraPos = cf.Position
	cameraFov = Camera.FieldOfView
	initialCameraRot = cameraRot
	initialCameraPos = cameraPos
	initialCameraFov = cameraFov

	movementSpring:Reset(Vector3.new())
	panSpring:Reset(Vector2.new())
	fovSpring:Reset(0)
	rollSpring:Reset(0)

	if not freecamGui or not freecamGui.Parent then
		local playerGui = LocalPlayer:WaitForChild("PlayerGui")
		if not playerGui:IsA("PlayerGui") then
			return
		end

		freecamGui = ensureFreecamGui(playerGui)
	end

	buildWatermark(freecamGui)

	if not monitorGui then
		buildMonitorGui(freecamGui)
	end

	PlayerState.Push()
	freecamGui.Enabled = true

	local function makeEffect(className, name)
		local e = Instance.new(className)
		e.Name = name
		e.Parent = Camera
		return e
	end
	for _, def in ipairs(effectDefs) do
		local s = savedEffects[def.key]
		local e = makeEffect(def.class, "Freecam" .. def.key)

		if def.parent then
			e.Parent = def.parent
		end

		for _, p in ipairs(def.props) do
			e[p] = s[p]
		end
		e.Enabled = s.Enabled
		def.set(e)
	end

	RunService:BindToRenderStep("Freecam", Enum.RenderPriority.Camera.Value, StepFreecam)
	RunService:BindToRenderStep(
		"FreecamFreezeCharacterMovement",
		Enum.RenderPriority.Camera.Value + 1,
		FreezeCharacterMovement
	)
	Input.StartCapture()
end

local function StopFreecam()
	if playerAddedConnection then
		playerAddedConnection:Disconnect()
		playerAddedConnection = nil
	end
	if playerRemovingConnection then
		playerRemovingConnection:Disconnect()
		playerRemovingConnection = nil
	end
	playerLockEnabled = false
	currentTargetIndex = 1
	playerList = {}
	pointLockHoldPreview = false
	clearPointLock()
	destroyPointLockPreview()

	disableMasterEffects()
	masterEffectsEnabled = false
	for _, def in ipairs(effectDefs) do
		local e = def.get()
		if e then
			local s = savedEffects[def.key]
			s.Enabled = e.Enabled
			for _, p in ipairs(def.props) do
				s[p] = e[p]
			end
			e:Destroy()
			def.set(nil)
		end
	end

	if monitorGui then
		playMonitorSlideOut(true)
	end

	if freecamGui and freecamGui.Parent then
		freecamGui.Enabled = false
	end

	screenGuisEnabled = false
	leaderboardEnabled = false
	watermarkEnabled = false

	if watermark then
		watermark.Visible = false
	end

	Input.StopCapture()
	RunService:UnbindFromRenderStep("Freecam")
	RunService:UnbindFromRenderStep("FreecamFreezeCharacterMovement")
	PlayerState.Pop()
end

------------------------------------------------------------------------

local function applyFreecamEnabled(): ()
	script:SetAttribute(Constants.AttributeName, LocalPlayer:GetAttribute(Constants.AttributeName) == true)
end

do
	local enabled = false

	script:SetAttribute(Constants.AttributeName, enabled)
	script:GetAttributeChangedSignal(Constants.AttributeName):Connect(function()
		local attributeValue = script:GetAttribute(Constants.AttributeName)
		if typeof(attributeValue) ~= "boolean" then
			script:SetAttribute(Constants.AttributeName, enabled)
			return
		end
		if attributeValue ~= enabled then
			if attributeValue then
				StartFreecam()
				enabled = true
			else
				StopFreecam()
				enabled = false
			end
		end
	end)

	local playerGui = LocalPlayer:WaitForChild("PlayerGui")
	if playerGui:IsA("PlayerGui") then
		playerGui.ChildAdded:Connect(function(child: Instance): ()
			replaceStockFreecam(playerGui, child)
		end)

		ensureFreecamGui(playerGui)

		LocalPlayer:GetAttributeChangedSignal(Constants.AttributeName):Connect(applyFreecamEnabled)
		applyFreecamEnabled()
	end
end
