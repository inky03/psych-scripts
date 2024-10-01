function math.lerp(a, b, t) return a + (b - a) * t end
function onCreate()
	nextFrame = {} -- queue to next frame (for example in loading screen events where you cant force a screen redraw :<)
	loadedModules = {}
	luaDebugMode = true
	isFinal = stringStartsWith(version, '1.0')

	pacmanVersion = '0.0.4'
	level = 1
	
	controls = {
		uiUP = false;
		uiDOWN = false;
		uiLEFT = false;
		uiRIGHT = false;
		ACCEPT = false;
		BACK = false;
	}

	reference = loadModHard 'backend.Reference'
	listener = loadModHard 'backend.listener'
	tween = loadModHard 'backend.Tween'
	util = loadModHard 'util.util'
	state = loadModHard 'backend.state'
	loadOverlay = loadMod 'backend.loadOverlay'
	
	reference.preset()
	JSON = reference 'tjson.TJSON'
	Alphabet = reference 'objects.Alphabet'
	FlxSound = reference 'flixel.sound.FlxSound'
	SpriteGroup = reference 'flixel.group.FlxTypedSpriteGroup'

	menuState = loadMod 'states.menuState'
	playState = loadMod 'states.playState'
	mazesState = loadMod 'states.mazesState'
	creditsState = loadMod 'states.creditsState'
	
	antialiasing = ClientPrefs.data.antialiasing

	fuck = FlxText:new()
	fuck.text = 'pacman ' .. pacmanVersion
	fuck.camera = game.camOther
	fuck.size = 14
	fuck.scrollFactor.set()
	fuck.antialiasing = antialiasing
	fuck.setPosition(10, FlxG.height - fuck.height - 8)
	setTextBorder(fuck._tag, 1.1, '000000')
	game.add(fuck)

	hscript.new('diag', [[
		function getCount() {
			var count = 0;
			for (_ in game.variables) count += 1;
			return count;
		}
		function update() { //i am done with you
			game.getLuaObject(txtTag).text = defText + ' | ' + getCount() + ' objects';
		}
	]], {txtTag = fuck._tag, defText = fuck.text}):run()
	hscript['diag']:update()
end
function onCreatePost()
	game.camGame.zoom = 1
	game.cameraSpeed = 6.1
	game.camZooming = true
	game.camZoomingMult = 0
	game.defaultCamZoom = 1
	game.updateTime = false

	game.uiGroup.visible = false
	game.noteGroup.visible = false
	for _, spr in ipairs{'boyfriendGroup', 'dadGroup', 'gfGroup', 'opponentStrums', 'iconP2'} do
		game[spr].kill()
	end
end

function switchState(state)
	if currentState then currentState:destroy() end
	currentState = state:create()
	currentStateStatic = state
end
function reloadModules()
	currentState:destroy()
	local mod = currentStateStatic.mod
	for name, m in pairs(loadedModules) do
		local reloadMod = m.mod
		local reloadVars = {}
		for k, v in pairs(m) do
			if type(v) ~= 'function' then
				reloadVars[k] = v
			end
		end
		for k, v in pairs(_G) do
			if v == m then _G[k] = nil end
		end
		loadedModules[name] = nil
		loadMod(reloadMod)
		for k, v in pairs(reloadVars) do
			loadedModules[name][k] = v
		end
		::continue::
	end
	collectgarbage()
	debugPrint('RELOADED', 'bbff66')
	switchState(loadedModules[mod])
end
function onStartCountdown()
	switchState(menuState)

	game.skipCountdown = true
	game.inst.loadEmbedded(Paths.music('freakyMenu'))
end
function onSongStart()
	game.camHUD.visible = true
	FlxG.sound.music.looped = true
	hscript('FlxG.sound.music.onComplete = () -> Conductor.songPosition = 0;')
end

local diag = 0
function onKeyPress(k)
	if currentState then currentState:keyPressed(k) end
end
function onKeyRelease(k)
	if currentState then currentState:keyReleased(k) end
end
function onUpdate(dt)
	if keyboardJustPressed('F5') and currentState then
		reloadModules()
	end
	updateCtrl()
	for i, f in ipairs(nextFrame) do
		local continue, success, msg
		if type(f) == 'function' then
			success, msg = pcall(f)
		elseif type(f) == 'thread' then
			success, msg = coroutine.resume(f)
			if coroutine.status(f) ~= 'dead' and success then continue = true end
		end
		if not success then
			local error = loadOverlay:new()
			error:setString('ERROR!!\n' .. msg, false)
		end

		if not continue then
			table.remove(nextFrame, i)
		end
	end
	if currentState then currentState:update(dt) end
end
function onUpdatePost(dt)
	if currentState then currentState:updatePost(dt) end
	tween.Manager.update(dt)
	diag = diag + dt
	if diag > .1 then
		diag = diag % .1 -- ok ill check that later
		hscript['diag']:update()
	end
end

function updateCtrl()
	controls.uiLEFT = keyJustPressed('left')
	controls.uiRIGHT = keyJustPressed('right')
	controls.special = keyboardJustPressed('P') or (controls.uiLEFT and controls.uiRIGHT)
	controls.uiUP = keyJustPressed('up')
	controls.uiDOWN = keyJustPressed('down')
	controls.ACCEPT = keyJustPressed('accept') or (controls.uiUP and controls.uiDOWN)
	controls.BACK = keyJustPressed('back')
end

function loadModHard(name) return loadMod(name, false) end
function loadMod(name, canReload)
	local reload = (canReload == nil and true or canReload)
	name = name:gsub('%.', '/')
	for _, path in ipairs{'scripts/' .. name; name} do
		if loadedModules[name] then return loadedModules[name] end
		if checkFileExists(path .. '.lua') then
			local mod
			if isFinal then
				mod = 'mods/' .. modFolder .. '/' .. path
			else
				mod = callMethodFromClass('backend.Paths', 'modFolders', {path .. '.lua'}):gsub('.lua', '')
				if mod:find('mods/') then mod = mod:sub(mod:find('mods/'), #mod) end -- fix for mobile
			end
			local modf
			if reload then
				modf = dofile(mod .. '.lua')
				loadedModules[name] = modf -- save these shits into a handy table so we can reload them
				modf.mod = name
			else
				modf = require(mod) -- we do not add those that are added as "un-reload-able"
				modf.mod = name -- and also require because yeah why not
			end
			return modf
		end
	end
	debugPrint('CAN\'T LOAD MODULE: Path "' .. name .. '" not found!!', 'ff0000')
	return nil
end