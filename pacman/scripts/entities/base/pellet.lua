-- this is not an entity per se but, what gives
if pellet then return end
pellet = {}
pellet.__index = pellet

function pellet:new(x, y, power)
	local new = {eaten = false; power = power or false}
	setmetatable(new, pellet)
	
	local spr = LuaSprite:new() --.new(pellet.getKey(x, y))
	spr.x = x * 32 + 6
	spr.y = y * 32 + 6
	if power then
		spr.frames = Paths.getSparrowAtlas('energizer')
		spr.animation.addByPrefix('big', 'power pellet0', 24, false)
		spr.animation.addByPrefix('small', 'power pellet small', 24, false)
		spr.addOffset('big', 11, 13)
		spr.addOffset('small', 5, 5)
		spr.playAnim('small')
	else
		--spr.loadGraphic(Paths.image('pellet'))
		spr.active = false
	end
	spr.antialiasing = antialiasing
	new.sprite = spr
	
	return new
end
function pellet:destroy()
	self.sprite:destroy()
end
function pellet:bop(beat)
	if self.power then
		local spr = self.sprite
		spr.playAnim(beat % 2 == 0 and 'big' or 'small')
	end
end
function pellet.getKey(x, y)
	return ('pellet' .. x .. 'x' .. y)
end

return pellet