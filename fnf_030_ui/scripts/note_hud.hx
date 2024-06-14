import flixel.util.FlxColor;
import objects.PixelSplashShader;
import flixel.group.FlxTypedSpriteGroup;
using StringTools;

var skinSettings:Map = [ //if you need to modify the scale for other skins add it here
	'NOTE_assets-future' => { //you may do this by noteskin asset name
		scale: {x: 1.4, y: 1},
		offset: {x: -9, y: 0},
	},
	'chip' => { //or noteskin postfix (all lowercase)
		scale: {x: 1.37, y: 1},
		offset: {x: -8, y: 0},
	}
];

/*
TODO
- improve code
*/
var coverGroup:FlxTypedSpriteGroup<FlxSprite>;
var coverSplashGroup:FlxTypedSpriteGroup<FlxSprite>;
var prevFrame:Int = 0;
var rgbs:Array = []; //rgb shader references for hold covers
var holdCovers:Array = [];
var playHits:Array = [];
var playPresses:Array = [];
var flicker:Array = [];
var flickered:Bool = false;
var flickers:Bool = false;
var noteEffects:Bool = false;

function getSetting(setting, def) {
	var setting = game.callOnHScript('getScrSetting', [setting, def]);
	if (!Std.isOfType(setting, Bool)) return def;
	return setting;
}
function onCreatePost() {
	coverGroup = new FlxTypedSpriteGroup();
	coverGroup.cameras = [game.camHUD];
	game.add(coverGroup);
	coverSplashGroup = new FlxTypedSpriteGroup();
	coverSplashGroup.cameras = [game.camHUD];
	game.add(coverSplashGroup);
	
	var pixel:Float = (PlayState.isPixelStage ? PlayState.daPixelZoom : 1);
	var i = 0;
	flickers = getSetting('worstsettinginthewholehistoryofpsych072+modding', false);
	noteEffects = getSetting('pixeleffects', true) || !PlayState.isPixelStage;
	for (note in game.unspawnNotes) if (!noteEffects) note.noteSplashData.disabled = true;
	for (strum in game.strumLineNotes.members) {
		strum.animation.rename('confirm', 'hit');
		
		var cover = new FlxSprite();
		cover.frames = Paths.getSparrowAtlas('holdCoverShader');
		cover.antialiasing = ClientPrefs.data.antialiasing;
		cover.animation.addByPrefix('start', 'holdCoverStart', 24, false);
		cover.animation.addByPrefix('loop', 'holdCover0', 24, true);
		cover.animation.play('loop', true);
		cover.offset.set(106, 99);
		cover.visible = false;
		
		if (PlayState.isPixelStage) cover.offset.set(112, 102); //silly solution
		
		var superScale = {x: 1, y: 1};
		var postfix:String = getSkinPostfix(strum.graphic.key);
		if (!skinSettings.exists(postfix)) postfix = getFilename(strum.graphic.key);
		var config = skinSettings[postfix];
		if (config != null) {
			if (config.scale != null) {
				cover.scale.set(config.scale.x, config.scale.y);
				superScale.x = config.scale.x;
				superScale.y = config.scale.y;
			}
			if (config.offset != null) {
				cover.offset.x -= config.offset.x;
				cover.offset.y -= config.offset.y;
			}
		} else { //attempts to scale hold cover automatically
			var path:String = 'noteSkins/' + getFilename(strum.graphic.key);
			if (path != 'noteSkins/NOTE_assets') {
				var ref = new FlxSprite(300, 300);
				Paths.image(path);
				ref.frames = Paths.getSparrowAtlas(path);
				ref.animation.addByPrefix('hold', inArray(Note.colArray, strum.noteData) + ' hold piece');
				ref.animation.play('hold');
				if (PlayState.isPixelStage) ref.scale.x *= .7;
				ref.updateHitbox();
				superScale.x = Math.max(ref.width / 85, 1); //(50 is vanilla notes hold width!)
				ref.destroy();
				cover.scale.x = superScale.x;
				cover.offset.x -= (1 - superScale.x) * 16;
			}
		}
		
		var rgb = new PixelSplashShader();
		rgb.uBlocksize.value = [pixel / superScale.x, pixel / superScale.y];
		rgb.mult.value = [1];
		cover.shader = rgb;
		rgbs.push(rgb);
		holdCovers.push({cover: cover, strum: strum, hitTime: -1});
		coverSplashGroup.add(cover);
		
		i ++;
	}
	return;
}

function getFilename(key) {
	var s = key.replace('\\', '/');
	var pos:Int = s.lastIndexOf('/');
	var dot:Int = s.lastIndexOf('.');
	if (s.lastIndexOf('/') >= 0) return s.substring(pos + 1, (dot < 0 ? s.length : dot));
	else return '';
}
function getSkinPostfix(key) {
	var s = key.replace('\\', '/');
	var pos:Int = s.lastIndexOf('-');
	var dot:Int = s.lastIndexOf('.');
	if (pos > s.lastIndexOf('/')) return s.substring(pos + 1, (dot < 0 ? s.length : dot)).toLowerCase();
	else return '';
}

function inArray(array, pos) { //array access lags workaround???
    var i = 0;
	if (pos >= array.length) return null;
    for (item in array) {
        if (i == pos) { return item; }
        i ++;
    }
    return null;
}

function onSpawnNote(note) {
	if (note.isSustainNote) {
		var strum = getStrum(note.mustPress, note.noteData);
		note.multAlpha = 1;
		if (PlayState.isPixelStage) note.scale.x = 6 * .7;
		if (note.animation.name.endsWith('end')) note.scale.y = note.scale.x;
		note.updateHitbox();
		note.offsetX = (strum.width - note.width) * .5;
	}
}
function onKeyRelease(k) {
	var data = inArray(holdCovers, k + game.opponentStrums.length);
	if (data == null) return;
	var cover = data.cover;
	if (cover != null && cover.animation.name != 'end') cover.visible = false;
	return;
}
function popCover(note, strum, cover, rgb) {
	if (note.noteSplashData.disabled) return;
	var strum = cover.strum;
	if (strum != null && !strum.visible) return;
	
	cover.visible = true;
	if (rgb != null) {
		if (note.rgbShader.enabled) {
			rgb.r.value = note.shader.r.value;
			rgb.g.value = note.shader.g.value; //blue color channel is not used
		} else {
			rgb.r.value = rgb.g.value = [1, 1, 1];
		}
	}
}
function spawnCoverSparks(cover) {
	var coverSplash:FlxSprite = new FlxSprite(); //coverSplashGroup.recycle(FlxSprite); figure out why this doesnt work correctly later
	coverSplash.frames = Paths.getSparrowAtlas('holdCoverShader');
	coverSplash.setPosition(cover.x, cover.y);
	coverSplash.offset.x = cover.offset.x;
	coverSplash.offset.y = cover.offset.y;
	coverSplash.antialiasing = ClientPrefs.data.antialiasing;
	coverSplash.animation.addByPrefix('end', 'holdCoverEnd', 24, false);
	coverSplash.animation.play('end', true);
	coverSplash.shader = cover.shader;
	coverSplash.animation.finishCallback = () -> coverSplash.destroy();
	coverSplashGroup.add(coverSplash);
}
function coverLogic(note, end) {
	var data = note.noteData;
	if (note.mustPress) data += game.opponentStrums.length;
	
	var coverData = inArray(holdCovers, data);
	var rgb = inArray(rgbs, data);
	
	if (coverData == null) return;
	var cover = coverData.cover;
	
	var strum = getStrum(note.mustPress, note.noteData);
	if (strum == null) return;
	
	if (note.isSustainNote) {
		if (end) {
			if (!note.mustPress || game.cpuControlled) {
				strum.playAnim('static');
				cover.visible = false;
				var par = note.parent;
				if (par != null) for (child in par.tail) child.visible = false;
				if (note.mustPress && !note.noteSplashData.disabled) spawnCoverSparks(cover);
			} else {
				var hitTime:Float = note.strumTime;
				var delay:Float = (note.height / .45 / game.songSpeed / note.multSpeed); //pixels > ms
				new FlxTimer().start(delay * .001, () -> {
					if (strum != null && coverData.hitTime == hitTime && strum.animation.name == 'hit') {
						if (note != null && !note.noteSplashData.disabled) spawnCoverSparks(cover);
						cover.visible = false;
						strum.playAnim('pressed');
						strum.animation.finishCallback = null;
					}
				});
				coverData.hitTime = hitTime;
			}
			return;
		}
		if (!cover.visible || cover.animation.name == 'end') popCover(note, strum, cover, rgb);
	} else if (note.tail.length > 0) {
		cover.animation.play('start', true);
		cover.animation.finishCallback = () -> cover.animation.play('loop');
		popCover(note, strum, cover, rgb);
		if (flickers) {
			flickered = true;
			for (child in note.tail) {
				if (child.visible) {
					child.visible = false;
					flicker.push(child);
				}
			}
		}
	}
}
function getStrum(hit, data) return inArray((hit ? game.playerStrums : game.opponentStrums).members, data);
function opponentNoteHitPre(note) {
	coverLogic(note, note.animation.name.endsWith('end'));
	if (note.isSustainNote) {
		if (!note.noAnimation) {
			note.noAnimation = true;
			game.dad.holdTimer = 0;
		}
	} else {
		var strum = getStrum(false, note.noteData);
		if (strum != null) {
			strum.playAnim('hit', true);
			if (note.tail.length > 0) {
				strum.animation.finishCallback = () -> {
					strum.playAnim('hit', true);
					strum.animation.finishCallback = null;
				}
			}
		}
	}
}
function opponentNoteHit(note) {
	var strum = getStrum(false, note.noteData);
	strum.resetAnim = (note.isSustainNote ? 0 : Conductor.crochet * .001);
}
function makeGhostNote(note) {
	var ghost = new Note(note.strumTime, note.noteData, null, note.isSustainNote);
	ghost.noteType = 'MISSED_NOTE';
	ghost.multAlpha = note.multAlpha * .5;
	ghost.mustPress = note.mustPress;
	ghost.ignoreNote = true;
	ghost.blockHit = true;
	game.notes.add(ghost);
	ghost.rgbShader.r = int_desat(ghost.rgbShader.r, 0.5); //desaturate note
	ghost.rgbShader.g = int_desat(ghost.rgbShader.g, 0.5);
	ghost.rgbShader.b = int_desat(ghost.rgbShader.b, 0.5);
}
function goodNoteHitPre(note) {
	var strum = getStrum(true, note.noteData);
	if (note.isSustainNote) {
		if (!note.noAnimation) {
			note.noAnimation = true;
			game.dad.holdTimer = 0;
		}
	}
	return;
}
function goodNoteHit(note) {
	var strum = getStrum(true, note.noteData);
	if (!note.isSustainNote && strum != null) {
		playHits.push({strum: strum, hold: note.sustainLength > 0});
		for (press in playPresses) if (press.strum == strum) playPresses.remove(press);
		if (note.tail.length == 0 && !game.cpuControlled) playPresses.push({strum: strum, time: note.strumTime + Conductor.crochet});
		strum.resetAnim = (note.tail.length > 0 || (game.cpuControlled && note.tail.length == 0) ? (Conductor.crochet * .001) : 0);
	}
	coverLogic(note, note.animation.name.endsWith('end'));
	return;
}
function onUpdate() {
	if (!flickered) {
		while (flicker.length > 0) {
			var sus = flicker.shift();
			sus.visible = true;
		}
	}
	flickered = false;
}
function onUpdatePost(e) {
	while (playHits.length > 0) { //psych engine is a meanie
		var i = playHits.shift();
		var strum = i.strum;
		if (strum == null) continue;
		strum.playAnim('hit', true);
		if (i.hold) {
			strum.animation.finishCallback = () -> {
				strum.playAnim('hit', true);
				strum.animation.finishCallback = null;
			}
		}
	}
	for (press in playPresses) {
		if (Conductor.songPosition >= press.time) {
			var strum = press.strum;
			if (strum != null && strum.animation.name == 'hit' && strum.resetAnim <= 0) {
				strum.animation.finishCallback = null;
				strum.playAnim('pressed');
				strum.resetAnim = 0;
			}
			playPresses.remove(press);
		}
	}
	for (cover in holdCovers) {
		var instance = cover.cover;
		var strum = cover.strum;
		if (strum != null) {
			instance.setPosition(strum.x, strum.y);
			instance.alpha = (strum.alpha > 0 ? 1 : 0);
			if (strum.animation.name != 'hit') instance.visible = false;
		}
	}
	return;
}

//RGB FUNCTIONS CAUSE CUSTOMFLXCOLOR IS ASS
//(functions taken directly from FlxColor)
function int_desat(col, sat) { //except this one
	var hsv = rgb2hsv(int2rgb(col));
	hsv.saturation *= (1 - sat);
	var rgb = hsv2rgb(hsv);
	return FlxColor.fromRGBFloat(rgb.red, rgb.green, rgb.blue);
}
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