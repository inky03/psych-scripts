if maze then return end
tiles = loadMod 'util.tiles'
pellet = loadMod 'entities.base.pellet'
maze = {}
maze.__index = maze

maze.chars = {
	[' '] = tiles.air;
	['w'] = tiles.air;
	['#'] = tiles.wall;
	['.'] = tiles.pellet;
	['W'] = tiles.pellet;
	['o'] = tiles.bigpellet;
	['O'] = tiles.power;
	['<'] = tiles.slow;
}
maze.slowTile = 0
maze.movementRestricted = 1
maze.specialChars = { -- special tile types
	['<'] = {kind = maze.slowTile};
	['w'] = {kind = maze.movementRestricted; restrictDir = 1};
	['a'] = {kind = maze.movementRestricted; restrictDir = 2};
	['s'] = {kind = maze.movementRestricted; restrictDir = 3};
	['d'] = {kind = maze.movementRestricted; restrictDir = 4};
}
for _, k in ipairs{'W'; 'A'; 'S'; 'D'} do maze.specialChars[k] = maze.specialChars[k:lower()] end

function maze:new(set, name, useBackdrop)
	local new = {meta = {}; pellets = {}; special = {}}
	setmetatable(new, maze)
	listener.define(new)
	
	local mazePath = 'mazes/' .. set .. '/' .. name
	util.tableAppend(new.meta, util.getJSON('mazes/' .. set .. '/general.json'))
	util.tableAppend(new.meta, util.getJSON(mazePath .. '.json'))
	
	new.meta._path = mazePath
	new.meta.symmetric = new.meta.symmetric or true
	
	local content = getTextFromFile(mazePath .. '.txt')
	local cols = stringSplit(content:gsub('\r', ''), '\n')
	new.meta.width = 0
	new.meta.height = #cols
	for y, v in ipairs(cols) do
		v = v:gsub('\t', '    ')
		local col = stringSplit(new.meta.symmetric and (v .. v:reverse()) or v, '')
		for x, row in ipairs(col) do
			local special = maze.specialChars[row]
			if special then
				new.special[maze.getTileKey(x - 1, y - 1)] = special
			end
			col[x] = (maze.chars[row] or col[x])
		end
		new.meta.width = math.max(new.meta.width, #col - 1)
		cols[y] = col
	end
	new.tiles = cols
	
	local grp = SpriteGroup:new()
	new.sprGroup = grp

	local spr
	if useBackdrop then
		import 'flixel.addons.display.FlxBackdrop'
		spr = FlxBackdrop:new()
	else
		spr = FlxSprite:new()
	end
	new.sprite = spr
	spr.antialiasing = antialiasing
	spr.shader = game.createRuntimeShader('goodRgb')
	spr.loadGraphic(Paths.image(new.meta.image_path and ('mazes/' .. new.meta.image_path) or mazePath))
	new.sprGroup.add(spr)
	
	util.tableFallback(new.meta, 'ghost_house', {
		exit = {
			x = new.meta.width * .5;
			y = 14;
		}
	})
	util.tableFallback(new.meta, 'pacmen', {
		pacman = {
			x = new.meta.width * .5;
			y = 26;
		}
	})
	util.tableFallback(new.meta, 'maze_color', {r = {33; 33; 255}; b = {0; 0; 0}; dim = .5; a = 1})
	new.meta.maze_color.g = (new.meta.maze_color.g or util.tableCopy(new.meta.maze_color.b))
	util.shaderSet(spr.shader, new.meta.maze_color, true)
	
	new.spawns = {
		[tiles.pellet] = function(x, y)
			local p = pellet:new(x, y)
			new.pellets[maze.getTileKey(x, y)] = p
			return p
		end;
		[tiles.power] = function(x, y)
			local p = pellet:new(x, y, true)
			new.pellets[maze.getTileKey(x, y)] = p
			return p
		end;
	}
	
	return new
end

function maze:generate()
	self.genTime = 0
	self.genPellets = coroutine.create(function()
		local gen = 0
		local queue = {}
		for y, col in ipairs(self.tiles) do
			for x, row in ipairs(col) do
				local func = self.spawns[row]
				if func then table.insert(queue, func(x - 1, y - 1)) gen = gen + 1 end
				if func and os.clock() - self.genTime >= 1 / 30 then
					currentState.loader:setString('(playState) maze: ' .. gen .. ' pellets generated')
					coroutine.yield()
				end
			end
		end
		for i, pellet in ipairs(queue) do
			self.sprGroup.add(pellet.sprite)
			if os.clock() - self.genTime >= 1 / 30 then
				currentState.loader:setString('(playState) maze: ' .. i .. '/' .. gen .. ' pellets added')
				coroutine.yield()
			end
		end
		self:dispatchEvent('pelletsLoaded')
		self.genPellets = nil
	end)
end
function maze:update(dt)
	if not self.genPellets then return end
	self.genTime = os.clock()
	coroutine.resume(self.genPellets)
end

function maze:destroy()
	for _, pellet in pairs(self.pellets) do
		pellet:destroy()
	end
	self.sprite:destroy()
	self.sprGroup:destroy()
end

function maze.getTileKey(x, y) return (x .. 'x' .. y) end
function maze:getSpecial(x, y) return self.special[maze.getTileKey(x, y)] end
function maze:getPellet(x, y) return self.pellets[maze.getTileKey(x, y)] end
function maze:colliding(x, y) return (self:tileAt(x, y) == tiles.wall) end
function maze:tileAt(x, y)
	local cols = self.tiles
	if #cols == 0 then return tiles.air end
	local col = cols[math.max(math.min(y + 1, #cols), 1)]
	if #col == 0 then return tiles.air end
	return (col[math.max(math.min(x + 1, #col), 1)] or tiles.air)
end

return maze