local ServerScriptService = game:GetService("ServerScriptService")

local ServerData = require(ServerScriptService.server.modules.ServerData)

export type Default = {
	index: number?,
	type: string?,
	path: { any },
	PlayerAdded: (self: Default, player: Player) -> (),
	Init: () -> (),
}

local test: Default = {} :: Default
test.type = "controller"

function test:PlayerAdded(player: Player): ()
	task.wait(5)
	local data = ServerData:GetPlayerProfile(player)
	print("DataTest: Player profile loaded")
	print("DataTest: Initial state structure:")
	print("DataTest: - Full state:", data.producer.getState())
	print("DataTest: - Player state:", data.producer.getState().player)
	print("DataTest: - Initial coins:", data.producer.getState().player.coins)
	print("DataTest: - Settings:", data.producer.getState().settings)
	print("DataTest: - Inventory:", data.producer.getState().inventory)

	-- Add coins one by one and print the result each time
	print("\nDataTest: Adding coins...")
	data.producer.secureAddCoins(1)
	print("DataTest: After adding 1 coin:", data.producer.getState().player.coins)

	data.producer.secureAddCoins(1)
	print("DataTest: After adding another coin:", data.producer.getState().player.coins)

	data.producer.secureAddCoins(1)
	print("DataTest: After adding a third coin:", data.producer.getState().player.coins)

	print("\nDataTest: Final state:")
	print("DataTest: - Final coins value:", data.producer.getState().player.coins)
	print("DataTest: - Full final state:", data.producer.getState())
	print("DataTest: IMPORTANT: Remember this coins value and check if it matches after rejoining")
	print("DataTest: If you see more coins after rejoining, there's a data duplication issue")
end

function test:Init(): ()
	print("init")
end

return test
