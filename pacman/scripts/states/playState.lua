if playState then return playState end
playState = {}
setmetatable(playState, {__index = state})
playState.set = ''
playState.maze = ''

local keyDirs = {{X = -1; Y = 0}; {X = 0; Y = 1}; {X = 0; Y = -1}; {X = 1; Y = 0}}
function playState:create()
	local new = state:create()
	setmetatable(new, {__index = playState})

	new.exitToState = mazesState
	new.pacmen = {}
	new.ghosts = {}
	new.modeSwitches = {}

	new.loader = loadOverlay:new()
	new.refreshRate = 60.606061
	new.pausedLogic = false
	new.prevBeat = -1
	new.curBeat = 0
	new.delta = 0

	new.level = 1
	
	local bpm = 130.35
	FlxG.sound.music.stop()
	new.refreshRate = 60.606061 * game.playbackRate
	game.inst.loadEmbedded(Paths.music('toyboxLoop'))
	PlayState.SONG.bpm = bpm
	Conductor.bpm = bpm

	game.cameraSpeed = 3
	game.uiGroup.visible = true
	game.noteGroup.visible = true
	game.botplayTxt.visible = false
	FlxG.sound.music.volume = 0

	new.loader:setString('(playState) loading entities')

	-- init game
	table.insert(nextFrame, coroutine.create(function()
		for _, n in ipairs{'backend.maze', 'entities.base.ghost', 'entities.base.pacman', 'backend.leveldata'} do
			new.loader:setString('(playState) loading ' .. n)
			local split = stringSplit(n, '.')
			_G[split[#split]] = loadMod(n)
			coroutine.yield()
		end

		new.gameMaze = maze:new(playState.set, playState.maze)
		new.levelData = leveldata.fromSet('pacman', new.level, new.gameMaze)
		
		-- debugPrint(new.levelData)
		new.modeSwitches = new.levelData.mode_switch or {}
		new.modeSwitchTimer = new.modeSwitches[1]

		new.pelletCount = 0
		new.pelletsEaten = 0
		new.levelLoaded = false
		new.gameMaze:addEventListener('pelletsLoaded', function() new:onMazeLoaded() end)
		
		new.pacmen.pacman = pacman:new('pacman', new.gameMaze, new.levelData)
		
		for _, ghost in ipairs{'blinky', 'pinky', 'inky', 'clyde'} do
			local entPath = 'entities.' .. ghost
			new.loader:setString('(playState) loading ' .. entPath)
			_G[ghost] = loadMod(entPath)
			new.ghosts[ghost] = _G[ghost]:new(ghost, new.gameMaze, new.levelData)
			new.ghosts[ghost]:prepare()
			coroutine.yield()
		end

		game.healthBar.rightBar.color = 0x66ff33
		game.healthBar.leftBar.color = 0xff0000
		game.iconP1.changeIcon('pacman');
		game.iconP1.y = game.healthBar.y + (game.healthBar.height - game.iconP1.height) * .5

		game.scoreTxt.size = 16
		game.timeTxt.size = 16
		game.scoreTxt.borderSize = 1
		game.timeTxt.borderSize = game.scoreTxt.borderSize
		game.timeTxt.y = game.timeBar.y + (game.timeBar.height - game.timeTxt.height) * .5

		new.gameMaze:generate()
	end))
	
	--[=[
	hscript.new('fps', [[
		import Main;
		import openfl.text.TextField;
		import openfl.text.TextFormat;
		import flixel.util.FlxStringUtil;

		var twn:FlxTween;
		var fpsDisp = Main.fpsVar;
		var maxMem:Float = 1000000000;
		var memPlus:Float = maxMem;
		var prevFPS = fpsDisp.updateText;

		var versionDisplay = new TextField();
		versionDisplay.x = 10;
		versionDisplay.autoSize = fpsDisp.autoSize; //ok
		versionDisplay.text = 'pacman-rewrite ' + pacmanVersion;
		versionDisplay.defaultTextFormat = new TextFormat('_sans', 10, -1);
		
		function initDisplay() {
			if (fpsDisp.updateText != prevFPS) return;
			FlxG.game.addChild(versionDisplay);
			fpsDisp.updateText = () -> {
				var mem = fpsDisp.memoryMegas + memPlus;
				fpsDisp.text = 'FPS: ' + fpsDisp.currentFPS
				+ '\nMemory: ' + FlxStringUtil.formatBytes(mem);
				versionDisplay.x = -FlxG.game.x + 10;
				versionDisplay.y = -FlxG.game.y + FlxG.stage.window.height - 20;
			}
		}
		function setProgress(next, max) {
			if (twn != null) twn.cancel();
			twn = FlxTween.num(memPlus, FlxMath.remapToRange(next, 0, max, maxMem, 0), .25, {ease: FlxEase.quadOut}, (n) -> memPlus = n);
		}
		function resetDisplay() {
			fpsDisp.updateText = prevFPS;
			FlxG.game.removeChild(versionDisplay);
		}
	]], {pacmanVersion = pacmanVersion}):run()
	hscript['fps']:initDisplay()]=]
	return new
end

function playState:onMazeLoaded()
	self.levelLoaded = true
	self.pelletCount = util.tableCount(self.gameMaze.pellets)

	self.loader:destroy()
	Conductor.songPosition = 0
	game.insert(1, self.gameMaze.sprGroup)
	FlxG.sound.playMusic(game.inst._sound, 1, true)
	hscript('FlxG.sound.music.onComplete = () -> Conductor.songPosition = 0;')
end

function playState:updatePost(dt)
	if self.gameMaze then self.gameMaze:update(dt) end
	if not self.levelLoaded then return end

	if keyJustPressed('back') then
		switchState(self.exitToState)
		return
	end

	local songPos = getSongPosition()
	self.curBeat = math.floor(songPos / Conductor.crochet)
	if songPos < songLength - 100 and self.curBeat ~= self.prevBeat then
		self.prevBeat = self.curBeat
		self:beatHit(self.curBeat)
	end
	
	self.delta = math.min(self.delta + dt * self.refreshRate, 60)
	while self.delta >= 1 do
		self:tick()
		self.delta = self.delta - 1
	end
	
	local progress = self.pelletsEaten / self.pelletCount * 100
	game.timeBar.percent = progress
	if timeBarType == 'Time Left' then
		local left = self.pelletCount - self.pelletsEaten
		game.timeTxt.text = left .. (left == 1 and ' pellet left' or ' pellets left')
	elseif timeBarType == 'Time Elapsed' then
		game.timeTxt.text = math.floor(progress) .. '% clear'
	else
		game.timeTxt.text = 'Level ' .. self.level
	end
	
	local focusPac = self.pacmen.pacman
	for _, pac in pairs(self.pacmen) do focusPac = pac pac:draw() end
	for _, ghost in pairs(self.ghosts) do ghost:draw() end
	if focusPac then
		local distY = screenHeight * .5 / self.gameMaze.sprite.height
		local centerY = self.gameMaze.sprite.y + self.gameMaze.sprite.height * .5
		game.camFollow.x = focusPac.sprite.x
		game.camFollow.y = (focusPac.sprite.y - centerY) * distY + centerY
	end
	
	game.iconP1.x = game.healthBar.barCenter - 75
end

function playState:tickToSecs(t) return (t / self.refreshRate) end
function playState:tick()
	local flip
	if self.modeSwitchTimer and self:frightCount() == 0 then
		self.modeSwitchTimer = self.modeSwitchTimer - 1
		if self.modeSwitchTimer <= 0 then
			flip = true
			table.remove(self.modeSwitches, 1)
			self.modeSwitchTimer = self.modeSwitches[1]
		end
	end
	for _, pac in pairs(self.pacmen) do
		if not self.pausedLogic then
			pac:update()
		end
	end
	for _, ghost in pairs(self.ghosts) do
		if flip then
			ghost.mode = (ghost.mode == ghostMode.scatter and ghostMode.chase or ghostMode.scatter)
			ghost:turn()
		end
		if (ghost.dead and not ghost.justKilled) or not self.pausedLogic then
			ghost:update()
		end
	end
end
function playState:beatHit(beat)
	for _, pellet in pairs(self.gameMaze.pellets) do pellet:bop(beat) end
	if beat % 4 == 0 then
		game.camGame.zoom = game.camGame.zoom + .015
		game.camHUD.zoom = game.camHUD.zoom + .03
	end
	game.iconP1.scale.x = 1.2
	game.iconP1.scale.y = 1.2
end
function playState:frightCount()
	local count = 0
	for _, ghost in pairs(self.ghosts) do
		if ghost.fright > 0 then count = count + 1 end
	end
	return count
end

function playState:keyPressed(k)
	if not self.levelLoaded then return end
	local dir = keyDirs[k + 1]
	local pac = self.pacmen.pacman
	pac.nextDir.X = dir.X
	pac.nextDir.Y = dir.Y

	local pinky = self.ghosts['pinky'] -- pinky award stuff
	if not pinky then return end
	if (pac.curDir.X ~= 0 and pac.curDir.X == -dir.X) or (pac.curDir.Y ~= 0 and pac.curDir.Y == -dir.Y) then
		if pac.flick <= 0 then
			if util.euclideanDist(pac.tilePosition, pinky.tilePosition) <= 8 then
				pinky.onFlick = true
			end
			pac.flick = 20
		end
	else
		pac.flick = 0
	end
end

function playState:destroy()
	self.gameMaze:destroy()
	game.uiGroup.visible = false
	game.noteGroup.visible = false
	FlxG.sound.playMusic(Paths.music('freakyMenu'))
	for _, pac in pairs(self.pacmen) do pac:destroy() end
	for _, ghost in pairs(self.ghosts) do ghost:destroy() end
end

return playState