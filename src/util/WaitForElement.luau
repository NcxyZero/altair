return function<T>(element: T & any, maxRetries: number?, waitCooldown: number?): T
	local counter: number = 0

	while not element do
		task.wait(waitCooldown)
		counter += 1

		if maxRetries and counter == maxRetries then
			warn(`{maxRetries} retries passed while waiting for the element.`)
			print(debug.traceback())
		end
	end

	return element
end
