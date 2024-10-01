if listener then return listener end
listener = {}

function listener.define(tbl)
	tbl.listeners = {}
	tbl.addEventListener = function(self, event, func)
		if not self.listeners[event] then
			self.listeners[event] = {func}
			return func
		end
		table.insert(self.listeners[event], func)
		return func
	end
	tbl.dispatchEvent = function(self, event, ...)
		if not self.listeners[event] then return end
		for _, f in ipairs(self.listeners[event]) do
			f(...)
		end
	end
end
return listener