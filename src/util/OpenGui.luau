local OpenGui = {}
OpenGui.current = { exec = nil, id = nil }

function OpenGui:Handle(id: any, show: any, hide: any)
	pcall(function()
		if self.current.exec and typeof(self.current.exec) == "function" then
			self.current.exec()
		end
	end)

	self.current.id = id
	self.current.exec = hide

	if typeof(show) == "function" then
		show()
	end
end

return OpenGui
