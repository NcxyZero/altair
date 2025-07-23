local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Reflex = require(ReplicatedStorage.Packages.Reflex)

export type Producer = Reflex.Producer<State, Actions>

export type InventoryItem = {
	id: string,
	name: string,
	description: string,
	quantity: number,
	rarity: string,
	equipped: boolean,
}

export type State = {
	items: { [string]: InventoryItem },
	equippedItems: { [string]: string },
	maxSlots: number,
}

type Actions = {
	addItem: (itemId: string, item: InventoryItem) -> (),
	removeItem: (itemId: string) -> (),
	updateItemQuantity: (itemId: string, quantity: number) -> (),
	equipItem: (itemId: string, slotName: string) -> (),
	unequipItem: (slotName: string) -> (),
	increaseMaxSlots: (amount: number) -> (),
	clearInventory: () -> (),
}

local DEFAULT_STATE: State = {
	items = {},
	equippedItems = {},
	maxSlots = 20,
}

function CreateProducer(initialState: State): Producer
	local producer = Reflex.createProducer(initialState, {
		addItem = function(state, itemId: string, item: InventoryItem)
			if state.items[itemId] then
				state.items[itemId].quantity += item.quantity
			else
				state.items[itemId] = item
			end
			return state
		end,

		removeItem = function(state, itemId: string)
			if state.items[itemId] then
				state.items[itemId] = nil

				-- Unequip the item if it was equipped
				for slot, id in state.equippedItems do
					if id == itemId then
						state.equippedItems[slot] = nil
					end
				end
			end
			return state
		end,

		updateItemQuantity = function(state, itemId: string, quantity: number)
			if state.items[itemId] then
				state.items[itemId].quantity = quantity

				-- If quantity is 0 or less, remove the item
				if quantity <= 0 then
					state.items[itemId] = nil

					-- Unequip the item if it was equipped
					for slot, id in state.equippedItems do
						if id == itemId then
							state.equippedItems[slot] = nil
						end
					end
				end
			end
			return state
		end,

		equipItem = function(state, itemId: string, slotName: string)
			if state.items[itemId] then
				state.equippedItems[slotName] = itemId
				state.items[itemId].equipped = true
			end
			return state
		end,

		unequipItem = function(state, slotName: string)
			local itemId = state.equippedItems[slotName]
			if itemId and state.items[itemId] then
				state.items[itemId].equipped = false
			end
			state.equippedItems[slotName] = nil
			return state
		end,

		increaseMaxSlots = function(state, amount: number)
			state.maxSlots += amount
			return state
		end,

		clearInventory = function()
			return table.clone(DEFAULT_STATE)
		end,
	}) :: Producer

	return producer
end

return {
	CreateProducer = CreateProducer,
	DEFAULT_STATE = DEFAULT_STATE,
}
