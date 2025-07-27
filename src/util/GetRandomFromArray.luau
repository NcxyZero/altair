return function<T>(array: { T }): T
	return array[math.random(1, #array)]
end
