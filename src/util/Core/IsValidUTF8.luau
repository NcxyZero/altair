return function(text: string): boolean
	return xpcall(function(): ()
		for _ in utf8.codes(text) do
			continue -- the iterator throws an error if there is an illegal character
		end
	end, warn)
end
