if ghost then return end
ghostMode = loadMod 'util.ghostMode'
entity = loadMod 'backend.entity'
ghost = {}
setmetatable(ghost, {__index = entity})

function ghost:new(name, color, maze, data)
	local new = entity:new(name, maze, data)
	new.fright = 0
	new.dead = false
	new.inTunnel = false
	new.specialTile = nil
	new.mode = ghostMode.scatter
	new.color = util.arrayOperate(color, '/', 255)
	new.speed = data.ghost_speed.normal * util.percentToSpeed
	new.nextDir = {X = -1; Y = 0}
	new.curDir = {X = new.nextDir.X; Y = 0}
	setmetatable(new, {__index = ghost})
	
	local spr = new.sprite
	spr.frames = Paths.getSparrowAtlas('ghost-body')
	spr.animation.addByPrefix('main', 'ghost body', 30, true)
	spr.animation.addByPrefix('regenerate', 'body regeneration', 30, false)
	spr.addOffset('regenerate', 2, 0)
	spr.addOffset('main', 0, 0)
	spr.playAnim('main')
	spr.shader = game.createRuntimeShader('goodRgb')
	util.shaderSet(spr.shader, {r = new.color; b = {0; 0; 0}; g = {1; 1; 1}; dim = .3; a = 1; pixel = 0})
	new.frightColor = {new.color[1] * .5, new.color[2] * .5, new.color[3] * .5 + .5}
	game.add(new.sprGroup)
	local eyes = LuaSprite:new() --reference.createInstance(name .. 'Eyes', 'psychlua.ModchartSprite')
	eyes.antialiasing = antialiasing
	eyes.frames = Paths.getSparrowAtlas('ghost-eyes')
	eyes.animation.addByPrefix('regular', 'ghost eyes', 0)
	eyes.animation.addByPrefix('eaten', 'ghost eaten eyes', 24, false)
	eyes.animation.addByPrefix('sad', 'ghost sad eyes', 0)
	eyes.animation.addByPrefix('angry', 'ghost angry eyes', 0)
	eyes.animation.addByPrefix('pissed', 'ghost mad eyes', 0)
	eyes.addOffset('regular', -1, -.5)
	eyes.addOffset('eaten', -5, -2)
	eyes.addOffset('sad', -4, -5)
	eyes.addOffset('angry', 0, -3.5)
	eyes.addOffset('pissed', 3, 3)
	eyes.playAnim('regular')
	eyes.shader = game.createRuntimeShader('goodRgb')
	util.shaderSet(eyes.shader, {r = {0; 0; 1}; g = {1; 1; 1}; b = {0; 0; 0}; dim = .6; a = 1})
	new.eyes = eyes
	new.sprGroup.add(eyes)
	
	local targetSpr = FlxSprite:new() --reference.createInstance(name .. 'Target', 'flixel.FlxSprite')
	targetSpr.makeGraphic(1, 1, -1)
	targetSpr.color = getColorFromHex(string.format('%02x%02x%02x', color[1], color[2], color[3]))
	targetSpr.scale.set(32, 32)
	targetSpr.updateHitbox()
	game.add(targetSpr)
	new.targetDebug = targetSpr
	
	new.offset.X = spr.width * .25
	new.offset.Y = spr.height * .25
	new.move.X = new.curDir.X
	
	new:addEventListener('fright', new.frighten)
	new:addEventListener('kill', new.kill)
	return new
end

local dirPriority = {{X = 0; Y = -1}; {X = -1; Y = 0}; {X = 0; Y = 1}; {X = 1; Y = 0}}

function ghost.getEyeFrame(dir)
    local frame = (dir.Y == 0 and 0 or 1)
    if dir.X > 0 or dir.Y > 0 then frame = frame + 2 end
    return frame
end
function ghost:pathfind(dir, pos, target)
	local freeDirs = {}
	local nextPos = {X = pos.X + self.curDir.X; Y = pos.Y + self.curDir.Y}
	local special = self.maze:getSpecial(nextPos.X, nextPos.Y)
	local restrictDir = nil
	if special and special.kind == maze.movementRestricted then restrictDir = special.restrictDir end
	for i, dir in ipairs(dirPriority) do
		if i == restrictDir then goto blocked end
		if (dir.X ~= 0 and dir.X == -self.curDir.X) or (dir.Y ~= 0 and dir.Y == -self.curDir.Y) then goto blocked end
		if not self.maze:colliding(nextPos.X + dir.X, nextPos.Y + dir.Y) then table.insert(freeDirs, dir) end
		::blocked::
	end
	local nextDir
	if #freeDirs == 0 then return end
	if target == nil then
		nextDir = freeDirs[getRandomInt(1, #freeDirs)]
		return nextDir.X, nextDir.Y
	elseif #freeDirs > 0 then
		local closest = {dir = nil; dist = nil}
		for _, dir in ipairs(freeDirs) do
			local from = {X = nextPos.X + dir.X; Y = nextPos.Y + dir.Y}
			local dist = util.euclideanDist(from, target)
			--if self.name == 'blinky' then debugPrint(dir.X .. ',' .. dir.Y .. ' : (' .. from.X .. ',' .. from.Y .. ') - (' .. target.X .. ',' .. target.Y .. ') = ' .. (util.round(dist * 100) / 100)) end
			if not closest.dist or dist < closest.dist then
				closest.dist = dist
				closest.dir = dir
			end
		end
		return closest.dir.X, closest.dir.Y
	end
end
function ghost:unfrighten()
	if self.dead then return end
	local color = self.color
	self.fright = 0
	self.eyes.animation.curAnim.curFrame = self.getEyeFrame(self.nextDir)
	util.shaderSet(self.sprite.shader, {r = self.color})
	util.shaderSet(self.eyes.shader, {g = {1; 1; 1}})
	if self.frightBy then self.frightBy:dispatchEvent('onUnfrighted', self.frightBy, self) end
	self:dispatchEvent('unfright', self)
end
function ghost:frighten(culprit, duration)
	if self.dead then return end
	self:turn()

	if duration <= 0 then self:dispatchEvent('unfright', self) return end

	local color = self.color
	self.fright = duration
	self.frightBy = culprit
	util.shaderSet(self.sprite.shader, {r = self.frightColor})
	util.shaderSet(self.eyes.shader, {g = {1; 0xb8 / 255; 0xae / 255}})
	self:dispatchEvent('frighted', culprit, self, duration)
	if culprit then culprit:dispatchEvent('onFrighted', culprit, self, duration) end
end
function ghost:kill(culprit)
	if self.dead then return end
	if self.fright > 0 then self:unfrighten() end

	self.dead = true
	self.justKilled = true
	util.shaderSet(self.sprite.shader, {a = 0})

	if culprit then
		local prev = culprit.sprite.animation.name
		culprit.sprite.playAnim('bite', true)
		currentState.pausedLogic = true
		self.eyes.playAnim('eaten')
		tween.tween(0, 0, currentState:tickToSecs(64), {onComplete = function()
			currentState.pausedLogic = false
			culprit.sprite.playAnim(prev)
			self.eyes.playAnim('sad')
			self.justKilled = false
		end})
	end
end
function ghost:turn()
	self.nextDir.X = -self.curDir.X
	self.nextDir.Y = -self.curDir.Y
end
function ghost:closestPacman()
	return currentState.pacmen.pacman
end
function ghost:housePosition()
	local house = self.maze.meta.ghost_house.exit
	return {X = house.x; Y = house.y}
end

function ghost:tick()
	local tile = self.tilePosition
	local ghostSpeed = self.lvData.ghost_speed
	self.specialTile = self.maze:getSpecial(util.round(tile.X), util.round(tile.Y))
	self.inTunnel = (self.specialTile and self.specialTile.kind == maze.slowTile)
	if self.fright <= 0 then
		if self.dead then
			self.speed = 2
		else
			self.speed = ghostSpeed[self.inTunnel and 'tunnel' or 'normal'] * util.percentToSpeed
		end
	else
		self.speed = ghostSpeed.fright * util.percentToSpeed
	end
	if util.isInt(tile.X) and util.isInt(tile.Y) then
		local target = self:target()
		self.curDir.X = self.nextDir.X
		self.curDir.Y = self.nextDir.Y
		self.move.X = self.curDir.X
		self.move.Y = self.curDir.Y
		self.nextDir.X, self.nextDir.Y = self:pathfind(self.nextDir, tile, target)
		if self.nextDir.X ~= self.curDir.X or self.nextDir.Y ~= self.curDir.Y then
			self:dispatchEvent('onTurn', self)
		end
		if self.fright <= 0 then
		  self:updateEyeFrame()
		end
	end
	self:doMove()
end
function ghost:updateEyeFrame()
	self.eyes.animation.curAnim.curFrame = self.getEyeFrame(self.nextDir)
end

function ghost:target() end
function ghost:prepare()
	self.tilePosition.Y = self.maze.meta.ghost_house.exit.y
end

function ghost:update()
	entity.update(self)
	if self.fright > 0 then
		self.fright = self.fright - 1
		self.eyes.animation.curAnim.curFrame = (self.sprite.animation.curAnim.curFrame < 2 and 4 or 5)
		--debugPrint(self.name .. ' : ' .. self.fright)
		if self.fright <= 0 then
			self.fright = 0
			self:unfrighten()
		end
	end
end

function ghost:updatePos()
	entity.updatePos(self)
	local target = self:target()
	if target then
		self.targetDebug.x = target.X * 32
		self.targetDebug.y = target.Y * 32
		self.targetDebug.visible = true
	else
		self.targetDebug.visible = false
	end
end

function ghost:destroy()
	self.eyes:destroy()
	self.targetDebug:destroy()
	entity.destroy(self)
end

return ghost