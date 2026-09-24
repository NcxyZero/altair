local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local InitializerTypes = require(ReplicatedStorage.shared.types.InitializerTypes)
local WithoutPlayer = require(ReplicatedStorage.util.WithoutPlayer)

export type Queue = {
	list: { [number]: any },
	head: number,
	size: number,
}

export type QueueManagerServer = {
	Clear: (self: QueueManager, player: Player, key: string, category: string?) -> (),
	ClearAll: (self: QueueManager, player: Player, category: string?) -> (),
	Dequeue: (self: QueueManager, player: Player, key: string, category: string?) -> any?,
	Enqueue: (self: QueueManager, player: Player, key: string, value: any, category: string?) -> (),
	Peek: (self: QueueManager, player: Player, key: string, category: string?) -> any?,
	PlayerRemoving: (self: QueueManager, player: Player) -> (),
	Size: (self: QueueManager, player: Player, key: string, category: string?) -> number,
	path: InitializerTypes.ServerPath,
	queues: { [Player]: { [string]: { [string]: Queue } } },
	defaultCategory: string,
}

export type QueueManagerClient = {
	Clear: (self: QueueManager, key: string, category: string?) -> (),
	ClearAll: (self: QueueManager, category: string?) -> (),
	Dequeue: (self: QueueManager, key: string, category: string?) -> any?,
	Enqueue: (self: QueueManager, key: string, value: any, category: string?) -> (),
	Peek: (self: QueueManager, key: string, category: string?) -> any?,
	Size: (self: QueueManager, key: string, category: string?) -> number,
	path: InitializerTypes.ClientPath,
	queues: { [string]: { [string]: Queue } },
	defaultCategory: string,
}

export type QueueManager = QueueManagerServer & QueueManagerClient

type QueueMethods = {
	Clear: (self: QueueManager, player: Player?, key: string, category: string?) -> (),
	ClearAll: (self: QueueManager, player: Player?, category: string?) -> (),
	Dequeue: (self: QueueManager, player: Player?, key: string, category: string?) -> any?,
	Enqueue: (self: QueueManager, player: Player?, key: string, value: any, category: string?) -> (),
	Peek: (self: QueueManager, player: Player?, key: string, category: string?) -> any?,
	Size: (self: QueueManager, player: Player?, key: string, category: string?) -> number,
	defaultCategory: string,
	type: string,
}

local QueueMethods: QueueMethods = {
	type = "other",
	defaultCategory = "default",
} :: QueueMethods

local function newQueue(): Queue
	return {
		list = {},
		head = 1,
		size = 0,
	}
end

local function compactQueue(queue: Queue): ()
	if queue.head <= 128 then
		return
	end

	if queue.size == 0 then
		queue.list = {}
		queue.head = 1

		return
	end

	local newList: { [number]: any } = {}
	local index: number = 0
	local startIndex: number = queue.head
	local endIndex: number = queue.head + queue.size - 1
	local i: number = startIndex
	while i <= endIndex do
		index += 1
		newList[index] = queue.list[i]
		i += 1
	end

	queue.list = newList
	queue.head = 1
end

local function getCategories(self: QueueManager, player: Player?, create: boolean): { [string]: { [string]: Queue } }?
	if not player then
		local client: QueueManagerClient = self

		return client.queues
	end

	local server: QueueManagerServer = self
	local categories: { [string]: { [string]: Queue } } = server.queues[player]
	if not categories and create then
		categories = {}
		server.queues[player] = categories
	end

	return categories
end

local function getContainer(self: QueueManager, player: Player?, category: string?): { [string]: Queue }
	local categories: { [string]: { [string]: Queue } } =
		getCategories(self, player, true) :: { [string]: { [string]: Queue } }
	local categoryName: string = category or self.defaultCategory
	local container: { [string]: Queue } = categories[categoryName]
	if not container then
		container = {}
		categories[categoryName] = container
	end

	return container
end

local function getQueue(self: QueueManager, player: Player?, category: string?, key: string): Queue
	local container: { [string]: Queue } = getContainer(self, player, category)
	local queue: Queue = container[key]
	if not queue then
		queue = newQueue()
		container[key] = queue
	end

	return queue
end

function QueueMethods.Enqueue(self: QueueManager, player: Player?, key: string, value: any, category: string?): ()
	local queue: Queue = getQueue(self, player, category, key)
	local index: number = queue.head + queue.size
	queue.list[index] = value
	queue.size += 1
end

function QueueMethods.Dequeue(self: QueueManager, player: Player?, key: string, category: string?): any?
	local queue: Queue = getQueue(self, player, category, key)
	if queue.size == 0 then
		return
	end

	local value = queue.list[queue.head]
	queue.list[queue.head] = nil
	queue.head += 1
	queue.size -= 1

	compactQueue(queue)

	return value
end

function QueueMethods.Peek(self: QueueManager, player: Player?, key: string, category: string?): any?
	local queue: Queue = getQueue(self, player, category, key)
	if queue.size == 0 then
		return
	end

	return queue.list[queue.head]
end

function QueueMethods.Size(self: QueueManager, player: Player?, key: string, category: string?): number
	local queue: Queue = getQueue(self, player, category, key)

	return queue.size
end

function QueueMethods.Clear(self: QueueManager, player: Player?, key: string, category: string?): ()
	local categories: { [string]: { [string]: Queue } } =
		getCategories(self, player, false) :: { [string]: { [string]: Queue } }
	if not categories then
		return
	end

	local container: { [string]: Queue } = categories[category or self.defaultCategory]
	if container then
		container[key] = nil
	end
end

function QueueMethods.ClearAll(self: QueueManager, player: Player?, category: string?): ()
	if not category then
		if player then
			local server: QueueManagerServer = self
			server.queues[player] = nil
		else
			local client: QueueManagerClient = self
			client.queues = {}
		end

		return
	end

	local categories: { [string]: { [string]: Queue } } =
		getCategories(self, player, false) :: { [string]: { [string]: Queue } }
	if categories then
		categories[category] = nil
	end
end

local QueueServer: QueueManagerServer = setmetatable({
	queues = {},
}, { __index = QueueMethods }) :: any

local QueueClient: QueueManagerClient = setmetatable({
	Clear = WithoutPlayer(QueueMethods.Clear),
	ClearAll = WithoutPlayer(QueueMethods.ClearAll),
	Dequeue = WithoutPlayer(QueueMethods.Dequeue),
	Enqueue = WithoutPlayer(QueueMethods.Enqueue),
	Peek = WithoutPlayer(QueueMethods.Peek),
	Size = WithoutPlayer(QueueMethods.Size),
	queues = {},
}, { __index = QueueMethods }) :: any

function QueueServer.PlayerRemoving(self: QueueManagerServer, player: Player): ()
	self.queues[player] = nil
end

return (RunService:IsServer() and QueueServer or QueueClient) :: QueueManager
