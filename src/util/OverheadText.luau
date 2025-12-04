local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Logger = require(ReplicatedStorage.util.Logger)
local Maid = require(ReplicatedStorage.package.Maid)

export type OverheadText = {
	Show: (
		adornee: Instance,
		text: string,
		color: Color3?,
		seconds: number?,
		maid: Maid.Maid?
	) -> BillboardGui,
}

local OverheadText: OverheadText = {} :: any

local DEFAULT_LIFETIME: number = 1

function OverheadText.Show(
	adornee: Instance,
	text: string,
	color: Color3?,
	seconds: number?,
	maid: Maid.Maid?
): BillboardGui
	local target: BasePart?
	if adornee:IsA("BasePart") then
		target = adornee
	elseif adornee:IsA("Model") then
		local humanoidRootPart: Instance? = adornee:FindFirstChild("HumanoidRootPart")
		if humanoidRootPart and humanoidRootPart:IsA("BasePart") then
			target = humanoidRootPart
		end
	end

	local billboardGui: BillboardGui = Instance.new("BillboardGui")
	billboardGui.Name = "OverheadText"
	billboardGui.AlwaysOnTop = true
	billboardGui.Size = UDim2.fromOffset(64, 64)
	billboardGui.StudsOffsetWorldSpace = Vector3.yAxis * 4

	if target then
		billboardGui.Adornee = target
		billboardGui.Parent = target
	else
		Logger.warn("OverheadText.Show: adornee has no BasePart; parenting to workspace")
		billboardGui.Parent = workspace
	end

	local label: TextLabel = Instance.new("TextLabel")
	label.Name = "Text"
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.Size = UDim2.fromScale(1, 1)
	label.Text = text
	label.TextColor3 = color or Color3.new()
	label.TextScaled = true
	label.TextStrokeColor3 = Color3.new()
	label.TextStrokeTransparency = 0
	label.Parent = billboardGui

	local life: number = seconds or DEFAULT_LIFETIME

	local function destroy(): ()
		if billboardGui and billboardGui.Parent then
			billboardGui:Destroy()
		end
	end

	if maid then
		maid:GiveTask(destroy)
	end

	task.delay(life, destroy)

	return billboardGui
end

return OverheadText
