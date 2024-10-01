if creditsState then return creditsState end
creditsState = {}
setmetatable(creditsState, {__index = state})
creditsState.itemSelected = 1

function creditsState:create()
	local new = state:create()
	setmetatable(new, {__index = creditsState})

	game.cameraSpeed = 3

	new.bg = FlxSprite:new(0, 0, Paths.image('menuBGMagenta'))
	new.bg.scale.set(1.1, 1.1)
	new.bg.scrollFactor.set()
	game.add(new.bg)

	local txt = FlxText:new()
	txt.antialiasing = true
	txt.fieldWidth = screenWidth
	txt.scrollFactor.set()
	txt.alignment = 'center'
	txt.text = 'abcd'
	txt.size = 24
	txt.y = screenHeight - txt.height - 20
	setTextBorder(txt._tag, 1.3, '000000')
	game.add(txt)

	new.creditText = txt

	new.creditsData = {}
	local creditsContent = getTextFromFile('data/credits.txt')
	creditsContent = stringSplit(creditsContent:gsub('\r', ''), '\n')
	for _, line in ipairs(creditsContent) do
		table.insert(new.creditsData, stringSplit(line, '::'))
	end
	new.creditsItems = {}

	import 'objects.HealthIcon'
	local yy = 0
	for i, insightfulInformation in ipairs(new.creditsData) do
		local item = {}
		item.data = insightfulInformation

		item.sprite = Alphabet:new(0, yy, item.data[1])
		if item.data[2] then
			yy = yy + 90
			item.sprite.x = 150
			item.icon = FlxSprite:new(0, 0, Paths.image('credits/' .. item.data[2]))
			item.icon.setPosition(0, item.sprite.y + (item.sprite.height - item.icon.height) * .5)
			item.icon.antialiasing = antialiasing
			game.add(item.icon)
			local nextItem = new.creditsData[i + 1]
			if nextItem and not nextItem[2] then yy = yy + 80 end

			item.sprite.alpha = .6
			item.icon.alpha = .6
		else
			yy = yy + 100
		end

		game.add(item.sprite)

		table.insert(new.creditsItems, item)
	end

	new:updateSelection(creditsState.itemSelected)
	game.camGame.snapToTarget()
	return new
end

function creditsState:updateSelection(newSelection)
	newSelection = FlxMath.wrap(newSelection, 1, #self.creditsItems)
	local diff = newSelection - creditsState.itemSelected
	local itemUnsel = self.creditsItems[creditsState.itemSelected]
	local itemSel = self.creditsItems[newSelection]
	if itemUnsel.icon then
		itemUnsel.sprite.alpha = .6
		itemUnsel.icon.alpha = .6
	end
	if itemSel.icon then
		itemSel.sprite.alpha = 1
		itemSel.icon.alpha = 1
	end

	if not itemSel.icon then
		if newSelection == #self.creditsItems then return end
		if diff == 0 then diff = 1 end
		creditsState.itemSelected = newSelection
		self:updateSelection(newSelection + diff)
		return creditsState.itemSelected
	end

	game.camFollow.setPosition(itemSel.sprite.x + FlxG.width * .5 - 200, itemSel.sprite.y)

	if creditsState.itemSelected ~= newSelection then
		FlxG.sound.play(Paths.sound('scrollMenu'))
		creditsState.itemSelected = newSelection
		self.creditText.text = itemSel.data[3] or '---'
	end

	return newSelection
end

function creditsState:update()
	if controls.uiUP then
		self:updateSelection(creditsState.itemSelected - 1)
	end if controls.uiDOWN then
		self:updateSelection(creditsState.itemSelected + 1)
	end
	if controls.BACK then
		switchState(menuState)
	end
end

function creditsState:destroy()
	self.bg:destroy()
	self.creditText:destroy()
	for _, item in ipairs(self.creditsItems) do
		if item.icon then item.icon:destroy() end
		item.sprite:destroy()
	end
end

return creditsState