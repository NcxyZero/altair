--!nocheck
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local modules = (script.Parent :: Folder):WaitForChild("modules")

local path = {}
path.controller = {}
path.module = {}
path.tag = {}
local loadFirst = {}
local load = {}

for _, module in modules:GetChildren() do
    pcall(function()
        local required = require(module) :: any
        local moduleType = required.type or "module"
        path[moduleType][module.Name] = required

        if moduleType == "controller" then
            if required.index then
                loadFirst[required.index] = required
            else
                table.insert(load, required) 
            end
        end
    
        path[moduleType][module.Name] = path[moduleType][module.Name] :: required.Default
    end)
end

local function InitController(required: any)
    required.path = path

    local Init = required.Init
    local PlayerAdded = required.PlayerAdded

    if Init then
        Init(required)
    end

    if PlayerAdded then
        for _, player in Players:GetPlayers() do
            PlayerAdded(required, player)
        end
    end
end

local tags = {}

local function InitTag(required: any)
    local tag = required.tag

    if not tag then
        return
    end

    local new = required.new

    if not new then
        return
    end

    local PlayerAdded = required.PlayerAdded

    CollectionService:GetInstanceAddedSignal(tag):Connect(function(instance: Instance)
        local class = new(instance)
        tags[instance] = class
        
        if PlayerAdded then
            for _, player in Players:GetPlayers() do
                PlayerAdded(required, player)
            end
        end
    end)

    CollectionService:GetInstanceRemovedSignal(tag):Connect(function(instance: Instance)
        if tags[instance] and tags[instance].Destroy then
            tags[instance]:Destroy(instance)
            tags[instance] = nil
        end
    end)

    for _, instance in CollectionService:GetTagged(tag) do
        local class = new(instance)
        tags[instance] = class
        
        if PlayerAdded then
            for _, player in Players:GetPlayers() do
                PlayerAdded(required, player)
            end
        end
    end
end

for _, required in loadFirst do
    InitController(required)
end

for _, required in load do 
    InitController(required)
end

for _, required in path.tag do
    task.spawn(InitTag, required)
end

Players.PlayerAdded:Connect(function(player: Player)
    for _, class in path.controller do
        if class.PlayerAdded then
            class:PlayerAdded(player)
        end
    end

     for _, class in tags do
        if class.PlayerAdded then
            class:PlayerAdded(player)
        end
    end

    player.CharacterAdded:Connect(function(character: Model)
        for _, class in path.controller do
            if class.CharacterAdded then
                class:CharacterAdded(player, character)
            end
        end

        for _, class in tags do
            if class.CharacterAdded then
                class:CharacterAdded(player, character)
            end
        end

        local humanoid = character:WaitForChild("Humanoid") :: Humanoid

        humanoid.Died:Connect(function()
            for _, class in path.controller do
                if class.Died then
                    class:Died(player, character)
                end
            end

            for _, class in tags do
                if class.Died then
                    class:Died(player, character)
                end
            end
        end)
    end)

    player.CharacterAppearanceLoaded:Connect(function(character: Model)
            for _, class in path.controller do
            if class.CharacterAppearanceLoaded then
                class:CharacterAppearanceLoaded(player, character)
            end
        end

        for _, class in tags do
            if class.CharacterAppearanceLoaded then
                class:CharacterAppearanceLoaded(player, character)
            end
        end
    end)
end)

RunService.Heartbeat:Connect(function(delta: number)
    for _, class in path.controller do
        task.defer(function()
            if class.Physics then
                class:Physics(delta)
            end
        end)
    end

    for _, class in tags do
        task.defer(function()
            if class.Physics then
                class:Physics(delta)
            end
        end)
    end
end)

RunService.PreSimulation:Connect(function(delta: number)
    for _, class in path.controller do
        task.defer(function()
            if class.Stepped then
                class:Stepped(delta)
            end
        end)
    end

    for _, class in tags do
        task.defer(function()
            if class.Stepped then
                class:Stepped(delta)
            end
        end)
    end
end)

RunService.PreRender:Connect(function(delta: number)
    for _, class in path.controller do
        task.defer(function()
            if class.Render then
                class:Render(delta)
            end
        end)
    end

    for _, class in tags do
        task.defer(function()
            if class.Render then
                class:Render(delta)
            end
        end)
    end
end)
