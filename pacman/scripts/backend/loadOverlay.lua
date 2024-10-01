if loadOverlay then return loadOverlay end
loadOverlay = {}
loadOverlay.__index = loadOverlay

function loadOverlay:new()
	local new = {}
	setmetatable(new, loadOverlay)

	local spr = FlxSprite:new()
	new.bg = spr
	spr.antialiasing = antialiasing
	spr.loadGraphic(Paths.image('loader'))
	spr.setGraphicSize(screenWidth)
	spr.camera = game.camOther
	spr.updateHitbox()
	spr.screenCenter()
	game.insert(0, spr)

	local text = FlxText:new()
	new.text = text

	text.size = 18
	text.alignment = 'center'
	text.y = screenHeight - 60
	text.camera = game.camOther
	text.fieldWidth = screenWidth
	text.antialiasing = antialiasing

	setTextBorder(text._tag, 1.3, '000000')

	game.add(text)
	new:setString()

	return new
end

function loadOverlay:setString(str, header)
	header = (header == nil and true or header)
	self.text.text = header and (str and 'LOADING\n' .. tostring(str) or 'LOADING') or tostring(str)
	self.text.y = screenHeight - self.text.height - 10
end
function loadOverlay:destroy()
	self.text:destroy()
	self.bg:destroy()
	self = nil
end

return loadOverlay