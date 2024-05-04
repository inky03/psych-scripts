import backend.Difficulty;
import objects.Note;
import tjson.TJSON as Json;

var loaded:Bool = false;
var save:Int = 0;
/*
SAVING MODES:
0 - dont save (only play chart)
1 - save this difficulty
2 - save ALL difficulties
every chart will be exported as songname-difficultyBACK.json
DOESNT WORK RIGHT NOW! keep it at 0 unless you want slightly slower load 
*/

/*
TODO
- implement BPM changes (theyre ms based now)
- implement time sig changes
- save mode (you can just use other tools for that though, this is really shoddy)
*/

var startingBPM:Float = 100;

function onCreate() {
	var diff = Difficulty.getString().toLowerCase();
	var path_chart = Paths.modsJson(game.songName + '/' + game.songName + '-chart');
	var path_metadata = Paths.modsJson(game.songName + '/' + game.songName + '-metadata');
	
	if (FileSystem.exists(path_metadata)) {
		//debugPrint('LOAD METADATA');
		var file = File.getContent(path_metadata);
		var metadata = Json.parse(file);
		
		var timeChanges = [];
		for (i in 0 ... metadata.timeChanges.length) {
			var change = metadata.timeChanges[i];
			var data = {
				bpm: change.bpm
			};
			if (i > 0) {
				//debugPrint('bpm change found');
				timeChanges.push(data.bpm);
			} else {
				startingBPM = data.bpm;
				PlayState.SONG.bpm = startingBPM;
				Conductor.crochet = 60000 / startingBPM;
			}
		}
		PlayState.SONG.artist = metadata.artist;
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
		
		var finalChart:Array = [];
		for (diffic in diffs) {
			var fnfNotes = [];
			var notes = Reflect.field(chart.notes, diffic);
			var oldNote = null;
			for (note in notes) {
				var onote = [note.t, note.d, note.l];
				if (note.k != null) onote.push(note.k);
				fnfNotes.push(onote);
				/*if (!spawn) continue;
				var onote = new Note(note.t, note.d % 4, oldNote);
				onote.sustainLength = note.l;
				onote.mustPress = (note.d < 4);
				var oldNote = onote;
				game.unspawnNotes.push(onote);*/
			}
			if (diffic == diff) finalChart = fnfNotes;
			PlayState.SONG.notes[0].sectionNotes = fnfNotes;
		}
		for (event in chart.events) {
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
		//debugPrint(PlayState.SONG.notes.length + ' sections');
		PlayState.SONG.notes[0].sectionNotes = finalChart;
		
		var speed = Reflect.field(chart.scrollSpeed, diff);
		PlayState.SONG.speed = speed;
		loaded = true;
		//debugPrint(data.notes);
	}
	return Function_Continue;
}