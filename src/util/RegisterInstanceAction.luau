local RunService = game:GetService("RunService")

return function(
	scope: Instance,
	className: string,
	eventOrPropertyName: string,
	callback: (...any) -> (),
	allowOutsideStudio: true?
): (() -> ())?
	if not scope or not allowOutsideStudio and not RunService:IsStudio() then
		return
	end

	local connections: { [RBXScriptConnection]: RBXScriptSignal } = {}

	local function checkInstance(instance: Instance): ()
		if not instance:IsA(className) then
			return
		end

		local eventOrProperty: unknown? = instance[eventOrPropertyName]
		if not eventOrProperty then
			warn(`"{eventOrPropertyName}" not found in instance "{instance} of class matching "{className}""`)
			return
		end

		local event: RBXScriptSignal? = typeof(eventOrProperty) == "RBXScriptSignal" and eventOrProperty or nil
		local property: RBXScriptSignal? = not event
				and select(
					2,
					xpcall(function(): RBXScriptSignal<...any>
						return instance:GetPropertyChangedSignal(eventOrPropertyName)
					end, warn)
				)
			or nil

		local signal: RBXScriptSignal = event or property
		if not signal then
			warn(
				`"{eventOrPropertyName}" is not an event nor a property in instance "{instance} of class matching "{className}""`
			)
			return
		end

		connections[signal:Connect(callback)] = signal
	end

	connections[scope.DescendantAdded:Connect(checkInstance)] = scope.DescendantAdded

	task.spawn(function(): ()
		for _index: number, instance: Instance in scope:GetDescendants() do
			checkInstance(instance)
		end
	end)

	return function(): ()
		for connection: RBXScriptConnection, _signal: RBXScriptSignal in connections do
			connections[connection] = nil
			connection:Disconnect()
		end
	end
end
