import backend.Difficulty;
import objects.Note;
import tjson.TJSON as Json;

var loaded:Bool = false;
var save:Int = 0;
/*
SAVING MODES:
DOESNT WORK RIGHT NOW! keep it at 0 unless you want slightly slower load 
*/
var overrides = [
	'pico-playable' => 'pico-player'
];
//if you want to replace characters by other ones

/*
TODO
- implement BPM changes (theyre ms based now)
- implement time sig changes
- save mode (you can just use other tools for that though (or you know, save it with the chart editor), this is really shoddy)
*/

var generate:Bool = true;
var startingBPM:Float = 100;

function onCreatePost() {
	if (!generate) return Function_Continue;
	
	var sectionBeats:Int = 4;
	var crochet:Float = BPMms(PlayState.SONG.bpm);
	var beats:Int = 0;
	var time:Int = 0;
	for (section in PlayState.SONG.notes) {
		sectionBeats = section.sectionBeats;
		if (sectionBeats == null) sectionBeats = 4;
		if (section.changeBPM) crochet = BPMms(section.bpm);
		beats += sectionBeats;
		time += crochet * sectionBeats;
	}
	while (time < game.inst.length) { //generate filler sections to reach song length completely
		var sec = blankSection();
		sec.sectionBeats = sectionBeats;
		PlayState.SONG.notes.push(sec);
		time += crochet * sectionBeats;
	}
	return Function_Continue;
}
function onCreate() {
	//only generate if chart is blank (so the chart is not overwritten when editing in the chart editor!)
	for (section in PlayState.SONG.notes) generate = generate && (section.sectionNotes.length <= 0);
	if (!generate) return Function_Continue;
	
	var diff = Difficulty.getString().toLowerCase();
	var path_chart = Paths.modsJson(game.songName + '/' + game.songName + '-chart');
	var path_metadata = Paths.modsJson(game.songName + '/' + game.songName + '-metadata');
	
	var timeChanges:Array = [];
	if (FileSystem.exists(path_metadata)) {
		//debugPrint('LOAD METADATA');
		var file = File.getContent(path_metadata);
		var metadata = Json.parse(file);
		
		for (i in 0 ... metadata.timeChanges.length) {
			var change = metadata.timeChanges[i];
			var data = {
				bpm: change.bpm
			};
			if (i > 0) {
				//debugPrint('bpm change found');
				timeChanges.push({newBpm: data.bpm});
			} else {
				startingBPM = data.bpm;
				PlayState.SONG.bpm = startingBPM;
				Conductor.crochet = BPMms(startingBPM);
			}
		}
		if (PlayState.SONG.artist == null) PlayState.SONG.artist = metadata.artist;
		if (metadata.songName != null && PlayState.SONG.song.toLowerCase() == metadata.songName.toLowerCase()) PlayState.SONG.song = metadata.songName;
		//yippee
		
		var playData = metadata.playData;
		if (playData != null) {
			var chars = playData.characters;
			if (chars != null) {
				if (chars.player != null) PlayState.SONG.player1 = overrideChara(chars.player);
				if (chars.opponent != null) PlayState.SONG.player2 = overrideChara(chars.opponent);
				if (chars.girlfriend != null) PlayState.SONG.gfVersion = overrideChara(chars.girlfriend);
				if (PlayState.SONG.gfVersion != null) PlayState.SONG.player3 = PlayState.SONG.gfVersion;
			}
		}
	}
	
	if (FileSystem.exists(path_chart)) {
		//debugPrint('LOAD CHART');
		var file = File.getContent(path_chart);
		var chart = Json.parse(file);
		
		var diffs:Array = Reflect.fields(chart.notes);
		if (diffs == null) {
			debugPrint('CHART CAN\'T LOAD!');
			return Function_Continue;
		}
		if (save < 2) {
			if (diffs.contains(diff)) diffs = [diff];
			else diffs = [diffs[Math.max(PlayState.storyDifficulty, diffs.length - 1)]];
		}
		
		var focus:Array = [];
		for (event in chart.events) {
			if (event.e == 'FocusCamera') focus.push({time: event.t, focus: event.v.char == 0});
			var values = event.v;
			var vala = event.e;
			var valb = event.e;
			var i = 0;
			for (v in Reflect.fields(values)) {
				vala += ',' + v;
				valb += ',' + Reflect.field(values, v);
				i ++;
			}
			var fin:Array = [event.t, [['030CEvent', vala, valb]]];
			game.makeEvent(fin);
		}
		focus.reverse();
		
		var section:Int = 0;
		var sectionBeats:Int = 4;
		var crochet:Float = BPMms(startingBPM);
		var lolCrochet:Float = 0;
		var addCrochet:Float = crochet * sectionBeats;
		PlayState.SONG.notes = [];
		for (diffic in diffs) {
			var fnfNotes:Array = [];
			var notes = Reflect.field(chart.notes, diffic);
			var oldNote = null;
			for (note in notes) {
				var onote = {t: note.t, d: note.d, l: note.l, k: note.k};
				var tt:Float = note.t + 2; //account for time Fluctuations
				if (tt > addCrochet) {
					var sec = null;
					while (tt > addCrochet) {
						sec = blankSection();
						PlayState.SONG.notes.push(sec);
						
						var hit:Bool = getMustHit(lolCrochet, focus);
						sec.mustHitSection = hit;
						
						lolCrochet += crochet * sectionBeats;
						addCrochet += crochet * sectionBeats;
					}
					if (sec != null) sec.sectionNotes = notesFromObjects(fnfNotes, !sec.mustHitSection);
					fnfNotes = [];
					section ++;
				}
				fnfNotes.push(onote);
			}
			if (fnfNotes.length > 0) {
				var hit:Bool = getMustHit(lolCrochet, focus);
				var sec = blankSection();
				sec.mustHitSection = hit;
				sec.sectionNotes = notesFromObjects(fnfNotes, !sec.mustHitSection);
				PlayState.SONG.notes.push(sec);
			}
			//if (diffic == diff) finalChart = fnfNotes;
			//debugPrint(PlayState.SONG.notes[section].sectionNotes == null);
			//PlayState.SONG.notes[section].sectionNotes = fnfNotes;
		}
		
		var speed = Reflect.field(chart.scrollSpeed, diff);
		PlayState.SONG.speed = speed;
		loaded = true;
	}
	
	return Function_Continue;
}

function overrideChara(char) return overrides.exists(char) ? overrides.get(char) : char;
function notesFromObjects(objects, shift) { //{t: time, d: data, l:length} -> [time, data, length]
	var realNotes:Array = [];
	for (n in objects) {
		if (shift) n.d = (n.d + 4) % 8;
		var dat:Array = [n.t, n.d, n.l];
		if (n.k != null) dat.push(n.k);
		realNotes.push(dat);
	}
	return realNotes;
}
function getMustHit(time, focusArray) {
	for (f in focusArray) if ((time + 10) >= f.time) return f.focus;
	return false;
}
function blankSection() {
	return {
		sectionBeats: 4,
		mustHitSection: true,
		sectionNotes: [],
	};
}
function BPMms(BPM) return Math.max(60000 / BPM, 1); //cant be THAT low