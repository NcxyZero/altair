return function(text: string): boolean
	return pcall(function()
		for _ in utf8.codes(text) do
			continue --iterator wywala errora jak bedzie niedozwolony znak
		end
	end)
end
