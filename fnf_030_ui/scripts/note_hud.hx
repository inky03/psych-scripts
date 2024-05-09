import flixel.util.FlxColor;
import objects.PixelSplashShader;

/*
TODO
- improve code
- custom pause menu?
- shader for hold note covers (DONE!)
- 0.3.0 score system? (make a gameplay script and move the hold stuff there)
- 0.3.0 ratings (which are also in camera)
*/
var prevFrame:Int = 0;
var rgbs:Array = []; //rgb shader references for hold covers
var holdCovers:Array = [];

function onCreatePost() {
	for (note in game.unspawnNotes) {
		if (note.isSustainNote) {
			note.multAlpha = 1;
			note.noAnimation = true;
		}
	}
	var pixel:Float = (PlayState.isPixelStage ? PlayState.daPixelZoom : 1);
	var i = 0;
	for (strum in game.strumLineNotes.members) {
		var cover = new FlxSprite();
		cover.frames = Paths.getSparrowAtlas('holdCoverShader');
		cover.cameras = [game.camHUD];
		cover.antialiasing = ClientPrefs.data.antialiasing;
		cover.animation.addByPrefix('start', 'holdCoverStart', 24, false);
		cover.animation.addByPrefix('loop', 'holdCover0', 24, true);
		cover.animation.addByPrefix('end', 'holdCoverEnd', 24, false);
		cover.animation.play('loop', true);
		cover.offset.set(106, 100);
		cover.visible = false;
		
		var rgb = new PixelSplashShader();
		rgb.uBlocksize.value = [pixel, pixel];
		cover.shader = rgb;
		rgbs.push(rgb);
		holdCovers.push({cover: cover, strum: strum});
		game.add(cover);
		
		i ++;
	}
	return Function_Continue;
}

function onUpdateScore() game.scoreTxt.text = 'Score: ' + game.songScore;

function onKeyRelease(k) {
	var cover = holdCovers[k + game.opponentStrums.length].cover;
	if (cover != null && cover.animation.curAnim.name != 'end') cover.visible = false;
	return Function_Continue;
}
function popCover(note, strum, cover, rgb) {
	var strum = cover.strum;
	if (strum != null && !strum.visible) return;
	
	cover.visible = true;
	if (rgb != null) {
		rgb.r.value = int2rgbfloat(note.rgbShader.r);
		rgb.g.value = int2rgbfloat(note.rgbShader.g); //blue color channel is not used
	}
	cover.animation.play('start', true);
}
function coverLogic(note) {
	if (note.noteSplashData.disabled) return;
	
	var data = note.noteData;
	if (note.mustPress) data += game.opponentStrums.length;
	
	var cover = holdCovers[data];
	var rgb = rgbs[data];
	
	if (cover != null) {
		cover = cover.cover;
		if (note.isSustainNote) {
			var strum = (note.mustPress ? game.playerStrums.members[note.noteData] : game.opponentStrums.members[note.noteData]);
			if (!cover.visible || cover.animation.curAnim.name == 'end') popCover(note, strum, cover, rgb);
			if (StringTools.endsWith(note.animation.curAnim.name, 'holdend')) {
				cover.animation.play('end', true);
				if (!note.mustPress) {
					cover.visible = false;
					if (strum != null) strum.playAnim('static');
				} else if (strum != null) strum.playAnim('pressed');
			}
		} else if (note.sustainLength > 0) {
			var strum = (note.mustPress ? game.playerStrums.members[note.noteData] : game.opponentStrums.members[note.noteData]);
			popCover(note, strum, cover, rgb);
		}
	}
}
function opponentNoteHit(note) {
	coverLogic(note);
	if (note.isSustainNote) game.dad.holdTimer = 0;
	var strum = game.opponentStrums.members[note.noteData];
	if (strum != null) strum.resetAnim = (note.sustainLength > 0 ? note.sustainLength : Conductor.crochet) / 1000;
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
	if (note.isSustainNote) game.boyfriend.holdTimer = 0;
	else {
		var strum = game.playerStrums.members[note.noteData];
		if (strum != null) strum.resetAnim = (note.sustainLength > 0 ? note.sustainLength / 1000 : 0);
	}
	return Function_Continue;
}
function onUpdatePost(e) {
	for (cover in holdCovers) {
		var instance = cover.cover;
		var strum = cover.strum;
		if (strum != null) {
			instance.setPosition(strum.x, strum.y);
			instance.alpha = (strum.alpha > 0 ? 1 : 0);
		}
		if (instance.animation.curAnim.finished) {
			if (instance.animation.curAnim.name == 'end') instance.visible = false;
			else instance.animation.play('loop', true);
		}
	}
	var i = 0;
	for (strum in game.playerStrums.members) {
		if (strum.animation.curAnim.finished && strum.animation.curAnim.name == 'confirm') {
			strum.playAnim('pressed');
		}
	}
	return Function_Continue;
}

//RGB FUNCTIONS CAUSE CUSTOMFLXCOLOR IS ASS
//(functions taken directly from FlxColor)
function int_desat(col, sat) { //except this one
	var hsv = rgb2hsv(int2rgb(col));
	hsv.saturation *= (1 - sat);
	var rgb = hsv2rgb(hsv);
	return FlxColor.fromRGBFloat(rgb.red, rgb.green, rgb.blue);
}
function int2rgbfloat(col) return [((col >> 16) & 0xff) / 255, ((col >> 8) & 0xff) / 255, (col & 0xff) / 255]; //or this one (lol)
function int2rgb(col) return {red: (col >> 16) & 0xff, green: (col >> 8) & 0xff, blue: col & 0xff}; //or this one
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