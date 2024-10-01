if menuState then return menuState end
menuState = {}
setmetatable(menuState, {__index = state})
menuState.optionSelected = 1 -- its kinda like using static variables
menuState.test = 456
--menuState.mod = 'states.menuState'

function menuState:create()
	local new = state:create()
	setmetatable(new, {__index = menuState})
	new.confirmed = false

	import 'flixel.effects.FlxFlicker'
	game.camFollow.x = FlxG.width * .5
	game.camFollow.y = FlxG.height * .5
	game.isCameraOnForcedPos = true
	game.camGame.snapToTarget()
	game.cameraSpeed = 3

	new.flickerBg = FlxSprite:new(0, 0, Paths.image('menuBGMagenta'))
	new.flickerBg.antialiasing = antialiasing
	new.flickerBg.scrollFactor.set(0, .1)
	new.flickerBg.scale.set(1.1, 1.1)
	game.add(new.flickerBg)
	
	new.bg = FlxSprite:new(0, 0, Paths.image('menuBG'))
	new.bg.antialiasing = antialiasing
	new.bg.scrollFactor.set(0, .1)
	new.bg.scale.set(1.1, 1.1)
	game.add(new.bg)

	new.options = {}
	local ops = {{'story_mode'; 'story_mode'}; {'mazes'; 'mazes'}; {'options'; 'options-alt'}; {'credits'; 'credits-alt'}}
	for i, op in ipairs(ops) do
		local opname, opframe = op[1], op[2]
		local option = FlxSprite:new()
		option.antialiasing = antialiasing
		option.frames = Paths.getSparrowAtlas('mainmenu/menu_' .. opframe)
		option.animation.addByPrefix('unselected', opname .. ' idle', 24, true)
		option.animation.addByPrefix('unselected', opname .. ' basic', 24, true)
		option.animation.addByPrefix('unselected', opname .. ' unselected', 24, true)
		option.animation.addByPrefix('selected', opname .. ' selected', 24, true)
		option.animation.addByPrefix('selected', opname .. ' white', 24, true)
		option.animation.play('unselected')
		option.updateHitbox()
		table.insert(new.options, {
			option = opname;
			sprite = option;
		})
		option.x = FlxG.width * .5
		option.y = FlxG.height * .5 + (i - #ops * .5 - .5) * 140
		option.offset.set(option.width * .5, option.height * .5)
		game.add(option)
	end

	new:updateSelection(menuState.optionSelected)
	return new
end

function menuState:update(dt)
	if self.confirmed then
		return
	end
	if controls.uiUP then
		menuState.optionSelected = self:updateSelection(menuState.optionSelected - 1)
	end if controls.uiDOWN then
		menuState.optionSelected = self:updateSelection(menuState.optionSelected + 1)
	end
	if controls.ACCEPT then
		self.confirmed = true
		self:confirm()
	end
end
function menuState:destroy()
	self.bg:destroy()
	self.flickerBg:destroy()
	for _, op in ipairs(self.options) do
		op.sprite:destroy()
	end
end

function menuState:confirm()
	local selectedOp = self.options[menuState.optionSelected]
	local cases = {
		['story_mode'] = function() end;
		['mazes'] = function()
			switchState(mazesState)
		end;
		['options'] = function() end;
		['credits'] = function()
			switchState(creditsState)
		end;
	}
	local case = cases[selectedOp.option]
	case = case or function() end
	FlxG.sound.play(Paths.sound('confirmMenu'))
	FlxFlicker.flicker(self.bg, 1.1, 0.15, false)
	FlxFlicker.flicker(selectedOp.sprite, 1, 0.06, false, false)
	tween.tween(0, 0, 1, {onComplete = function()
		self.confirmed = false
		FlxFlicker.stopFlickering(self.bg)
		FlxFlicker.stopFlickering(selectedOp.sprite)
		selectedOp.sprite.visible = true
		self.bg.visible = true
		case()
	end})
end
function menuState:updateSelection(newSelection)
	newSelection = FlxMath.wrap(newSelection, 1, #self.options)
	local optionUnsel = self.options[menuState.optionSelected].sprite
	local optionSel = self.options[newSelection].sprite

	optionUnsel.animation.play('unselected')
	optionUnsel.updateHitbox()
	optionUnsel.offset.set(optionUnsel.width * .5, optionUnsel.height * .5)

	optionSel.animation.play('selected')
	optionSel.updateHitbox()
	optionSel.offset.set(optionSel.width * .5, optionSel.height * .5)

	game.camFollow.y = math.lerp(optionSel.y, FlxG.height * .5, .75)

	if menuState.optionSelected ~= newSelection then
		FlxG.sound.play(Paths.sound('scrollMenu'))
	end
	
	return newSelection
end

return menuState