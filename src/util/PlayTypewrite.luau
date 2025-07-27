--local ReplicatedStorage = game:GetService("ReplicatedStorage")

--local soundManager = require(ReplicatedStorage.shared.util.soundManager)

return function(text: string, guiObject: TextLabel, duration: number): ()
	local cooldown: number = duration / #text

	guiObject.MaxVisibleGraphemes = 0
	guiObject.Text = text

	for i = 1, #text do
		guiObject.MaxVisibleGraphemes = i

		local char: string = text:sub(i, i)
		if char ~= " " then
			--soundManager:PlaySound("Typewrite")
			task.wait(table.find({ ",", ".", "!", "?" }, char) and cooldown * 2 or cooldown)
		end
	end
end
