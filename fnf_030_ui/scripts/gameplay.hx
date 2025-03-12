var holdSystem:Bool = true;
var leniency:Int = 50; //ms

var c_HEALTH_MAX:Float = 2; //doesnt do anything other than serve as a base for health bonuses
var c_HOLD_BONUS:Int = 250; //score bonus per second

//more constants
function getHealth(h) return h / 100 * c_HEALTH_MAX;
var c_HEALTH_BONUS:Float = getHealth(7.5);
var c_RATING_HEALTH:Map = [
	'sick' => getHealth(1.5),
	'good' => getHealth(.75),
	'bad' => getHealth(0),
	'shit' => getHealth(-1),
];
var c_MISS_PENALTY:Float = getHealth(4);
var c_GHOST_MISS_PENALTY:Float = getHealth(2);
var c_HOLD_DROP_PENALTY:Float = getHealth(0);
var c_MINE_PENALTY:Float = getHealth(15);

var c_PBOT1_MISS = 160;
var c_PBOT1_PERFECT = 5;
var c_PBOT1_SCORING_OFFSET = 54.99;
var c_PBOT1_SCORING_SLOPE = .08;
var c_PBOT1_MAX_SCORE = 500;
var c_PBOT1_MIN_SCORE = 5;

var killInfo:Array = [];
var holdInfo:Array = [];
var skull:Float = 0; //well, songScore is an integer
var ghost:Bool = false;
var miss:Bool = false;
var badBreaks:Bool = true;

var useLegacy:Bool = false;
var useF028:Bool = false;
var usePBOT:Bool = false;

function getSetting(setting, def) {
	var setting = game.callOnHScript('getScrSetting', [setting, def]);
	return setting;
}
function onCreatePost() {
	var scoringSystem:String = getSetting('scoring', 'Funkin (PBOT1)');
	switch (scoringSystem) {
		case 'Funkin [LEGACY]':
			Conductor.safeZoneOffset = (10 / 60) * 1000;
			game.ratingsData[0].hitWindow = Conductor.safeZoneOffset * .2; //sick
			game.ratingsData[1].hitWindow = Conductor.safeZoneOffset * .75; //good
			game.ratingsData[2].hitWindow = Conductor.safeZoneOffset * .9; //bad
			useLegacy = true;
		case 'Funkin [WEEK 7]':
			Conductor.safeZoneOffset = (10 / 60) * 1000;
			game.ratingsData[0].hitWindow = Conductor.safeZoneOffset * .2; //sick
			game.ratingsData[1].hitWindow = Conductor.safeZoneOffset * .55; //good
			game.ratingsData[2].hitWindow = Conductor.safeZoneOffset * .8; //bad
			useF028 = true;
		case 'Funkin [PBOT1]':
			Conductor.safeZoneOffset = 160;
			game.ratingsData[0].hitWindow = 45; //sick
			game.ratingsData[1].hitWindow = 90; //good
			game.ratingsData[2].hitWindow = 135; //bad
			usePBOT = true;
		default:
	}
	holdSystem = getSetting('holdscoring', true);
	miss = getSetting('missbutlikeactually', false);
	badBreaks = getSetting('badcombobreak', true);
	ghost = ClientPrefs.data.ghostTapping;
	ClientPrefs.data.ghostTapping = true;
	return;
}
function onDestroy()
	ClientPrefs.data.ghostTapping = ghost;
function onGhostTap(k) {
	if (!ghost) {
		FlxG.sound.play(Paths.soundRandom('missnote', 1, 3), FlxG.random.float(0.1, 0.2));
		game.boyfriend.playAnim(game.singAnimations[k] + 'miss', true);
		game.health -= c_MISS_PENALTY * game.healthLoss;
		game.songScore -= 10;
		game.RecalculateRating(true);
		game.callOnScripts('noteMissPress', [k]);
		if (miss) {
			game.combo = 0;
			game.songMisses ++;
		}
		
		game.stagesFunc(function(stage:BaseStage) stage.noteMissPress());
	}
}
function onSpawnNote(note)
	if (note.noteType == 'Hurt Note')
		note.missHealth = c_MINE_PENALTY;
function noteMiss(note) {
	if (!note.hitCausesMiss || note.hitsound == 'hitsound') FlxG.sound.play(Paths.soundRandom('missnote', 1, 3), FlxG.random.float(0.5, 0.6));
	if (!note.isSustainNote && usePBOT) {
		var sub:Float = (note != null ? note.missHealth : .05);
		game.health -= c_MISS_PENALTY * game.healthLoss;
		game.health += sub * game.healthLoss;
	}
	return;
}
function goodNoteHit(note) {
	var rating = snipeRating(note.rating);
	switch (true) { //lmfao
		default:
		case useLegacy:
		case useF028:
		case usePBOT:
			scorePBOT(note, rating);
	}
	if (badBreaks && !note.isSustainNote && rating.ratingMod <= .5) {
		game.callOnHScript('makeGhostNote', [note]);
		game.combo = 0;
	}
	if (!holdSystem) return;
	if (!note.isSustainNote) {
		if (!game.cpuControlled && note.sustainLength > 0) {
			var info = {
				data: note.noteData,
				start: Math.min(Conductor.songPosition, note.strumTime),
				length: note.sustainLength,
				note: note,
				p: 0,
				g: 0
			};
			holdInfo.push(info);
			updateHoldData(info, Conductor.songPosition, false);
		}
		var health = c_RATING_HEALTH[note.rating];
		if (health == null) health = 0;
		game.health -= note.hitHealth * game.healthGain;
		game.health += health * game.healthGain;
	}
	game.updateScore();
	return;
}
function snipeRating(string) {
	for (rating in game.ratingsData) if (rating.name == string) return rating;
	return null;
}
function onPause() {
	if (!game.cpuControlled) clearHoldData(-1);
}
function onKeyRelease(k) {
	clearHoldData(k);
}
function clearHoldData(k) {
	for (hold in holdInfo) {
		if (k >= 0 && hold.data != k) continue;
		updateHoldData(hold, Conductor.songPosition, true);
		var note = hold.note;
		if (note != null) {
			for (child in note.tail) {
				child.kill(child);
				game.notes.remove(child, true);
				child.destroy();
			}
			note.tail = [];
		}
		hold.start = -1;
		killInfo.push(hold);
	}
}
function onUpdatePost(elapsed:Float) {
	for (kill in killInfo) holdInfo.remove(kill);
	for (hold in holdInfo) updateHoldData(hold, Conductor.songPosition, false);
}
function updateHoldData(hold, time, apply) {
	if (hold.start < 0) return;
	
	var p:Float = time - hold.start;
	if (p >= hold.length - (apply ? leniency : 0)) {
		p = hold.length;
		hold.start = -1;
		killInfo.push(hold);
	} else if (apply) game.health -= c_HOLD_DROP_PENALTY;
	
	var delta = Math.max(p - hold.p, 0); //deltatime
	skull += delta * c_HOLD_BONUS * .001; //account for rounding
	game.songScore += Math.floor(skull); //account for rounding
	skull %= 1;
	if (game.guitarHeroSustains) game.health += delta * c_HEALTH_BONUS * .001;
	game.updateScore();
	hold.p = p;
	hold.g += delta * c_HOLD_BONUS * .001;
	
	if (apply) hold.start = -1;
}

function scoreLegacy(note, rating) {
	if (rating != null) game.songScore -= rating.score;
}
function scorePBOT(note, rating) {
	if (rating != null) game.songScore -= rating.score;
	
	var timing = Math.abs(note.strumTime - Conductor.songPosition + ClientPrefs.data.ratingOffset);
	var score = c_PBOT1_MIN_SCORE;
	if (timing < c_PBOT1_PERFECT) score = c_PBOT1_MAX_SCORE;
	else if (timing < c_PBOT1_MISS) {
		var factor:Float = 1.0 - (1.0 / (1.0 + Math.exp(-c_PBOT1_SCORING_SLOPE * (timing - c_PBOT1_SCORING_OFFSET))));
		score = Math.floor(c_PBOT1_MAX_SCORE * factor + c_PBOT1_MIN_SCORE);
	}
	game.songScore += score;
}