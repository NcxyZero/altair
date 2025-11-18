local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.shared.config.GameConfig)
local InitializerTypes = require(ReplicatedStorage.shared.types.InitializerTypes)
local LocalPlayer = require(ReplicatedStorage.util.LocalPlayer)
local Logger = require(ReplicatedStorage.util.Logger)
local Promise = require(ReplicatedStorage.package.Promise)
local RaycastActions = require(ReplicatedStorage.client.clientConfig.RaycastActions)
local WaitForGameToLoad = require(ReplicatedStorage.util.WaitForGameToLoad)

export type Default = {
	index: number?,
	type: string?,
	path: InitializerTypes.ClientPath,
	lastRaycastInstance: Instance,
	lastRaycastActionName: string,
	RaycastPlayerStanding: (self: Default, raycastParams: RaycastParams) -> (),
	Init: (self: Default) -> (),
}

local RaycastController: Default = {} :: Default
RaycastController.type = "controller"

function RaycastController:RaycastPlayerStanding(raycastParams: RaycastParams): ()
	local primaryPart: BasePart = LocalPlayer.Character and LocalPlayer.Character.PrimaryPart
	if not primaryPart then
		return
	end

	local raycast: RaycastResult = workspace:Raycast(primaryPart.Position, Vector3.yAxis * -50, raycastParams)
	if not raycast or not raycast.Instance then
		if self.lastRaycastActionName and self.lastRaycastInstance then
			RaycastActions[self.lastRaycastActionName](self.lastRaycastInstance, true)

			self.lastRaycastInstance = nil
			self.lastRaycastActionName = nil
		end

		return
	end

	local raycastActionName: string = raycast.Instance:GetAttribute("RaycastAction") :: string
	if not raycastActionName then
		Logger.warn(`No RaycastAction attribute found on RaycastDetect instance "{raycast.Instance}"`)
		return
	end

	local raycastAction: (instance: Instance, leaving: boolean?) -> () = RaycastActions[raycastActionName]
	if not raycastAction then
		Logger.warn(
			`No RaycastAction found in RaycastActions config for name "{raycastActionName}" on RaycastDetect instance "{raycast.Instance}"`
		)
		return
	end

	if raycastActionName == self.lastRaycastActionName then
		return
	elseif self.lastRaycastActionName and self.lastRaycastInstance then
		RaycastActions[raycastActionName](self.lastRaycastInstance, true)
	end

	self.lastRaycastInstance = raycast.Instance
	self.lastRaycastActionName = raycastActionName

	local raycastActionAnimationName: string = raycast.Instance:GetAttribute("RaycastActionAnimation") :: any
	if raycastActionAnimationName then
		local raycastActionAnimation = self.path.tag[raycast.Instance][raycastActionAnimationName]
		if raycastActionAnimation and raycastActionAnimation.Animate then
			raycastActionAnimation:Animate()
		end
	end

	raycastAction(raycast.Instance)
end

function RaycastController:Init(): ()
	task.defer(function(): ()
		WaitForGameToLoad()

		local raycastParams: RaycastParams = RaycastParams.new()
		raycastParams.FilterType = Enum.RaycastFilterType.Include
		raycastParams.FilterDescendantsInstances = { CollectionService:GetTagged("RaycastDetect") }

		Promise.retryWithDelay(function(): Promise.TypedPromise<>
			return Promise.new(function(_resolve: () -> (), reject: () -> ()): ()
				reject(self:RaycastPlayerStanding(raycastParams))
			end)
		end, math.huge, GameConfig.core.raycastDetectionTimeout)
	end)
end

return RaycastController
