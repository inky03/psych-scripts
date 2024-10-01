if pinky then return end
pinky = {}
pinky.aiBug = true
setmetatable(pinky, {__index = ghost})

function pinky:new(name, maze, data)
	local new = ghost:new(name, {255; 184; 255}, maze, data)
	setmetatable(new, {__index = pinky})
	new.onFlick = false

	new:addEventListener('onTurn', new.updateAward)
	return new
end

function pinky:updateAward()
	if self.fright > 0 then
		self.onFlick = false
		return
	end
	local pac = self:closestPacman()
	local onLine = util.round(pac.tilePosition.X) == util.round(self.tilePosition.X)
	onLine = onLine or (util.round(pac.tilePosition.Y) == util.round(self.tilePosition.Y))
	if self.onFlick and pac.flick > 0 and onLine then
		debugPrint('GOTCHA')
	else
		self.onFlick = false
	end
end

function pinky:target()
	if self.fright > 0 then return nil end
	if self.dead then return self:housePosition() end
	if self.mode == ghostMode.scatter then return {X = 4; Y = 0} end
	local pac = self:closestPacman()
	local tile = pac.tilePosition
	return {X = tile.X + pac.curDir.X * 4 - (pac.curDir.Y < 0 and pinky.aiBug and 4 or 0); Y = tile.Y + pac.curDir.Y * 4}
end

function pinky:prepare(maze)
	ghost.prepare(self) -- superclass
	self.tilePosition.X = self.maze.meta.width * .5
	--self.tilePosition.Y = 14
end

return pinky