return function(): ()
	if not game:IsLoaded() then
		game.Loaded:Wait()
	end
end
