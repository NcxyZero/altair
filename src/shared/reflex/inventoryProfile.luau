local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Reflex = require(ReplicatedStorage.package.Reflex)

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
	secureAddItem: (itemId: string, item: InventoryItem) -> State,
	secureRemoveItem: (itemId: string) -> State,
	secureUpdateItemQuantity: (itemId: string, quantity: number) -> State,
	equipItem: (itemId: string, slotName: string) -> State,
	unequipItem: (slotName: string) -> State,
	secureIncreaseMaxSlots: (amount: number) -> State,
	clearInventory: () -> State,
}

local DEFAULT_STATE: State = {
	items = {},
	equippedItems = {},
	maxSlots = 20,
}

function CreateProducer(initialState: State): Producer
	local producer: Producer = Reflex.createProducer(initialState, {
		secureAddItem = function(oldState: State, itemId: string, item: InventoryItem): State
			local state: State = table.clone(oldState)
			state.items = table.clone(oldState.items)

			if oldState.items[itemId] then
				local existingItem = table.clone(oldState.items[itemId])
				existingItem.quantity += item.quantity
				state.items[itemId] = existingItem
			else
				state.items[itemId] = item
			end

			return state
		end,

		secureRemoveItem = function(oldState: State, itemId: string): State
			if oldState.items[itemId] then
				local state: State = table.clone(oldState)
				state.items = table.clone(oldState.items)
				state.equippedItems = table.clone(oldState.equippedItems)

				state.items[itemId] = nil

				for slot: string, id: string in oldState.equippedItems do
					if id == itemId then
						state.equippedItems[slot] = nil
					end
				end

				return state
			end

			return oldState
		end,

		secureUpdateItemQuantity = function(oldState: State, itemId: string, quantity: number): State
			if oldState.items[itemId] then
				local state: State = table.clone(oldState)
				state.items = table.clone(oldState.items)

				if quantity <= 0 then
					state.items[itemId] = nil

					state.equippedItems = table.clone(oldState.equippedItems)
					for slot, id in oldState.equippedItems do
						if id == itemId then
							state.equippedItems[slot] = nil
						end
					end
				else
					local updatedItem = table.clone(oldState.items[itemId])
					updatedItem.quantity = quantity
					state.items[itemId] = updatedItem
				end

				return state
			end

			return oldState
		end,

		equipItem = function(state: State, itemId: string, slotName: string): State
			if state.items[itemId] then
				state.equippedItems[slotName] = itemId
				state.items[itemId].equipped = true
			end

			return state
		end,

		unequipItem = function(state: State, slotName: string): State
			local itemId: string = state.equippedItems[slotName]
			if itemId and state.items[itemId] then
				state.items[itemId].equipped = false
			end

			state.equippedItems[slotName] = nil

			return state
		end,

		secureIncreaseMaxSlots = function(oldState: State, amount: number): State
			local state: State = table.clone(oldState)
			state.maxSlots += amount

			return state
		end,

		clearInventory = function(_oldState: State): State
			return table.clone(DEFAULT_STATE)
		end,
	})

	return producer
end

return {
	CreateProducer = CreateProducer,
	DEFAULT_STATE = DEFAULT_STATE,
}
