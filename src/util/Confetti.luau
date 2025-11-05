local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Maid = require(ReplicatedStorage.package.Maid)
local SFX = require(ReplicatedStorage.util.SFX)

local RotationSpeed: number = 20

local ConfettiUI = {}
ConfettiUI.__index = ConfettiUI

local function Curve(t, direction, currentX, currentY, startX, startY, delta, finished)
	if -math.sin(math.pi * t) < 0 and not finished then
		local y = startY + -math.sin(math.pi * t)

		local x = math.abs(startX * 2) * direction * (1 - math.cos(math.pi * t)) / 2
		return (-x + 1) / 2, (y + 1) / 2, false
	else
		return currentX, currentY + 1.75 * delta, true
	end
end

function ConfettiUI:Show(amount: number)
	local ui = Instance.new("ScreenGui")
	ui.DisplayOrder = -10
	ui.Name = "Confetti"
	ui.Enabled = false
	ui.Parent = Players.LocalPlayer.PlayerGui

	local colors = {
		Color3.fromRGB(251, 255, 2),
		Color3.fromRGB(0, 255, 0),
		Color3.fromRGB(27, 143, 252),
		Color3.fromRGB(255, 0, 0),
		Color3.fromRGB(166, 22, 223),
	}

	ui.Enabled = true
	local maid = Maid.new()
	local frames = {}

	for _index = 1, amount, 1 do
		task.spawn(function()
			local frame = Instance.new("Frame")
			maid:GiveTask(frame)
			local zindex = math.random(10)

			frame.Size = UDim2.fromScale(0.075 / (10 - zindex), (math.random(50, 75) / 1000) / (10 - zindex))

			frame:SetAttribute("RotationDirection", math.random(2) % 2 == 0 and 1 or -1)
			frame.BackgroundColor3 = colors[math.random(#colors)]
			frame.Rotation = math.random(360)
			local x = math.random(-500, 500) / 1000
			local y = math.random(-1000, 1000) / 1000
			local direction = 0

			if x > 0 then
				direction = 1
			elseif x < 0 then
				direction = -1
			end

			frame:SetAttribute("X", x)
			frame:SetAttribute("Y", y)
			frame:SetAttribute("Progress", 0)
			frame:SetAttribute("Direction", direction)
			frame.BorderSizePixel = 0
			table.insert(frames, frame)
			frame.Parent = ui
		end)
	end

	local finished = false

	task.spawn(function()
		SFX.new(SFX.Sounds.Confetti)
	end)

	maid:GiveTask(RunService.PreAnimation:Connect(function(delta: number)
		for _, frame in frames do
			task.spawn(function()
				frame:SetAttribute("Progress", frame:GetAttribute("Progress") + delta)
				local x, y, done = Curve(
					frame:GetAttribute("Progress"),
					frame:GetAttribute("Direction"),
					frame.Position.X.Scale,
					frame.Position.Y.Scale,
					frame:GetAttribute("X"),
					frame:GetAttribute("Y"),
					delta,
					finished
				)

				finished = done

				frame.Position = UDim2.fromScale(x, y)
				frame.Rotation += delta * RotationSpeed * frame:GetAttribute("RotationDirection")

				if frame.Position.Y.Scale >= 1 or frame.Position.X.Scale <= -0.1 or frame.Position.X.Scale >= 1 then
					local found = table.find(frames, frame)

					if found then
						table.remove(frames, found)
					end

					frame:Destroy()
				end
			end)
		end
	end))

	repeat
		task.wait()
	until #frames <= 0

	ui:Destroy()
	maid:DoCleaning()
end

return ConfettiUI
