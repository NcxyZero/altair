export type Default = {
	index: number?,
	type: string?,
	path: { any },
	PlayerAdded: (self: Default, player: Player) -> (),
	Init: () -> (),
}

local test: Default = {} :: Default
test.type = "controller"

function test:Init(): ()
	local ClientData = self.path.controller.ClientData
	print("init")
	task.wait(8)
	print("get producer")
	local producer = ClientData:getPlayerProducerAsync():expect()
	print("DataTest: Player profile loaded")
	print("DataTest: Initial state structure:")
	print("DataTest: - Full state:", producer.getState())
	print("DataTest: - Player state:", producer.getState().player)
	print("DataTest: - Initial coins:", producer.getState().player.coins)
	print("DataTest: - Settings:", producer.getState().settings)
	print("DataTest: - Inventory:", producer.getState().inventory)

	print("\nDataTest: Adding coins...")
	producer.secureAddCoins(1)
	print("DataTest: After adding 1 coin:", producer.getState().player.coins)

	producer.secureAddCoins(1)
	print("DataTest: After adding another coin:", producer.getState().player.coins)

	producer.secureAddCoins(1)
	print("DataTest: After adding a third coin:", producer.getState().player.coins)

	print("\nDataTest: Final state:")
	print("DataTest: - Final coins value:", producer.getState().player.coins)
	print("DataTest: - Full final state:", producer.getState())
	print("DataTest: IMPORTANT: Remember this coins value and check if it matches after rejoining")
	print("DataTest: If you see more coins after rejoining, there's a data duplication issue")
end

return test
