if entity then return end
entity = {}
entity.__index = entity

function entity:new(name, maze, data)
	local new = {
		name = name;
		tilePosition = {X = 0; Y = 0};
		offset = {X = 0; Y = 0};
		move = {X = 0; Y = 0};
		lvData = data;
		maze = maze;
		delta = 0;
		speed = 1;
	}
	setmetatable(new, entity)
	listener.define(new)
	
	local grp = SpriteGroup.new(new.name .. 'Group')
	local spr = LuaSprite.new(new.name)
	spr.antialiasing = antialiasing
	grp.add(spr)
	new.sprGroup = grp
	new.sprite = spr
	
	return new
end

function entity:safeFunc(func, ...) if type(self[func]) == 'function' then self[func](self, ...) end end
function entity:update()
	self:dispatchEvent('update', self)
	self.delta = self.delta + self.speed
	while self.delta >= 1 do
		self:dispatchEvent('preTick', self)
		self:tick()
		self.delta = self.delta - 1
		self:dispatchEvent('postTick', self)
	end
end
function entity:draw() -- this is not drawing but i dont care
	self:dispatchEvent('preDraw', self)
	self:updatePos()
	self:dispatchEvent('postDraw', self)
end
function entity:tick() end
function entity:doMove()
	self:dispatchEvent('preMove', self)
	self.tilePosition.X = self.tilePosition.X + self.move.X * .125
	self.tilePosition.Y = self.tilePosition.Y + self.move.Y * .125
	if self.maze then
		if self.tilePosition.X > self.maze.meta.width then
			self.tilePosition.X = self.tilePosition.X - self.maze.meta.width
		elseif self.tilePosition.X < 0 then
			self.tilePosition.X = self.tilePosition.X + self.maze.meta.width
		end
	end
	self:dispatchEvent('postMove', self)
end
function entity:updatePos()
	local grp = self.sprGroup
	local m = .125
	grp.x = (self.tilePosition.X + self.delta * self.move.X * m) * 32 - self.offset.X
	grp.y = (self.tilePosition.Y + self.delta * self.move.Y * m) * 32 - self.offset.Y
end
function entity:destroy()
	self.sprite:destroy()
	self.sprGroup:destroy()
	self = nil
end

return entity