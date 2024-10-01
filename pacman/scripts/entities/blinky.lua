if blinky then return end
blinky = {}
setmetatable(blinky, {__index = ghost})

function blinky:new(name, maze, data)
	local new = ghost:new(name, {255; 0; 0}, maze, data)
	setmetatable(new, {__index = blinky})

	new.elroy = 0
	new.elroyPoint = new.lvData.elroy_dots or 0
	new:addEventListener('preMove', new.elroyStuff)
	currentState:addEventListener('pelletEaten', function(pac, eaten) new:detectElroy(eaten) end)
	return new
end

function blinky:detectElroy(eaten)
	local pelletsLeft = currentState.pelletCount - eaten
	if pelletsLeft == self.elroyPoint then
		self.elroy = 1
		self:updateEyeAnim()
	elseif pelletsLeft == math.floor(self.elroyPoint * .5) then
		self.elroy = 2
		self:updateEyeAnim()
	end
end
function blinky:updateEyeAnim()
	if self.elroy == 1 then
		self.eyes.playAnim('angry')
		self:updateEyeFrame()
	elseif self.elroy == 2 then
		self.eyes.playAnim('pissed')
		self:updateEyeFrame()
	end
end
function blinky:elroyStuff()
	if not currentState.pelletCount or self.dead or self.fright > 0 then return end
	if self.elroy == 2 then
		self.speed = self.lvData.ghost_speed.elroy2 * util.percentToSpeed
	elseif self.elroy == 1 then
		self.speed = self.lvData.ghost_speed.elroy1 * util.percentToSpeed
	end
end

function blinky:target()
	if self.fright > 0 then return nil end
	if self.dead then return self:housePosition() end
	if self.mode == ghostMode.scatter then return {X = self.maze.meta.width - 4; Y = 0} end
	return self:closestPacman().tilePosition
end

function blinky:prepare(maze)
	ghost.prepare(self) -- superclass
	self.tilePosition.X = self.maze.meta.width * .5
end

return blinky