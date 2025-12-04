local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ConvertToTextTime = require(ReplicatedStorage.util.ConvertToTextTime)
local GetBridge = require(ReplicatedStorage.util.GetBridge)
local InitializerTypes = require(ReplicatedStorage.shared.types.InitializerTypes)
local Maid = require(ReplicatedStorage.package.Maid)

export type Default = {
	type: string,
	tag: string,
	path: InitializerTypes.ClientPath,
	accum: number,
	nextRestockAt: number?,
	restockInterval: number?,
	instance: TextLabel,
	maid: Maid.Maid,
	__index: Default,
	new: (instance: TextLabel, path: InitializerTypes.ClientPath) -> Default,
	Physics: (self: Default, delta: number) -> (),
	Destroy: (self: Default) -> (),
}

local StockTimerUI: Default = {} :: any
StockTimerUI.__index = StockTimerUI
StockTimerUI.type = "local_tag"
StockTimerUI.tag = "StockTimerCounter"

function StockTimerUI.new(instance: TextLabel, path: InitializerTypes.ClientPath): Default
	local self = setmetatable({}, StockTimerUI)
	self.path = path
	self.instance = instance
	self.maid = Maid.new()
	self.accum = 0

	local targetStockName: string? = instance:GetAttribute("StockName") :: string?

	self.maid:GiveTask(GetBridge("Notification"):Connect(function(data: {
		text: string,
		seconds: number?,
		color: Color3?,
		showAt: number?,
		stockName: string?,
		restockInterval: number?,
	}): ()
		if not data then
			return
		end

		if not (data.showAt and (not targetStockName or (data.stockName == targetStockName))) then
			return
		end

		self.nextRestockAt = data.showAt

		if data.restockInterval and data.restockInterval > 0 then
			self.restockInterval = data.restockInterval
		end
	end))

	return self
end

function StockTimerUI:Physics(delta: number): ()
	self.accum += delta
	if self.accum < 0.1 then
		return
	end
	self.accum = 0

	local label: TextLabel = self.instance

	if not self.nextRestockAt then
		label.Text = "..."
		return
	end

	local nowUnix: number = os.time()

	if self.restockInterval and self.restockInterval > 0 then
		while self.nextRestockAt and nowUnix >= self.nextRestockAt do
			self.nextRestockAt += self.restockInterval
		end
	end

	label.Text = ConvertToTextTime(math.max(0, self.nextRestockAt - nowUnix))
end

function StockTimerUI:Destroy(): ()
	self.maid:DoCleaning()
end

return StockTimerUI
