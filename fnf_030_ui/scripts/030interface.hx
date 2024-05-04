import Main;
import openfl.text.TextFormat;
import flixel.addons.transition.FlxTransitionableState;
import flixel.util.FlxColor;
import flixel.util.FlxStringUtil;
import flixel.text.FlxText;
import flixel.text.FlxTextBorderStyle;
var coverNames:Array = ['Purple', 'Blue', 'Green', 'Red'];
var holdCovers:Array = [];
var heldNotes:Array = [];
var inputs:Array = [];
var lerpHealth:Float = 1;
var iconScale:Float = 150;

var psychFps = null;
var memPeak = 0;

/*
TODO
- improve code
- custom pause menu?
*/

function onCreate() {
	var showRam = getModSetting('showram');
	FlxTransitionableState.skipNextTransOut = true; //custom fps display
	psychFps = Main.fpsVar.updateText;
	Main.fpsVar.defaultTextFormat = new TextFormat('_sans', 12, 0xffffff, false, false, false, '', '', 'left', 0, 0, 0, -4); //lol!
	Main.fpsVar.updateText = () -> {
        memPeak = Math.max(memPeak, Main.fpsVar.memoryMegas);
        Main.fpsVar.text = 'FPS: ' + Main.fpsVar.currentFPS + (showRam ? ('\nRAM: ' + FlxStringUtil.formatBytes(Main.fpsVar.memoryMegas).toLowerCase() + ' / ' + FlxStringUtil.formatBytes(memPeak).toLowerCase()) : '');
    }
}
function onDestroy():Void {
	Main.fpsVar.defaultTextFormat = new TextFormat('_sans', 14, 0xffffff, false, false, false, '', '', 'left', 0, 0, 0, 0);
	Main.fpsVar.updateText = psychFps;
}

function onCreatePost() {
	for (strum in game.playerStrums.members) heldNotes.push(null);
	for (note in game.unspawnNotes) {
		if (note.isSustainNote) {
			note.multAlpha = 1;
			note.noAnimation = true;
		}
	}
	
	game.healthBar.y = FlxG.height * (ClientPrefs.data.downscroll ? .1 : .9);
	game.healthBar.setColors(0xff0000, 0x66ff33);
	
	game.scoreTxt.fieldWidth = 0;
	game.scoreTxt.setPosition(game.healthBar.x + game.healthBar.width - 190, game.healthBar.y + 30);
	game.scoreTxt.setFormat(Paths.font('vcr.ttf'), 16, -1, 'right', FlxTextBorderStyle.OUTLINE, 0xff000000);
}
function onStartCountdown() {
	game.skipArrowStartTween = true;
	return Function_Continue;
}
function onCountdownStarted() {
	var m = (ClientPrefs.data.downScroll ? -1 : 1);
	var i = 0;
	for (strum in game.strumLineNotes.members) {
		var player = (i >= game.opponentStrums.length);
		strum.x = Note.swagWidth * (i % game.opponentStrums.length) + 45 + (player ? FlxG.width * .5 : 0);
		strum.y = (ClientPrefs.data.downScroll ? FlxG.height - 150 : 48);
		var name = coverNames[strum.noteData];
		var cover = new FlxSprite(strum.x, strum.y);
		cover.frames = Paths.getSparrowAtlas('holdCover' + name);
		cover.cameras = [game.camHUD];
		cover.antialiasing = ClientPrefs.data.antialiasing;
		cover.animation.addByPrefix('start', 'holdCoverStart' + name, 24, false);
		cover.animation.addByPrefix('loop', 'holdCover' + name, 24, true);
		cover.animation.addByPrefix('end', 'holdCoverEnd' + name, 24, false);
		cover.animation.play('loop', true);
		cover.offset.set(cover.width * .36, cover.height * .25);
		cover.visible = false;
		holdCovers.push(cover);
		game.add(cover);
		
		strum.y -= m * 10;
		strum.alpha = 0;
		FlxTween.tween(strum, {y: strum.y + m * 10, alpha: ((ClientPrefs.data.middleScroll && i < game.opponentStrums.length) ? 0.35 : 1)}, 1, {ease: FlxEase.circOut, startDelay: 0.5 + (0.2 * (i % game.opponentStrums.length))});
		i ++;
	}
	
	return Function_Continue;
}

function goodNoteHitPre(note) if (!note.isSustainNote) inputs.push(note.noteData);
function onKeyPress(k) {
	if (inputs.contains(k)) inputs.remove(k);
	else if (ClientPrefs.data.ghostTapping) {
		FlxG.sound.play(Paths.soundRandom('missnote', 1, 3), FlxG.random.float(0.1, 0.2));
		game.boyfriend.playAnim(game.singAnimations[k] + 'miss', true);
		game.health -= 0.05 * game.healthLoss;
		game.songScore -= 10;
		game.RecalculateRating(true);
	}
}
function onUpdateScore() game.scoreTxt.text = 'Score: ' + game.songScore;

function onKeyRelease(k) {
	var cover = holdCovers[k + game.opponentStrums.length];
	if (cover != null && cover.animation.curAnim.name != 'end') cover.visible = false;
	var note = heldNotes[k];
	if (note != null) {
		for (child in note.tail) {
			child.kill(child);
			game.notes.remove(child, true);
			child.destroy();
		}
		note.tail = [];
		heldNotes[note.noteData] = null;
	}
}
function coverLogic(note) {
	var data = note.noteData;
	if (note.mustPress) data += game.opponentStrums.length;
	var cover = holdCovers[data];
	if (note.isSustainNote) {
		cover.visible = true;
		if (!cover.visible || cover.animation.curAnim.name == 'end') cover.animation.play('start');
		if (StringTools.endsWith(note.animation.curAnim.name, 'holdend')) {
			cover.animation.play('end', true);
			if (!note.mustPress) {
				cover.visible = false;
				var strum = game.opponentStrums.members[note.noteData];
				if (strum != null) strum.playAnim('static');
			} else {
				var strum = game.playerStrums.members[note.noteData];
				if (strum != null) strum.playAnim('pressed');
			}
		}
	}
}
function opponentNoteHit(note) {
	coverLogic(note);
	var strum = game.opponentStrums.members[note.noteData];
	if (strum != null) strum.resetAnim = Conductor.crochet / 1000;
}
function makeGhostNote(note) {
	var ghost = new Note(note.strumTime, note.noteData, null, note.isSustainNote);
	ghost.multAlpha = note.multAlpha * .5;
	ghost.mustPress = note.mustPress;
	ghost.ignoreNote = true;
	ghost.blockHit = true;
	game.notes.add(ghost);
	ghost.rgbShader.r = int_desat(ghost.rgbShader.r, 0.5); //desaturate note
	ghost.rgbShader.g = int_desat(ghost.rgbShader.g, 0.5);
	ghost.rgbShader.b = int_desat(ghost.rgbShader.b, 0.5);
}
function goodNoteHit(note) {
	coverLogic(note);
	if (note.tail.length > 0) heldNotes[note.noteData] = note;
	if (!note.isSustainNote && (note.rating == 'bad' || note.rating == 'shit')) {
		makeGhostNote(note);
		game.combo = 0;
	}
}

function boom() {
	game.camGame.zoom += .015;
	game.camHUD.zoom += .03;
}
function onCountdownTick(_, t) {
	if (t % 4 == 0) boom();
	iconScale += 30;
	return Function_Continue;
}
function onBeatHit() {
	if (curBeat % 4 == 0) boom();
	iconScale += 30;
}

function onUpdate(e) {
	var mult:Float = 1 - Math.exp(-e * 7);
	game.camGame.zoom += (game.defaultCamZoom - game.camGame.zoom) * mult;
	game.camHUD.zoom += (1 - game.camHUD.zoom) * mult;
}
function onUpdatePost(e) {
	game.camZooming = false;
	for (strum in game.playerStrums.members) {
		if (strum.animation.curAnim.finished && strum.animation.curAnim.name == 'confirm') strum.playAnim('pressed');
	}
	for (cover in holdCovers) {
		if (cover.animation.curAnim.finished) {
			if (cover.animation.curAnim.name == 'end') cover.visible = false;
			else cover.animation.play('loop', true);
		}
	}
	var mult:Float = 1 - Math.exp(-e * 30);
	lerpHealth += (game.health - lerpHealth) * mult;
	game.healthBar.percent = lerpHealth * 50;
	
	game.iconP1.setGraphicSize(iconScale);
	game.iconP2.setGraphicSize(iconScale);
	game.updateIconsPosition();
	mult = 1 - Math.exp(-e * 18);
	iconScale += (150 - iconScale) * mult;
}

//RGB FUNCTIONS CAUSE CUSTOMFLXCOLOR IS ASS
//(functions taken directly from FlxColor)
function int_desat(col, sat) { //except this one
	var hsv = rgb2hsv(int2rgb(col));
	hsv.saturation *= (1 - sat);
	var rgb = hsv2rgb(hsv);
	return FlxColor.fromRGBFloat(rgb.red, rgb.green, rgb.blue);
}
function int2rgb(col) return {red: (col >> 16) & 0xff, green: (col >> 8) & 0xff, blue: col & 0xff}; //and this one
function rgb2hsv(col) {
	var hueRad = Math.atan2(Math.sqrt(3) * (col.green - col.blue), 2 * col.red - col.green - col.blue);
	var hue:Float = 0;
	if (hueRad != 0) hue = 180 / Math.PI * hueRad;
	hue = hue < 0 ? hue + 360 : hue;
	var bright:Float = Math.max(col.red, Math.max(col.green, col.blue));
	var sat:Float = (bright - Math.min(col.red, Math.min(col.green, col.blue))) / bright;
	return {hue: hue, saturation: sat, brightness: bright};
}
function hsv2rgb(col) {
	var chroma = col.brightness * col.saturation;
	var match = col.brightness - chroma;
	
	var hue:Float = col.hue % 360;
	var hueD = hue / 60;
	var mid = chroma * (1 - Math.abs(hueD % 2 - 1)) + match;
	chroma += match;
	
	chroma /= 255; //joy emoji
	mid /= 255;
	match /= 255;

	switch (Std.int(hueD)) {
		case 0: return {red: chroma, green: mid, blue: match};
		case 1: return {red: mid, green: chroma, blue: match};
		case 2: return {red: match, green: chroma, blue: mid};
		case 3: return {red: match, green: mid, blue: chroma};
		case 4: return {red: mid, green: match, blue: chroma};
		case 5: return {red: chroma, green: match, blue: mid};
	}
}