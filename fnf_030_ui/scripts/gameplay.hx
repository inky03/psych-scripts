var holdSystem:Bool = true;
var leniency:Int = 50; //ms

var c_HEALTH_MAX:Float = 2; //doesnt do anything other than a base for health bonuses
var c_HOLD_BONUS:Int = 250; //score bonus per second

//more constants
function getHealth(h) return h / 100 * c_HEALTH_MAX;
var c_HEALTH_BONUS:Float = getHealth(7.5); //theres nothing in the decompile??? i made this up
var c_RATING_HEALTH:Map = [
	'sick' => getHealth(1.5),
	'good' => getHealth(.75),
	'bad' => getHealth(0),
	'shit' => getHealth(-1),
];
var c_MISS_PENALTY:Float = getHealth(4);
var c_GHOST_MISS_PENALTY:Float = getHealth(2);
var c_HOLD_DROP_PENALTY:Float = getHealth(0);
//var c_MINE_PENALTY:Float = getHealth(15);

var holdInfo:Array = [];
var skull:Float = 0; //well, songScore is an integer
var inputs:Array = [];
var ghost:Bool = false;
var miss:Bool = false;
var badBreaks:Bool = true;
var newScore:Bool = true;

function onCreatePost() {
	newScore = getModSetting('newscoring');
	miss = getModSetting('missbutlikeactually');
	badBreaks = getModSetting('badcombobreak');
	ghost = ClientPrefs.data.ghostTapping;
	ClientPrefs.data.ghostTapping = true;
	for (strum in game.strumLineNotes.members) holdInfo[strum.noteData] = {start: -1, end: 0, p: 0, g: 0};
	var i = game.unspawnNotes.length;
	var strum = game.playerStrums.members[0];
	game.unspawnNotes.sort(PlayState.sortByTime);
	return Function_Continue;
}
function onDestroy() ClientPrefs.data.ghostTapping = ghost;
function onKeyPress(k) {
	if (inputs.contains(k)) inputs.remove(k);
	else if (!ghost) {
		FlxG.sound.play(Paths.soundRandom('missnote', 1, 3), FlxG.random.float(0.1, 0.2));
		game.boyfriend.playAnim(game.singAnimations[k] + 'miss', true);
		game.health -= c_GHOST_MISS_PENALTY * game.healthLoss;
		game.songScore -= 10;
		game.RecalculateRating(true);
		if (miss) {
			game.callOnScripts('noteMissPress', [k]);
			game.combo = 0;
		}
	}
	return Function_Continue;
}
function noteMiss(note) {
	FlxG.sound.play(Paths.soundRandom('missnote', 1, 3), FlxG.random.float(0.5, 0.6));
	if (!note.isSustainNote && newScore) {
		var sub:Float = (note != null ? note.missHealth : .05);
		game.health += sub * game.healthLoss;
		game.health -= c_MISS_PENALTY;
	}
	return Function_Continue;
}
function goodNoteHitPre(note) if (!note.isSustainNote) inputs.push(note.noteData);
function goodNoteHit(note) {
	if (!holdSystem) return Function_Continue;
	if (!note.isSustainNote) {
		if (badBreaks && (note.rating == 'bad' || note.rating == 'shit')) {
			game.callOnHScript('makeGhostNote', [note]);
			game.combo = 0;
		}
		if (!newScore) return Function_Continue;
		if (!game.cpuControlled && note.sustainLength > 0) {
			var info = holdInfo[note.noteData];
			info.note = note;
			info.start = Math.min(Conductor.songPosition, note.strumTime); //why does this kinda work
			info.length = note.sustainLength;
			info.g = 0;
			info.p = 0;
			updateHoldData(info, Conductor.songPosition, false);
		}
		var health = c_RATING_HEALTH[note.rating];
		if (health == null) health = 0;
		game.health -= note.hitHealth * game.healthGain;
		game.health += health;
	}
	return Function_Continue;
}
function onKeyRelease(k) {
	var hold = holdInfo[k];
	if (hold != null && hold.start >= 0) {
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
	}
	return Function_Continue;
}
function onUpdatePost() {
	for (hold in holdInfo) if (hold.start >= 0) updateHoldData(hold, Conductor.songPosition, false);
	return Function_Continue;
}
function updateHoldData(hold, time, apply) {
	var p:Float = time - hold.start;
	if (p >= hold.length - (apply ? leniency : 0)) {
		p = hold.length;
		hold.start = -1;
	} else if (apply) game.health -= c_HOLD_DROP_PENALTY;
	
	var delta = Math.max(p - hold.p, 0); //deltatime
	skull += delta * c_HOLD_BONUS * .001; //account for rounding
	game.songScore += Math.floor(skull); //account for rounding
	if (game.guitarHeroSustains) game.health += delta * c_HEALTH_BONUS * .001;
	game.updateScore();
	skull %= 1;
	hold.p = p;
	hold.g += delta * c_HOLD_BONUS * .001;
	
	if (apply) hold.start = -1;
}