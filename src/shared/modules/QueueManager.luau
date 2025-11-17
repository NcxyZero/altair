local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local InitializerTypes = require(ReplicatedStorage.shared.types.InitializerTypes)

local isServer: boolean = RunService:IsServer()

export type Queue = {
	list: { [number]: any },
	head: number,
	size: number,
}

export type QueueManagerServer = {
	path: InitializerTypes.ServerPath,
	defaultCategory: string,
	queues: { [Player]: { [string]: { [string]: Queue } } },
	Enqueue: (self: QueueManager, player: Player, key: string, value: any, category: string?) -> (),
	Dequeue: (self: QueueManager, player: Player, key: string, category: string?) -> any?,
	Peek: (self: QueueManager, player: Player, key: string, category: string?) -> any?,
	Size: (self: QueueManager, player: Player, key: string, category: string?) -> number,
	Clear: (self: QueueManager, player: Player, key: string, category: string?) -> (),
	ClearAll: (self: QueueManager, player: Player, category: string?) -> (),
	PlayerRemoving: (self: QueueManager, player: Player) -> (),
}

export type QueueManagerClient = {
	path: InitializerTypes.ClientPath,
	defaultCategory: string,
	queues: { [string]: { [string]: Queue } },
	Enqueue: (self: QueueManager, key: string, value: any, category: string?) -> (),
	Dequeue: (self: QueueManager, key: string, category: string?) -> any?,
	Peek: (self: QueueManager, key: string, category: string?) -> any?,
	Size: (self: QueueManager, key: string, category: string?) -> number,
	Clear: (self: QueueManager, key: string, category: string?) -> (),
	ClearAll: (self: QueueManager, category: string?) -> (),
}

export type QueueManager = QueueManagerServer & QueueManagerClient

local defaultCategory: string = "default"

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

local QueueMeta = {
	type = "other",
	defaultCategory = defaultCategory,
}

local QueueServer: QueueManagerServer = table.clone(QueueMeta) :: any
local QueueClient: QueueManagerClient = table.clone(QueueMeta) :: any

QueueServer.queues = {}
QueueClient.queues = {}

local function getServerQueue(self: QueueManagerServer, player: Player, category: string?, key: string): Queue
	local playerMap: { [string]: { [string]: Queue } } = self.queues[player]
	if not playerMap then
		playerMap = {}
		self.queues[player] = playerMap
	end

	local categoryName: string = category or self.defaultCategory
	local categoryMap: { [string]: Queue } = playerMap[categoryName]
	if not categoryMap then
		categoryMap = {}
		playerMap[categoryName] = categoryMap
	end

	local queue = categoryMap[key]
	if not queue then
		queue = newQueue()
		categoryMap[key] = queue
	end

	return queue
end

local function getClientQueue(self: QueueManagerClient, category: string?, key: string): Queue
	local categoryName: string = category or self.defaultCategory
	local categoryMap: { [string]: Queue } = self.queues[categoryName]
	if not categoryMap then
		categoryMap = {}
		self.queues[categoryName] = categoryMap
	end

	local queue = categoryMap[key]
	if not queue then
		queue = newQueue()
		categoryMap[key] = queue
	end

	return queue
end

function QueueServer:Enqueue(player: Player, key: string, value: any, category: string?): ()
	local queue: Queue = getServerQueue(self, player, category, key)
	local index: number = queue.head + queue.size
	queue.list[index] = value
	queue.size += 1
end

function QueueClient:Enqueue(key: string, value: any, category: string?): ()
	local queue: Queue = getClientQueue(self, category, key)
	local index: number = queue.head + queue.size
	queue.list[index] = value
	queue.size += 1
end

function QueueServer:Dequeue(player: Player, key: string, category: string?): any?
	local queue: Queue = getServerQueue(self, player, category, key)
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

function QueueClient:Dequeue(key: string, category: string?): any?
	local queue: Queue = getClientQueue(self, category, key)
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

function QueueServer:Peek(player: Player, key: string, category: string?): any?
	local queue: Queue = getServerQueue(self, player, category, key)
	if queue.size == 0 then
		return
	end

	return queue.list[queue.head]
end

function QueueClient:Peek(key: string, category: string?): any?
	local queue: Queue = getClientQueue(self, category, key)
	if queue.size == 0 then
		return
	end

	return queue.list[queue.head]
end

function QueueServer:Size(player: Player, key: string, category: string?): number
	local queue: Queue = getServerQueue(self, player, category, key)

	return queue.size
end

function QueueClient:Size(key: string, category: string?): number
	local queue: Queue = getClientQueue(self, category, key)

	return queue.size
end

function QueueServer:Clear(player: Player, key: string, category: string?): ()
	local playerMap: { [string]: { [string]: Queue } } = self.queues[player]
	if not playerMap then
		return
	end

	local categoryName: string = category or self.defaultCategory
	local categoryMap: { [string]: Queue } = playerMap[categoryName]
	if not categoryMap then
		return
	end

	categoryMap[key] = nil
end

function QueueClient:Clear(key: string, category: string?): ()
	local categoryName: string = category or self.defaultCategory
	local categoryMap: { [string]: Queue } = self.queues[categoryName]
	if not categoryMap then
		return
	end

	categoryMap[key] = nil
end

function QueueServer:ClearAll(player: Player, category: string?): ()
	if not category then
		self.queues[player] = nil

		return
	end

	local playerMap = self.queues[player]
	if playerMap then
		playerMap[category] = nil
	end
end

function QueueClient:ClearAll(category: string?): ()
	if not category then
		self.queues = {}

		return
	end

	self.queues[category] = nil
end

function QueueServer:PlayerRemoving(player: Player): ()
	self.queues[player] = nil
end

return (isServer and QueueServer or QueueClient) :: QueueManager
