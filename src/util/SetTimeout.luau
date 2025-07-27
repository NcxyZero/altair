return function(time: number?, func: () -> ...any): () -> ()
	local cancelled: boolean = false

	task.delay(time, function(): ()
		if cancelled then
			return
		end

		func()
	end)

	return function(): ()
		cancelled = true
	end
end
