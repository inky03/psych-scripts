//import flixel.text.FlxBitmapText;
//import flixel.graphics.frames.FlxBitmapFont; Ok it doesnt work
/*
TODO
- improve song text??
- cleanup
- seriously, cleanup
- finish stats for story mode (total notes, combo, etc)
- fix other stuff
*/
import backend.CustomFadeTransition;
import tjson.TJSON as JSON;
import flixel.util.FlxSave;
import backend.CoolUtil;
import backend.MusicBeatState;
import flixel.addons.transition.FlxTransitionableState;
import backend.WeekData;
import backend.Highscore;
import backend.Difficulty;
import states.FreeplayState;
import states.StoryMenuState;
import flixel.math.FlxBasePoint;
import flixel.group.FlxTypedSpriteGroup;

var characters:String = 'AaBbCcDdEeFfGgHhiIJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz:1234567890';

var grpStickers = null;
var grpInfoTexts = null;

var subTimers:Array = []; //timers to cancel before destroying state
var diffText:FlxSprite = null;
var lastAlpha:FlxSprite = null;
var resultsBf:FlxSprite = null;
var resultsGf:FlxSprite = null;
var currentTally = -1;
var tallies:Array = [];
var shownResults:Bool = false;
var inResults:Bool = false;
var resultsActive:Bool = false;

var maxCombo:Int = 0;
var totalHits:Int = 0;
var totalNotes:Int = 0;
var campaignScore:Int = 0;

function onCreatePost() {
	//for (note in game.unspawnNotes) if (note.mustPress && !note.isSustainNote) totalNotes ++;
	for (asset in ['resultBoyfriendGOOD', 'results', 'soundSystem', 'score-digital-numbers', 'tallieNumber',
	'resultGirlfriendGOOD', 'scorePopin', 'ratingsPopin', 'highscoreNew']) Paths.getSparrowAtlas('resultScreen/' + asset);
	for (asset in ['alphabet']) Paths.image('resultScreen/' + asset);
	Paths.music('resultsNORMAL');
	//get rid of story mode save when starting a week, in case of unexpected song exit
	if (PlayState.isStoryMode) {
		var weekSongs = WeekData.getCurrentWeek().songs;
		if (PlayState.SONG.song.toLowerCase() == weekSongs[0][0].toLowerCase()) {
			var save:FlxSave = new FlxSave();
			save.bind('_storymode', CoolUtil.getSavePath() + '/psychenginemods');
			save.erase();
			save.flush();
		}
	}
	var funny:FlxSprite = new FlxSprite(100, 100).loadGraphic(Paths.image('icons/icon-dad'));
}
function goodNoteHit(note) {
	if (!note.hitCausesMiss && !note.isSustainNote) totalHits ++;
	maxCombo = Math.max(maxCombo, game.combo);
	return Function_Continue;
}
function onEndSong() {
	if (ClientPrefs.getGameplaySetting('botplay') || ClientPrefs.getGameplaySetting('practice')) return Function_Continue;
	if (PlayState.isStoryMode && PlayState.storyPlaylist.length > 1) {
		var save:FlxSave = new FlxSave();
		save.bind('_storymode', CoolUtil.getSavePath() + '/psychenginemods');
		//campaignScore acted weird?? for some fuckin reason???
		if (save.data.score == null) save.data.score = 0; save.data.score += game.songScore;
		if (save.data.hits == null) save.data.hits = 0; save.data.hits += totalHits;
		if (save.data.sicks == null) save.data.sicks = 0; save.data.sicks += game.ratingsData[0].hits;
		if (save.data.goods == null) save.data.goods = 0; save.data.goods += game.ratingsData[1].hits;
		if (save.data.bads == null) save.data.bads = 0; save.data.bads += game.ratingsData[2].hits;
		if (save.data.shits == null) save.data.shits = 0; save.data.shits += game.ratingsData[3].hits;
		if (save.data.maxCombo == null) save.data.maxCombo = 0; save.data.maxCombo = Math.max(save.data.maxCombo, maxCombo);
		save.flush();
		
		return Function_Continue;
	}
	if (shownResults) return Function_Continue;
	
	if (PlayState.isStoryMode) {
		var save:FlxSave = new FlxSave();
		save.bind('_storymode', CoolUtil.getSavePath() + '/psychenginemods');
		totalHits += (save.data.hits != null ? save.data.hits : 0);
		campaignScore = game.songScore + (save.data.score != null ? save.data.score : 0);
		game.ratingsData[0].hits += (save.data.sicks != null ? save.data.sicks : 0);
		game.ratingsData[1].hits += (save.data.goods != null ? save.data.goods : 0);
		game.ratingsData[2].hits += (save.data.bads != null ? save.data.bads : 0);
		game.ratingsData[3].hits += (save.data.shits != null ? save.data.shits : 0);
		if (save.data.maxCombo != null) maxCombo = Math.max(save.data.maxCombo, maxCombo);
		save.erase();
		save.flush();
		PlayState.campaignScore = campaignScore;
	}
	
	var weekNoMiss:String = WeekData.getWeekFileName() + '_nomiss';
	game.checkForAchievement([weekNoMiss, 'ur_bad', 'ur_good', 'hype', 'two_keys', 'toastie', 'debugger']);
	shownResults = true;
	
	if (game.gf != null) game.camFollow.setPosition(game.gf.getMidpoint().x, game.gf.getMidpoint().y);
	var fade:FlxSprite = new FlxSprite(FlxG.width * .5, FlxG.height * .5).makeGraphic(1, 1, 0xff000000);
	fade.scale.set(FlxG.width * 2, FlxG.height * 2);
	fade.scrollFactor.set();
	fade.alpha = 0;
	game.playbackRate = 1;
	game.add(fade);
	FlxTween.tween(fade, {alpha: 1}, 1);
	FlxTween.tween(game.camHUD, {alpha: 0}, 1);
	new FlxTimer().start(1.5, () -> {
		game.remove(fade);
		resultsScreen(game);
		game.paused = true;
		//CustomSubstate.openCustomSubstate('results');
	});
	return Function_Stop;
}

function stickers(inst) {
	debugPrint('make sticklers');
	var grpStickers = new FlxTypedSpriteGroup();
	var stickersPath:String = Paths.modFolders('images/transitionSwag/');
	var stickerImages:Array = [];
	if (FileSystem.exists(stickersPath)) {
		for (sub in FileSystem.readDirectory(stickersPath)) {
			var jsonPath = stickersPath + sub + '/stickers.json';
			if (FileSystem.exists(jsonPath)) {
				var content = File.getContent(jsonPath);
				var json = JSON.parse(content);
				var stickers = json.stickers;
				for (sticker in Reflect.fields(stickers)) {
					var images = Reflect.field(stickers, sticker);
					if (images == null) continue;
					for (image in images) { //jesus
						stickerImages.push('transitionSwag/' + sub + '/' + image);
					}
				}
			}
		}
	}
	var xPos:Float = -100;
	var yPos:Float = -100;
	while (xPos <= FlxG.width) {
		var randomSticky:String = stickerImages[FlxG.random.int(0, stickerImages.length - 1)];
		var stickerSprite:FlxSprite = new FlxSprite(xPos, yPos).loadGraphic(Paths.image(randomSticky));
		stickerSprite.origin.set(stickerSprite.frameWidth * .5, stickerSprite.frameHeight * .5);
		stickerSprite.visible = false;
		stickerSprite.scrollFactor.set();
		stickerSprite.antialiasing = ClientPrefs.data.antialiasing;
		stickerSprite.angle = FlxG.random.int(-60, 70);
		grpStickers.add(stickerSprite);
		
		xPos += Math.max(stickerSprite.frameWidth * .5, 50);
		if (xPos >= FlxG.width) {
			if (yPos <= FlxG.height) {
				xPos = -100;
				yPos += FlxG.random.float(70, 120);
			}
		}
	}
	var track = grpStickers.members[0];
	shuffleArray(grpStickers.members);
	debugPrint(grpStickers.members.indexOf(track));
	var i = 0;
	for (sticker in grpStickers.members) {
		var timing = FlxMath.remapToRange(i, 0, grpStickers.members.length, 0, 0.9);
		new FlxTimer().start(timing, () -> {
			if (grpStickers == null) return;
			sticker.visible = true;
			var frameTimer:Int = FlxG.random.int(0, 2);
			if (i == grpStickers.members - 1) frameTimer = 2;
			new FlxTimer().start((1 / 24) * frameTimer, () -> {
				sticker.scale.x = sticker.scale.y = FlxG.random.float(0.97, 1.02);
			});
		});
		i ++;
	}
	inst.add(grpStickers);
	var lastOne = grpStickers.members[grpStickers.members.length - 1];
	if (lastOne != null) {
		lastOne.updateHitbox();
		lastOne.screenCenter();
		lastOne.angle = 0;
	}
}
function shuffleArray(array) {
	var maxValidIndex = array.length - 1;
	for (i in 0...maxValidIndex) {
		var j = FlxG.random.int(i, maxValidIndex);
		var tmp = inArray(array, i);
		setArray(array, i, inArray(array, j));
		setArray(array, j, tmp);
	}
}

function resultsScreen(inst) {
	inResults = true;
	resultsActive = true;
	game.playbackRate = 1;
	
	var newHi:Bool = false;
	var percent:Float = game.ratingPercent;
	if (Math.isNaN(percent)) percent = 0;
	
	if (PlayState.isStoryMode) {
		newHi = (PlayState.campaignScore > Highscore.getWeekScore(WeekData.getWeekFileName(), PlayState.storyDifficulty));
		StoryMenuState.weekCompleted.set(WeekData.weeksList[PlayState.storyWeek], true);
		Highscore.saveWeekScore(WeekData.getWeekFileName(), PlayState.campaignScore, PlayState.storyDifficulty);
		FlxG.save.data.weekCompleted = StoryMenuState.weekCompleted;
		FlxG.save.flush();
	} else newHi = (game.songScore > Highscore.getScore(PlayState.SONG.song, PlayState.storyDifficulty));
	Highscore.saveScore(PlayState.SONG.song, game.songScore, PlayState.storyDifficulty, percent); //save hiscore shit
	
	var resultsMusic:String = 'resultsNORMAL';
	var resultsLoop:Bool = true;
	if (game.totalNotesHit >= 10) { //is it even worth it?
		if (game.ratingsData[1].hits + game.ratingsData[2].hits + game.ratingsData[3].hits <= 0 && game.ratingsData[0].hits > 0)
			resultsMusic = 'resultsPERFECT';
		else if (percent <= .5) {
			resultsMusic = 'resultsSHIT';
			resultsLoop = false;
		}
	}
	
	FlxG.sound.music.stop();
	if (resultsLoop) FlxG.sound.playMusic(Paths.music(resultsMusic));
	else FlxG.sound.play(Paths.music(resultsMusic)); //music loops always??
	
	if (game.vocals != null) game.vocals.volume = 0;
	if (game.opponentVocals != null) game.opponentVocals.volume = 0;
	
	subTimers = [];
	tallies = [];
	currentTally = -1;
	var bg:FlxSprite = new FlxSprite().makeGraphic(1, 1, -1);
	bg.color = 0xfffec85c;
	bg.scale.set(FlxG.width, FlxG.height);
	bg.updateHitbox();
	var bgTop:FlxSprite = new FlxSprite().makeGraphic(1, 1, -1);
	bgTop.color = 0xfffec85c;
	bgTop.scale.set(535, FlxG.height);
	bgTop.updateHitbox();
	var cats:FlxSprite = new FlxSprite(-150, 120); //(short for categories (or not, if you so desire))
	cats.frames = Paths.getSparrowAtlas('resultScreen/ratingsPopin');
	cats.animation.addByPrefix('main', 'Categories', 24, false);
	cats.antialiasing = ClientPrefs.data.antialiasing;
	var score:FlxSprite = new FlxSprite(-180, FlxG.height - 200);
	score.frames = Paths.getSparrowAtlas('resultScreen/scorePopin');
	score.animation.addByPrefix('main', 'tally score', 24, false);
	score.antialiasing = ClientPrefs.data.antialiasing;
	var bf:FlxSprite = new FlxSprite(640, -200);
	bf.frames = Paths.getSparrowAtlas('resultScreen/resultBoyfriendGOOD');
	bf.animation.addByPrefix('start', 'Boyfriend Good Anim', 24, false);
	bf.animation.addByIndices('loop', 'Boyfriend Good Anim', [70, 71, 72, 73], '', 24, true);
	bf.antialiasing = ClientPrefs.data.antialiasing;
	bf.animation.play('start');
	resultsBf = bf;
	var gf:FlxSprite = new FlxSprite(625, 325);
	gf.frames = Paths.getSparrowAtlas('resultScreen/resultGirlfriendGOOD');
	gf.animation.addByPrefix('start', 'Girlfriend Good Anim', 24, false);
	gf.animation.addByIndices('loop', 'Girlfriend Good Anim', [46, 47, 48, 49, 50, 51], '', 24, true);
	gf.animation.play('start');
	gf.antialiasing = ClientPrefs.data.antialiasing;
	resultsGf = gf;
	var resultsTitle:FlxSprite = new FlxSprite(0, -10);
	resultsTitle.antialiasing = ClientPrefs.data.antialiasing;
	resultsTitle.frames = Paths.getSparrowAtlas('resultScreen/results');
	resultsTitle.animation.addByPrefix('anim', 'results instance 1', 24, false);
	resultsTitle.animation.play('anim');
	resultsTitle.screenCenter(0x01);
	resultsTitle.x -= 275;
	var soundSystem:FlxSprite = new FlxSprite(-15, -180);
	soundSystem.antialiasing = ClientPrefs.data.antialiasing;
	soundSystem.frames = Paths.getSparrowAtlas('resultScreen/soundSystem');
	soundSystem.animation.addByPrefix('anim', 'sound system', 24, false);
	var hiscore:FlxSprite = new FlxSprite(310, 570);
	hiscore.antialiasing = ClientPrefs.data.antialiasing;
	hiscore.frames = Paths.getSparrowAtlas('resultScreen/highscoreNew');
	hiscore.animation.addByPrefix('anim', 'NEW HIGHSCORE', 24, true);
	hiscore.animation.play('anim');
	hiscore.setGraphicSize(hiscore.width * .8);
	hiscore.updateHitbox();
	var resultsBar:FlxSprite = new FlxSprite().loadGraphic(Paths.image('resultScreen/topBarBlack'));
	resultsBar.y -= resultsBar.height;
	resultsBar.antialiasing = ClientPrefs.data.antialiasing;
	
	//var b:FlxBitmapText = new FlxBitmapText(null, null, null, FlxBitmapFont.fromMonospace(Paths.image('resultScreen/alphabet'), characters, new FlxBasePoint(49, 62)));
	//b.text = 'ABCDefgh';
	
	bg.scrollFactor.set();
	inst.add(bg);
	
	var artist:String = PlayState.SONG.artist == null ? '' : (' by ' + PlayState.SONG.artist);
	var songText:String = PlayState.isStoryMode ? WeekData.getCurrentWeek().storyName.toUpperCase() : (PlayState.SONG.song + artist);
	var rm = Math.sin(-4.4 / 180 * Math.PI);
	
	grpInfoTexts = new FlxTypedSpriteGroup();
	grpInfoTexts.setPosition(555, 187 - 75);
	grpInfoTexts.alpha = .0001;
	grpInfoTexts.scrollFactor.set();
	inst.add(grpInfoTexts);
	
	var difficulty:String = Difficulty.getString();
	difficulty = 'enis';
	var diffImg = Paths.image('resultScreen/dif' + difficulty);
	if (diffImg == null) diffImg = Paths.image('resultScreen/difUnknown');
	var diffText:FlxSprite = new FlxSprite().loadGraphic(diffImg);
	diffText.antialiasing = ClientPrefs.data.antialiasing;
	diffText.y -= diffText.height;
	grpInfoTexts.add(diffText);
	createAlphabet(grpInfoTexts, diffText.width + 22, -72 + diffText.width * rm, songText);
	bgTop.scrollFactor.set();
	inst.add(bgTop);
	
	for (i in [resultsGf, resultsBf, soundSystem, resultsBar, cats, score, hiscore]) {
		i.scrollFactor.set();
		i.alpha = .0001;
		inst.add(i);
	}
	resultsTitle.scrollFactor.set();
	inst.add(resultsTitle);
	
	createTally(inst, 375, 150, -1, totalHits); //i think its the total amount of notes you hit actually??
	createTally(inst, 375, 200, -1, maxCombo);
	createTally(inst, 230, 265, 0xff89e59e, game.ratingsData[0].hits);
	createTally(inst, 210, 317, 0xff89c9e5, game.ratingsData[1].hits);
	createTally(inst, 190, 369, 0xffe6cf8a, game.ratingsData[2].hits);
	createTally(inst, 220, 421, 0xffe68c8a, game.ratingsData[3].hits);
	createTally(inst, 260, 473, 0xffc68ae6, PlayState.isStoryMode ? PlayState.campaignMisses : game.songMisses);
	
	var scoreNames:Array = ['ZERO', 'ONE', 'TWO', 'THREE', 'FOUR', 'FIVE', 'SIX', 'SEVEN', 'EIGHT', 'NINE'];
	var scores:Array = Std.string(Math.max(PlayState.isStoryMode ? campaignScore : game.songScore, 0)).split('');
	var scoreNums:Array = [];
	while (scores.length < 10) scores.unshift('');
	var i = 0;
	for (n in scores) {
		var num = new FlxSprite(i * 65 + 70, FlxG.height - 110);
		num.antialiasing = ClientPrefs.data.antialiasing;
		num.frames = Paths.getSparrowAtlas('resultScreen/score-digital-numbers');
		num.animation.addByPrefix('main', n == '' ? 'DISABLED' : (scoreNames[n] + ' DIGITAL'), 24, false);
		num.animation.play('main');
		num.alpha = .0001;
		num.scrollFactor.set();
		scoreNums.push(num);
		inst.add(num);
		i ++;
	}
	
	resultsBar.alpha = 1;
	FlxTween.tween(resultsBar, {y: resultsBar.y + resultsBar.height}, .4, {ease: FlxEase.quartOut, startDelay: .5});
	subTimers.push(new FlxTimer().start(.5, () -> { //bf appear, tally
		if (resultsBf == null) return;
		currentTally = 0;
		resultsBf.animation.play('start', true);
		resultsBf.animation.finishCallback = () -> resultsBf.animation.play('loop');
		soundSystem.animation.play('anim');
		cats.animation.play('main');
		for (i in [resultsBf, soundSystem, cats]) i.alpha = 1;
		subTimers.push(new FlxTimer().start(.5, () -> {
			FlxTween.color(bg, .4, 0xffffe466, 0xfffec85c);
			FlxTween.color(bgTop, .4, 0xffffe466, 0xfffec85c);
		}));
		subTimers.push(new FlxTimer().start(.4, () -> {
			grpInfoTexts.alpha = 1;
			FlxTween.tween(grpInfoTexts, {y: grpInfoTexts.y + 75}, .5, {ease: FlxEase.quartOut});
		}));
		cats.animation.finishCallback = () -> {
			score.animation.play('main');
			score.alpha = 1;
			score.animation.finishCallback = () -> {
				for (num in scoreNums) {
					num.alpha = 1;
					num.animation.play('main', true);
				}
			}
			if (newHi) {
				hiscore.alpha = 1;
				FlxTween.tween(hiscore, {y: hiscore.y + 10}, 0.8, {ease: FlxEase.quartOut});
			}
		};
	}));
	subTimers.push(new FlxTimer().start(3, moveAlphabets));
	subTimers.push(new FlxTimer().start(.9166, () -> { //gf appear
		if (resultsGf == null) return;
		resultsGf.animation.play('start', true);
		resultsGf.animation.finishCallback = () -> resultsGf.animation.play('loop');
		resultsGf.alpha = 1;
	}));
	
	//stickers(inst);
}
function tallyDumb(tally, e) {
	var tallied = updateTally(tally, e * 1000, e * 4);
	if (tallied) tallyDumb(++ currentTally, e);
}
function onCustomSubstateCreate(substate) {
	if (substate == 'results') resultsScreen(CustomSubstate.instance);
}
function exitSong() {
	MusicBeatState.switchState(PlayState.isStoryMode ? new StoryMenuState() : new FreeplayState());
	FlxG.sound.playMusic(Paths.music('freakyMenu'));
	PlayState.changedDifficulty = false;
	PlayState.chartingMode = false;
	game.transitioning = true;
	FlxG.camera.followLerp = 0;
	Mods.loadTopMod();
	return true;
}
function resultsClose() {
	CustomSubstate.closeCustomSubstate();
	
	grpInfoTexts = null;
	resultsBf = null;
	resultsGf = null;
	while (subTimers.length > 0) {
		var t = subTimers.shift();
		t.cancel();
		t.destroy();
	}
	//FlxTransitionableState.skipNextTransIn = true;
	//FlxTransitionableState.skipNextTransOut = true;
	resultsActive = false;
	FlxG.sound.playMusic(Paths.music('freakyMenu'));
	game.paused = true;
	game.vocals.volume = 0;
	MusicBeatState.switchState(PlayState.isStoryMode ? new StoryMenuState() : new FreeplayState());
}
function resultsUpdate(inst, e) {
	if (!resultsActive) return;
	game.health = 2;
	if (grpInfoTexts.x < -grpInfoTexts.width) {
		grpInfoTexts.setPosition(555, 187 - 75);
		grpInfoTexts.acceleration.set(0, 0);
		grpInfoTexts.velocity.set(0, 0);
		FlxTween.tween(grpInfoTexts, {y: grpInfoTexts.y + 75}, .5, {ease: FlxEase.quartOut});
		subTimers.push(new FlxTimer().start(1.5, moveAlphabets));
	}
	if (inst.controls.ACCEPT) resultsClose();
	tallyDumb(currentTally, e);
}
function onUpdatePost(e) {
	if (inResults) {
		resultsUpdate(game, e);
		game.camGame.zoom = 1; //lol im lazy
	}
	return Function_Continue;
}
function createTally(inst, x, y, color, score) {
	var grp = new FlxTypedSpriteGroup(x, y);
	grp.scrollFactor.set();
	grp.color = color;
	inst.add(grp);
	tallies.push({first: false, tally: 0, score: Std.int(score), wait: 0, group: grp});
}
function updateTally(index, count, time) {
	var tally = tallies[index];
	if (tally == null || tally.group == null) return false;
	tally.wait += time;
	if (tally.tally < tally.score || !tally.first) {
		tally.first = true;
		tally.tally = Math.min(tally.score * tally.wait, tally.score);
		var count:String = Std.string(Math.floor(tally.tally));
		
		var tallyGrp = tally.group;
		var i = tallyGrp.members.length;
		while (tallyGrp.members.length < count.length) {
			var num:FlxSprite = new FlxSprite(i * 43, 0);
			num.color = tallyGrp.color; //cant tint group
			num.frames = Paths.getSparrowAtlas('resultScreen/tallieNumber');
			for (n in 0...10) num.animation.addByPrefix(Std.string(n), n + ' small', 24, false);
			num.antialiasing = ClientPrefs.data.antialiasing;
			tallyGrp.add(num);
			i ++;
		}
		var i = 0;
		for (num in tallyGrp.members) {
			num.animation.play(count.charAt(i), true);
			i ++;
		}
	}
	return (tally.wait >= 1);
}
function createAlphabet(group, x, y, text) {
	var alphabets:Array = [];
	var letters:Array = text.split('');
	var i:Int = 0;
	var dist:Int = 34;
	var angle:Int = -4.4;
	var angleRad:Float = angle / 180 * Math.PI;
	for (c in letters) {
		var char = characters.indexOf(c);
		if (char >= 0) {
			var letter:FlxSprite = new FlxSprite(x + i * Math.cos(angleRad) * dist, y + i * Math.sin(angleRad) * dist).loadGraphic(Paths.image('resultScreen/alphabet'), true, 392 / 8, 496 / 8);
			letter.y -= Math.cos(angle) * letter.height;
			letter.antialiasing = ClientPrefs.data.antialiasing;
			letter.animation.add('letter', [char], 24, true);
			letter.animation.play('letter');
			letter.angle = angle;
			alphabets.push(letter);
			group.add(letter);
		}
		i ++;
	}
}
function moveAlphabets() { //move alphabet and stuff
	var rm = Math.sin(-4.4 / 180 * Math.PI);
	grpInfoTexts.acceleration.x = -150;
	grpInfoTexts.acceleration.y = -150 * rm;
	grpInfoTexts.maxVelocity.x = 150;
	grpInfoTexts.maxVelocity.y = Math.abs(-150 * rm);
}
function inArray(array, pos) { //array access lags workaround???
	if (pos >= array.length) return null;
    var i = 0;
    for (item in array) {
        if (i == pos) return item;
        i ++;
    }
    return null;
}
function setArray(array, pos, v) { //this is fucking stupid..
	if (pos < 0 || pos >= array.length) return null;
	var readd:Array = [];
	while (array.length > pos) {
		var i = array.pop();
		readd.unshift(i);
	}
	readd.shift();
	readd.unshift(v);
	while (readd.length > 0) array.push(readd.shift());
}