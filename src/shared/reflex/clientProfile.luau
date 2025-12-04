local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DeepClone = require(ReplicatedStorage.util.DeepClone)
local IsPlayerOnMobile = require(ReplicatedStorage.util.IsPlayerOnMobile)
local Reflex = require(ReplicatedStorage.package.Reflex)

export type Producer = Reflex.Producer<State, Actions>

export type LocalSettings = {
	musicVolume: number,
	sfxVolume: number,
	[string]: any,
}

export type Item = Frame & {
	ImageButton: ImageButton,
	ToolImage: ImageLabel,
	Amount: TextLabel,
	Index: TextLabel,
	ToolName: TextLabel,
}

export type State = {
	localSettings: LocalSettings,
	inventory: {
		backpack: { Item },
		hotbar: { Item },
	},
}

type Actions = {
	setLocalSetting: (key: string, value: any) -> State,
}

local DEFAULT_STATE: State = {
	localSettings = {
		musicVolume = 0.5,
		sfxVolume = 0.5,
	},

	inventory = {
		backpack = {},
		hotbar = {},
	},
}

function CreateProducer(initialState: State): Producer
	local producer: Producer = Reflex.createProducer(initialState, {
		setLocalSetting = function(oldState: State, key: string, value: any): State
			local state: State = table.clone(oldState)
			state.localSettings = table.clone(oldState.localSettings)
			state.localSettings[key] = value

			return state
		end,

		swapInventoryToHotbar = function(
			oldState: State,
			from: number,
			to: number,
			hotbar: Frame,
			inventory: ScrollingFrame
		): State
			local state = table.clone(oldState)
			state.inventory = DeepClone(state.inventory)

			local frame = state.inventory.backpack[from]

			state.inventory.backpack[from] = state.inventory.hotbar[to]
			state.inventory.backpack[from].LayoutOrder = 0
			state.inventory.backpack[from].Index.Visible = false

			state.inventory.hotbar[to] = frame
			frame.Index.Text = to == 10 and 0 or to
			frame.LayoutOrder = to
			frame.Index.Visible = true

			state.inventory.backpack[from].Parent = inventory
			frame.Parent = hotbar

			return state
		end,

		swapHotbarToInventory = function(
			oldState: State,
			from: number,
			to: number,
			hotbar: Frame,
			inventory: ScrollingFrame
		): State
			local state = table.clone(oldState)
			state.inventory = DeepClone(state.inventory)

			local frame = state.inventory.hotbar[from]

			state.inventory.hotbar[from] = state.inventory.backpack[to]
			state.inventory.hotbar[from].Index.Text = to == 10 and 0 or to
			state.inventory.hotbar[from].LayoutOrder = to
			state.inventory.hotbar[from].Index.Visible = true

			state.inventory.backpack[to] = frame
			state.inventory.backpack[to].LayoutOrder = 0
			frame.Index.Visible = true

			state.inventory.hotbar[from].Parent = hotbar
			frame.Parent = inventory

			return state
		end,

		swapToBackpack = function(oldState: State, id: number, backpack: ScrollingFrame): State
			local state = table.clone(oldState)
			state.inventory = DeepClone(state.inventory)

			local frame = state.inventory.hotbar[id]
			table.insert(state.inventory.backpack, frame)
			table.remove(state.inventory.hotbar, id)

			for index, item in state.inventory.hotbar do
				item.Index.Text = index == 10 and 0 or index
				item.LayoutOrder = index
			end

			frame.Parent = backpack
			frame.Index.Visible = false

			return state
		end,

		swapToHotbar = function(oldState: State, id: number, hotbar: Frame): State
			local state = table.clone(oldState)
			state.inventory = DeepClone(state.inventory)

			local frame = state.inventory.backpack[id]
			table.insert(state.inventory.hotbar, frame)
			table.remove(state.inventory, id)

			for index, item in state.inventory.hotbar do
				item.Index.Text = index == 10 and 0 or index
				item.LayoutOrder = index
			end

			frame.Parent = hotbar
			frame.Index.Visible = true

			return state
		end,

		swapHotbarSlot = function(oldState: State, id: number, to: number): State
			local state = table.clone(oldState)
			state.inventory = DeepClone(state.inventory)

			local temp = state.inventory.hotbar[id]
			temp.LayoutOrder = to == 0 and 10 or to
			state.inventory.hotbar[to].LayoutOrder = id == 0 and 10 or id
			temp.Index.Text = to
			state.inventory.hotbar[to].Index.Text = id
			state.inventory.hotbar[id] = state.inventory.hotbar[to]
			state.inventory.hotbar[to] = temp

			return state
		end,

		addItem = function(oldState: State, frame: Item, hotbar: Frame, backpack: ScrollingFrame): State
			local state = table.clone(oldState)
			state.inventory = DeepClone(state.inventory)
			local max = IsPlayerOnMobile() and 3 or 10

			if #state.inventory.hotbar >= max then
				frame.Index.Visible = false
				frame.Parent = backpack
				table.insert(state.inventory.backpack, frame)
			else
				table.insert(state.inventory.hotbar, frame)
				frame.Parent = hotbar
				frame.Index.Text = tostring(#state.inventory.hotbar == 10 and 0 or #state.inventory.hotbar)
				frame.LayoutOrder = #state.inventory.hotbar
				frame.Index.Visible = true
			end

			frame.Visible = true

			return state
		end,

		removeItem = function(oldState: State, item: string): State
			local state = table.clone(oldState)
			state.inventory = DeepClone(state.inventory)

			local name, id, found

			for category, inventoryData in state.inventory do
				for index, object in inventoryData do
					if object.ToolName.Text == item then
						found = item
						id = index
						name = category
						break
					end
				end

				if found then
					break
				end
			end

			if found then
				found:Destroy()
				table.remove(state.inventory[name], id)

				if name == "hotbar" then
					for index, inventoryItem in state.inventory[name] do
						inventoryItem.Index.Text = index == 10 and 0 or index
					end
				end
			end

			return state
		end,

		removeItemFromPath = function(oldState: State, category: string, id: number): State
			local state = table.clone(oldState)
			state.inventory = DeepClone(state.inventory)

			local found = state.inventory[category][id]

			if found then
				found:Destroy()
				table.remove(state.inventory[category], id)
			end

			if category == "hotbar" then
				for index, item in state.inventory[category] do
					item.Index.Text = index == 10 and 0 or index
				end
			end

			return state
		end,
	})

	return producer
end

return {
	CreateProducer = CreateProducer,
	DEFAULT_STATE = DEFAULT_STATE,
}
