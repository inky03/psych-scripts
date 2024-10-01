if inky then return end
inky = {}
inky.aiBug = true
setmetatable(inky, {__index = ghost})

function inky:new(name, maze, data)
	local new = ghost:new(name, {0; 255; 255}, maze, data)
	setmetatable(new, {__index = inky})
	
	return new
end

function inky:target()
	if self.fright > 0 then return nil end
	if self.dead then return self:housePosition() end
	if self.mode == ghostMode.scatter then return {X = 2; Y = self.maze.meta.height} end

	if not currentState.ghosts then return nil end
	local pac = self:closestPacman()
	local blinky = currentState.ghosts.blinky
	local target = {
		X = pac.tilePosition.X + pac.curDir.X * 2 - (pac.curDir.Y < 0 and inky.aiBug and 2 or 0);
		Y = pac.tilePosition.Y + pac.curDir.Y * 2;
	}
	if blinky then
		target.X = blinky.tilePosition.X + (target.X - blinky.tilePosition.X) * 2
		target.Y = blinky.tilePosition.Y + (target.Y - blinky.tilePosition.Y) * 2
	end
	return target
end

function inky:prepare(maze)
	ghost.prepare(self) -- superclass
	self.tilePosition.X = self.maze.meta.width * .5
	--self.tilePosition.Y = 14
end

return inky