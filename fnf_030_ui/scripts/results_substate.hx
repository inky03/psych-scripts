//import flixel.text.FlxBitmapText;
//import flixel.graphics.frames.FlxBitmapFont; Ok it doesnt work
/*
TODO
- readd clipping for song header (idk how do that)
- it still needs cleanup :(
- fix other stuff
*/
import Std;
import Type;
import Main;
import Reflect;
import sys.io.File;
import sys.FileSystem;
import flixel.effects.FlxFlicker;
import flixel.sound.FlxSound;
import flixel.util.FlxGradient;
import flixel.addons.display.FlxBackdrop;
import tjson.TJSON as JSON;
import flixel.util.FlxSave;
import flixel.addons.transition.FlxTransitionableState;
import backend.Mods;
import backend.Language;
import backend.CoolUtil;
import backend.WeekData;
import backend.Highscore;
import backend.Difficulty;
import backend.MusicBeatState;
import states.MainMenuState;
import states.FreeplayState;
import states.StoryMenuState;
import flixel.math.FlxBasePoint;
import flixel.group.FlxTypedSpriteGroup;

var DiscordClient = Type.resolveClass('backend.DiscordClient'); // lol??

var characters:String = 'AaBbCcDdEeFfGgHhiIJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz:1234567890';

var grpInfoTexts;
var diffText;
var grpClear;
var grpSongText;

var subTimers:Array = []; //timers to cancel before destroying state
var diffText:FlxSprite = null;
var lastAlpha:FlxSprite = null;
var resultsSprites:Array<Dynamic> = [];
var currentTally = -1;
var tallies:Array = [];
var shownResults:Bool = false;
var inResults:Bool = false;
var resultsActive:Bool = false;
var resultsMusic = null;
var cam;

var rankDelay:Map = [
	'PERFECT' => {music: 95 / 24, flash: 129 / 24, bf: 95 / 24, hi: 140 / 24},
	'EXCELLENT' => {music: 0, flash: 122 / 24, bf: 95 / 24, hi: 140 / 24}, //its 97/24 but it wouldnt sync ;(
	'GREAT' => {music: 5 / 24, flash: 109 / 24, bf: 95 / 24, hi: 129 / 24},
	'GOOD' => {music: 3 / 24, flash: 107 / 24, bf: 95 / 24, hi: 127 / 24},
	'SHIT' => {music: 2 / 24, flash: 186 / 24, bf: 95 / 24, hi: 207 / 24},
];
rankDelay['PERFECT_GOLD'] = rankDelay['PERFECT'];

var maxCombo:Int = 0;
var totalHits:Int = 0;
var totalNotes:Int = 0;
var campaignScore:Int = 0;

function onCreatePost() {
	for (asset in ['results', 'soundSystem', 'score-digital-numbers', 'tallieNumber',
		'scorePopin', 'ratingsPopin', 'highscoreNew', 'clearPercent/clearPercentNumberSmall'])
		Paths.getSparrowAtlas('resultScreen/' + asset);
	for (asset in ['alphabet']) Paths.image('resultScreen/' + asset);
	
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
	
	return;
}

function getPlayer(chara:String) {
	try {
		var charaSplit:Array<String> = chara.split('-');
		while (charaSplit.length > 0) { // trim dashes until it finds a working match
			var search:String = charaSplit.join('-');
			if (FileSystem.exists(Paths.getPath('players/' + search + '.json')))
				return search;
			charaSplit.pop();
		}
	} catch (e:Dynamic) {
		debugPrint('ERROR WHILE GETTING PLAYER: ' + e, 0xffff0000);
	}
	return 'bf';
}
function getPlayerFile(chara:String) {
	try {
		var path:String = Paths.getPath('players/' + chara + '.json');
		if (FileSystem.exists(path))
			return JSON.parse(File.getContent(path));
	} catch (e:Dynamic) {
		debugPrint('ERROR WHILE GETTING PLAYER FILE: ' + e, 0xffff0000);
	}
	return null;
}
function createResultsSprites(json:Dynamic, rank:String):Array<Dynamic> {
	var characters:Array<Dynamic> = [];
	
	if (json.results != null) {
		try {
			var resultsSprites:Array<Dynamic> = Reflect.field(json.results, rank);
			if (resultsSprites != null) {
				for (sprite in resultsSprites) {
					var character;
					var assetPath = StringTools.replace(sprite.assetPath, 'shared:', '');
					switch (sprite.renderType) {
						case 'animateatlas':
							character = new FlxAnimate(sprite.offsets[0], sprite.offsets[1]);
							Paths.loadAnimateAtlas(character, assetPath);
							if (sprite.scale != null)
								character.scale.set(sprite.scale, sprite.scale);
							
							if (sprite.loopFrameLabel != null) {
								var label:String = sprite.loopFrameLabel ?? '';
								var labelData = character.anim.getFrameLabel(label);
								if (labelData != null) {
									var startInd:Int = labelData.index;
									character.anim.onComplete.addOnce(() -> character.anim.play('', true, false, startInd));
								}
							} else if (sprite.looped || sprite.loopFrame != null) {
								var fr:Int = sprite.loopFrame ?? 0;
								character.anim.onComplete.add(() -> {
									character.anim.curFrame = fr ?? 0;
									character.anim.play();
								});
							} else {
								character.anim.onComplete.add(() -> character.anim.pause());
							}
							
							// fixes a bizarre issue caused by a weak point...
							var sym = character.anim.curInstance.symbol;
							var point = sym.transformationPoint;
							character.origin = sym.transformationPoint = FlxBasePoint.get(point.x, point.y);
						default:
							character = new FlxSprite(sprite.offsets[0], sprite.offsets[1]);
							character.frames = Paths.getSparrowAtlas(assetPath);
							character.animation.addByPrefix('idle', '', 24, false);
							
							if (sprite.loopFrame != null) {
								var fr:Int = sprite.loopFrame ?? 0;
								character.animation.finishCallback = (_) -> character.animation.play('idle', true, false, fr);
							}
					}
					
					character.updateHitbox();
					character.antialiasing = ClientPrefs.data.antialiasing;
					characters.push({sprite: character, z: sprite.zIndex, delay: sprite.delay});
				}
			}
			
			characters.sort((a, b) -> Std.int(a.z) - Std.int(b.z));
		} catch (e:Dynamic) {
			debugPrint('ERROR WHILE CREATING RESULTS SPRITES: ' + e, 0xffff0000);
		}
	}
	
	return characters;
}
function spawnSprites(inst) {
	for (dat in resultsSprites) {
		function pop() {
			dat.sprite.alpha = 1;
			if (dat.sprite.anim != null) {
				dat.sprite.anim.play('');
				dat.sprite.anim.framerate = 25;
			} else if (dat.sprite.animation != null) {
				dat.sprite.animation.play('idle', true);
			}
		}
		
		if (dat.delay != null && dat.delay > 0) {
			new FlxTimer().start(dat.delay, pop);
		} else {
			pop();
		}
	}
}

function goodNoteHit(note) {
	if (!note.hitCausesMiss && !note.isSustainNote) totalHits += 1;
	maxCombo = Math.max(maxCombo, game.combo);
	return;
}
function onEndSong() {
	if (ClientPrefs.getGameplaySetting('botplay') || ClientPrefs.getGameplaySetting('practice')) return;
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
		
		return;
	}
	if (shownResults) return;
	
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
	game.camGame.fade(0xff000000, .6);
	FlxTween.tween(game.camHUD, {alpha: 0}, .5);
	new FlxTimer().start(.6, () -> {
		//resultsScreen(game);
		CustomSubstate.openCustomSubstate('results');
	});
	return Function_Stop;
}

var prevRating:Int = -1;
var scrollV:FlxBackdrop;
var scrollHA:FlxTypedSpriteGroup;
var scrollHB:FlxTypedSpriteGroup;
var clearnumGrp:FlxTypedSpriteGroup;
var clearImage:FlxSprite;
var bg:FlxSprite;
var soundSystem:FlxSprite;
var scrollRad:Float = 0;
var scrollWidth:Float = 0;
function updateClearNums(inst, rating, target) {
	var n = Math.floor(rating);
	if (prevRating < n) {
		var done:Bool = (n == target);
		FlxG.sound.play(Paths.sound(done ? 'confirmMenu' : 'scrollMenu'));
		prevRating = n;
		var sn:String = Std.string(n);
		var i = clearnumGrp.members.length;
		while (clearnumGrp.members.length < sn.length) {
			var num:FlxSprite = new FlxSprite(i * -68);
			num.frames = Paths.getSparrowAtlas('resultScreen/clearPercent/clearPercentNumberRight');
			for (i in 0...10) num.animation.addByPrefix(Std.string(i), 'number ' + i, 24, false);
			num.animation.play('0');
			clearnumGrp.add(num);
			i += 1;
		}
		i = sn.length - 1;
		for (num in clearnumGrp.members) {
			var n = sn.charAt(i);
			num.animation.play(n);
			i -= 1;
			if (done) num.setColorTransform(0, 0, 0, 1, 255, 255, 255);
		}
		if (done) {
			subTimers.push(new FlxTimer().start(.4, () -> {
				for (num in clearnumGrp.members) num.setColorTransform();
			}));
			FlxTween.tween(clearnumGrp, {alpha: 0}, .5, {startDelay: .75, onComplete: () -> { inst.remove(clearnumGrp); }});
			FlxTween.tween(clearImage, {alpha: 0}, .5, {startDelay: .75, onComplete: () -> { inst.remove(clearImage); }});
		}
	}
}
function badsCount() {
	var i:Int = 0;
	var count:Int = 0;
	for (r in game.ratingsData) {
		if (i >= 2)
			count += r.hits;
		i += 1;
	}
	return count;
}
function getRank(percent) {
	if (percent >= 100) {
		if (badsCount() == 0)
			return 'perfectGold';
		return 'perfect';
	}
	if (percent >= 90) return 'excellent';
	if (percent >= 80) return 'great';
	if (percent >= 60) return 'good';
	return 'loss';
}
function getRankB(percent) { // ...why?
	if (percent >= 100) {
		if (badsCount() == 0)
			return 'PERFECT_GOLD';
		return 'PERFECT';
	}
	if (percent >= 90) return 'EXCELLENT';
	if (percent >= 80) return 'GREAT';
	if (percent >= 60) return 'GOOD';
	return 'SHIT';
}
function resultsScreen(inst) {
	cam = new FlxCamera(0, 0, FlxG.width, FlxG.height);
	cam.bgColor = 0;
	FlxG.cameras.remove(game.camOther, false);
	FlxG.cameras.add(cam, false);
	FlxG.cameras.add(game.camOther, false);
	// cam = game.camOther;
	
	inResults = true;
	resultsActive = true;
	game.playbackRate = 1;
	game.paused = true;
	cam.visible = true;
	cam.alpha = 1;
	for (grp in [game.noteGroup, game.uiGroup]) {
		game.remove(grp);
	}
	
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
	
	if (game.vocals != null) game.vocals.volume = 0;
	if (game.opponentVocals != null) game.opponentVocals.volume = 0;
	
	subTimers = [];
	tallies = [];
	currentTally = -1;
	bg = new FlxSprite().makeGraphic(1, 1, -1);
	bg.color = 0xfffec85c;
	bg.scale.set(FlxG.width, FlxG.height);
	bg.updateHitbox();
	var bgFlash:FlxSprite = FlxGradient.createGradientFlxSprite(1, FlxG.height, [0xfffff1a6, 0xfffff1be], 90);
	bgFlash.scale.set(1280, 1);
	bgFlash.updateHitbox();
	bgFlash.scrollFactor.set();
	var bgTop:FlxSprite = new FlxSprite().makeGraphic(1, 1, -1);
	bgTop.color = 0xfffec85c;
	bgTop.scale.set(535, FlxG.height);
	bgTop.updateHitbox();
	var cats:FlxSprite = new FlxSprite(-135, 135); //(short for categories (or not, if you so desire))
	cats.frames = Paths.getSparrowAtlas('resultScreen/ratingsPopin');
	cats.animation.addByPrefix('main', 'Categories', 24, false);
	cats.antialiasing = ClientPrefs.data.antialiasing;
	var score:FlxSprite = new FlxSprite(-180, FlxG.height - 205);
	score.frames = Paths.getSparrowAtlas('resultScreen/scorePopin');
	score.animation.addByPrefix('main', 'tally score', 24, false);
	score.antialiasing = ClientPrefs.data.antialiasing;
	
	var totalMisses:Int = PlayState.isStoryMode ? PlayState.campaignMisses : game.songMisses;
	var successHits:Int = game.ratingsData[0].hits + game.ratingsData[1].hits;
	var comboBreaks:Int = game.ratingsData[2].hits + game.ratingsData[3].hits + totalMisses;
	
	var clearStatus:Int = Math.floor(successHits / Math.max(successHits + comboBreaks, 1) * 100);
	var rankBig:String = getRankB(clearStatus);
	var rank:String = getRank(clearStatus);
	
	var player:Dynamic = getPlayerFile(getPlayer(game.boyfriend.curCharacter));
	resultsSprites = createResultsSprites(player, rank);
	
	var resultsTitle:FlxSprite = new FlxSprite(0, -10);
	resultsTitle.antialiasing = ClientPrefs.data.antialiasing;
	resultsTitle.frames = Paths.getSparrowAtlas('resultScreen/results');
	resultsTitle.animation.addByPrefix('anim', 'results instance 1', 24, false);
	resultsTitle.screenCenter(0x01);
	resultsTitle.x -= 275;
	soundSystem = new FlxSprite(-15, -180);
	soundSystem.antialiasing = ClientPrefs.data.antialiasing;
	soundSystem.frames = Paths.getSparrowAtlas('resultScreen/soundSystem');
	soundSystem.animation.addByPrefix('anim', 'sound system', 24, false);
	var hiscore:FlxSprite = new FlxSprite(44, 557);//310, 570);
	hiscore.antialiasing = ClientPrefs.data.antialiasing;
	hiscore.frames = Paths.getSparrowAtlas('resultScreen/highscoreNew');
	hiscore.animation.addByPrefix('anim', 'highscoreAnim0', 24, false);
	hiscore.setGraphicSize(hiscore.width * .8);
	hiscore.updateHitbox();
	var resultsBar:FlxSprite = new FlxSprite().loadGraphic(Paths.image('resultScreen/topBarBlack'));
	resultsBar.y -= resultsBar.height;
	resultsBar.antialiasing = ClientPrefs.data.antialiasing;
	
	//var b:FlxBitmapText = new FlxBitmapText(null, null, null, FlxBitmapFont.fromMonospace(Paths.image('resultScreen/alphabet'), characters, new FlxBasePoint(49, 62)));
	//b.text = 'ABCDefgh';
	
	bg.cameras = [cam];
	bg.scrollFactor.set();
	inst.add(bg);
	inst.add(bgFlash);
	bgFlash.alpha = 0.0001;
	bgFlash.cameras = [cam];
	
	var storyWeek:String = WeekData.getCurrentWeek();
	var artist:String = PlayState.SONG.artist == null ? PlayState.SONG.song : getPhrase('song_meta', '{1} by {2}', [PlayState.SONG.song, PlayState.SONG.artist]);
	var songText:String = PlayState.isStoryMode ? getPhrase('storyname_' + storyWeek.fileName, storyWeek.storyName, []).toUpperCase() : artist;
	var rm = Math.sin(-4.4 / 180 * Math.PI);
	
	grpClear = new FlxTypedSpriteGroup();
	grpSongText = new FlxTypedSpriteGroup();
	grpInfoTexts = new FlxTypedSpriteGroup();
	grpInfoTexts.setPosition(555, 187 - 87);
	grpInfoTexts.alpha = .0001;
	grpInfoTexts.scrollFactor.set();
	grpInfoTexts.cameras = [cam];
	
	var difficulty:String = Difficulty.list[PlayState.storyDifficulty];
	var diffImg = Paths.image('resultScreen/diff_' + difficulty.toLowerCase());
	if (diffImg == null) diffImg = Paths.image('resultScreen/diff_unknown');
	diffText = new FlxSprite().loadGraphic(diffImg);
	diffText.antialiasing = ClientPrefs.data.antialiasing;
	diffText.y -= diffText.height;
	createAlphabet(grpSongText, diffText.width + 135 + 22, -65 + (diffText.width + 135) * rm, songText);
	var infoClearPercent = createRatingNums(grpClear, diffText.width + 22 + 73, -72 + (diffText.width + 50) * rm + 10, clearStatus);
	infoClearPercent.visible = false;
	//bgTop.scrollFactor.set();
	//inst.add(bgTop);*/
	grpInfoTexts.add(diffText);
	grpInfoTexts.add(grpClear);
	grpInfoTexts.add(grpSongText);
	for (obj in [diffText, grpClear, grpSongText])
		obj.origin.y = obj.y;
	
	var bgCam = new FlxCamera();
	bgCam.bgColor = 0;
	FlxG.game.addChildAt(bgCam.flashSprite, FlxG.game.getChildIndex(cam.flashSprite) - 1);
	FlxG.cameras.list.insert(FlxG.cameras.list.indexOf(cam) - 1, bgCam);
	
	scrollHA = new FlxTypedSpriteGroup();
	scrollHA.scrollFactor.set();
	scrollHA.cameras = [cam];
	scrollHB = new FlxTypedSpriteGroup();
	scrollHB.scrollFactor.set();
	scrollHB.cameras = [cam];
	var rankImage = Paths.image('resultScreen/rankText/rankScroll' + rank.toUpperCase());
	if (rankImage != null) {
		var ang:Float = -3.666;
		var ww = rankImage.width;
		var rad = (ang / 180 * Math.PI);
		scrollRad = rad;
		scrollWidth = ww;
		for (yy in 0...10) {
			for (xx in 0 ... (Math.ceil(FlxG.width / ww) + 2)) {
				var xa:Float = (xx - 1) * ww - 2 * yy + (yy % 2 == 0 ? 0 : ww);
				var ya:Float = 67.4 * yy;
				var scroll = new FlxSprite(Math.cos(rad) * xa - Math.sin(rad) * ya, 165 + Math.sin(rad) * xa + Math.cos(rad) * ya).loadGraphic(rankImage);
				scroll.y += -scroll.height + 55;
				scroll.origin.set(0, 0);
				scroll.angle = ang;
				if (yy % 2 == 0) scrollHA.add(scroll);
				else scrollHB.add(scroll);
			}
		}
	}
	var rankImageB = Paths.image('resultScreen/rankText/rankText' + rank.toUpperCase());
	scrollV = new FlxBackdrop(rankImageB, 0x10, 0, 30);
	scrollV.x = FlxG.width - 45;
	scrollV.scrollFactor.set();
	scrollV.cameras = [cam];
	
	clearImage = new FlxSprite(900 - 75, 400 - 75).loadGraphic(Paths.image('resultScreen/clearPercent/clearPercentText'));
	clearImage.scrollFactor.set();
	clearImage.cameras = [cam];
	clearnumGrp = new FlxTypedSpriteGroup(965 - 75, 475 - 75);
	clearnumGrp.scrollFactor.set();
	clearnumGrp.cameras = [cam];
	
	var resultsHi = grpInfoTexts;
	for (dat in resultsSprites) {
		var i = dat.sprite;
		i.scrollFactor.set();
		i.cameras = [cam];
		i.alpha = .0001;
		resultsHi = i;
		inst.add(i);
	}
	for (i in [grpInfoTexts, soundSystem, resultsBar, cats, score, hiscore, resultsTitle]) {
		if (i == null) continue;
		i.cameras = [cam];
		i.scrollFactor.set();
		i.alpha = .0001;
		inst.add(i);
	}
	
	createTally(inst, 375, 150, -1, totalHits); //i think its the total amount of notes you hit actually??
	createTally(inst, 375, 200, -1, maxCombo);
	createTally(inst, 230, 277, 0xff89e59e, game.ratingsData[0].hits);
	createTally(inst, 210, 330, 0xff89c9e5, game.ratingsData[1].hits);
	createTally(inst, 190, 385, 0xffe6cf8a, game.ratingsData[2].hits);
	createTally(inst, 220, 439, 0xffe68c8a, game.ratingsData[3].hits);
	createTally(inst, 260, 493, 0xffc68ae6, totalMisses);
	
	var scoreNames:Array = ['ZERO', 'ONE', 'TWO', 'THREE', 'FOUR', 'FIVE', 'SIX', 'SEVEN', 'EIGHT', 'NINE'];
	var scores:Array = Std.string(Math.max(PlayState.isStoryMode ? campaignScore : game.songScore, 0)).split('');
	var scoreNums:Array = [];
	while (scores.length < 10) scores.unshift('');
	var i = 0;
	for (n in scores) {
		var num = new FlxSprite(i * 65 + 70, FlxG.height - 110);
		num.antialiasing = ClientPrefs.data.antialiasing;
		num.frames = Paths.getSparrowAtlas('resultScreen/score-digital-numbers');
		for (i in 0...10) num.animation.addByPrefix(Std.string(i), scoreNames[i], 24, false);
		num.animation.addByPrefix('disabled', 'DISABLED', 24, false);
		num.animation.addByPrefix('gone', 'GONE', 24, false);
		num.animation.play(n == '' ? 'disabled' : Std.string(n));
		num.alpha = .0001;
		num.scrollFactor.set();
		num.cameras = [cam];
		scoreNums.push(num);
		inst.add(num);
		i += 1;
	}
	
	FlxG.sound.music.stop();
	var resultsIntro;
	var resultsMusic;
	if (player?.results?.music != null) {
		var musicDat = player.results.music;
		var musicRank = Reflect.field(musicDat, rankBig);
		if (musicRank != null) {
			resultsMusic = Paths.music(musicRank);
			resultsIntro = Paths.music(musicRank + '-intro');
		} else {
			resultsMusic = Paths.music('resultsNORMAL');
		}
	}
	if (resultsIntro != null && resultsIntro.length < 1000)
		resultsIntro = null;
	
	var delayData = rankDelay.get(rankBig);
	if (delayData == null) delayData = {music: 3.5, bf: 3.5, flash: 3.5, hi: 3.5};
	subTimers.push(new FlxTimer().start(delayData.bf, () -> { //bf delay
		spawnSprites(inst);
		infoClearPercent.visible = true;
		var i:Int = 0;
		for (item in infoClearPercent.members) {
			if (i > 0) item.setColorTransform(0, 0, 0, 1, 255, 255, 255); //the % doesnt get colored
			i += 1;
		}
		subTimers.push(new FlxTimer().start(.4, () -> {
			for (item in infoClearPercent.members)
				item.setColorTransform();
		}));
		subTimers.push(new FlxTimer().start(2.5, moveAlphabets));
	}));
	subTimers.push(new FlxTimer().start(delayData.flash, () -> {
		bgFlash.alpha = 1;
		FlxTween.tween(bgFlash, {alpha: 0}, 5 / 24);
		inst.insert(inst.members.indexOf(bg) + 1, scrollHA);
		inst.insert(inst.members.indexOf(bg) + 1, scrollHB);
		inst.insert(inst.members.indexOf(resultsHi) + 1, scrollV);
		FlxFlicker.flicker(scrollV, 2 / 24 * 3, 2 / 24, true);
		
		var speed:Float = 7;
		scrollHA.velocity.set(Math.cos(scrollRad) * speed, Math.sin(scrollRad) * speed);
		scrollHB.velocity.set(-scrollHA.velocity.x, -scrollHA.velocity.y);
		subTimers.push(new FlxTimer().start(30 / 24, () -> scrollV.velocity.y = -80));
	}));
	subTimers.push(new FlxTimer().start(delayData.music, () -> {
		if (resultsIntro != null) {
			FlxG.sound.playMusic(resultsIntro);
			FlxG.sound.music.onComplete = () -> {
				FlxG.sound.playMusic(resultsMusic);
				FlxG.sound.music.onComplete = null;
			}
		} else {
			FlxG.sound.playMusic(resultsMusic);
		}
	}));
	if (newHi) {
		subTimers.push(new FlxTimer().start(delayData.hi, () -> {
			hiscore.alpha = 1;
			hiscore.animation.play('anim', true);
			hiscore.animation.finishCallback = () -> hiscore.animation.play('anim', true, false, 16);
		}));
	}
	
	resultsBar.alpha = 1;
	FlxTween.tween(resultsBar, {y: resultsBar.y + resultsBar.height}, .4, {ease: FlxEase.quartOut, startDelay: .5});
	subTimers.push(new FlxTimer().start(6 / 24, () -> {
		resultsTitle.animation.play('anim');
		resultsTitle.alpha = 1;
	}));
	subTimers.push(new FlxTimer().start(8 / 24, () -> {
		soundSystem.animation.play('anim');
		soundSystem.alpha = 1;
	}));
	subTimers.push(new FlxTimer().start(21 / 24, () -> {
		cats.animation.play('main');
		cats.alpha = 1;
		score.animation.play('main');
		score.alpha = 1;
		var i = 0;
		for (num in scoreNums) {
			num.alpha = 1;
			if (num.animation.name == 'disabled') {
				num.animation.play('main', true);
			} else {
				var digit:Int = num.animation.name;//Std.int(num.animation.name);
				var finalDigit:Int = digit;
				var start:Bool = true;
				num.animation.play('gone');
				subTimers.push(new FlxTimer().start((i - 1) / 24, () -> {
					var duration:Float = 41 / 24;
					var interval:Float = 1 / 24;
					subTimers.push(new FlxTimer().start(interval, (t) -> {
						digit = (digit + 1) % 9;
						num.animation.play(Std.string(digit), true);
						if (t.loopsLeft <= 0) {
							subTimers.push(FlxTween.num(0, finalDigit, 23 / 24, {ease: FlxEase.quadOut, onComplete: () -> {
								num.animation.play(Std.string(finalDigit), true);
							}}, (n) -> {
								num.animation.play(Std.string(Math.round(n)));
								num.animation.finish();
							}));
						}
						if (start) start = false;
						else num.animation.finish();
					}, Math.floor(duration / interval)));
				}));
			}
			i += 1;
		}
	}));
	subTimers.push(new FlxTimer().start(37 / 24, () -> { //bf appear, tally
		currentTally = 0;
		for (i in [clearnumGrp, clearImage]) inst.insert(inst.members.indexOf(resultsHi), i);
		bgFlash.alpha = 1;
		subTimers.push(FlxTween.tween(bgFlash, {alpha: 0}, 5 / 24));
		subTimers.push(FlxTween.num(0, clearStatus, 58 / 24, {ease: FlxEase.quartOut}, (n) -> {
			updateClearNums(inst, n, clearStatus);
		}));
		
		subTimers.push(new FlxTimer().start(.4, () -> {
			grpInfoTexts.alpha = 1;
			tweenTexts();
		}));
	}));
	
	if (DiscordClient != null && game.autoUpdateRPC)
		DiscordClient.changePresence('Results Screen - ' + game.detailsText, PlayState.SONG.song + ' (' + game.storyDifficultyText + ')', iconP2.getCharacter());
}
function tallyDumb(tally, e) {
	var tallied = updateTally(tally, e * 1000, e * 4);
	if (tallied) {
		currentTally += 1;
		tallyDumb(currentTally, e);
	}
}
function onCustomSubstateCreate(substate)
	if (substate == 'results') resultsScreen(CustomSubstate.instance);
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
function resultsClose(inst) {
	while (subTimers.length > 0) {
		var t = subTimers.shift();
		t.cancel();
		t.destroy();
	}
	
	grpInfoTexts = null;
	resultsSprites = [];
	resultsActive = false;
	
	game.paused = true;
	game.vocals.volume = 0;
	FlxTween.tween(FlxG.sound.music, {volume: 0}, 0.8);
	FlxTween.tween(FlxG.sound.music, {pitch: 3}, 0.1, {onComplete: () -> {
		FlxTween.tween(FlxG.sound.music, {pitch: 0.5}, 0.4);
	}});
}
function onDestroy() {
	if (shownResults) {
		FlxTween.tween(Main.fpsVar, {alpha: 1}, .4, {ease: FlxEase.circInOut});
		FlxG.sound.playMusic(Paths.music('freakyMenu'));
	}
	return;
}
function tweenTexts() {
	grpInfoTexts.acceleration.set(0, 0);
	grpInfoTexts.velocity.set(0, 0);
	var i:Int = 0;
	for (obj in [diffText, grpClear, grpSongText]) {
		FlxTween.tween(obj, {y: obj.origin.y + 75}, .5, {ease: FlxEase.quartOut, startDelay: i * .05});
		i += 1;
	}
}
function resultsUpdate(inst, e) {
	if (!resultsActive) return;
	
	game.health = 2;
	if (scrollHA.x > Math.cos(scrollRad) * scrollWidth) {
		scrollHA.x -= Math.cos(scrollRad) * scrollWidth;
		scrollHA.y -= Math.sin(scrollRad) * scrollWidth;
	}
	if (scrollHB.x < Math.cos(scrollRad) * -scrollWidth) {
		scrollHB.x += Math.cos(scrollRad) * scrollWidth;
		scrollHB.y += Math.sin(scrollRad) * scrollWidth;
	}
	if (grpInfoTexts.x < -grpInfoTexts.width) {
		grpInfoTexts.setPosition(555, 187 - 87);
		for (obj in [diffText, grpClear, grpSongText])
			obj.y -= 75;
		tweenTexts();
		subTimers.push(new FlxTimer().start(1.5, moveAlphabets));
	}
	var close:Bool = game.controls.ACCEPT || game.controls.BACK || (FlxG.android != null && FlxG.android.justReleased.BACK);
	if (close) {
		game.callOnHScript('startStickerTransition', [() -> FlxG.switchState(PlayState.isStoryMode ? new StoryMenuState() : new FreeplayState())]);
		resultsClose(game);
	}
	tallyDumb(currentTally, e);
}
function onCustomSubstateUpdate(substate, e) {
	if (substate == 'results') {
		if (FlxG.keys.justPressed.F5)
			FlxG.resetState();
		resultsUpdate(FlxG.state.subState, e);
	}
}
function createTally(inst, x, y, color, score) {
	var grp = new FlxTypedSpriteGroup(x, y);
	grp.scrollFactor.set();
	grp.cameras = [cam];
	grp.color = color;
	inst.add(grp);
	tallies.push({first: false, tally: 0, score: Math.floor(score), wait: 0, group: grp});
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
			i += 1;
		}
		var i = 0;
		for (num in tallyGrp.members) {
			num.animation.play(count.charAt(i), true);
			i += 1;
		}
	}
	return (tally.wait >= 1);
}
function createAlphabet(group, x, y, text) {
	var letters:Array = text.split('');
	var i:Int = 0;
	var dist:Int = 34;
	var angle:Int = -4.4;
	var angleRad:Float = angle / 180 * Math.PI;
	for (c in letters) {
		var isUpper:Bool = (c == c.toUpperCase());
		
		c = switch (c.toLowerCase()) {
			case 'á', 'à', 'â', 'ä': 'a';
			case 'é', 'è', 'ê', 'ë': 'e';
			case 'í', 'ì', 'î', 'ï': 'i';
			case 'ó', 'ò', 'ô', 'ö': 'o';
			case 'ú', 'ù', 'û', 'ü': 'u';
			default: c;
		}
		if (isUpper)
			c = c.toUpperCase();
		
		var char = characters.indexOf(c);
		if (char >= 0) {
			var letter:FlxSprite = new FlxSprite(x + i * Math.cos(angleRad) * dist, y + i * Math.sin(angleRad) * dist).loadGraphic(Paths.image('resultScreen/alphabet'), true, 392 / 8, 496 / 8);
			letter.y -= Math.cos(angle) * letter.height;
			letter.antialiasing = ClientPrefs.data.antialiasing;
			letter.animation.add('letter', [char], 24, true);
			letter.animation.play('letter');
			letter.angle = angle;
			group.add(letter);
			i += 1;
		} else if (c == ' ') {
			i += 1;
		}
	}
}
function createRatingNums(group, x, y, rating) {
	var clearPercentSmall:FlxTypedSpriteGroup = new FlxTypedSpriteGroup();
	var text = rating + '%';
	var chars:Array = text.split('');
	chars.reverse();
	var i:Int = 0;
	for (char in chars) {
		var sprite:FlxSprite = new FlxSprite(x - i * 32, y + i * 4);
		if (char == '%') {
			sprite.loadGraphic(Paths.image('resultScreen/clearPercent/clearPercentTextSmall'));
			sprite.offset.y = -20;
			sprite.offset.x = -5;
		} else {
			sprite.frames = Paths.getSparrowAtlas('resultScreen/clearPercent/clearPercentNumberSmall');
			sprite.animation.addByPrefix('sprite', 'number ' + char, 24, true);
			sprite.offset.y = -12;
			sprite.offset.x = -5;
			sprite.animation.play('sprite');
		}
		//sprite.y -= sprite.height;
		clearPercentSmall.add(sprite);
		sprite.antialiasing = ClientPrefs.data.antialiasing;
		i += 1;
	}
	group.add(clearPercentSmall);
	return clearPercentSmall;
}
function moveAlphabets() { //move alphabet and stuff
	var rm = Math.sin(-4.4 / 180 * Math.PI);
	grpInfoTexts.velocity.x = -100;
	grpInfoTexts.velocity.y = Math.abs(100 * rm);
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