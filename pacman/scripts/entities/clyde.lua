if clyde then return end
clyde = {}
setmetatable(clyde, {__index = ghost})

function clyde:new(name, maze, data)
	local new = ghost:new(name, {255; 184; 81}, maze, data)
	setmetatable(new, {__index = clyde})
	
	return new
end

function clyde:target()
	if self.fright > 0 then return nil end
	if self.dead then return self:housePosition() end
	if self.mode == ghostMode.scatter then return {X = self.maze.meta.width - 2; Y = self.maze.meta.height} end
	local pac = self:closestPacman()
	if util.euclideanDist(self.tilePosition, pac.tilePosition) < 8 then
		return {X = 0; Y = 34}
	else
		return {X = pac.tilePosition.X; Y = pac.tilePosition.Y}
	end
end

function clyde:prepare(maze)
	ghost.prepare(self) -- superclass
	self.tilePosition.X = self.maze.meta.width * .5
	--self.tilePosition.Y = 14
end

return clyde