if pacman then return end
entity = loadMod 'backend.entity'
pacman = {}
setmetatable(pacman, {__index = entity})

function pacman:new(name, maze, data)
	local new = entity:new(name, maze, data)
	new.nextDir = {X = -1; Y = 0}
	new.curDir = {X = -1; Y = 0}
	new.pelletFreeze = 0
	new.flick = 0
	new.wa = true
	new.waSnd = FlxSound:new()
	new.kaSnd = FlxSound:new()
	new.waSnd.loadEmbedded(Paths.sound('eat_1'))
	new.kaSnd.loadEmbedded(Paths.sound('eat_2'))
	FlxG.sound.list.add(new.waSnd)
	FlxG.sound.list.add(new.kaSnd)
	setmetatable(new, {__index = pacman})
	
	local spr = new.sprite
	spr.frames = Paths.getSparrowAtlas('pacman')
	spr.animation.addByPrefix('munch', 'pacman munch', 30, true)
	spr.animation.addByPrefix('aggro', 'pacman sharp', 30, true)
	spr.animation.addByPrefix('bite', 'pacman whack', 24, false)
	spr.animation.addByPrefix('death', 'pacman die', 30, true)
	spr.playAnim('munch')
	spr.shader = game.createRuntimeShader('goodRgb')
	util.shaderSet(spr.shader, {r = {1; 1; 0}; b = {0; 0; 0}; g = {1; 1; 1}; dim = 1; a = 1; pixel = 0})
	game.add(new.sprGroup)
	
	new.offset.X = spr.width * .25
	new.offset.Y = spr.height * .25
	new.move.X = -1
	new.speed = data.pacman_speed.normal * util.percentToSpeed
	new.tilePosition.X = maze.meta.pacmen[new.name].x
	new.tilePosition.Y = maze.meta.pacmen[new.name].y
	
	new:addEventListener('onUnfrighted', new.unfrighted)
	
	return new
end

function pacman:update()
	for _, ghost in pairs(currentState.ghosts) do
		if self:collide(ghost) then return end
	end
	if self.flick > 0 then self.flick = self.flick - 1 end
	if self.pelletFreeze > 0 then
		self.pelletFreeze = self.pelletFreeze - 1
	else
		entity.update(self)
	end
end
function pacman:tick()
	if self.pelletFreeze > 0 then return end
	local tile = self.tilePosition
	if util.isInt(tile.X) and self.curDir.X == 0 then self.move.X = 0 end
	if util.isInt(tile.Y) and self.curDir.Y == 0 then self.move.Y = 0 end
	if util.isInt(tile.X) and util.isInt(tile.Y) then
		if self.maze:colliding(tile.X + self.move.X, tile.Y) then
			self.move.X = 0
		end
		if self.maze:colliding(tile.X, tile.Y + self.move.Y) then
			self.move.Y = 0
		end
	end
	local pellet = self.maze:getPellet(util.round(tile.X), util.round(tile.Y))
	if pellet then
		if not pellet.eaten then
			pellet.eaten = true
			pellet.sprite.kill()
			currentState.pelletsEaten = currentState.pelletsEaten + 1
			currentState:dispatchEvent('pelletEaten', self, currentState.pelletsEaten)
			self.pelletFreeze = (pellet.power and 3 or 1)
			-- hscript['fps']:setProgress(pelletsEaten, pelletCount)

			local snd = (self.wa and self.waSnd or self.kaSnd)
			self.wa = not self.wa
			snd.play()

			if pellet.power then
				local frightTime = self.lvData.fright_duration
				currentState:dispatchEvent('power', self, frightTime)
				for _, ghost in pairs(currentState.ghosts) do
					ghost:dispatchEvent('fright', ghost, self, frightTime)
				end
				if currentState:frightCount() > 0 then
					self.sprite.playAnim('aggro')
				end
			end
		end
	end
	if not self.maze:colliding(util.round(tile.X) + self.nextDir.X, util.round(tile.Y) + self.nextDir.Y) then
		if self.nextDir.X ~= 0 then
			self.move.X = self.nextDir.X
			self.move.Y = util.sign(util.round(tile.Y) - tile.Y)
		end
		if self.nextDir.Y ~= 0 then
			self.move.Y = self.nextDir.Y
			self.move.X = util.sign(util.round(tile.X) - tile.X)
		end
		self.curDir.X = self.nextDir.X
		self.curDir.Y = self.nextDir.Y
	end
	self:doMove()
end
function pacman:unfrighted(ghost)
	if currentState:frightCount() == 0 then
		self.sprite.playAnim('munch')
	end
end
function pacman:collide(ghost)
	if not ghost.dead
	and util.round(self.tilePosition.X) == util.round(ghost.tilePosition.X)
	and util.round(self.tilePosition.Y) == util.round(ghost.tilePosition.Y) then
		if ghost.fright > 0 then
			ghost:dispatchEvent('kill', ghost, self)
			self:dispatchEvent('onKilled', self, ghost)
		end
		return true
	end
	return false
end

function pacman:updatePos()
	entity.updatePos(self) -- superclass
	local spr = self.sprite
	if self.move.X ~= 0 or self.move.Y ~= 0 then
		spr.angle = math.deg(math.atan2(self.move.Y, self.move.X))
		spr.animation.timeScale = 1
	else
		spr.animation.timeScale = 0
	end
end

function pacman:destroy()
	self.waSnd:destroy()
	self.kaSnd:destroy()
	entity.destroy(self)
end

return pacman