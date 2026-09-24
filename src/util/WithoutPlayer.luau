local function WithoutPlayer<Self, Arguments..., Results...>(method: (Self, Player?, Arguments...) -> Results...): (Self, Arguments...) -> Results...
	return function(self: Self, ...: Arguments...): Results...
		return method(self, nil, ...)
	end
end

return WithoutPlayer
