local bf
local spriteTest
local sscale

local speed
local defaultSpeed
local scoreTxt
local camGame
local game

local mouse

local glich = 0 --glich :smiling_face_with_3_hearts:
local singDirs = {{-1, 0}, {0, 1}, {0, -1}, {1, 0}}

function onCreatePost()
	luaDebugMode = true
	reference = require(runHaxeCode('return Paths.modFolders("scripts/reference.lua");'):gsub('.lua', '')) -- IMPORTS THE MODULE
	reference.indexFromZero = true -- enabling this will make array access in references to start at [0] instead of [1] (as is usual in lua)
	
	mustHitSection = getPropertyFromClass('states.PlayState', 'SONG.notes[0].mustHitSection')
	
	mouse = reference.ref('mouse', 'flixel.FlxG')
	mouse.visible = true
	
	game = reference.ref('game') -- use '' or 'game' to reference the PlayState instance directly!
	camGame = reference.ref('camGame')
	scoreTxt = reference.ref('scoreTxt')
	speed = reference.ref('songSpeed')
	defaultSpeed = speed._value --use _value to get the value of a reference!
	-- or, like, you can use game.songSpeed, both work
	
	bf = reference.ref('boyfriend')
	bf.animOffsets.singLEFT[0] = bf.animOffsets.singLEFT[0] + 40
	bf.animOffsets.singDOWN[1] = bf.animOffsets.singDOWN[1] - 40
	bf.animOffsets.singUP[1] = bf.animOffsets.singUP[1] + 40
	bf.animOffsets.singRIGHT[0] = bf.animOffsets.singRIGHT[0] - 40
	runHaxeCode('game.boyfriend.clipRect = new flixel.math.FlxRect();')
	sscale = {x = bf.scale.x, y = bf.scale.y} -- we store bf's original scale here
	
	reference.ref('camZooming')._value = true
	
	-- this little square will rotate, move to the beat and react to notes
	makeLuaSprite('spr', '', bf.x, bf.y)
	addLuaSprite('spr', true)
	
	spriteTest = reference.ref('spr')
	--spriteTest.scale.set(200, 200)
	spriteTest.blend = 0
	spriteTest.alpha = .25
	
	onUpdateScore()
	
	local paths = reference.ref('', 'backend.Paths')
	spriteTest.loadGraphic(paths.image('icons/icon-bf'))
end

function noteBoom(d, focus)
	local dir = singDirs[d + 1]
	camGame.scroll.x = camGame.scroll.x + dir[1] * 15
	camGame.scroll.y = camGame.scroll.y + dir[2] * 15
	game.moveCamera(focus)
end

function goodNoteHit(i, dir, _, sus)
	if mustHitSection and not sus then noteBoom(dir, false) end
	
	local note = reference.ref('notes.members[' .. i .. ']')
	spriteTest.color = note.rgbShader.r -- colors the square to the note
	spriteTest.scale.set(300, 300)
	spriteTest.alpha = .9
	spriteTest.angle = spriteTest.angle + 25
end
function opponentNoteHit(_, dir, _, sus)
	if not mustHitSection then
		bf.playAnim(getProperty('singAnimations[' .. dir .. ']'), true)
		bf.holdTimer = 0
		
		if not sus then noteBoom(dir, true) end
	end
	
	spriteTest.alpha = spriteTest.alpha + .1
	spriteTest.setGraphicSize(spriteTest.width + 20)
	spriteTest.angle = spriteTest.angle + 10
end
function onSectionHit() -- lots of messy hot garbage
	spriteTest.alpha = spriteTest.alpha + .1
	spriteTest.setGraphicSize(spriteTest.width + 20)
end
function onBeatHit()
	glich = 1
	camGame.zoom = camGame.zoom + .01
	camGame.scroll.y = camGame.scroll.y - 15
	game.moveCamera(not mustHitSection)
	
	spriteTest.alpha = spriteTest.alpha + .1
	spriteTest.setGraphicSize(spriteTest.width + 20)
end
function onUpdateScore() scoreTxt.text = 'hi hello hello!! | Score: ' .. score .. (hits + misses > 0 and (' (' .. (math.floor(rating * 10000) / 100) .. '%)') or ' (NA)') .. ' | Misses: ' .. misses end
function onUpdatePost(e)
	local mousePress = mouse.pressed
	local targetScale = spriteTest.width + ((mousePress and 180 or 230) - spriteTest.width) * e * 9
	spriteTest.alpha = spriteTest.alpha + ((mousePress and .4 or .25) - spriteTest.alpha) * e * 9
	spriteTest.setGraphicSize(targetScale)
	spriteTest.angle = spriteTest.angle + e * 10
	
	if mousePress then
		spriteTest.x = spriteTest.x + mouse.deltaX
		spriteTest.y = spriteTest.y + mouse.deltaY
	end
	
	bf.x = defaultBoyfriendX + math.sin(getSongPosition() / 300) * 70 - 60
	bf.y = bf.x - 350
	bf.scale.x = sscale.x + math.sin(getSongPosition() / 200) * .2
	bf.scale.y = sscale.y + math.cos(getSongPosition() / 200) * .2
	
	bf.clipRect.width = (300 + math.sin(getSongPosition() / 400) * 50) / sscale.x
	bf.clipRect.height = (300 + math.cos(getSongPosition() / 300) * 50) / sscale.y
	bf.clipRect = bf.clipRect
	
	-- notes fun
	glich = glich - glich * e * 12
	speed._value = defaultSpeed + math.cos(getSongPosition() / 300) * .25 - .05 + glich * .25
	
	local fun = 90
	local t = os.clock()
	for i = 0, getProperty('notes.members.length') - 1 do
		local note = reference.ref('notes.members[' .. i .. ']')
		-- you can also do 'notes.members.i' like 'notes.members.0',
		-- but 'notes.members[0]' is the correct way to type it(and is actually gonna be much more performant in most cases here!!)
		-- this is the least laggy way to access arrays due to reasons..
		
		local sus = note.isSustainNote
		local base = (getSongPosition() - note.strumTime + (sus and (glich * crochet * -1) or 0)) / (fun - glich * 60)
		local lanem = (1.5 - note.noteData)
		
		local move = true
		if sus then
			if getSongPosition() >= note.strumTime then
				local clip = note.clipRect
				if (clip ~= nil and clip.y > 0) then
					lanem = lanem * (1 - clip.y / note.frameHeight)
				end
			end
			note.angle = math.cos(base) * 10 * lanem
		end
		note.x = note.x + (math.sin(base) * 20) * lanem
	end
	--debugPrint((os.clock() - t) .. ' / ' .. (1 / 90))
end