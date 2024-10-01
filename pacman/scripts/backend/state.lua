if state then return state end
state = {}
state.__index = state

function state:create()
	local new = {}
	setmetatable(new, state)
	listener.define(new)

	return new
end

function state:update() end
function state:updatePost() end
function state:keyPressed() end
function state:keyReleased() end

function state:destroy() end

return state