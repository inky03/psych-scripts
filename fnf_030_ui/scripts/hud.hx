import Std;
import Main;
import backend.Language;
import backend.Difficulty;
import substates.PauseSubState;
import openfl.text.TextFormat;
import flixel.text.FlxText;
import flixel.text.FlxTextBorderStyle;
import flixel.addons.transition.FlxTransitionableState;
import flixel.math.FlxBasePoint;
import flixel.util.FlxStringUtil;
import flixel.group.FlxTypedSpriteGroup;

var forceHBColors:Bool = false;
var lerpHealth:Float = 1;
var cameraBopMultiplier:Float = 1;
var combo:Int = 0;
var doMiss:Bool = false;
var missRating:Bool = false;
var skipTween:Bool = false;
var comboGroup:FlxTypedSpriteGroup<FlxSprite>;
var vwooshGroup:FlxTypedSpriteGroup<FlxSprite>;

var oldTitle = 'Friday Night Funkin\': Psych Engine';
var showRam:Bool = false;
var psychFps = null;
var memPeak = 0;

var fakeTrayY = 0;
var fakeTrayAlpha = 0;
var trayLerpY = 0;
var trayAlphaTarget = 0;
var oldVolume:Float = 0;
var soundTray = FlxG.game.soundTray;

//constants
var c_PIXELARTSCALE:Float = 6;

function getSetting(setting, def) {
	var setting = game.callOnHScript('getScrSetting', [setting, def]);
	return setting;
}
function onCreate() {
	vwooshGroup = new FlxTypedSpriteGroup();
	comboGroup = new FlxTypedSpriteGroup();
	game.add(comboGroup);
	
	doMiss = getSetting('missbutlikeactually', false);
	missRating = getSetting('miss', false);
	showRam = getSetting('showram', false);
	
	for (snd in ['Volup', 'Voldown', 'VolMAX']) Paths.sound('soundtray/' + snd);
	if (soundTray != null && soundTray.y != null) { //yea man!??
		fakeTrayY = soundTray.y;
		fakeTrayAlpha = soundTray.alpha;
	}
	oldVolume = FlxG.sound.volume;
	
	var appTitle:String = FlxG.stage.window.title;
	if (StringTools.trim(appTitle) != '' && appTitle != 'Friday Night Funkin\'') oldTitle = appTitle;
	FlxG.stage.window.title = 'Friday Night Funkin\'';
	
	FlxTransitionableState.skipNextTransOut = true;
	Main.fpsVar.defaultTextFormat = new TextFormat('_sans', 12, 0xffffff, false, false, false, '', '', 'left', 0, 0, 0, -4); //lol!
	game.updateIconsScale = () -> {};
	
	psychFps = Main.fpsVar.updateText; // custom fps display
	Main.fpsVar.updateText = updateFPS;
	
	game.subStateOpened.add(hookPauseMenu);
	game.subStateClosed.add(hookPauseExit);
	FlxG.game.addEventListener('enterFrame', updateSoundTray); // soundtray override
	
	var last:String = PlayState.storyPlaylist.pop();
	if (last == '_FRESTART') {
		game.skipArrowStartTween = true;
	} else if (last != null) {
		PlayState.storyPlaylist.push(last);
	}
}
function addPauseNotes() {
	vwooshGroup.cameras = noteGroup.cameras;
	
	game.insert(game.members.indexOf(game.noteGroup) + 1, vwooshGroup);
	for (plug in FlxG.plugins.list) {
		if (Std.isOfType(plug, Note)) {
			vwooshGroup.add(plug);
			FlxTween.tween(plug, {y: plug.y + FlxG.height * (ClientPrefs.data.downScroll ? -1 : 1)}, .5, {ease: FlxEase.expoIn, onComplete: (_) -> {
				plug.kill();
				vwooshGroup.remove(plug, true);
				plug.destroy();
			}});
		}
	}
	FlxG.plugins.removeAllByType(Note);
}
function savePauseNotes() {
	while (game.notes.members.length > 0) {
		var note:Note = game.notes.members.shift();
		if (note != null) {
			var prevScale:FlxPoint = FlxBasePoint.get(note.scale.x, note.scale.y);
			var prevOffset:FlxPoint = FlxBasePoint.get(note.offset.x, note.offset.y);
			note.reloadNote();
			note.scale.set(prevScale.x, prevScale.y);
			note.offset.set(prevOffset.x, prevOffset.y);
			FlxG.plugins.addPlugin(note);
		}
	}
}

var artistText:FlxText;
var artistTween:FlxTimer;
var songRestarting:Bool = false;
function hookPauseMenu(subState:FlxSubState) {
	if (!Std.isOfType(subState, PauseSubState)) return;
	
	try {
		var artistString:String = 'Artist: ' + (PlayState.SONG.artist ?? 'Unknown');
		artistText = new FlxText(20, 0, 0, artistString, 32);
		artistText.setFormat(Paths.font('vcr.ttf'), 32);
		artistText.x = FlxG.width - artistText.width - 20;
		artistText.scrollFactor.set();
		artistText.updateHitbox();
		
		var i:Int = 0;
		var diffString:String = Difficulty.getString();
		for (member in subState.members) {
			if (!Std.isOfType(member, FlxText)) continue;
			
			var recalc:Bool = true;
			switch (member.text) {
				case Language.getPhrase('Charting Mode').toUpperCase():
					continue;
				case PlayState.SONG.song:
					subState.insert(subState.members.indexOf(member) + 1, artistText);
				case diffString.toUpperCase():
					member.text = 'Difficulty: ' + diffString;
				default:
					recalcX = false;
			}
			if (recalc)
				member.x = FlxG.width - member.width - 20;
			member.y = 15 + 32 * i;
			
			i += 1;
			member.alpha = 1;
			FlxTween.cancelTweensOf(member);
			FlxTween.tween(member, {y: member.y + 5}, 1.8, {ease: FlxEase.quartOut, startDelay: i * .1});
		}
		
		subState.menuItemsOG.insert(subState.menuItemsOG.indexOf('Restart Song'), 'FRESTART');
		subState.menuItemsOG.remove('Restart Song');
		
		subState.menuItemsOG.remove('Toggle Practice Mode');
		if (PlayState.chartingMode || !game.practiceMode)
			subState.menuItemsOG.insert(3, 'Toggle Practice Mode');
		subState.deleteSkipTimeText();
		subState.regenMenu();
		for (item in subState.grpMenuShit) {
			if (item.text == 'Toggle Practice Mode')
				item.text = 'Enable Practice Mode';
			if (item.text == 'FRESTART')
				item.text = 'Restart Song';
		}
		
		pauseCharterTween();
		
		FlxG.signals.postUpdate.add(hookPauseUpdate);
	} catch (e:Dynamic) {
		debugPrint('FAILED TO HOOK: ' + e, 0xffff0000);
	}
}
function pauseCharterTween(?_) {
	var charterString:String = 'Charter: ' + (PlayState.SONG.charter ?? 'Unknown');
	artistTween = FlxTween.tween(artistText, {alpha: 0}, .75, {ease: FlxEase.quartOut, startDelay: 15, onComplete: (_) -> {
		artistText.text = charterString;
		artistText.x = FlxG.width - artistText.width - 20;
		FlxTween.tween(artistText, {alpha: 1}, .75, {ease: FlxEase.quartOut, onComplete: pauseArtistTween});
	}});
}
function pauseArtistTween(?_) {
	var artistString:String = 'Artist: ' + (PlayState.SONG.artist ?? 'Unknown');
	artistTween = FlxTween.tween(artistText, {alpha: 0}, .75, {ease: FlxEase.quartOut, startDelay: 15, onComplete: (_) -> {
		artistText.text = artistString;
		artistText.x = FlxG.width - artistText.width - 20;
		FlxTween.tween(artistText, {alpha: 1}, .75, {ease: FlxEase.quartOut, onComplete: pauseCharterTween});
	}});
}
function hookPauseUpdate() {
	var subState:FlxSubState = game.subState;
	if (!Std.isOfType(subState, PauseSubState)) return;
	
	try {
		if (controls.ACCEPT && (subState.cantUnpause <= 0 || !controls.controllerMode)) {
			switch (subState.menuItems[subState.curSelected]) {
				case 'FRESTART':
					restartSong();
				case 'Toggle Practice Mode':
					if (!PlayState.chartingMode) {
						if (!game.startingSong)
							subState.menuItemsOG.insert(3, 'Skip Time');
						subState.menuItemsOG.remove('Toggle Practice Mode');
						subState.regenMenu();
					}
			}
			for (item in subState.grpMenuShit) {
				if (item.text == 'Toggle Practice Mode')
					item.text = 'Enable Practice Mode';
				if (item.text == 'FRESTART')
					item.text = 'Restart Song';
			}
		}
		for (item in subState.grpMenuShit) {
			item.distancePerItem.x = 25;
			item.distancePerItem.y = 157.5;
			
			item.isMenuItem = false;
			var lerpVal:Float = Math.exp(-FlxG.elapsed * 20);
			if (item.changeX) item.x = FlxMath.lerp((item.targetY * item.distancePerItem.x) + item.startPosition.x, item.x, lerpVal);
			if (item.changeY) item.y = FlxMath.lerp((item.targetY * item.distancePerItem.y) + item.startPosition.y + 30, item.y, lerpVal);
		}
	} catch (e:Dynamic) {
		debugPrint('FAILED TO HOOK: ' + e, 0xffff0000);
	}
}
function hookPauseExit(subState:FlxSubState) {
	if (!Std.isOfType(subState, PauseSubState)) return;
	
	try {
		if (artistTween != null) {
			artistTween.cancel();
			artistTween.destroy();
			artistTween = null;
		}
		artistText = null;
		FlxG.signals.postUpdate.remove(hookPauseUpdate);
	} catch (e:Dynamic) {
		debugPrint('FAILED TO HOOK: ' + e, 0xffff0000);
	}
}

function restartSong() {
	songRestarting = true;
	PlayState.prevCamFollow = camFollow;
	PlayState.storyPlaylist.push('_FRESTART');
	camFollow.setPosition(FlxG.camera.scroll.x + FlxG.width * .5, FlxG.camera.scroll.y + FlxG.height * .5);
	
	FlxTransitionableState.skipNextTransIn = true;
	PauseSubState.restartSong();
}

function updateFPS() {
	memPeak = Math.max(memPeak, Main.fpsVar.memoryMegas);
	Main.fpsVar.text = 'FPS: ' + Main.fpsVar.currentFPS + (showRam ? ('\nRAM: ' + FlxStringUtil.formatBytes(Main.fpsVar.memoryMegas).toLowerCase() + ' / ' + FlxStringUtil.formatBytes(memPeak).toLowerCase()) : '');
}
function updateSoundTray() {
	//cant modify soundTray.show (or i couldnt get it to work), so override here :(
	if (soundTray != null && soundTray.active && soundTray.visible) {
		if (soundTray._timer > 0) {
			trayAlphaTarget = 1;
			trayLerpY = 10;
		} else {
			trayLerpY = -soundTray.height - 10;
			trayAlphaTarget = 0;
		}
		fakeTrayY = FlxMath.lerp(fakeTrayY, trayLerpY, .1 * FlxG.elapsed * 60);
		fakeTrayAlpha = FlxMath.lerp(fakeTrayAlpha, trayAlphaTarget, .25 * FlxG.elapsed * 60);
		soundTray.y = fakeTrayY;
		soundTray.alpha = fakeTrayAlpha;
		var globalVolume:Int = (FlxG.sound.muted ? 0 : Math.round(FlxG.sound.volume * 10));
		var i = 1;
		for (bar in soundTray._bars) {
			bar.visible = (i == globalVolume); //so the bars dont stack up lmao!
			i += 1;
		}
		//check volume change
		if (FlxG.sound.volume != oldVolume || (FlxG.keys.anyJustPressed(FlxG.sound.volumeUpKeys) && FlxG.sound.volume >= 1)) {
			if (oldVolume > FlxG.sound.volume) FlxG.sound.play(Paths.sound('soundtray/Voldown'));
			else FlxG.sound.play(Paths.sound('soundtray/Vol' + (FlxG.sound.volume < 1 ? 'up' : 'MAX')));
			oldVolume = FlxG.sound.volume;
		}
	}
}

function onDestroy() {
	if (songRestarting)
		savePauseNotes();
	
	Main.fpsVar.updateText = psychFps;
	FlxG.stage.window.title = oldTitle;
	FlxG.game.removeEventListener('enterFrame', updateSoundTray);
	Main.fpsVar.defaultTextFormat = new TextFormat('_sans', 14, 0xffffff, false, false, false, '', '', 'left', 0, 0, 0, 0);
	return Function_Continue;
}

function onUpdateScore()
	game.scoreTxt.text = (game.cpuControlled ? getPhrase('botplay_vanilla', 'Bot Play Enabled', []) : getPhrase('score_text_vanilla', 'Score: {1}', [game.songScore]));

function onCreatePost() {
	addPauseNotes();
	comboGroup.cameras = [game.camHUD];
	
	game.healthBar.y = FlxG.height * (ClientPrefs.data.downScroll ? .1 : .9);
	game.healthBar.setColors(0xff0000, 0x66ff33);
	game.iconP1.y = game.healthBar.y - (game.iconP1.height / 2);
	game.iconP2.y = game.healthBar.y - (game.iconP2.height / 2);
	
	game.scoreTxt.fieldWidth = 0;
	game.scoreTxt.setPosition(game.healthBar.x + game.healthBar.width - 190, game.healthBar.y + 30);
	game.scoreTxt.setFormat(Paths.font('vcr.ttf'), 16, -1, 'right', FlxTextBorderStyle.OUTLINE, 0xff000000);
	game.scoreTxt.antialiasing = ClientPrefs.data.antialiasing;
	game.botplayTxt.kill();
	
	game.healthBar.y = FlxG.height * (ClientPrefs.data.downScroll ? .1 : .9);
	game.healthBar.leftBar.color = 0xff0000;
	game.healthBar.rightBar.color = 0x66ff33;
	oldifyBar(game.healthBar);
	oldifyBar(game.timeBar);
	game.timeBar.rightBar.color = 0x000080;
	//game.timeBar.leftBar.color = 0x66ffff;
	game.timeBar.bg.loadGraphic(Paths.image('timeBar'));
	game.timeTxt.size = game.scoreTxt.size + 6;
	game.timeTxt.y = game.timeBar.y + (game.timeBar.height - game.timeTxt.height) * .5;
	game.healthBar.barOffset.set(4, 4);
	
	game.uiGroup.remove(game.scoreTxt, true);
	game.uiGroup.insert(game.uiGroup.members.indexOf(game.healthBar), game.scoreTxt);
	game.uiGroup.remove(game.iconP1, true);
	game.uiGroup.insert(game.uiGroup.members.indexOf(game.iconP2) + 1, game.iconP1);
	
	return Function_Continue;
}

function oldifyBar(bar) {
	bar.remove(bar.leftBar);
	bar.remove(bar.rightBar);
	var what = bar.members.indexOf(bar.bg) + 1;
	bar.insert(what, bar.leftBar);
	bar.insert(what, bar.rightBar);
	bar.barWidth = bar.bg.width - 8;
	bar.barHeight = bar.bg.height - 8;
	bar.barOffset.set(4, 4);
	bar.updateBar();
}

function onStartCountdown() {
	skipTween = game.skipArrowStartTween;
	game.skipArrowStartTween = true;
	return Function_Continue;
}

function onCountdownStarted() {
	game.remove(game.uiGroup);
	game.insert(0, game.uiGroup);
	var m:Int = (ClientPrefs.data.downScroll ? -1 : 1);
	var i:Int = 0;
	for (strum in game.strumLineNotes.members) {
		var player = (i >= game.opponentStrums.length);
		if (!ClientPrefs.data.middleScroll) strum.x = Note.swagWidth * (i % game.opponentStrums.length) + 45 + (player ? FlxG.width * .5 : 0);
		strum.y = (ClientPrefs.data.downScroll ? FlxG.height - 150 : 48);
		
		if (!skipTween && PlayState.startOnTime <= 0 && (player || ClientPrefs.data.opponentStrums)) {
			strum.y -= m * 10;
			strum.alpha = 0;
			FlxTween.tween(strum, {y: strum.y + m * 10, alpha: ((ClientPrefs.data.middleScroll && i < game.opponentStrums.length) ? 0.35 : 1)}, 1, {ease: FlxEase.circOut, startDelay: 0.5 + (0.2 * (i % game.opponentStrums.length))});
		}
		
		i += 1; //++ isnt implemented sobbing rn
	}
	return Function_Continue;
}

function boom() {
	if (game.camZoomingDecay > 0 && FlxG.camera.zoom < 1.35 * FlxCamera.defaultZoom && ClientPrefs.data.camZooms) {
		FlxG.camera.zoom = game.defaultCamZoom * (1 + .015 * game.camZoomingMult);
		game.camHUD.zoom = .03 + 1;
	}
}
function onCountdownTick(_, t) {
	if (t % 4 == 0) boom();
	
	game.iconP1.setGraphicSize(game.iconP1.width * 1.2);
	game.iconP2.setGraphicSize(game.iconP2.width * 1.2);
	game.iconP1.updateHitbox();
	game.iconP2.updateHitbox();
	
	for (spr in [game.countdownReady, game.countdownSet, game.countdownGo]) {
		if (spr == null) continue;
		
		game.remove(spr, true);
		game.insert(game.members.indexOf(game.noteGroup) + 1, spr);
	}
}
function onSectionHit() boom();
function onUpdate(e) {
	if (FlxG.keys.justPressed.NINE) {
		if (game.iconP1.char == 'bf-old') {
			game.iconP1.changeIcon(game.boyfriend.healthIcon);
			game.iconP1.scale.set(1, 1);
			game.iconP1.updateHitbox();
		} else {
			game.iconP1.changeIcon('bf-old');
		}
	}
	if (game.camZoomingDecay > 0) {
		var hudZoomingMult:Float = (getVar('hudZoomingMult') != null ? getVar('hudZoomingMult') : 1);
		FlxG.camera.zoom = FlxMath.lerp(game.defaultCamZoom, FlxG.camera.zoom, 0.95);
		game.camHUD.zoom = FlxMath.lerp(1, game.camHUD.zoom, 0.95) * hudZoomingMult;
	}
	return;
}
function coolLerp(base, target, ratio) { //funkin mathutil
	return base + (ratio * FlxG.elapsed / (1 / 60)) * (target - base);
}
function onUpdatePost(e) {
	game.camZooming = false;
	if (game.cameraTwn?._properties?.zoom != null)
		game.defaultCamZoom = game.cameraTwn._properties.zoom;
	
	var lerp:Float = .15 * Math.exp(-e / 60);
	lerpHealth = FlxMath.lerp(lerpHealth, Math.min(game.health, 2), lerp);
	game.healthBar.percent = lerpHealth * 50;
	
	game.iconP1.setGraphicSize(coolLerp(game.iconP1.width, 150, lerp));
	game.iconP2.setGraphicSize(coolLerp(game.iconP2.width, 150, lerp));
	game.iconP1.updateHitbox();
	game.iconP2.updateHitbox();
	game.updateIconsPosition();
	
	game.healthBar.percent = Math.round(game.healthBar.percent);
	
	if (forceHBColors && (game.healthBar.leftBar.color != 0xff0000 || game.healthBar.rightBar.color != 0x66ff33))
		game.healthBar.setColors(0xff0000, 0x66ff33);
	return;
}
function onEvent(event, v1, v2) {
	game.healthBar.setColors(0xff0000, 0x66ff33);
	return;
}

//ratings stuff
function goodNoteHit(note) {
	if (!note.isSustainNote) {
		for (c in game.comboGroup) c.visible = false;
		combo = game.combo;
		popUpScore(note.rating);
	}
	return;
}
function noteMissPress(d) {
	if (!doMiss) return Function_Continue;
	var wipe:Bool = false;
	if (missRating) wipe = displayRating('miss');
	if (combo >= 10) displayCombo(0);
	if (wipe && !ClientPrefs.data.comboStacking) wipeRatings();
	combo = 0;
	return;
}
function noteMiss(note) {
	var wipe:Bool = false;
	if (missRating && !note.isSustainNote) wipe = displayRating('miss');
	if (combo >= 10) displayCombo(0);
	if (wipe && !ClientPrefs.data.comboStacking) wipeRatings();
	combo = 0;
	return;
}
function popUpScore(rating) {
	if (ClientPrefs.data.hideHud) return;
	if (!ClientPrefs.data.comboStacking) wipeRatings();
	displayRating(rating);
	if (combo >= 10 || combo == 0) displayCombo(combo);
}
function wipeRatings() {
	for (spr in comboGroup) {
		spr.destroy();
		comboGroup.remove(spr);
	}
}
function displayRating(rating) {
	if (!game.showRating) return;
	var ratingPath:String = rating;
	var isPixel:Bool = PlayState.isPixelStage;
	if (isPixel) ratingPath = 'pixelUI/' + ratingPath + '-pixel';
	var rating:FlxSprite = new FlxSprite(0, 0).loadGraphic(Paths.image(ratingPath));
	rating.scrollFactor.set(.2, .2);
	rating.setPosition(FlxG.width * 0.474, FlxG.camera.height * 0.45 - 60);
	rating.acceleration.y = 550;
	rating.velocity.x = -FlxG.random.int(0, 10);
	rating.velocity.y = -FlxG.random.int(140, 175);
	comboGroup.add(rating);
	if (isPixel) rating.setGraphicSize(rating.width * c_PIXELARTSCALE * .7);
	else rating.setGraphicSize(rating.width * .65);
	rating.updateHitbox();
	rating.x -= rating.width * .5;
	rating.y -= rating.height * .5;
	rating.antialiasing = isPixel ? false : ClientPrefs.data.antialiasing;
	FlxTween.tween(rating, {alpha: 0}, 0.2, {onComplete: () -> {
		comboGroup.remove(rating, true);
		rating.destroy();
	}, startDelay: Conductor.crochet * .001});
	return true;
}
function displayCombo(combo) {
	if (!game.showComboNum) return;
	var isPixel:Bool = PlayState.isPixelStage;
	var pixelShitPart1:String = isPixel ? 'pixelUI/' : '';
	var pixelShitPart2:String = isPixel ? '-pixel' : '';
	var pos = {x: FlxG.width * .507, y: FlxG.camera.height * .44};
	
	if (game.showCombo) {
		var comboSpr:FlxSprite = new FlxSprite().loadGraphic(Paths.image(pixelShitPart1 + 'combo' + pixelShitPart2));
		comboSpr.setPosition(pos.x, pos.y);
		comboSpr.acceleration.y = 600;
		comboSpr.velocity.x = FlxG.random.int(1, 10);
		comboSpr.velocity.y = -150;
		comboGroup.add(comboSpr);
		if (isPixel) comboSpr.setGraphicSize(comboSpr.width * c_PIXELARTSCALE * .7);
		else comboSpr.setGraphicSize(comboSpr.width * .65);
		comboSpr.updateHitbox();
		comboSpr.antialiasing = isPixel ? false : ClientPrefs.data.antialiasing;
		FlxTween.tween(comboSpr, {alpha: 0}, 0.2, {onComplete: () -> {
			comboGroup.remove(comboSpr, true);
			comboSpr.destroy();
		}, startDelay: Conductor.crochet * .001});
	}
	
	var separatedScore:Array = [];
	var tempCombo:Int = combo;
	while (tempCombo >= 1) {
		separatedScore.push(tempCombo % 10);
		tempCombo = tempCombo / 10 | 0;
	}
	while (separatedScore.length < 3) separatedScore.push(0);
	var daLoop = 1;
	for (n in separatedScore) {
		var numScore:FlxSprite = new FlxSprite(pos.x - 36 * daLoop - 65, pos.y).loadGraphic(Paths.image(pixelShitPart1 + 'num' + n + pixelShitPart2));
		if (isPixel) numScore.setGraphicSize(numScore.width * c_PIXELARTSCALE * .7);
		else numScore.setGraphicSize(numScore.width * .45);
		numScore.updateHitbox();
		numScore.antialiasing = isPixel ? false : ClientPrefs.data.antialiasing;
		numScore.acceleration.y = FlxG.random.int(250, 300);
		numScore.velocity.x = FlxG.random.float(-5, 5);
		numScore.velocity.y = -FlxG.random.int(130, 150);
		FlxTween.tween(numScore, {alpha: 0}, 0.2, {onComplete: () -> {
			comboGroup.remove(numScore, true);
			numScore.destroy();
		}, startDelay: Conductor.crochet * .002});
		comboGroup.add(numScore);
		daLoop += 1;
	}
	return combo;
}

function getPhrase(key, def, values) { //note: move to util
	if (Language != null) {
		return Language.getPhrase(key, def, values);
	} else {
		var i:Int = 1;
		for (val in values) {
			def = StringTools.replace(def, '{' + i + '}', val);
			i += 1;
		}
		return def;
	}
}