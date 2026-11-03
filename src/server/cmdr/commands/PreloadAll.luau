local ReplicatedStorage = game:GetService("ReplicatedStorage")

return {
	Name = "preloadAll",
	Aliases = { "preloadassets" },
	Description = "Load all replicated/UI assets and print failed or inaccessible assets to Studio Output.",
	Group = "Admin",
	Args = {},
	ClientRun = function(context: any): string
		local AssetPreloader = require(ReplicatedStorage.util.Core.AssetPreloader)
		local playerGui: PlayerGui = context.Executor:WaitForChild("PlayerGui") :: PlayerGui

		return AssetPreloader.Preload(playerGui)
	end,
}
