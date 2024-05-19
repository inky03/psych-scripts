import Main;
import lime.app.Application;
import openfl.text.TextFormat;
import flixel.text.FlxText;
import flixel.text.FlxTextBorderStyle;
import flixel.addons.transition.FlxTransitionableState;
import flixel.util.FlxStringUtil;
import flixel.group.FlxTypedSpriteGroup;

var forceHBColors:Bool = false;
var lerpHealth:Float = 1;
var iconScale:Float = 150;
var cameraBopMultiplier:Float = 1;
var combo:Int = 0;
var missRating:Bool = false;
var noteEffects:Bool = false;
var skipTween:Bool = false;
var comboGroup:FlxTypedSpriteGroup<FlxSprite>;

var oldTitle = 'Friday Night Funkin\': Psych Engine';
var psychFps = null;
var memPeak = 0;

var fakeTrayY = 0;
var fakeTrayAlpha = 0;
var trayLerpY = 0;
var trayAlphaTarget = 0;
var oldVolume:Float = 0;

//constants
var c_PIXELARTSCALE:Float = 6;

function onCreate() {
	comboGroup = new FlxTypedSpriteGroup();
	game.add(comboGroup);
	
	missRating = getModSetting('miss');
	noteEffects = getModSetting('pixeleffects') || !PlayState.isPixelStage;
	var showRam:Bool = getModSetting('showram');
	
	for (snd in ['Volup', 'Voldown', 'VolMAX']) Paths.sound('soundtray/' + snd);
	var soundTray = FlxG.game.soundTray;
	fakeTrayY = soundTray.y;
	fakeTrayAlpha = soundTray.alpha;
	oldVolume = FlxG.sound.volume;
	
	var appTitle:String = Application.current.window.title;
	if (StringTools.trim(appTitle) != '' && appTitle != 'Friday Night Funkin\'') oldTitle = appTitle;
	Application.current.window.title = 'Friday Night Funkin\'';
	
	FlxTransitionableState.skipNextTransOut = true; //custom fps display
	psychFps = Main.fpsVar.updateText;
	Main.fpsVar.defaultTextFormat = new TextFormat('_sans', 12, 0xffffff, false, false, false, '', '', 'left', 0, 0, 0, -4); //lol!
	Main.fpsVar.updateText = () -> {
        memPeak = Math.max(memPeak, Main.fpsVar.memoryMegas);
        Main.fpsVar.text = 'FPS: ' + Main.fpsVar.currentFPS + (showRam ? ('\nRAM: ' + FlxStringUtil.formatBytes(Main.fpsVar.memoryMegas).toLowerCase() + ' / ' + FlxStringUtil.formatBytes(memPeak).toLowerCase()) : '');
		
		//cant modify soundTray.show (or i couldnt get it to work), so override here :(
		if (soundTray.active && soundTray.visible) {
			if (soundTray._timer > 0) {
				trayAlphaTarget = 1;
				trayLerpY = 10;
			} else {
				trayLerpY = -soundTray.height - 10;
				trayAlphaTarget = 0;
			}
			fakeTrayY = FlxMath.lerp(fakeTrayY, trayLerpY, .1);
			fakeTrayAlpha = FlxMath.lerp(fakeTrayAlpha, trayAlphaTarget, .25);
			soundTray.y = fakeTrayY;
			soundTray.alpha = fakeTrayAlpha;
			var globalVolume:Int = (FlxG.sound.muted ? 0 : Math.round(FlxG.sound.volume * 10));
			var i = 1;
			for (bar in soundTray._bars) {
				bar.visible = (i == globalVolume); //so the bars dont stack up lmao!
				i ++;
			}
			//check volume change
			if (FlxG.sound.volume != oldVolume || (FlxG.keys.anyJustPressed(FlxG.sound.volumeUpKeys) && FlxG.sound.volume >= 1)) {
				if (oldVolume > FlxG.sound.volume) FlxG.sound.play(Paths.sound('soundtray/Voldown'));
				else FlxG.sound.play(Paths.sound('soundtray/Vol' + (FlxG.sound.volume < 1 ? 'up' : 'MAX')));
				oldVolume = FlxG.sound.volume;
			}
		}
    }
	return Function_Continue;
}

function onDestroy() {
	Application.current.window.title = oldTitle;
	Main.fpsVar.defaultTextFormat = new TextFormat('_sans', 14, 0xffffff, false, false, false, '', '', 'left', 0, 0, 0, 0);
	Main.fpsVar.updateText = psychFps;
}

function onUpdateScore() game.scoreTxt.text = (game.cpuControlled ? 'Bot Play Enabled' : 'Score:' + game.songScore);

function onCreatePost() {
	for (note in game.unspawnNotes) if (!noteEffects) note.noteSplashData.disabled = true;
	
	comboGroup.cameras = [game.camHUD];
	
	game.healthBar.y = FlxG.height * (ClientPrefs.data.downScroll ? .1 : .9);
	game.healthBar.setColors(0xff0000, 0x66ff33);
	game.iconP1.y = healthBar.y - (game.iconP1.height / 2);
	game.iconP2.y = healthBar.y - (game.iconP2.height / 2);
	
	game.scoreTxt.fieldWidth = 0;
	game.scoreTxt.setPosition(game.healthBar.x + game.healthBar.width - 190, game.healthBar.y + 30);
	game.scoreTxt.setFormat(Paths.font('vcr.ttf'), 16, -1, 'right', FlxTextBorderStyle.OUTLINE, 0xff000000);
	game.botplayTxt.kill();
	
	game.healthBar.y = FlxG.height * (ClientPrefs.data.downScroll ? .1 : .9);
	game.healthBar.leftBar.color = 0xff0000;
	game.healthBar.rightBar.color = 0x66ff33;
	oldifyBar(game.healthBar);
	game.healthBar.barOffset.set(4, 4);
	
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
		
		i ++;
	}
	return Function_Continue;
}

function boom() {
	if (game.camZoomingDecay > 0 && FlxG.camera.zoom < 1.35 * FlxCamera.defaultZoom && ClientPrefs.data.camZooms) {
		cameraBopMultiplier = 1 + .015 * game.camZoomingMult;
		FlxG.camera.zoom = game.defaultCamZoom * cameraBopMultiplier;
		game.camHUD.zoom = .03 + 1;
	}
}
function onCountdownTick(_, t) {
	if (t % 4 == 0) boom();
	iconScale += 30;
	return Function_Continue;
}
function onBeatHit() {
	iconScale += 30;
	return Function_Continue;
}
function onSectionHit() {
	boom();
	return Function_Continue;
}
function onUpdate(e) {
	if (game.camZoomingDecay > 0) {
		cameraBopMultiplier = 1 + 0.95 * (cameraBopMultiplier - 1.0);
		var zoomPlusBop:Float = game.defaultCamZoom * cameraBopMultiplier;
		var hudZoomingMult:Float = (Std.isOfType(getVar('hudZoomingMult'), Float) ? getVar('hudZoomingMult') : 1);
		FlxG.camera.zoom = game.defaultCamZoom * cameraBopMultiplier * game.camZoomingMult;
		game.camHUD.zoom = FlxMath.lerp(1, camHUD.zoom, 0.95) * hudZoomingMult;
	}
	return Function_Continue;
}
function onUpdatePost(e) {
	game.camZooming = false;
	
	lerpHealth = FlxMath.lerp(lerpHealth, game.health, .15); //WHY IS EVERYTHING TIED TO FPS
	game.healthBar.percent = lerpHealth * 50;
	
	game.iconP1.setGraphicSize(iconScale);
	game.iconP2.setGraphicSize(iconScale);
	game.updateIconsPosition();
	iconScale = FlxMath.lerp(iconScale, 150, .15);
	
	if (forceHBColors && (game.healthBar.leftBar.color != 0xff0000 || game.healthBar.rightBar.color != 0x66ff33)) game.healthBar.setColors(0xff0000, 0x66ff33);
	//uhh!
	return Function_Continue;
}
function onEvent() {
	game.healthBar.setColors(0xff0000, 0x66ff33);
	return Function_Continue;
}

//ratings stuff
function goodNoteHit(note) {
	if (!note.isSustainNote) {
		for (c in game.comboGroup) c.visible = false;
		combo = game.combo;
		popUpScore(note.rating);
	}
	return Function_Continue;
}
function noteMissPress(d) {
	var miss = getModSetting('missbutlikeactually');
	if (!miss) return Function_Continue;
	var wipe:Bool = false;
	if (missRating) wipe = displayRating('miss');
	if (combo >= 10) displayCombo(0);
	if (wipe && !ClientPrefs.data.comboStacking) wipeRatings();
	combo = 0;
	return Function_Continue;
}
function noteMiss(note) {
	var wipe:Bool = false;
	if (missRating && !note.isSustainNote) wipe = displayRating('miss');
	if (combo >= 10) displayCombo(0);
	if (wipe && !ClientPrefs.data.comboStacking) wipeRatings();
	combo = 0;
	return Function_Continue;
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
		daLoop ++;
	}
	return combo;
}