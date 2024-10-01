if mazesState then return mazesState end
mazesState = {}
setmetatable(mazesState, {__index = state})
mazesState.setSelected = 1
mazesState.itemSelected = 1
mazesState.defaultSelections = {}
mazesState.mod = 'states.mazesState'

function mazesState:create()
	local new = state:create()
	setmetatable(new, {__index = mazesState})
	new.exitToState = menuState
	new.confirmed = false
	new.setScrollX = 0

	playState.set = ''
	playState.maze = ''

	game.camFollow.x = FlxG.width * .5
	game.camFollow.y = FlxG.height * .5
	game.isCameraOnForcedPos = true
	game.camGame.snapToTarget()
	game.cameraSpeed = 6

	new.bg = FlxSprite:new(0, 0, Paths.image('menuBGBlue'))
	new.bg.antialiasing = antialiasing
	new.bg.scrollFactor.x = 0
	new.bg.scale.y = 1.1
	new.bg.updateHitbox()
	new.bg.scale.x = 1.1
	game.add(new.bg)

	new.setList = {}
	new.mazeList = {}
	for _, set in ipairs(stringSplit(getTextFromFile('mazes/setList.txt'), '\n')) do
		local folder = set:gsub('\r', '')
		local content = getTextFromFile('mazes/' .. folder .. '/data.json')
		if not content then goto continue end
		local set = {}
		set.json = JSON.parse(content)._value
		set.name = set.json.set_name
		set.mazes = set.json.mazes
		set.folder = folder
		table.insert(new.setList, set)
		table.insert(mazesState.defaultSelections, 1)
		::continue::
	end
	new.items = {}
	new:regenItems(new.setList[mazesState.setSelected])

	-- note to self: maybe we can recycle thos alphabets
	new.setItems = {}
	local setItemSpacing = 720
	for i, set in ipairs(new.setList) do
		local ii = i - 1
		local item = Alphabet:new(ii * setItemSpacing, 30, set.name)
		table.insert(new.setItems, {name = set; sprite = item})
		item.camera = game.camHUD
		item.alpha = .6
		game.add(item)
	end

	new.mazeTween = nil
	new:updateSetlection(mazesState.setSelected)
	new:updateSelection(mazesState.itemSelected)
	return new
end

function mazesState:update(dt)
	if self.confirmed then return end
	local t = 1 - math.exp(-dt * 15)
	game.camHUD.scroll.x = FlxMath.lerp(game.camHUD.scroll.x, new.setScrollX, t) 
	if controls.BACK then
		switchState(self.exitToState)
		return
	end
	if controls.uiLEFT then
		self:updateSetlection(mazesState.setSelected - 1)
	end if controls.uiRIGHT then
		self:updateSetlection(mazesState.setSelected + 1)
	end
	if controls.uiUP then
		self:updateSelection(mazesState.itemSelected - 1)
	end if controls.uiDOWN then
		self:updateSelection(mazesState.itemSelected + 1)
	end
	if controls.special then
		self:previewMap()
	end
	if controls.ACCEPT then
		self:confirm()
	end
end
function mazesState:destroy()
	if self.mazePreview then self.mazePreview:destroy() end
	if self.mazeTween then self.mazeTween:cancel() end
	self.bg:destroy()
	game.camHUD.scroll.x = 0
	for _, item in ipairs(self.items) do
		item.sprite:destroy()
	end
	for _, item in ipairs(self.setItems) do
		item.sprite:destroy()
	end
end

function mazesState:previewMap() -- todo: make this readable you slut
	maze = loadMod 'backend.maze'
	local prevSet, prevMaze = playState.set, playState.maze
	local wipe = true
	playState.set = self.setList[mazesState.setSelected].folder
	playState.maze = self.items[mazesState.itemSelected].path
	if self.mazePreview then
		wipe = (playState.set == prevSet and playState.maze == prevMaze)
		if self.mazeTween then
			self.mazeTween:cancel()
			self.mazeTween = nil
		end
		local oldPrev = self.mazePreview
		local oldSpr = oldPrev.sprite
		tween.tween(oldSpr, {x = oldSpr.x + 50}, .15, {ease = 'quadOut'; onComplete = function()
			oldPrev:destroy()
		end}, function(prog)
			oldSpr.shader.setFloat('a', .3 - prog * .3)
			oldSpr.shader.setFloat('dim', .3 - prog * .3)
		end)
		self.mazePreview = nil
		if wipe then
			self.mazeTween = tween.tween(1, 0, .3, {ease = 'quartOut'}, function(prog)
				self.bg.setColorTransform(1, 1, 1, 1, -prog * 240, -prog * 250, -prog * 220)
			end)
			return
		end
	end
	self.mazePreview = maze:new(playState.set, playState.maze, true)
	local spr = self.mazePreview.sprite
	local ratio = math.min(screenHeight / spr.height, screenWidth / spr.width)
	spr.scale.y = ratio
	spr.scale.x = ratio
	spr.updateHitbox()
	spr.screenCenter(0x10)
	spr.scrollFactor.set()
	spr.x = screenWidth - spr.width
	game.insert(game.members.indexOf(self.bg) + 1, self.mazePreview.sprGroup)

	spr.alpha = 0
	spr.x = spr.x + 50
	spr.velocity.x = -40
	spr.velocity.y = 40
	if self.mazeTween then self.mazeTween:cancel() end
	self.mazeTween = tween.tween(spr, {x = spr.x - 50; alpha = 1}, .2, {ease = 'circOut'}, function(prog)
		spr.shader.setFloat('a', prog * .3)
		spr.shader.setFloat('dim', prog * .3)
		if wipe then
			self.bg.setColorTransform(1, 1, 1, 1, -prog * 240, -prog * 250, -prog * 220)
		end
	end)
end
function mazesState:confirm()
	playState.set = self.setList[mazesState.setSelected].folder
	playState.maze = self.items[mazesState.itemSelected].path

	self.confirmed = true
	FlxG.sound.play(Paths.sound('confirmMenu'))
	tween.tween(0, 0, 1.3, {onComplete = function()
		switchState(playState)
	end})
end
function mazesState:updateSelection(newSelection, force)
	if #self.items == 0 then return end
	newSelection = FlxMath.wrap(newSelection, 1, #self.items)

	local itemUnsel = self.items[mazesState.itemSelected]
	local itemSel = self.items[newSelection]
	if itemUnsel then itemUnsel.sprite.alpha = .6 end -- fuck this bum shit
	itemSel.sprite.alpha = 1
	game.camFollow.setPosition(
		itemSel.sprite.x + FlxG.width * .5 - 120,
		itemSel.sprite.y + itemSel.sprite.height * .5
	)
	
	if mazesState.itemSelected ~= newSelection or force then
		mazesState.itemSelected = newSelection
		FlxG.sound.play(Paths.sound('scrollMenu'))
		mazesState.defaultSelections[mazesState.setSelected] = newSelection
	end

	return newSelection
end
function mazesState:updateSetlection(newSelection)
	if #self.setItems == 0 then return end
	newSelection = FlxMath.wrap(newSelection, 1, #self.setItems)

	local itemUnsel = self.setItems[mazesState.setSelected]
	local itemSel = self.setItems[newSelection]
	itemUnsel.sprite.alpha = .6
	itemSel.sprite.alpha = 1
	new.setScrollX = itemSel.sprite.x - 30
	
	if mazesState.setSelected ~= newSelection then
		mazesState.setSelected = newSelection
		self:regenItems(self.setList[newSelection])
		mazesState.itemSelected = self:updateSelection(mazesState.defaultSelections[newSelection] or 1, true)
	end

	return newSelection
end
function mazesState:regenItems(set)
	local brandNew = (#self.items == 0)
	for _, item in ipairs(self.items) do item.sprite:destroy() end

	self.items = {}
	self.mazeList = {}
	for _, maze in ipairs(set.mazes) do
		table.insert(self.mazeList, {name = maze.name, path = maze.path})
	end

	local itemSpacing = 110
	for i, maze in ipairs(self.mazeList) do
		local ii = i - 1
		local item = Alphabet:new(ii * 9, ii * itemSpacing + FlxG.height * .5, maze.name)
		table.insert(self.items, {name = maze.name; path = maze.path; sprite = item})
		item.alpha = .6
		game.add(item)
	end

	--local scrollFY = (self.bg.height - FlxG.height) / (#self.items * itemSpacing)
	self.bg.scrollFactor.y = .02 --scrollFY
	--tween.tween(self.bg.scrollFactor, {y = scrollFY}, brandNew and 0 or .75, {ease = 'circOut'})
end

function mazesState:findSet(name)
	for i, set in ipairs(self.setList) do
		if set.folder == name then return set, i end
	end
	return nil, 0
end

return mazesState
--chloe was here ( kind of )