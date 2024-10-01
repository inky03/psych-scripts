--[[
TODO
put EVERYTHING on ITS OWN MODULE (high priority)
]]

local aiBug = true
local refreshRate = 60.606061 * playbackRate
local delta = 0
local mazedata
local mazemeta = {
	width = 0;
	height = 0;
	pellets = 0;
}
local meta = {}
local session = {
	set = 'mspacman';
	maze = 'mspacman_a';
	pellets = 0;
	level = 1;
	
	leveldata = nil;
	modeswitch = nil;
	switchTime = 0;
	curSwitch = 1;
	elroy = 0;
	
	motion = false;
	pause = 0;
	frightCount = 0;
	eyesCount = 0;
	ghostCombo = 0;
}
local energizers = {}
local pacmen = {}
local ghosts = {}
local bonus = {}
local pointer
local pointerCoord = {x = 0; y = 0}

local maxLives = 4
local lives = maxLives - 1
local extraLife = false

local maze
local mazeGroup
local timeBonus
local nextBonus
local fullBar
local frightSound
local eyesSound
local mazeText
local version = '0.1.4'

local camPos = {x = 0; y = 0}
local prevBeat

local function percentPX(percent) return percent * 1.25 end
local function levelData(bonus, pacSpeed, ghostSpeed, ghostTunnelSpeed, elroy1, elroy1Speed, elroy2, elroy2Speed, frightPacSpeed, frightGhostSpeed, frightTime)
	return {
		bonus = bonus;
		pacSpeed = percentPX(pacSpeed);
		ghostSpeed = percentPX(ghostSpeed);
		ghostTunnelSpeed = percentPX(ghostTunnelSpeed);
		elroy1 = elroy1;
		elroy1Speed = percentPX(elroy1Speed);
		elroy2 = elroy2;
		elroy2Speed = percentPX(elroy2Speed);
		frightPacSpeed = percentPX(frightPacSpeed or 1);
		frightGhostSpeed = percentPX(frightGhostSpeed or .6);
		frightTime = frightTime or 0;
	}
end
local bonuses = {
	cherry = {score = 100};
	strawberry = {score = 300};
	orange = {score = 500};
	apple = {score = 700};
	melon = {score = 1000};
	galaxian = {score = 2000};
	bell = {score = 3000};
	key = {score = 5000};
}
local leveldata = {
	[1] = levelData('cherry',		.8, .75, .4, 20, .8, 10, .85, .9, .5, 6);
	[2] = levelData('strawberry',	.9, .85, .45, 30, .9, 15, .95, .95, .55, 5);
	[3] = levelData('orange',		.9, .85, .45, 40, .9, 20, .95, .95, .55, 4);
	[4] = levelData('orange',		.9, .85, .45, 40, .9, 20, .95, .95, .55, 3);
	[5] = levelData('apple',		1, .95, .5, 40, 1, 20, 1.05, 1, .6, 2);
	[6] = levelData('apple',		1, .95, .5, 50, 1, 25, 1.05, 1, .6, 5);
	[7] = levelData('melon',		1, .95, .5, 50, 1, 25, 1.05, 1, .6, 2);
	[9] = levelData('galaxian',		1, .95, .5, 60, 1, 30, 1.05, 1, .6, 1);
	[10] = levelData('galaxian',	1, .95, .5, 60, 1, 30, 1.05, 1, .6, 5);
	[11] = levelData('bell',		1, .95, .5, 60, 1, 30, 1.05, 1, .6, 2);
	[12] = levelData('bell',		1, .95, .5, 80, 1, 40, 1.05, 1, .6, 1);
	[13] = levelData('key',			1, .95, .5, 80, 1, 40, 1.05, 1, .6, 1);
	[14] = levelData('key',			1, .95, .5, 80, 1, 40, 1.05, 1, .6, 3);
	[15] = levelData('key',			1, .95, .5, 100, 1, 50, 1.05, 1, .6, 1);
	[17] = levelData('key',			1, .95, .5, 100, 1, 50, 1.05);
	[18] = levelData('key',			1, .95, .5, 100, 1, 50, 1.05, 1, .6, 1);
	[19] = levelData('key',			1, .95, .5, 120, 1, 60, 1.05);
	[21] = levelData('key',			.9, .95, .5, 120, 1, 60, 1.05);
}
local modeswitch = {
	[1] = {7 * 60; 20 * 60; 7 * 60; 20 * 60; 5 * 60; 20 * 60; 5 * 60};
	[2] = {7 * 60; 20 * 60; 7 * 60; 20 * 60; 5 * 60; (13 * 60 + 17) * 60; 1};
	[5] = {5 * 60; 20 * 60; 5 * 60; 20 * 60; 5 * 60; (13 * 60 + 17) * 60; 1};
}

function onCreate()
	luaDebugMode = true
	reference = loadMod('backend/Reference')
	
	if not reference then
		debugPrint('ERROR: we cant load the freaking game', 'ff0000')
	end

	--addHaxeLibrary('NoteSplash', 'objects')
	reference.preset()
	File = reference 'sys.io.File'
	JSON = reference 'tjson.TJSON'
	NoteSplash = reference 'objects.NoteSplash'
	game = reference '' -- passing no arguments will just make a reference to the playstate instance!
	
	local bpm = 60 / .46
	PlayState.SONG.bpm = bpm
	game.initLuaShader('goodRgb')
end
function gotoLevel(level)
	session.level = level
	session.leveldata = mapGetMin(level)
	session.modeswitch = mapGetMin(level, modeswitch)
	session.switchTime = session.modeswitch[1]
	for _, ghost in pairs(ghosts) do
		ghost.speedMult = session.leveldata.ghostSpeed
	end
	for _, pac in pairs(pacmen) do
		pac.speedMult = session.leveldata.pacSpeed
	end
	local elroy1Percent = session.leveldata.elroy1 / mazemeta.pellets
	local elroy2Percent = session.leveldata.elroy2 / mazemeta.pellets
	local elroy1Bar = reference.createInstance('elroy1Bar', 'flixel.FlxSprite')
	elroy1Bar.makeGraphic(game.timeBar.barWidth * elroy1Percent, game.timeBar.barHeight, -1)
	elroy1Bar.color = 0xffa0a0
	elroy1Bar.x = game.timeBar.barWidth - elroy1Bar.width + game.timeBar.barOffset.x
	elroy1Bar.y = game.timeBar.barOffset.y
	elroy1Bar.scale.y = game.timeBar.scale.y
	setBlendMode('elroy1Bar', 'multiply')
	game.timeBar.insert(game.timeBar.members.indexOf(game.timeBar.bg), elroy1Bar)
	local elroy2Bar = reference.createInstance('elroy2Bar', 'flixel.FlxSprite')
	elroy2Bar.makeGraphic(game.timeBar.barWidth * elroy2Percent, game.timeBar.barHeight, -1)
	elroy2Bar.color = 0xff6060
	elroy2Bar.x = game.timeBar.barWidth - elroy2Bar.width + game.timeBar.barOffset.x
	elroy2Bar.y = game.timeBar.barOffset.y
	elroy2Bar.scale.y = game.timeBar.scale.y
	setBlendMode('elroy2Bar', 'multiply')
	game.timeBar.insert(game.timeBar.members.indexOf(elroy1Bar) + 1, elroy2Bar)
	
	timeBonus.loadGraphic(Paths.image('bonuses/' .. session.leveldata.bonus))
	nextBonus.loadGraphic(Paths.image('bonuses/' .. mapGetMin(session.level + 1).bonus))
	
	for _, bon in ipairs({timeBonus, nextBonus}) do
		bon.scale.set(.5, .5)
		bon.updateHitbox()
		bon.y = game.timeBar.y - 3
	end
	
	timeBonus.x = game.timeBar.x - timeBonus.width - 10
	nextBonus.x = game.timeBar.x + game.timeBar.bg.width + 10
end
function onCreatePost()
	if not reference then return end
	
	Paths.music('toyboxIntro')
	Paths.getSparrowAtlas('blast')
	for _, snd in ipairs({'eat_1', 'eat_2', 'eat_big'}) do Paths.sound(snd) end
	frightSound = reference.createInstance('frightSound', 'flixel.sound.FlxSound')
	frightSound.loadEmbedded(Paths.sound('sirenFright'))
	frightSound.looped = true
	eyesSound = reference.createInstance('eyesSound', 'flixel.sound.FlxSound')
	eyesSound.loadEmbedded(Paths.sound('sirenEyes'))
	eyesSound.looped = true
	FlxG.sound.list.add(frightSound)
	FlxG.sound.list.add(eyesSound)
	
	game.cameraSpeed = 0;
	
	game.iconP1.loadGraphic(Paths.image('icons/pacman'), true, 150, 150)
	game.iconP1.animation.add('icon', {0; 1}, 0, false, true)
	game.iconP1.animation.play('icon')
	game.iconP1.antialiasing = ClientPrefs.data.antialiasing
	game.iconP1.iconOffsets[2] = -15 -- why is it offcenter
	game.healthBar.rightBar.color = 0x66ff33
	game.healthBar.leftBar.color = 0xff0000
	--game.healthBar.scale.y = 2.2
	game.timeBar.rightBar.color = 0x404040
	--game.timeBar.scale.y = 2.2
	game.timeTxt.size = game.scoreTxt.size
	game.timeTxt.borderSize = game.scoreTxt.borderSize
	game.timeTxt.y = game.timeBar.y + (game.timeBar.height - game.timeTxt.height) * .5
	game.timeTxt.screenCenter(0x01)
	game.showRating = false
	game.comboGroup.camera = game.camGame;
	for _, tag in ipairs({'timeBonus', 'nextBonus'}) do
		local bon = reference.createInstance(tag, 'flixel.FlxSprite')
		bon.antialiasing = ClientPrefs.data.antialiasing
		game.timeBar.add(bon)
	end
	
	-- custom ui
	local white = 212
	for i = maxLives, 1, -1 do
		game.health = math.max(i / maxLives * 2, .001)
		local life = reference.createInstance('life' .. i, 'flixel.FlxSprite')
		life.loadGraphic(Paths.image('icons/pacman-empty'))
		life.scale.set(.5, .5)
		life.x = game.healthBar.barCenter - life.width * .5
		life.y = game.healthBar.y + game.healthBar.height * .5 - life.height * .5
		life.flipX = true
		life.active = false
		life.antialiasing = ClientPrefs.data.antialiasing
		--life.setColorTransform(0, 0, 0, 1, white, white, white) -- im sorry for being white....
		game.uiGroup.insert(game.uiGroup.members.indexOf(game.iconP1), life)
	end
	timeBonus = reference.ref('timeBonus')
	nextBonus = reference.ref('nextBonus')
	fullBar = reference.createInstance('fullBar', 'flixel.FlxSprite')
	fullBar.makeGraphic(game.healthBar.leftBar.frameWidth, game.healthBar.leftBar.clipRect.height, -1)
	fullBar.y = fullBar.y + game.healthBar.barOffset.y
	--fullBar.setPosition(game.healthBar.barOffset.x, game.healthBar.barOffset.y)
	fullBar.color = 0xffa300
	fullBar.updateHitbox()
	fullBar.active = false
	fullBar.scale.set(game.healthBar.scale.x, game.healthBar.scale.y)
	hscript([[
		import flixel.math.FlxRect;
		var bar = game.getLuaObject('fullBar');
		bar.clipRect = new FlxRect(0, 0, bar.width, bar.height);
	]])
	--fullBar.clipRect = reference.createInstance('barClip', 'flixel.math.FlxRect', {0, 0, fullBar.width, fullBar.height})
	game.healthBar.insert(game.healthBar.members.indexOf(game.healthBar.rightBar) + 1, fullBar)
	
	watermark = reference.createInstance('watermark', 'flixel.text.FlxText', {10, 0, 0, 'pacman ' .. version, 14})
	setTextFont('watermark', 'vcr.ttf')
	setTextBorder('watermark', 1, '000000')
	watermark.alpha = .5
	watermark.antialiasing = ClientPrefs.data.antialiasing
	watermark.y = FlxG.height - 6 - watermark.height
	watermark.camera = game.camHUD
	game.add(watermark)
	
	mazeTitle = reference.createInstance('mazeTitle', 'flixel.text.FlxText', {10, 0, 0, '', 24})
	--setTextFont('mazeTitle', 'vcr.ttf')
	setTextColor('mazeTitle', 'ff0000')
	setTextBorder('mazeTitle', 2, '0000ff')
	mazeTitle.shader = game.createRuntimeShader('goodRgb')
	mazeTitle.antialiasing = ClientPrefs.data.antialiasing
	mazeTitle.y = watermark.y - watermark.height - 12
	mazeTitle.camera = game.camHUD
	game.add(mazeTitle)
	
	mazeText = reference.createInstance('mazeText', 'flixel.text.FlxText', {0, 0, 0, 'unknown', 16})
	--setTextFont('mazeText', 'vcr.ttf')
	setTextColor('mazeText', 'ff0000')
	setTextBorder('mazeText', 2, '0000ff')
	mazeText.shader = game.createRuntimeShader('goodRgb')
	mazeText.antialiasing = ClientPrefs.data.antialiasing
	mazeText.y = mazeTitle.y + 8
	mazeText.camera = game.camHUD
	game.add(mazeText)
	
	game.iconP2.visible = false
	game.camGame.scroll.x = 0
	game.camGame.scroll.y = 0
	game.camZoomingMult = 0
	game.camZooming = true
	game.inst.loadEmbedded(Paths.music('toyboxLoop'))
	
	for _, v in ipairs({'boyfriend', 'dad', 'gf'}) do game[v].visible = false end
	
	hscript([[
		var rightCam = new FlxCamera(0, 0, FlxG.width, FlxG.height, 1);
		rightCam.bgColor = 0;
		FlxG.game.addChildAt(rightCam.flashSprite, FlxG.game.getChildIndex(game.camHUD.flashSprite));
		FlxG.cameras.list.insert(FlxG.cameras.list.indexOf(game.camHUD) - 1, rightCam);
		game.variables.set('rightCam', rightCam);
		
		var leftCam = new FlxCamera(0, 0, FlxG.width, FlxG.height, 1);
		leftCam.bgColor = 0;
		FlxG.game.addChildAt(leftCam.flashSprite, FlxG.game.getChildIndex(game.camHUD.flashSprite));
		FlxG.cameras.list.insert(FlxG.cameras.list.indexOf(game.camHUD) - 1, leftCam);
		game.variables.set('leftCam', leftCam);
	]])
	leftCam = reference.ref('leftCam')
	rightCam = reference.ref('rightCam')
	
	mazeGroup = reference.createInstance('mazeGroup', 'flixel.group.FlxTypedSpriteGroup')
	game.add(mazeGroup)
	maze = reference.createInstance('maze', 'flixel.FlxSprite')
	maze.antialiasing = ClientPrefs.data.antialiasing
	maze.shader = game.createRuntimeShader('goodRgb')
	maze.active = false
	mazeGroup.add(maze)
	loadMeta()
	loadMaze(session.maze)
	
	game.noteGroup.remove(game.grpNoteSplashes)
	game.add(game.grpNoteSplashes)
	game.grpNoteSplashes.cameras = camList
	mazeGroup.cameras = camList
	
	pointer = reference.createInstance('pointer', 'flixel.FlxSprite')
	pointer.makeGraphic(1, 1, -1)
	pointer.scale.set(32, 32)
	pointer.updateHitbox()
	
	local center = mazemeta.width * .5
	if mazemeta.ghost_house ~= nil then
		center = mazemeta.ghost_house.x or center
	end
	pacmen.pacman = makePacman('pacman', {1; 1; 0}, {x = center, y = 26})
	ghosts.blinky = makeGhost('blinky', {1; 0; 0}, {x = center; y = 14}, function(self, tile) -- this function determines where the ghost will be targetting!
		local pac = closePacman(tile)
		if self.fright > 0 then return nil end
		if self.scatter and session.elroy == 0 then
			return {x = mazemeta.width - 2; y = -1}
		end
		return {x = pac.tilePos.x; y = pac.tilePos.y}
	end)
	ghosts.pinky = makeGhost('pinky', {1; 184 / 255; 1}, {x = center; y = 17}, function(self, tile)
		local pac = closePacman(tile)
		if self.fright > 0 then return nil end
		if self.scatter then
			return {x = 2; y = -1}
		end
		local offset = (pac.finalDir.y == -1 and aiBug and -4 or 0)
		return {
			x = pac.tilePos.x + pac.finalDir.x * 4 + offset;
			y = pac.tilePos.y + pac.finalDir.y * 4
		}
	end)
	ghosts.inky = makeGhost('inky', {0; 1; 1}, {x = center - 2; y = 17}, function(self, tile)
		local pac = closePacman(tile)
		if self.fright > 0 then return nil end
		if self.scatter then
			return {x = mazemeta.width; y = 34}
		end
		local blinky = ghosts.blinky
		local offset = (pac.finalDir.y == -1 and aiBug and -2 or 0)
		local vec = {
			x = pac.tilePos.x + pac.finalDir.x * 2 + offset - blinky.tilePos.x;
			y = pac.tilePos.y + pac.finalDir.y * 2 - blinky.tilePos.y
		}
		return {
			x = blinky.tilePos.x + vec.x * 2;
			y = blinky.tilePos.y + vec.y * 2
		}
	end)
	ghosts.clyde = makeGhost('clyde', {1; 184 / 255; 81 / 255}, {x = center + 2; y = 17}, function(self, tile)
		local pac = closePacman(tile)
		if self.fright > 0 then return nil end
		if self.scatter then
			return {x = 0; y = 34}
		end
		local dist = euclideanDist(tile, pac.tilePos)
		return (
			dist >= 64 and {x = pac.tilePos.x; y = pac.tilePos.y} or {x = 0; y = 34}
		) -- 8 ^ 2
	end)
	for i, ghost in ipairs({ghosts.inky, ghosts.pinky, ghosts.clyde}) do
		ghost.tilePos.y = mazemeta.ghost_house.inside.y
		ghost.dir = {x = 0, y = (i == 2 and 1 or -1)}
		ghost.house = true
	end
	
	strumPlayAnim(pacmen.pacman.curKey, 'confirm')
	
	--FlxG.mouse.visible = true
	--game.add(pointer)
	pointer.blend = 0
	pointer.alpha = .5
	
	local strumDir = {{-1; 0}; {0; 1}; {0; -1}; {1; 0}}
	for i = 0, 3 do
		local strum = reference.ref('playerStrums.members.' .. i)
		local sDir = strumDir[i + 1]
		strum.scale.set(.5, .5)
		strum.x = sDir[1] * 50 + FlxG.width - 170
		strum.y = sDir[2] * 50 + (downScroll and (FlxG.height - 170) or (170 - strum.height))
		
		strum = reference.ref('opponentStrums.members.' .. i)
		strum.visible = false
	end
	
	gotoLevel(session.level)
	updateHealth()
	--spawnBonus()
	--bonus.bonus = makeBonus('bonus', session.leveldata.bonus)
end
function mapGetMin(num, map)
	map = map or leveldata
	local min = {n = math.huge, dat = nil}
	local max = {n = 0, dat = nil}
	for k, data in pairs(map) do
		if k < min.n then
			min.n = k
			min.dat = data
		end
		if k > max.n and num >= k then
			max.n = k
			max.dat = data
		end
	end
	return max.dat or min.dat
end
function tileKey(row, col)
	return 'tile' .. row .. 'x' .. col
end
function closePacman(tile)
	local pac = pacmen.pacman
	return pac
end
function onCountdownTick(t)
	if not reference then return end
	
	local countdownAssets = {'countdownReady'; 'countdownSet'; 'countdownGo'}
	if t == 0 then
		introSound = reference.createInstance('introSound', 'flixel.sound.FlxSound')
		introSound.loadEmbedded(Paths.music('toyboxIntro'))
		FlxG.sound.list.add(introSound)
		introSound.pitch = playbackRate
		introSound.volume = .5
		introSound.play()
	elseif t <= #countdownAssets then
		local spr = reference.ref(countdownAssets[t])
		spr.camera = game.camGame
		spr.scrollFactor.set(1, 1)
		spr.scale.set(.25, .25)
		spr.updateHitbox()
		
		local coord = getMazeCoord(mazemeta.pacmen.pacman.x, mazemeta.bonus.y)
		spr.x = coord.x - spr.width * .5 + 24
		spr.y = coord.y - spr.height * .5 + 24 - t * 5
	end
end
function onPause()
	if introSound then introSound.pause() end
	frightSound.pause()
	eyesSound.pause()
end
function onResume()
	if introSound then introSound.resume() end
	frightSound.resume()
	eyesSound.resume()
end
function onSongStart()
	if not reference then return end
	FlxG.sound.music.volume = .5
	FlxG.sound.music.looped = true
	hscript('FlxG.sound.music.onComplete = () -> Conductor.songPosition = 0;')
	session.motion = true
end

function shaderSet(ref, uniforms)
	local shd = ref
	for uniform, val in pairs(uniforms) do
		if type(val) == 'number' then shd.setFloat(uniform, val)
		elseif type(val) == 'table' then shd.setFloatArray(uniform, val) --whatever nobody uses bool array
		elseif type(val) == 'boolean' then shd.setBool(uniform, val)
		elseif val == 'true' or val == 'false' then shd.setBool(uniform, val == 'true')
		else --[[ nothing ]] end
	end
end

function makePacman(tag, color, startTile)
	local pac = reference.createInstance(tag, 'psychlua.ModchartSprite')
	pac.frames = Paths.getSparrowAtlas('pacman')
	pac.animation.addByPrefix('munch', 'pacman munch', 30, true)
	pac.animation.addByPrefix('aggro', 'pacman sharp', 30, true)
	pac.animation.addByPrefix('bite', 'pacman whack', 24, false)
	pac.animation.addByPrefix('death', 'pacman die', 30, true)
	pac.playAnim('munch')
	pac.antialiasing = ClientPrefs.data.antialiasing
	pac.offset.set(15, 15)
	pac.origin.set(pac.width * .5, pac.height * .5)
	pac.shader = game.createRuntimeShader('goodRgb') 
	pac.animation.timeScale = 0
	pac.cameras = camList
	shaderSet(pac.shader, {r = color or {1; 1; 1}; g = {1; 1; 1;}; b = {0; 0; 0}; dim = 1; a = 1})
	
	game.add(pac)
	
	local data = {
		tag = tag;
		obj = pac;
		roundTile = {x = 0; y = 0};
		tilePos = {x = startTile.x; y = startTile.y};
		finalDir = {x = -1; y = 0};
		nextDir = {x = -1; y = 0};
		dir = {x = -1; y = 0};
		nextKey = 0;
		curKey = 0;
		wa = true;
		pelletFreeze = 0;
		
		delta = 0;
		speedMult = mapGetMin(session.level).pacSpeed;
	}
	data.roundTile.x = math.round(data.tilePos.x)
	data.roundTile.y = math.round(data.tilePos.y)
	if mazemeta.pacmen ~= nil then
		pacMeta = mazemeta.pacmen[tag]
		if pacMeta ~= nil then
			local pos = fixPos(pacMeta)
			data.tilePos.x = pos.x or data.tilePos.x
			data.tilePos.y = pos.y or data.tilePos.y
		end
	end
	return data
end
local pathDirs = {
	['<'] = {x = -1; y = 0};
	['v'] = {x = 0; y = 1};
	['>'] = {x = 1; y = 0};
	['^'] = {x = 0; y = -1};
}
function makeBonus(tag, name)
	local bonGroup = reference.createInstance(tag .. 'Group', 'flixel.group.FlxTypedSpriteGroup')
	bonGroup.cameras = camList
	game.insert(game.members.indexOf(mazeGroup) + 1, bonGroup)
	
	local bon = reference.createInstance(tag, 'flixel.FlxSprite')
	bon.loadGraphic(Paths.image('bonuses/' .. name))
	bon.antialiasing = ClientPrefs.data.antialiasing
	bon.scale.set(.72, .72)
	bon.updateHitbox()
	bon.offset.set(bon.width * .75 - 20, bon.height * .75 - 20)
	bonGroup.add(bon)
	
	local data = {
		tag = tag;
		obj = bonGroup;
		name = name;
		tilePos = {x = mazemeta.bonus.x; y = mazemeta.bonus.y};
		dir = {x = 0; y = 0};
		behavior = 'classic';
		target = {x = mazemeta.ghost_house.inside.x; y = mazemeta.ghost_house.inside.y};
		bounce = 0;
		cycling = false;
		exiting = false;
		followsPath = false;
		entrancePath = '';
		exitPath = '';
		pathP = 0;
		
		alive = 0;
		delta = 0;
		speedMult = .5;
	}
	local paths = mazemeta.fruit_paths
	if paths then
		data.followsPath = true
		local entrances = paths.entrances
		local entrance = entrances[getRandomInt(1, #entrances)] or {path = ''}
		data.entrancePath = entrance.path
		if entrance.start then
			data.tilePos = fixPos({x = entrance.start.x; y = entrance.start.y})
		end
		
		local exits = paths.exits
		local freeExits = {}
		local enDir = pathDirs[data.entrancePath:sub(-1, -1)]
		for _, exitPath in pairs(exits) do
			local exDir = pathDirs[exitPath.path:sub(1, 1)]
			if (enDir.x == 0 or enDir.x ~= -exDir.x) and (enDir.y == 0 or enDir.y ~= -exDir.y) then
				table.insert(freeExits, exitPath)
			end
		end
		local exitt = freeExits[getRandomInt(1, #freeExits)] or {path = ''}
		data.exitPath = exitt.path
	else
		if mazemeta.fruit_behavior == 'jr' then
			data.target = nil
			data.alive = 60 * 10
			data.behavior = 'jr'
			findFreeDirection(data.dir, {x = math.round(data.tilePos.x); y = math.round(data.tilePos.y)}, nil)
		else
			data.alive = 60 * 10
			data.speedMult = 0
		end
	end
	return data
end
function makeGhost(tag, color, startTile, chase)
	local grp = reference.createInstance(tag .. 'Group', 'flixel.group.FlxTypedSpriteGroup')
	grp.cameras = camList
	game.add(grp)
	
	local ghost = reference.createInstance(tag, 'psychlua.ModchartSprite')
	grp.add(ghost)
	ghost.antialiasing = ClientPrefs.data.antialiasing
	ghost.frames = Paths.getSparrowAtlas('ghost-body')
	ghost.animation.addByPrefix('main', 'ghost body', 30, true)
	ghost.animation.addByPrefix('regenerate', 'body regeneration', 30, false)
	ghost.addOffset('regenerate', 2, 0)
	ghost.addOffset('main', 0, 0)
	ghost.playAnim('main')
	ghost.setPosition(-ghost.width * .25 + 2, -ghost.height * .25)
	ghost.shader = game.createRuntimeShader('goodRgb')
	-- dont reference the createRuntimeShader function! we're referencing ghost.shader instead
	-- whenever it tries to access it the method is called again, so diff runtime shader would be created for each access attempt (and it wouldnt work)
	shaderSet(ghost.shader, {r = color or {1; 1; 1}; g = {1; 1.2; 1.25}; b = {0; 0; 0}; dim = .3; a = 1})
	
	local eyes = reference.createInstance(tag .. 'Eyes', 'psychlua.ModchartSprite')
	grp.add(eyes)
	eyes.antialiasing = true
	eyes.frames = Paths.getSparrowAtlas('ghost-eyes')
	eyes.animation.addByPrefix('regular', 'ghost eyes', 0)
	eyes.animation.addByPrefix('eaten', 'ghost eaten eyes', 24, false)
	eyes.animation.addByPrefix('sad', 'ghost sad eyes', 0)
	eyes.animation.addByPrefix('angry', 'ghost angry eyes', 0)
	eyes.animation.addByPrefix('pissed', 'ghost mad eyes', 0)
	eyes.addOffset('regular', 0, 0)
	eyes.addOffset('eaten', -5, -2)
	eyes.addOffset('sad', -4, -5)
	eyes.addOffset('angry', 0, -3.5)
	eyes.addOffset('pissed', 1, -1)
	eyes.playAnim('sad')
	eyes.setPosition(ghost.x + 1, ghost.y + .5)
	eyes.shader = game.createRuntimeShader('goodRgb')
	shaderSet(eyes.shader, {r = {0; 0; 1}; g = {1; 1; 1}; b = {0; 0; 0}; dim = .6; a = 1})
	
	local data = {
		tag = tag;
		obj = grp;
		color = color;
		target = {x = 0; y = 0};
		tilePos = {x = startTile.x; y = startTile.y};
		nextDir = {x = -1; y = 0};
		dir = {x = -1; y = 0};
		chase = chase;
		scatter = true;
		
		fright = 0;
		dead = false;
		mustTurn = false;
		
		homePos = startTile.x;
		house = false;
		enteringHouse = false;
		exitingHouse = false;
		houseTurn = false;
		bored = 0;
		
		shake = 0;
		delta = 0;
		speedMult = mapGetMin(session.level).ghostSpeed;
	}
	if mazemeta.ghosts ~= nil then
		ghostMeta = mazemeta.ghosts[tag]
		if ghostMeta ~= nil then
			local pos = fixPos(ghostMeta)
			data.tilePos.x = pos.x or data.tilePos.x
			data.tilePos.y = pos.y or data.tilePos.y
		end
	end
	return data
end

function spawnBonus()
	if bonus.bonus == nil then
		bonus.bonus = makeBonus('bonus', session.leveldata.bonus)
		FlxG.sound.play(Paths.sound('bonusAppear'))
		local timeBonus = reference.ref('timeBonus')
		timeBonus.setColorTransform(1, 1, 1, 1, 0, 255, 255)
		runTimer('bonusFlash', .25)
	end
end

function isInt(num) return (math.floor(num) == num) end
function getMazeCoord(row, col)
	return {
		x = maze.x + 32 * row; -- 8 * 4
		y = maze.y + 32 * col
	}
end
function getMazeTile(row, col)
	if #mazedata == 0 then return ' ' end
	local mazeCol = mazedata[math.max(math.min(col + 1, #mazedata), 1)]
	if #mazeCol == 0 then return ' ' end
	local mazeRow = mazeCol[math.max(math.min(row + 1, #mazeCol), 1)]
	return mazeRow
end
function getMazeCollision(row, col)
	return getMazeTile(row, col) == '#'
end
function euclideanDist(pointa, pointb)
	return (pointb.x - pointa.x) ^ 2 + (pointb.y - pointa.y) ^ 2
end
local targetDirPriority = {{0; -1}; {-1; 0}; {0; 1}; {1; 0}}
function findFreeDirection(current, coord, target)
	local freeDirs = {}
	local goUp = (target == nil or getMazeTile(coord.x, coord.y):lower() ~= 'w')
	for _, dir in ipairs(targetDirPriority) do
		if dir[2] == -1 and not goUp then goto continue end
		if (current.x ~= 0 and dir[1] == -current.x) or (current.y ~= 0 and dir[2] == -current.y) then goto continue end
		local free = not getMazeCollision(coord.x + dir[1], coord.y + dir[2])
		if free then
			--current.x = dir[1]
			--current.y = dir[2]
			table.insert(freeDirs, dir)
		end
		::continue::
	end
	if target == nil then
		if #freeDirs > 0 then
			local next = freeDirs[getRandomInt(1, #freeDirs)]
			current.x = next[1]
			current.y = next[2]
		end
		return current
	end
	local closestDist = nil
	local closestDir = nil
	for _, dir in ipairs(freeDirs) do
		local apos = {x = coord.x + dir[1]; y = coord.y + dir[2]}
		local dist = euclideanDist(apos, target)
		if closestDist == nil or dist < closestDist then
			closestDist = dist
			closestDir = dir
		end
	end
	if closestDir ~= nil then
		current.x = closestDir[1]
		current.y = closestDir[2]
	end
	return current
end
function math.round(n) return (n > 0 and math.floor or math.ceil)(n + (n > 0 and .5 or -.5)) end
function getAngle(coord)
	return math.atan2(coord.y, coord.x)
end
function pacAddScore(score)
	game.songScore = game.songScore + score
	game.totalNotesHit = game.totalNotesHit + score
	game.totalPlayed = game.totalPlayed + score
	game.songHits = game.songHits + 1
	rating = game.totalNotesHit / game.totalPlayed
	game.RecalculateRating()
	
	if not extraLife then
		lives = lives + (score / 10000)
		if game.songScore >= 10000 then
			FlxG.sound.play(Paths.sound('extend'))
			lives = math.floor(lives + .01) - .0001
			extraLife = true
			fullBar.color = 0xffffff
			runTimer('barFlash', .2, 10)
		end
	end
	updateHealth()
end
function onTimerCompleted(t, loops, left)
	if t == 'barFlash' then
		fullBar.color = (left > 0 and (left % 2 == 1 and 0xffff00 or 0xffffff) or 0x66ff33)
		if left == 0 then game.health = math.round(game.health) end
	end
	if t == 'bonusFlash' then
		local timeBonus = reference.ref('timeBonus')
		local flashy = (left % 2 == 0 and 0 or 255)
		timeBonus.setColorTransform(1, 1, 1, 1, 0, flashy, flashy)
		if reference.luaObjectExists('bonus') and left == 0 then
			runTimer('bonusFlash', .25, 2)
		end
	end
end
function modeswitchGhosts()
	reverseGhosts()
	for _, ghost in pairs(ghosts) do
		ghost.scatter = not ghost.scatter
	end
end
function reverseGhosts(fright)
	local frighted = 0
	for _, ghost in pairs(ghosts) do
		if ghost.dead then goto continue end
		ghost.mustTurn = true
		if fright ~= nil and fright > 0 then
			if ghost.fright <= 0 then
				session.frightCount = session.frightCount + 1
				frighted = frighted + 1
			end
			ghost.fright = fright
			ghost.speedMult = session.leveldata.frightGhostSpeed
			local body = reference.ref(ghost.tag)
			local eyes = reference.ref(ghost.tag .. 'Eyes')
			local r = body.shader.getFloatArray('r')._value
			shaderSet(body.shader, {r = {r[1] * .5; r[2] * .5; r[3] * .5 + .5}})
			shaderSet(eyes.shader, {g = {1; 0xb8 / 255; 0xae / 255}})
		end
		::continue::
	end
	return frighted
end
function updateHealth()
	game.health = lives / maxLives * 2
	game.iconP1.animation.curAnim.curFrame = (lives <= 1 and 1 or 0)
	local clipX = game.healthBar.rightBar.clipRect.x
	fullBar.clipRect.x = clipX
	fullBar.clipRect.width = ((1 - math.floor(lives) / maxLives) * fullBar.width) - clipX
	fullBar.clipRect = fullBar.clipRect
end
function spawnCombo()
	game.combo = game.combo + 1
	hscript([[
		import objects.NoteSplash;
		//doing this in hscript to not hog the game
		var prevCombos = (ClientPrefs.data.comboStacking ? game.comboGroup.members.length : 0);
		var note = new Note(Conductor.songPosition, 0);
		note.ratingDisabled = true;
		note.noteSplashData.disabled = true;
		game.popUpScore(note);
		note.destroy();
		
		var maze = game.getLuaObject('maze');
		var i:Int = 0;
		var n:Int = 0;
		var off = (game.comboGroup.members.length - prevCombos) * .5 - .5;
		for (num in game.comboGroup) {
			if (i >= prevCombos) {
				num.x = maze.x + (maze.width - num.width) * .5;
				num.x += (n - off) * 40;
				n += 1;
			}
			i += 1;
		}
	]])
end
function spawnSplash(x, y, scale, col)
	hscript([[
		import objects.NoteSplash;
		import Reflect;

		var note:Note = new Note(0, 0);
		note.noteSplashData.texture = (PlayState.SONG != null ? PlayState.SONG.splashSkin : 'noteSplashes');
		var splash = game.grpNoteSplashes.recycle(NoteSplash);
		if (Reflect.hasField(splash, 'setupNoteSplash'))
			splash.setupNoteSplash(x, y, 0);
		else {
			splash.spawnSplashNote(note);
			splash.setPosition(x, y);
		}
		splash.scrollFactor.set(1, 1);
		splash.rgbShader.shader.r.value = [0, 0, 1];
		splash.scale.set(scale, scale);
		game.grpNoteSplashes.add(splash);
		note.destroy();
	]], {x = x; y = y; scale = scale})
end
function eatBonus(bonus)
	local bon = bonus.obj
	spawnSplash(bon.x - 20, bon.y - 20, .5, {0; 0; 1})
	
	--FlxG.sound.play(Paths.sound('hitsound'), ClientPrefs.data.hitsoundVolume)
	FlxG.sound.play(Paths.sound('bonus'))
	reference.destroyInstance(bonus.tag)
	reference.destroyInstance(bonus.tag .. 'Group')
	local bonus = bonuses[bonus.name]
	if bonus and bonus.score then pacAddScore(bonus.score) end
	local timeBonus = reference.ref('timeBonus')
	timeBonus.setColorTransform(1, 1, 1, 1, 255, 255, 255)
	runTimer('bonusFlash', .5)
end
function jrFruitTarget()
	local liveEnergizers = {}
	for c, col in ipairs(mazedata) do
		for r, row in ipairs(col) do
			if row == 'O' then
				local pellet = reference.ref(tileKey(r - 1, c - 1))
				if pellet.alive then
					table.insert(liveEnergizers, {x = r - 1; y = c - 1})
				end
			end
		end
	end
	if #liveEnergizers > 0 then
		return liveEnergizers[getRandomInt(1, #liveEnergizers)]
	else
		return pacmen.pacman.tilePos
	end
end

function gameLogic()
	if session.motion and session.frightCount + session.eyesCount == 0 and session.switchTime ~= nil then
		session.switchTime = session.switchTime - 1
		if session.switchTime <= 0 then
			session.curSwitch = session.curSwitch + 1
			session.switchTime = session.modeswitch[session.curSwitch]
			modeswitchGhosts()
		end
	end
	
	for _, bon in pairs(bonus) do
		if not session.motion then goto continue end
		
		local jr = (bon.behavior == 'jr')
		if bon.alive > 0 then
			bon.alive = bon.alive - 1
			if bon.alive <= 0 then
				if jr then
					bon.target = jrFruitTarget()
				else
					reference.destroyInstance(bon.tag)
					reference.destroyInstance(bon.tag .. 'Group')
					-- you can usually just use sprite.destroy(),
					-- but this makes sure the instance is removed from the lua sprite/variable maps and isn't kept as a dead reference
					-- (it also returns true if the destruction was successful)
					bonus[_] = nil
					goto continue
				end
			end
		end
		
		bon.delta = bon.delta + bon.speedMult
		while bon.delta >= 1 do
			bon.bounce = bon.bounce + 1
			bon.delta = bon.delta - 1
			if isInt(bon.tilePos.x) and isInt(bon.tilePos.y) then
				if jr then
					findFreeDirection(bon.dir, bon.tilePos, bon.target)
					if getMazeTile(bon.tilePos.x, bon.tilePos.y) == '.' then
						local pellet = reference.ref(tileKey(bon.tilePos.x, bon.tilePos.y))
						if pellet.alive then
							mazedata[bon.tilePos.y + 1][bon.tilePos.x + 1] = 'o'
							pellet.loadGraphic(Paths.image('bigpellet'))
							pellet.shader = maze.shader
						end
					end
					if bon.target ~= nil and bon.tilePos.x == bon.target.x and bon.tilePos.y == bon.target.y then
						FlxG.sound.play(Paths.sound('bonusBoom'))
						local pellet = reference.ref(tileKey(bon.tilePos.x, bon.tilePos.y))
						if pellet.alive then
							pellet.kill()
							session.pellets = session.pellets + 1
							bonus[_] = nil
							
							hscript([[
								var boom = new FlxSprite(]] .. bon.obj.x .. [[, ]] .. bon.obj.y .. [[);
								boom.frames = Paths.getSparrowAtlas('blast');
								boom.animation.addByPrefix('boom', 'explotion', 32, false);
								boom.animation.play('boom');
								boom.antialiasing = ClientPrefs.data.antialiasing;
								boom.scale.set(.75, .75);
								boom.updateHitbox();
								boom.offset.set(boom.width * .5 + 16, boom.height * .5 + 16);
								game.insert(5000, boom); //lol
								boom.animation.finishCallback = () -> {
									game.remove(boom);
									boom.destroy();
								}
							]])
							reference.destroyInstance(bon.tag)
							reference.destroyInstance(bon.tag .. 'Group')
							goto continue
						end
					end
				else
					if bon.cycling then
						if bon.tilePos.x == bon.returnPos.x and bon.tilePos.y == bon.returnPos.y then
							bon.cycling = false
							bon.exiting = true
						end
					end
					if not bon.cycling then
						bon.pathP = bon.pathP + 1
						local path = bon[bon.exiting and 'exitPath' or 'entrancePath']
						local point = path:sub(bon.pathP, bon.pathP)
						local dir = pathDirs[point]
						if dir then
							bon.dir.x = dir.x
							bon.dir.y = dir.y
						end
						if bon.pathP > #path then
							if bon.exiting then
								reference.destroyInstance(bon.tag)
								reference.destroyInstance(bon.tag .. 'Group')
								bonus[_] = nil
								goto continue
							else
								bon.returnPos = {x = bon.tilePos.x; y = bon.tilePos.y}
								bon.cycling = true
								bon.pathP = 0
							end
						end
					end
					if bon.cycling then findFreeDirection(bon.dir, bon.tilePos, bon.target) end
				end
			end
			moveMazeEntity(bon)
		end
		::continue::
	end
	
	for _, pac in pairs(pacmen) do
		if not session.motion then goto continue end
		if pac.pelletFreeze > 0 then
			pac.pelletFreeze = pac.pelletFreeze - 1
			goto continue
		end
		
		pac.delta = pac.delta + pac.speedMult
		local ins = pac.obj
		local tile = pac.tilePos
		local roundTile = pac.roundTile
		while pac.delta >= 1 do
			if math.round(tile.x) ~= roundTile.x or math.round(tile.y) ~= roundTile.y then
				roundTile.x = math.round(tile.x)
				roundTile.y = math.round(tile.y)
				pacBuffer(pac)
				if reference.objectExists(tileKey(roundTile.x, roundTile.y)) then
					local pellet = reference.ref(tileKey(roundTile.x, roundTile.y))
					if pellet.alive then
						pellet.kill()
						
						local pelletTile = getMazeTile(roundTile.x, roundTile.y)
						local power = (pelletTile == 'O')
						local big = (pelletTile == 'o')
						if power then
							session.ghostCombo = 0
							local prevFright = session.frightCount
							local fright = session.leveldata.frightTime
							local frighted = reverseGhosts(fright * 60)
							if prevFright == 0 and frighted > 0 then
								game.defaultCamZoom = game.defaultCamZoom - .08
								pac.speedMult = session.leveldata.frightPacSpeed
								ins.playAnim('aggro')
								frightSound.play()
							end
							for _, bon in pairs(bonus) do
								if bon.behavior == 'jr' and bon.alive <= 0 and bon.target.x == roundTile.x and bon.target.y == roundTile.y then
									bon.target = jrFruitTarget()
								end
							end
						end
						
						--spawnCombo()
						
						FlxG.sound.play(Paths.sound(big and 'eatBig' or (pac.wa and 'eat_1' or 'eat_2')))
						pac.wa = not pac.wa
						pac.pelletFreeze = (power and 3 or (big and 2 or 1))
						session.pellets = session.pellets + 1
						if session.pellets % 100 == 70 then
							spawnBonus()
						end
						
						local score = ((power or big) and 50 or 10)
						pacAddScore(score)
						
						local pelletsLeft = mazemeta.pellets - session.pellets
						if pelletsLeft == session.leveldata.elroy1 then session.elroy = 1
						elseif pelletsLeft == session.leveldata.elroy2 then session.elroy = 2 end
					end
				end
			end
			local floorTile = {x = (pac.dir.x < 0 and math.floor or math.ceil)(tile.x); y = (pac.dir.y < 0 and math.floor or math.ceil)(tile.y)}
			if isInt(tile.x) then
				if getMazeCollision(tile.x + pac.dir.x, floorTile.y) or pac.finalDir.y ~= 0 then
					pac.dir.x = 0
				end
			end
			if isInt(tile.y) then
				if getMazeCollision(floorTile.x, tile.y + pac.dir.y) or pac.finalDir.x ~= 0 then
					pac.dir.y = 0
				end
			end
			if pac.dir.x ~= 0 or pac.dir.y ~= 0 then
				for _, bon in pairs(bonus) do -- pacman-bonus collision
					if (bon.speedMult > 0 and math.round(bon.tilePos.x) == roundTile.x and math.round(bon.tilePos.y) == roundTile.y)
					or (bon.tilePos.x == tile.x and bon.tilePos.y == tile.y) then
						eatBonus(bon)
						bonus[_] = nil
					end
				end
			end
			moveMazeEntity(pac)
			pac.delta = pac.delta - 1
		end
		
		if pac.dir.x ~= 0 or pac.dir.y ~= 0 then
			local ang = math.deg(getAngle(pac.dir))
			ins.angle = (ang == 180 and 0 or ang)
			ins.scale.x = (ang == 180 and -1 or 1)
			ins.animation.timeScale = 1
		else
			ins.animation.timeScale = 0
			if pac.curKey ~= nil then
				strumPlayAnim(pac.curKey, 'static')
				pac.curKey = nil
			end
			if pac.nextKey ~= nil then
				strumPlayAnim(pac.nextKey, 'static')
				pac.nextKey = nil
			end
		end
		
		for _, ghost in pairs(ghosts) do -- ghost-pacman collision fuzz
			if not ghost.dead and pac.roundTile.x == math.round(ghost.tilePos.x) and pac.roundTile.y == math.round(ghost.tilePos.y) then
				if ghost.fright > 0 then
					session.ghostCombo = session.ghostCombo + 1
					local ghostScore = 100 * 2 ^ session.ghostCombo
					local scale = session.ghostCombo * .1 + .5
					pacAddScore(ghostScore)
					
					session.pause = 64
					session.motion = false
					
					FlxG.sound.play(Paths.sound('eatGhost'), .87)
					game.defaultCamZoom = game.defaultCamZoom + .15
					
					ghost.fright = 1
					ghost.dead = true
					
					pac.obj.playAnim('bite')
					pac.obj.animation.timeScale = 1
					
					local eyes = reference.ref(ghost.tag .. 'Eyes')
					eyes.playAnim('eaten')
					shaderSet(eyes.shader, {g = {1; 1; 1}})
					
					local body = reference.ref(ghost.tag)
					body.visible = false
					spawnSplash(body.x - 16, body.y - 16, .7, {0; 0; 1})
					
					hscript([[
						var score = new FlxSprite(]] .. (body.x + 16) .. [[, ]] .. (body.y + 16) .. [[);
						score.loadGraphic(Paths.image('score/ghost]] .. ghostScore .. [['));
						score.scale.set(]] .. scale .. [[, ]] .. scale .. [[);
						score.updateHitbox();
						score.antialiasing = ClientPrefs.data.antialiasing;
						score.x += -score.width * .5 + 4;
						score.y += -score.height * .5;
						score.velocity.x = FlxG.random.int(-10, 10);
						score.velocity.y = FlxG.random.int(-200, -240);
						score.acceleration.y = 480;
						game.insert(5000, score);
						score.setColorTransform(0, 0, 0, 1, 0, 255, 255);
						
						new FlxTimer().start(1 / 12, () -> {
							score.setColorTransform();
						});
						FlxTween.tween(score, {alpha: 0}, .3, {startDelay: .7, onComplete: () -> {
							score.destroy();
						}});
					]])
				elseif not ghost.dead then
				end
				break
			end
		end
		::continue::
	end
	
	for _, ghost in pairs(ghosts) do
		local ins = ghost.obj
		local tile = ghost.tilePos
		local eyesAnim = 'regular'
		local eyeUpdate
		local eyes = reference.ref(ghost.tag .. 'Eyes')
		local ghosHouse = mazemeta.ghost_house
		ghost.shake = 0
		
		if ghost.fright > 0 then
			local body = reference.ref(ghost.tag)
			if not ghost.dead then eyes.animation.curAnim.curFrame = (body.animation.curAnim.curFrame < 2 and 4 or 5) end
			if session.motion then ghost.fright = ghost.fright - 1 end
			if ghost.fright <= 0 then
				if ghost.dead then
					game.defaultCamZoom = game.defaultCamZoom - .15
					for _, pac in pairs(pacmen) do
						pac.obj.playAnim('aggro')
					end
					if session.eyesCount == 0 then
						frightSound.stop()
						eyesSound.play()
					end
					session.eyesCount = session.eyesCount + 1
				end
				ghost.speedMult = session.leveldata.ghostSpeed
				shaderSet(body.shader, {r = ghost.color})
				shaderSet(eyes.shader, {g = {1; 1; 1}})
				eyeUpdate = ghost.nextDir
				
				session.frightCount = session.frightCount - 1
				if session.frightCount == 0 then
					for _, pac in pairs(pacmen) do
						pac.speedMult = session.leveldata.pacSpeed
						pac.obj.playAnim('munch')
					end
					game.defaultCamZoom = game.defaultCamZoom + .08
					frightSound.stop()
				end
			end
		end
		if ghost.dead then
			ghost.speedMult = 2
			eyesAnim = 'sad'
		elseif ghost.house then
			ghost.speedMult = .5
		elseif ghost.fright > 0 then
			ghost.speedMult = session.leveldata.frightGhostSpeed
		else
			local inTunnel = false
			if getMazeTile(math.round(tile.x), math.round(tile.y)) == '<' then
				ghost.speedMult = session.leveldata.ghostTunnelSpeed
				inTunnel = true
			else
				ghost.speedMult = session.leveldata.ghostSpeed
			end
			if ghost.tag == 'blinky' then
				if session.elroy == 2 then
					if not inTunnel then ghost.speedMult = session.leveldata.elroy2Speed end
					ghost.shake = .5
					eyesAnim = (inTunnel and 'angry' or 'pissed')
				elseif session.elroy == 1 then
					if not inTunnel then ghost.speedMult = session.leveldata.elroy1Speed end
					ghost.shake = .25
					eyesAnim = (inTunnel and 'regular' or 'angry')
				end
			end
		end
		if eyes.animation.name ~= eyesAnim and not (ghost.dead and ghost.fright > 0) then
			eyeUpdate = (ghost.house and ghost.dir or ghost.nextDir)
			eyes.playAnim(eyesAnim, false, false)
		end
		if not session.motion and not (ghost.dead and ghost.fright == 0) then goto continue end
		
		ghost.delta = ghost.delta + ghost.speedMult
		while ghost.delta >= 1 do
			ghost.delta = ghost.delta - 1
			ghost.target = (ghost.dead and {x = ghosHouse.exit.x; y = ghosHouse.exit.y} or ghost:chase(tile))
			if ghost.house then
				eyeUpdate = ghost.dir
				if not (ghost.exitingHouse or ghost.enteringHouse) then
					if tile.y % 1 == .5 then
						ghost.dir.y = -ghost.dir.y
					end
					if isInt(tile.y) then
						ghost.exitingHouse = true
					end
				end
				if ghost.enteringHouse then
					if tile.y == ghosHouse.inside.y then
						ghost.dir.y = 0
						if tile.x == ghost.homePos then
							if session.motion then
								ghost.dead = false
								ghost.exitingHouse = true
								ghost.enteringHouse = false
								ghost.speedMult = .5
								local body = reference.ref(ghost.tag)
								body.visible = true
								body.playAnim('regenerate')
								hscript([[
									var body = game.getLuaObject(']] .. ghost.tag .. [[');
									body.animation.finishCallback = () -> {
										body.playAnim('main');
										body.animation.finishCallback = null;
									};
								]])
								session.eyesCount = session.eyesCount - 1
								if session.eyesCount == 0 then
									eyesSound.stop()
									if session.frightCount > 0 then frightSound.play() end
								end
							else
								ghost.dir.x = 0 -- wait for it...
							end
						else
							ghost.dir.x = (ghost.homePos < tile.x and -1 or 1)
						end
					end
				end
				if ghost.exitingHouse then
					local diff = tile.x - mazemeta.width * .5
					ghost.dir.x = (diff < 0 and 1 or (diff > 0 and -1 or 0))
					ghost.dir.y = (diff == 0 and -1 or 0)
					eyeUpdate = ghost.dir
					if isInt(tile.y) and tile.y <= ghosHouse.exit.y then
						ghost.exitingHouse = false
						ghost.house = false
						ghost.dir.x = -1
						ghost.dir.y = 0
						ghost.speedMult = session.leveldata.ghostSpeed
					end
				end
			else
				if isInt(tile.x) and isInt(tile.y) then
					if ghost.mustTurn then
						ghost.nextDir.x = -ghost.dir.x
						ghost.nextDir.y = -ghost.dir.y
						ghost.mustTurn = false
					end
					ghost.dir.x = ghost.nextDir.x
					ghost.dir.y = ghost.nextDir.y
					
					findFreeDirection(ghost.nextDir, {x = tile.x + ghost.dir.x; y = tile.y + ghost.dir.y}, ghost.target)--pointerCoord)
					eyeUpdate = ghost.nextDir
				end
				if ghost.dead and tile.x == mazemeta.width * .5 and tile.y == ghosHouse.exit.y then
					ghost.dir.x = 0
					ghost.dir.y = 1
					ghost.house = true
					ghost.enteringHouse = true
					eyeUpdate = ghost.nextDir
				end
			end
			moveMazeEntity(ghost)
		end
		
		::continue::
		
		if eyeUpdate ~= nil and ghost.fright <= 0 and (eyeUpdate.x ~= 0 or eyeUpdate.y ~= 0) then
			local eyes = reference.ref(ghost.tag .. 'Eyes')
			eyes.animation.curAnim.curFrame = (eyeUpdate.x < 0 and 0 or (eyeUpdate.x > 0 and 2 or (eyeUpdate.y < 0 and 1 or 3)))
		end
		
	--local coord = getMazeCoord(ghost.target.x, ghost.target.y) --tile
	--ins.x = coord.x
	--ins.y = coord.y
		
		--game.camFollow.y = ins.y
	end
end
function onUpdatePost(e)
	if not reference then return end
	-- debugPrint(fullBar.clipRect.y)
	--pointerCoord.x = math.ceil((FlxG.mouse.x - maze.x) / 32)
	--pointerCoord.y = math.ceil((FlxG.mouse.y - maze.y) / 32)
	--local a = getMazeCoord(pointerCoord.x, pointerCoord.y)
	--pointer.setPosition(a.x - pointer.width, a.y - pointer.height)
	
	if prevBeat ~= game.curBeat then
		beatHit(game.curBeat)
		prevBeat = game.curBeat
	end
	
	delta = math.min(delta + e * refreshRate, 30)
	while delta >= 1 do
		if session.pause > 0 then
			session.pause = session.pause - 1
			session.motion = (session.pause == 0)
		end
		gameLogic()
		delta = delta - 1
	end
	for _, ghost in pairs(ghosts) do
		updateMazeEntityPos(ghost)
		if ghost.shake > 0 then
			local ins = ghost.obj
			ins.x = ins.x + getRandomInt(-ghost.shake, ghost.shake)
			ins.y = ins.y + getRandomInt(-ghost.shake, ghost.shake)
		end
		--[[if ghost.target ~= nil then -- target debug
			local coord = getMazeCoord(ghost.target.x, ghost.target.y)
			ghost.obj.x = coord.x
			ghost.obj.y = coord.y
		end]]
	end
	for _, bon in pairs(bonus) do
		updateMazeEntityPos(bon)
		local bonObj = reference.ref(bon.tag)
		bonObj.y = bon.obj.y - math.abs(math.sin(bon.bounce * math.pi / 8) * 8)
	end
	for _, pac in pairs(pacmen) do updateMazeEntityPos(pac) end
	
	local pelletPercent = session.pellets / mazemeta.pellets
	game.iconP1.x = game.healthBar.barCenter - 75
	if timeBarType == 'Song Name' then game.timeTxt.text = 'Level ' .. session.level
	elseif timeBarType == 'Time Elapsed' then game.timeTxt.text = math.floor(pelletPercent * 100) .. '% clear'
	else game.timeTxt.text = (mazemeta.pellets - session.pellets) .. ' left' end
	game.songPercent = pelletPercent
	
	local followPac = pacmen.pacman.obj
	
	game.camFollow.x = maze.x + maze.width * .5
	local offset = -32
	if followPac then
		local center = maze.y + maze.height * .5
		local centerX = maze.x + maze.width * .5
		local diff = followPac.x - game.camGame.scroll.x - screenWidth * .5
		if math.abs(diff) >= (maze.width + offset) * .5 then
			camPos.x = camPos.x + (maze.width + offset) * (diff > 0 and 1 or -1)
		end
		local qhatX = (followPac.x - centerX + 16)
		local intenseX = (
			mazemeta.loop_x and
			(1 - (1 - math.max(1 - math.abs(followPac.y - getMazeCoord(0, mazemeta.height * .5).y) / maze.height * 1.8, 0)) ^ 2) or
			(1 - math.abs(followPac.y - getMazeCoord(0, mazemeta.height * .5).y) / maze.height * .5)
		)
		local qhatY = (followPac.y - center)
		game.camFollow.x = ((qhatX / ((maze.width + offset) * .5)) ^ 2) * (maze.width + offset) * (qhatX > 0 and .5 or -.5) * intenseX + centerX
		game.camFollow.y = center + (1 - (1 - math.abs(qhatY / maze.height)) ^ 2) * (qhatY > 0 and .5 or -.5) * maze.height * .7
	end
	
	local camM = 1 - math.exp(-e * 3)
	camPos.x = camPos.x + (game.camFollow.x - camPos.x) * camM
	camPos.y = camPos.y + (game.camFollow.y - camPos.y) * camM
	game.camGame.scroll.x = camPos.x - screenWidth * .5
	game.camGame.scroll.y = camPos.y - screenHeight * .5
	local s = {x = game.camGame.scroll.x; y = game.camGame.scroll.y}
	for i, cam in ipairs({leftCam, rightCam}) do
		cam.zoom = game.camGame.zoom
		cam.scroll.x = s.x + (maze.width + offset) * (i == 1 and -1 or 1)
		cam.scroll.y = s.y
	end
end
function beatHit(beat)
	if beat % 4 == 0 then
		game.camGame.zoom = game.camGame.zoom + .015
		game.camHUD.zoom = game.camHUD.zoom + .03
	end
	for _, energizer in pairs(energizers) do
		energizer.playAnim(math.abs(beat) % 2 == 0 and 'big' or 'small')
	end
end
function pacBuffer(pac)
	local roundTile = pac.roundTile
	if not getMazeCollision(roundTile.x + pac.nextDir.x, roundTile.y + pac.nextDir.y) then
		if pac.curKey ~= pac.nextKey then
			strumPlayAnim(pac.curKey, 'static')
			strumPlayAnim(pac.nextKey, 'confirm')
			pac.curKey = pac.nextKey
		end
		if pac.nextDir.x ~= 0 then
			pac.dir.x = pac.nextDir.x
			local diff = pac.tilePos.y - roundTile.y
			pac.dir.y = math.abs(pac.dir.y) * (diff > 0 and -1 or (diff == 0 and 0 or 1))
		end
		if pac.nextDir.y ~= 0 then
			pac.dir.y = pac.nextDir.y
			local diff = pac.tilePos.x - roundTile.x
			pac.dir.x = math.abs(pac.dir.x) * (diff > 0 and -1 or (diff == 0 and 0 or 1))
		end
		pac.finalDir.x = pac.nextDir.x
		pac.finalDir.y = pac.nextDir.y
	end
end
function onUpdateScore()
	game.scoreTxt.text = 'Score: ' .. score .. ' | Accuracy: ' .. (hits + misses == 0 and 'N/A' or ((math.round(rating * 10000) * .01) .. '%'))
	return Function_Stop
end

function strumPlayAnim(strum, anim)
	if not strum then return end
	local strum = reference.ref('playerStrums.members.' .. strum)
	strum.playAnim(anim, true)
end

function onKeyPressPre(k)
	local pac = pacmen.pacman
	pac.nextDir = {x = (k == 3 and 1 or (k == 0 and -1 or 0)); y = (k == 1 and 1 or (k == 2 and -1 or 0))}
	local strum
	if pac.nextKey ~= k then
		strumPlayAnim(pac.nextKey, 'static')
		pac.nextKey = k
		strumPlayAnim(k, 'pressed')
	end
	if pac.curKey ~= k then
		strumPlayAnim(pac.curKey, 'static')
	end
	pacBuffer(pac)
	return Function_Stop
end

function onKeyReleasePre(k)
	return Function_Stop
end

function updateMazeEntityPos(entity)
	local ins = entity.obj
	local tile = entity.tilePos
	local d = entity.delta * entity.speedMult / 8
	local coord = getMazeCoord(tile.x + entity.dir.x * d, tile.y + entity.dir.y * d) --tile
	ins.x = coord.x
	ins.y = coord.y
end
function moveMazeEntity(entity)
	local tile = entity.tilePos
	tile.x = tile.x + entity.dir.x / 8
	tile.y = tile.y + entity.dir.y / 8
	if tile.x < 0 then
		tile.x = tile.x + mazemeta.width
	elseif tile.x > mazemeta.width then
		tile.x = tile.x - mazemeta.width
	end
end

function fixPos(pos)
	if type(pos.x) == 'number' and pos.x < 0 then pos.x = pos.x + mazemeta.width end
	if type(pos.y) == 'number' and pos.y < 0 then pos.y = pos.y + mazemeta.height end
	return pos
end
-- {entrance = ...; exit = ...}
-- {inside = ...; exit = ...}
function rgbInt(rgb)
	return math.floor(rgb.r) * 65536 + math.floor(rgb.g) * 256 + math.floor(rgb.b)
end
function isArray(tbl) return #tbl > 0 and next(tbl, #tbl) == nil end
function tableFallback(tbl, entry, data)
	if tbl[entry] == nil then
		tbl[entry] = data
	elseif type(data) == 'table' then
		for field, val in (isArray(data) and ipairs or pairs)(data) do
			tableFallback(tbl[entry], field, val)
		end
	end
end
function loadMeta()
	local jsonContent = getTextFromFile('mazes/' .. session.set .. '/general.json')
	if jsonContent ~= nil then
		local json = JSON.parse(jsonContent)._value
		for field, val in pairs(json) do meta[field] = val end
	end
	mazeTitle.text = (meta.name or session.set)
	mazeText.x = mazeTitle.x + mazeTitle.width + 10
	shaderSet(mazeTitle.shader, {r = {1; 1; 1}; b = {0; 0; 0}; dim = .5; a = 1})
end
function loadMaze(mazeName)
	local jsonContent = getTextFromFile('mazes/' .. session.set .. '/' .. mazeName .. '.json')
	if jsonContent ~= nil then
		local json = JSON.parse(jsonContent)._value
		for field, val in pairs(json) do mazemeta[field] = val end
	end
	local symmetryX = mazemeta.symmetric or true
	
	local content = getTextFromFile('mazes/' .. session.set .. '/' .. mazeName .. '.txt')
	local split = stringSplit(content, '\n')
	for i, v in ipairs(split) do
		v = v:gsub('\r', ''):gsub('\t', '    ')
		split[i] = stringSplit(symmetryX and (v .. v:reverse()) or v, '')
	end
	mazedata = split
	
	mazeText.x = mazeTitle.x + mazeTitle.width + 10
	mazeText.text = (mazemeta.name or mazeName)
	tableFallback(mazemeta, 'loop_x', true)
	camList = (mazemeta.loop_x and {leftCam, game.camGame, rightCam} or {game.camGame})
	
	local imagePath = 'mazes/' .. (mazemeta.image_path or (session.set .. '/' .. mazeName))
	maze.loadGraphic(Paths.image(imagePath))
	maze.updateHitbox()
	maze.screenCenter(0x11)
	mazemeta.height = #mazedata
	local pelletColor = mazemeta.pellet_color
	if pelletColor == nil then pelletColor = 0xffb8ae
	else pelletColor = rgbInt({r = pelletColor[1] or 0; g = pelletColor[2] or 0; b = pelletColor[3] or 0}) end
	
	for col = 1, #mazedata do
		local rows = mazedata[col]
		mazemeta.width = math.max(mazemeta.width, #rows - 1)
		for row, v in ipairs(rows) do
			local pellet
			local power = (v == 'O')
			if v == '.' or v == 'W' or power then
				pellet = reference.createInstance(tileKey(row - 1, col - 1), power and 'psychlua.ModchartSprite' or 'flixel.FlxSprite')
				mazeGroup.add(pellet)
			end
			if pellet then
				mazemeta.pellets = mazemeta.pellets + 1
				pellet.antialiasing = ClientPrefs.data.antialiasing
				if power then
					pellet.frames = Paths.getSparrowAtlas('energizer')
					pellet.animation.addByPrefix('big', 'power pellet0', 24, false)
					pellet.animation.addByPrefix('small', 'power pellet small', 24, false)
					pellet.addOffset('big', 26, 26)
					pellet.addOffset('small', 20, 18)
					pellet.playAnim('small')
					table.insert(energizers, pellet)
				else
					pellet.loadGraphic(Paths.image('pellet'))
					pellet.color = pelletColor
					pellet.active = false
				end
				local pos = getMazeCoord(row - 1, col - 1)
				pellet.setPosition(pos.x + pellet.width * .5, pos.y + pellet.height * .5)
			end
		end
	end
	
	tableFallback(mazemeta, 'maze_color', {r = {33; 33; 255}; b = {0; 0; 0}})
	local mazeColor = mazemeta.maze_color
	local shaderFields = {dim = .5; a = 1}
	for f, val in pairs(mazeColor) do
		shaderFields[f] = {val[1] / 255; val[2] / 255; val[3] / 255}
	end
	if shaderFields.g == nil then shaderFields.g = shaderFields.b end
	shaderSet(maze.shader, shaderFields)
	local textColor = mazemeta.maze_color.b
	if (textColor[1] + textColor[2] + textColor[3] < 32) then textColor = mazemeta.maze_color.r end
	shaderSet(mazeText.shader, {r = {textColor[1] / 255; textColor[2] / 255; textColor[3] / 255}; b = {0; 0; 0}; dim = .5; a = 1})
	
	tableFallback(mazemeta, 'pacmen', {
		pacman = {
			x = mazemeta.width * .5;
			y = 26;
		}
	})
	tableFallback(mazemeta, 'fruit_behavior', meta.fruit_behavior)
	tableFallback(mazemeta, 'bonus', {x = mazemeta.width * .5; y = 20})
	tableFallback(mazemeta, 'ghost_house', {
		exit = {
			x = mazemeta.width * .5;
			y = 14;
		};
		inside = {
			x = mazemeta.width * .5;
			y = 17;
		}
	})
	
	hscript([[
		import flixel.math.FlxRect;
		game.getLuaObject('maze').clipRect = new FlxRect();
	]])
	maze.clipRect.height = maze.height
	maze.clipRect.width = (mazemeta.loop_x and (mazemeta.width * 32) or maze.width)
	maze.clipRect = maze.clipRect
	return mazedata
end

function loadMod(name)
	isFinal = true
	for _, path in ipairs{'scripts/modules/' .. name; 'scripts/' .. name; name} do
		if checkFileExists(path .. '.lua') then
			local mod
			if isFinal then
				mod = 'mods/' .. modFolder .. '/' .. path
			else
				mod = runHaxeCode('return Paths.modFolders(\'' .. path .. '.lua\');'):gsub('.lua', '')
				if mod:find('mods/') then mod = mod:sub(mod:find('mods/'), #mod) end -- fix for mobile
			end
			return require(mod)
		end
	end
	debugPrint('CAN\'T LOAD MODULE: Path "' .. name .. '" not found!!', 'ff0000')
	return nil
end