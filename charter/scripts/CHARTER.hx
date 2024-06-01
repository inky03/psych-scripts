import Main;
import psychlua.LuaUtils;
import flixel.text.FlxText;
import flixel.text.FlxTextBorderStyle;
import flixel.addons.display.FlxBackdrop;
import flixel.addons.display.FlxGridOverlay;
import flixel.group.FlxTypedSpriteGroup;
import flixel.math.FlxRect;
import openfl.text.TextFormat;
import backend.Difficulty;

import flixel.addons.ui.FlxUI;
import flixel.addons.ui.FlxUIButton;

using StringTools;

var base_strum = null;

var curQuant:Int = 4;
var quant:Array = [4, 8, 12, 16, 20, 24, 32, 48, 64, 96, 192];

var chartingGui = null;
var frontNotes = null;
var killNotes:Array = [];
var removeNotes:Array = [];
var sectionNotes:Array = [];
var tospawnNotes:Array = [];
var spawnedSectionNotes:Map = [];
var spawnedSections:Map = [];
var heldNotes:Array = [];
var gridLines = null;
var grid = null;
var selectionBox = null;
var selectionLine = null;
var quantSprite = null;
var quantText = null;

var smoothGridY = 0;
var gridWidth = 0;
var base_x = 0;
var base_y = 0;
var base_yo = 0;
var downscroll:Bool = false;
var charterPaused:Bool = true;

var curBpmChange = -1;
var curSectionInfo = null;
var bpmChanges:Array = [];
var sections:Array = [];
var sectionQ:Array = [];
var denominator:Int = 2;

var uiSmoothScale:Float = .5;
var uiScale:Float = 1;
var uiBoom:Float = 1;
var spamTimer:Float = -1;

var stepCrochet = 0;
var beatCrochet = 0;

var sectionLength:Int = 4;
var curSection:Int = -1;
var prevBeat:Int = -1;
var curBeat:Int = -1;
var curStep:Int = -1;
var curDecStep:Int = 0;
var stepOffset:Float = 0;

var sounds:Array = []; //avoid audio stress

function playSound(sound, vol) {
	if (sound == null || sounds.contains(sound)) return;
	FlxG.sound.play(sound, vol);
	sounds.push(sound);
}
function inArray(array, pos) { //work around to hscript being ass
    var i = 0;
    for (item in array) {
        if (i == pos) { return item; }
        i ++;
    }
    return null;
}
function onCreate() {
	game.allowDebugKeys = false;
	game.skipArrowStartTween = true;
	game.skipCountdown = true;
	if (game.vocals != null) {
		game.vocals.pause();
		game.vocals.stop();
	}
	charterPaused = true;
}
function mapSections() {
	var sectionBeats:Int = 4;
	var beat:Int = 0;
	var bpm:Int = Std.parseFloat(PlayState.SONG.bpm);
	var i:Int = 0;
	var tempSections:Array = [];
	var ms = 0;
	for (section in PlayState.SONG.notes) {
		if (section.sectionBeats != null) sectionBeats = section.sectionBeats;
		else sectionBeats = 4;
		var changeLength:Bool = (i <= 0);
		var changeBPM = ((section.changeBPM && section.bpm != null) || i <= 0);
		var info = {id: i, beat: beat, beatLength: sectionBeats, denominator: 4};
		if (changeBPM) {
			if (section.changeBPM && section.bpm != null) bpm = section.bpm;
			bpmChanges.push({beat: beat, bpm: bpm});
		}
		sections.push(info);
		sectionQ.push(beat); //quick access without needing to loop through the whole sections array
		var oldBeat = beat;
		beat += sectionBeats;
		tempSections.push({start: oldBeat * 4, end: beat * 4});
		sectionNotes.push({id: i, notes: [], startStep: oldBeat * 4, endStep: oldBeat});
		i ++;
	}
	//testing
	/*bpmChanges.push({beat: 1.5, bpm: PlayState.SONG.bpm * .5});
	bpmChanges.push({beat: 2.5, bpm: PlayState.SONG.bpm * 3});
	bpmChanges.push({beat: 4, bpm: PlayState.SONG.bpm});
	bpmChanges.push({beat: 6, bpm: PlayState.SONG.bpm * .5});
	bpmChanges.push({beat: 12, bpm: PlayState.SONG.bpm * 2});
	bpmChanges.push({beat: 14, bpm: PlayState.SONG.bpm * 6});
	bpmChanges.push({beat: 20, bpm: PlayState.SONG.bpm * 1});*/
	sortBpmChanges();
	
	//we loop through this an excruciating amount of times
	i = 0;
	var tempNotes:Array = [];
	var stepOff = 1 / 192;
	for (section in PlayState.SONG.notes) { //sort notes (if theyre in the wrong sections)
		if (section.sectionNotes == null) continue;
		var mustHit = section.mustHitSection;
		for (note in section.sectionNotes) {
			var ms:Float = inArray(note, 0);
			var step:Float = stepFromMS(ms);
			var data:Int = inArray(note, 1);
			var length:Float = stepFromMS(ms + inArray(note, 2)) - step;
			var mynote = new Note(step, data % 4, null, false, true);
			mynote.mustPress = (mustHit == (data < 4));
			
			noteMakeSustain(mynote, length);
			tempNotes.push(mynote);
			
			var a:Int = 0;
			for (tsection in tempSections) {
				if (step + stepOff >= tsection.start && step + stepOff < tsection.end) {
					var sec = inArray(sectionNotes, a);
					sec.notes.push(mynote);
					sec.endStep = Math.max(sec.endStep, step + length);
					break;
				}
				a ++;
			}
			i ++;
		}
	}
	tempNotes.sort((a, b) -> return a.strumTime - b.strumTime);
	sectionBeats = 4; //lol
	/*while (ms < FlxG.sound.music.length) { //fill in missing sections
		sections.push({beat: beat, beatLength: sectionBeats, changeBeats: false});
		sectionQ.push(beat);
		beat += sectionBeats;
		debugPrint('clone section');
	}*/
	return sections;
}
function sortBpmChanges() bpmChanges.sort((a, b) -> a.beat - b.beat);
function onDestroy() {
	FlxG.mouse.visible = false;
	Main.fpsVar.alpha = 1;
}
function onCreatePost() {
	var loadBtn = new FlxUIButton(10, 10, 'Load Song', () -> {});
	loadBtn.resize(120, 24);
	loadBtn.setLabelFormat('vcr.ttf', 15, -1);
	loadBtn.x = FlxG.width - loadBtn.width - 10;
	loadBtn.getLabel().offset.y = 2;
	loadBtn.color = 0xff806060;
	loadBtn.label.color = -1;
	loadBtn.cameras = [game.camOther];
	game.add(loadBtn);
	
	var saveBtn = new FlxUIButton(10, 39, 'Save Song', () -> {});
	saveBtn.resize(120, 24);
	saveBtn.setLabelFormat('vcr.ttf', 15, -1);
	saveBtn.x = FlxG.width - saveBtn.width - 10;
	saveBtn.getLabel().offset.y = 2;
	saveBtn.color = 0xff608060;
	saveBtn.label.color = -1;
	saveBtn.cameras = [game.camOther];
	game.add(saveBtn);
	
	selectionBox = new FlxSprite().makeGraphic(1, 1, -1);
	selectionBox.alpha = .5;
	selectionBox.blend = 0;
	//selectionLine = new LineStyle();
	//selectionLine.thickness = 3;
	//selectionLine.color = 0xff00ff00;
	selectionBox.cameras = [game.camHUD];
	game.add(selectionBox);
	
	game.camGame.visible = false;
	game.camZoomingMult = 0;
	game.camZoomingDecay = 0;
	game.isCameraOnForcedPos = true;
	game.spawnTime = 4000;
	Main.fpsVar.alpha = .125;
	
	downscroll = ClientPrefs.data.downScroll;
	
	var i = 0;
	var base_strum_x = (FlxG.width - (112 * game.strumLineNotes.members.length)) * .5;
	for (strum in game.strumLineNotes.members) {
		strum.x = base_strum_x + 112 * i;
		strum.scrollFactor.set(1, 1);
		i ++;
	}
	while (game.unspawnNotes.length > 0) game.unspawnNotes.shift();
	
	FlxG.mouse.visible = true;
	
	//game.dad.cameras = [game.camHUD];
	//game.boyfriend.cameras = [game.camHUD];
	//game.camGame.visible = false;
	game.boyfriend.stunned = true; //pwned!
	
	var dim = new FlxSprite().makeGraphic(1, 1, 0x10ffffff);
	dim.alpha = 1;
	dim.scale.set(FlxG.width, FlxG.height);
	dim.updateHitbox();
	dim.cameras = [game.camHUD];
	var min = Math.min(game.members.indexOf(game.dad), game.members.indexOf(game.boyfriend));
	game.insert(0, dim);
	
	base_strum = inArray(game.strumLineNotes.members, 0);
	grid = new FlxTypedSpriteGroup(FlxG.width, base_strum.y);
	grid.updateHitbox();
	grid.cameras = [game.camHUD];
	var gridPos:Int = game.members.indexOf(game.noteGroup) - 1;
	game.insert(gridPos, grid);
	base_y = base_strum.y;
	//game.songSpeed = 1;
	//game.songSpeed = 1 / .45 / stepCrochet * 112;
	gridLines = new FlxTypedSpriteGroup();
	gridLines.cameras = [game.camHUD];
	game.insert(gridPos + 1, gridLines);
	
	game.dad.setPosition(-game.boyfriend.width * .5, FlxG.height - game.dad.height * 1.5 - 100);
	game.boyfriend.setPosition(FlxG.width - game.boyfriend.width * 2, FlxG.height - game.boyfriend.height * 1.5 - 100);
	
	frontNotes = new FlxTypedSpriteGroup();
	frontNotes.cameras = [game.camHUD];
	game.insert(game.members.indexOf(game.noteGroup) + 1, frontNotes);
	
	var border:Int = 25;
	for (grp in [game.opponentStrums.members, game.playerStrums.members]) {
		gridWidth += 112 * grp.length;
		grid.x = Math.min(grid.x, inArray(grp, 0).x - border);
	}
	gridWidth += border * 2;
	
	quantSprite = new FlxSprite(grid.x + gridWidth, 0);
	quantSprite.antialiasing = ClientPrefs.data.antialiasing;
	quantSprite.frames = Paths.getSparrowAtlas('quant');
	quantSprite.animation.addByPrefix('quant', 'quant', 0, false);
	quantSprite.animation.play('quant');
	quantSprite.setGraphicSize(quantSprite.width * .65);
	quantSprite.updateHitbox();
	game.uiGroup.add(quantSprite);
	
	quantText = new FlxText(quantSprite.x - 6, 0, 100, curQuant);
	quantText.setFormat(Paths.font('vcr.ttf'), 32, -1, 'center', FlxTextBorderStyle.OUTLINE, 0xff000000);
	quantText.borderSize = 2;
	game.uiGroup.add(quantText);
	
	game.scoreTxt.alignment = 'center';
	game.scoreTxt.fieldWidth = FlxG.width;
	game.scoreTxt.x = 0;
	
	for (spr in [game.iconP1, game.iconP2, game.timeBar, game.healthBar, game.scoreTxt, game.timeTxt, game.botplayTxt]) game.uiGroup.remove(spr);
	
	base_yo = base_strum.height * .5;//112 * mult * .5;
	
	//game.camHUD.flashSprite.scaleY = -1; note to self
	mapSections();
	makeTexts();
	doBPMChanges(false);
	conductorStuffs(false);
	updateUIPos(base_x, base_y);
	
	return Function_Continue;
}

var chartingInfoText = null;
var titleText = null;
function makeTexts() {
	chartingGui = new FlxTypedSpriteGroup();
	chartingGui.cameras = [game.camOther];
	game.add(chartingGui);
	
	var diff = Difficulty.getString().toLowerCase();
	var diffSprite = new FlxSprite(12, 12).loadGraphic(Paths.image('menudifficulties/' + diff));
	diffSprite.antialiasing = ClientPrefs.data.antialiasing;
	diffSprite.setGraphicSize(diffSprite.width * .5);
	diffSprite.updateHitbox();
	diffSprite.alpha = .75;
	chartingGui.add(diffSprite);
	
	titleText = new Alphabet(diffSprite.width + 32, 10, PlayState.SONG.song);
	titleText.setScale(.55);
	titleText.alpha = .75;
	chartingGui.add(titleText);
	
	var warningText = simpleText(8, 56, '!! WARNING WARNING WARNING !!\nyou can\'t save/load songs in the current state!!', 18);
	warningText.alpha = .75;
	warningText.color = 0xffff80a0;
	chartingGui.add(warningText);
	
	var version:String = '0.1.0';
	var versionText = simpleText(0, FlxG.height - 10, 'v' + version, 21);
	versionText.y -= versionText.height;
	versionText.fieldWidth = FlxG.width - 10;
	versionText.alignment = 'right';
	versionText.alpha = .3;
	chartingGui.add(versionText);
	
	chartingInfoText = simpleText(8, 0, '', 21);
	chartingInfoText.alpha = .75;
	chartingGui.add(chartingInfoText);
	updateTexts();
}

function simpleText(x, y, string, size) {
	var text = new FlxText(x, y, 0, string);
	text.antialiasing = ClientPrefs.data.antialiasing;
	text.setFormat(Paths.font('vcr.ttf'), size, -1, 'left', FlxTextBorderStyle.OUTLINE, 0xff000000);
	return text;
}
function updateTexts() {
	if (chartingInfoText == null) return;
	chartingInfoText.text =
	'BPM: ' + Conductor.bpm +
	'\n' + sectionLength + '/4\n' +
	(Conductor.songPosition >= 0 ?
	'\n' +
	'\ntime: ' + num_fixed(Conductor.songPosition / 1000, 2) + ' / ' + num_fixed(game.songLength / 1000, 2) + 's' +
	/*'\nDEBUG MS -> STEP ' + num_fixed(stepFromMS(Conductor.songPosition), 2) +
	'\nDEBUG NOTES SPAWNED ' + (frontNotes.length + backNotes.length) +*/
	'\nstep: ' + curStep +
	'\nbeat: ' + curBeat +
	'\nbar: ' + curSection: '') +
	'\nnotes spawned: ' + frontNotes.length + ' (' + tospawnNotes.length + ' queued)';
	chartingInfoText.y = FlxG.height - chartingInfoText.height - 8;
}
function isSection(beat) return sectionQ.contains(beat);
function BPMms(BPM) return Math.max(60000 / BPM, 1);
function makeGrid(section) {
	if (section >= sections.length || section < 0) return;
	
	var prevSection = inArray(sections, section - 1);
	var sectionInfo = inArray(sections, section);
	if (sectionInfo == null) {
		debugPrint('WARNING: SECTION FAIL (sec' + section + ')', 0xffff00);
		return;
	}
	
	var m = 1;//(sectionInfo.denominator / 4);
	var sectionBeats = sectionInfo.beatLength * m;
	var gridHeight = 112;
	
	var gridGrp = new FlxTypedSpriteGroup();
	gridGrp.setPosition(0, sectionInfo.beat * (downscroll ? -1 : 1) * gridHeight);
	grid.add(gridGrp);
	
	/*var gridSprite = FlxGridOverlay.create(1, gridHeight, 1, sectionBeats * gridHeight, true, 0x06ffffff, 0x0bffffff);
	gridSprite.scale.x = gridWidth;//gridHeight);
	gridSprite.updateHitbox();
	if (downscroll) {
		gridSprite.flipY = true;
		gridSprite.y -= gridSprite.height;
	}
	gridGrp.add(gridSprite);*/
	
	for (i in 0...sectionBeats) {
		if (i == 0) { //section text lol
			var gridText = new FlxText(-260, 0, 240, section);
			gridText.setFormat(Paths.font('vcr.ttf'), 40, -1, 'right', FlxTextBorderStyle.OUTLINE, 0xff000000);
			gridText.y -= gridText.height * .5;
			gridGrp.add(gridText);
		}
		var gridLine = new FlxSprite().makeGraphic(1, 1, -1);
		gridLine.scale.set(gridWidth, (i == 0 ? 10 : 4));
		gridLine.updateHitbox();
		gridLine.y = -gridLine.height * .5 - i * gridHeight / m * (downscroll ? 1 : -1);
		gridLine.alpha = (i > 0 ? .125 : .65);
		gridGrp.add(gridLine);
	}
	
	var changesMeasure:Bool = false;
	changesMeasure = (prevSection == null || prevSection.denominator != sectionInfo.denominator || prevSection.beatLength != sectionInfo.beatLength);
	var firstMeasure = null;
	for (change in bpmChanges) {
		if (change.beat >= sectionInfo.beat && change.beat < sectionInfo.beat + sectionBeats) {
			var measureString:String = change.bpm + ' BPM';
			//if (sectionInfo.changeBeats) measureString += (measureString.length > 0 ? '\n' : '') + sectionInfo.beatLength + '/4';
			var pos = -(change.beat - sectionInfo.beat) * gridHeight * (downscroll ? 1 : -1);
			var measureText = new FlxText(gridWidth + 90, pos, 240, measureString);
			measureText.setFormat(Paths.font('vcr.ttf'), 24, -1, 'left', FlxTextBorderStyle.OUTLINE, 0xff000000);
			measureText.antialiasing = ClientPrefs.data.antialiasing;
			measureText.y -= measureText.height * .5;
			measureText.alpha = .75;
			gridGrp.add(measureText);
			if (change.beat <= sectionInfo.beat) firstMeasure = measureText;
		}
	}
	if (changesMeasure) { //haha this is so dumb.
		var sigText:String = sectionInfo.beatLength + '/' + sectionInfo.denominator;
		if (firstMeasure != null) {
			firstMeasure.text += '\n' + sigText;
		} else {
			var measureText = new FlxText(gridWidth + 90, 0, 240, sigText);
			measureText.setFormat(Paths.font('vcr.ttf'), 24, -1, 'left', FlxTextBorderStyle.OUTLINE, 0xff000000);
			measureText.antialiasing = ClientPrefs.data.antialiasing;
			measureText.y -= measureText.height * .5;
			measureText.alpha = .75;
			gridGrp.add(measureText);
		}
	}
	return gridGrp;
}

function spawnSections(sec) {
	var beat = curDecStep * .25;
	for (section in sections) {
		var k = section.id;
		var diff:Float = section.beat - beat;
		var offscreen:Bool = Math.abs(diff - (diff > 0 ? section.beatLength : 0)) > 16;
		if (offscreen) {
			if (spawnedSections.exists(k)) {
				var grp = spawnedSections.get(k);
				for (item in grp.members) item.destroy();
				grid.remove(grp, true);
				grp.destroy();
				spawnedSections.remove(k);
			}
			continue;
		}
		if (!spawnedSections.exists(k)) {
			var grid = makeGrid(section.id);
			spawnedSections.set(k, grid);
		}
	}
	var i = 0;
	for (section in sectionNotes) {
		var k = section.id;
		var onscreen:Bool = ((section.startStep - curDecStep < 64) && (section.endStep - curDecStep > -32));
		i ++;
		if (onscreen) {
			if (!spawnedSectionNotes.exists(k)) {
				spawnedSectionNotes.set(k, section.notes);
				for (note in section.notes) {
					if (note == null || !note.exists) { //clean dead notes (just in case)
						removeNotes.push(note);
						continue;
					}
					if (!tospawnNotes.contains(note)) tospawnNotes.push(note);
				}
				while (removeNotes.length > 0) {
					var i = removeNotes.shift();
					section.notes.remove(i);
				}
			}
			continue;
		}
		for (note in section.notes) tospawnNotes.remove(note);
		spawnedSectionNotes.remove(k);
	}
}
function coolStepHit() {}
function coolBeatHit(sectionHit) {
	playSound(Paths.sound(charterPaused ? 'charterScroll' : (sectionHit ? 'tickBar' : 'Metronome_Tick')), .75);
	uiBoom += (sectionHit ? .015 : .006);
	if (sectionHit) spawnSections(curSection);
	game.resyncVocals();
}
function coolSectionHit() {}
function pauseMusic() {
	FlxG.sound.music.pause();
	game.vocals.pause();
}
function scrollConductor(section, steps, offset) {
	var info = curSectionInfo;
	var pos = Math.max(curDecStep + steps + stepOffset * sign(steps) + (charterPaused || steps > 0 ? 0 : steps * .5), 0);
	var old = curDecStep;
	curDecStep = pos / Math.abs(steps);
	if (steps >= 0) curDecStep = Math.floor(curDecStep);
	else curDecStep = Math.ceil(curDecStep);
	curDecStep *= Math.abs(steps);
	
	Conductor.songPosition = msFromStep(curDecStep);
	conductorStuffs(true);
	updateMusicPos();
}

function updateBPM(bpm) {
	Conductor.bpm = bpm;
	beatCrochet = BPMms(Conductor.bpm);
	stepCrochet = beatCrochet / 4;
	return bpm;
}
function updateConductorSection(section) {
	if (section != null) {
		sectionLength = section.beatLength;
		curSectionInfo = section;
		//yeah thats it
	}
}
function updateMusicPos() {
	FlxG.sound.music.time = Conductor.songPosition;
	game.vocals.time = Conductor.songPosition;
	if (charterPaused) pauseMusic();
}
function doBPMChanges(fixPos) {
	var change = inArray(bpmChanges, curBpmChange);
	var nextChange = inArray(bpmChanges, curBpmChange + 1);
	var step = Math.max(curDecStep, 0);
	while (change != null && step < change.beat * 4) {
		curBpmChange --;
		change = inArray(bpmChanges, curBpmChange);
		nextChange = inArray(bpmChanges, curBpmChange + 1);
		
		updateBPM(change.bpm);
	}
	while (nextChange != null && step >= nextChange.beat * 4) {
		updateBPM(nextChange.bpm);
		
		curBpmChange ++;
		change = inArray(bpmChanges, curBpmChange);
		nextChange = inArray(bpmChanges, curBpmChange + 1);
	}
	return false;
}
function stepFromMS(ms) {
	var sub:Float = 0;
	var off:Float = 0;
	var next:Float = 0;
	var last = null;
	for (change in bpmChanges) {
		if (last != null) next = sub + (change.beat - off) * BPMms(last.bpm);
		if (next > ms) break;
		sub = next;
		off = change.beat;
		last = change;
	}
	var msf = (ms - sub) / (BPMms(last.bpm) * .25) + off * 4;
	return msf;
}
function msFromStep(step) {
	var add:Float = 0;
	var off:Float = 0;
	var last = null;
	for (change in bpmChanges) {
		if (change.beat * 4 > step) break;
		if (last != null) add += (change.beat - off) * BPMms(last.bpm);
		off = change.beat;
		last = change;
	}
	return (BPMms(last.bpm) * .25) * (step - off * 4) + add;
}
function conductorStuffs(recalc) { //custom conductor
	if (curDecStep < 0) return;
	
	var sectionHit:Bool = false;
	var beatHit:Bool = false;
	var stepHit:Bool = false;
	
	while (curDecStep + stepOffset < curStep) { //backtrack
		var advances = Math.min(Math.ceil((curDecStep - curStep) * .25) * 4, -1);
		stepHit = true;
		curStep += advances;
		curBeat = Math.floor(curStep * .25);
		if (curStep % 4 == 0 && (curDecStep - curStep) <= stepOffset) {
			beatHit = true;
			sectionHit = isSection(curBeat);
		}
		if (isSection(curBeat + 1)) {
			updateConductorSection(inArray(sections, curSection));
			if (curBeat < curSectionInfo.beat) {
				curSection --;
				updateConductorSection(inArray(sections, curSection));
			}
		}
	}
	if (recalc) {
		if (curStep % 4 == 0 && (curDecStep - curStep) <= stepOffset) {
			beatHit = true;
			sectionHit = isSection(curBeat);
		}
	}
	while (Math.floor(curDecStep + stepOffset) > curStep) { //go forward
		stepHit = true;
		curStep += Math.max(Math.floor((curDecStep - curStep) / 4) * 4, 1);
		if (curStep % 4 == 0) {
			beatHit = true;
			curBeat = Math.floor(curStep / 4);
			if (isSection(curBeat)) {
				sectionHit = true;
				curSection ++;
				updateConductorSection(inArray(sections, curSection));
			}
		}
	}
	if (sectionHit) coolSectionHit();
	if (beatHit) coolBeatHit(sectionHit);
	if (stepHit) coolStepHit();
}

function onEndSong() {
	game.endingSong = false;
	return Function_Stop;
}
function updateUIPos(x, y) {
	for (strum in game.strumLineNotes) strum.y = y;
	quantSprite.y = y + base_yo - quantSprite.height * .5;
	quantText.y = y + base_yo - quantText.height * .5 - 2;
	game.camHUD.scroll.x = x;
}
function updateQuant(add) {
	var q = quant.indexOf(curQuant);
	q += add;
	while (q < 0) q = Math.min(q + quant.length, quant.length - 1);
	while (q >= quant.length) q = Math.max(q - quant.length, 0);
	
	var nextQuant = inArray(quant, q);
	quantSprite.animation.curAnim.curFrame = q;
	quantText.text = nextQuant;
	curQuant = nextQuant;
	return nextQuant;
}
function onUpdatePost(e) {
	var downscrollMult = (downscroll ? 1 : -1);
	
	if (!charterPaused) {
		var prevBPM = Conductor.bpm;
		var stepLimit:Float = Math.ceil(curDecStep);
		var nextStep = curDecStep + e * 1000 / stepCrochet;
		curDecStep = Math.min(nextStep, stepLimit);
		doBPMChanges(false);
		var fix = (nextStep - curDecStep) * (Conductor.bpm / prevBPM); //todo make better
		curDecStep += fix;
		//debugPrint(fix);
		
		conductorStuffs(false, 0);
	} else doBPMChanges(false);
	
	if (FlxG.keys.justPressed.LEFT) updateQuant(-1);
	if (FlxG.keys.justPressed.RIGHT) updateQuant(1);
	
	if (FlxG.keys.firstPressed() >= 0) spamTimer += e; else spamTimer = -1; //scrolling
	if (FlxG.keys.firstJustPressed() >= 0) spamTimer = 0;
	var hit:Bool = (spamTimer == 0);
	var spam:Bool = (spamTimer >= .5);
	var off:Float = (charterPaused ? 1 : (e * 1000 + 2));
	
	stepOffset = (1 / stepCrochet);
	
	if (hit || spam) {
		if ((spam ? FlxG.keys.pressed.UP : FlxG.keys.justPressed.UP) || (spam ? FlxG.keys.pressed.DOWN : FlxG.keys.justPressed.DOWN)) {
			var add:Int = ((spam ? FlxG.keys.pressed.UP : FlxG.keys.justPressed.UP) ? 1 : -1);
			scrollConductor(curSection, add * downscrollMult * 16 / curQuant, off);
			updateMusicPos();
		}
		var forwardKey = (downscroll ? 33 : 34);
		var backKey = (downscroll ? 34 : 33);
		if (FlxG.keys.anyJustPressed([forwardKey]) || (FlxG.keys.anyPressed([forwardKey]) && spam)) { //forward a section
			var beat = (curSectionInfo == null ? 4 : (curSectionInfo.beat + curSectionInfo.beatLength));
			curDecStep = beat * 4;
			conductorStuffs(true);
			Conductor.songPosition = msFromStep(curDecStep);
			updateMusicPos();
		}
		if (FlxG.keys.anyJustPressed([backKey]) || (FlxG.keys.anyPressed([backKey]) && spam)) { //go back a section
			var beat = (curSectionInfo == null ? 0 : curSectionInfo.beat);
			if (curDecStep - stepOffset - (charterPaused ? 0 : 2) <= beat * 4 && curSection > 0) {
				curSection --;
				updateConductorSection(inArray(sections, curSection));
				beat = (curSectionInfo == null ? 0 : curSectionInfo.beat);
			}
			curDecStep = beat * 4;
			conductorStuffs(true);
			Conductor.songPosition = msFromStep(curDecStep);
			updateMusicPos();
		}
	}
	if (FlxG.keys.justPressed.HOME) {
		curSection = 0;
		updateConductorSection(inArray(sections, 0));
		curDecStep = 0;
		
		smoothGridY = Math.min(smoothGridY, 112);
		spawnSections(curSection);
		conductorStuffs(true);
		updateMusicPos();
		FlxG.sound.play(Paths.sound('cancelMenu'), 1);
	}
	if (FlxG.keys.justPressed.END) {
		curSection = sections.length - 1;
		updateConductorSection(inArray(sections, curSection));
		curDecStep = (curSectionInfo.beat + curSectionInfo.beatLength) * 4;
		
		smoothGridY = Math.max(smoothGridY, (curDecStep * .25 * 112) - 112);
		spawnSections(curSection);
		conductorStuffs(true);
		updateMusicPos();
		FlxG.sound.play(Paths.sound('cancelMenu'), 1);
	}
	
	Conductor.songPosition = msFromStep(curDecStep);
	if (charterPaused) {
		game.canPause = true;
		game.endingSong = false;
		pauseMusic();
	}
	if (Math.abs(FlxG.sound.music.time - Conductor.songPosition) > e * 1000 + 100) updateMusicPos();
	
	if (FlxG.keys.justPressed.SPACE) {
		for (strum in game.strumLineNotes) strum.playAnim('static');
		charterPaused = !charterPaused;
		if (!charterPaused) {
			if (Conductor.songPosition >= 0) {
				if (curDecStep % 4 == 0) coolBeatHit(isSection(curBeat));
				
				if (Conductor.songPosition < FlxG.sound.music.length) {
					FlxG.sound.music.time = Conductor.songPosition;
					if (!FlxG.sound.music.playing) FlxG.sound.music.play();
					FlxG.sound.music.resume();
					if (!game.vocals.playing) game.vocals.play();
					game.vocals.resume();
					updateMusicPos();
				}
			}
		} else FlxG.sound.play(Paths.sound('pauseSong'), 1);
	}
	
	uiBoom += (1 - uiBoom) * (1 - Math.exp(-e * 7));
	game.camHUD.zoom = uiSmoothScale * uiBoom;
	game.camGame.zoom = game.camHUD.zoom;
	game.camFollow.setPosition(FlxG.width * .5 + game.camHUD.scroll.x, FlxG.height * .5 + game.camHUD.scroll.y);
	game.camGame.scroll.x = game.camFollow.x - FlxG.width * .5;
	game.camGame.scroll.y = game.camFollow.y - FlxG.height * .5;
	
	// ui positioning
	var diff = (uiScale - uiSmoothScale);
	var updatePos:Bool = (diff > .0005);
	if (FlxG.mouse.wheel != 0) {
		uiScale += FlxG.mouse.wheel * .05;
		uiScale = Math.round(uiScale / .05) * .05;
		uiScale = Math.max(Math.min(uiScale, FlxG.width / gridWidth), .35);
		updatePos = true;
	}
	uiSmoothScale += diff * (1 - Math.exp(-e * 9));
	
	var clamp_x:Float = base_x;
	var clamp_y:Float = base_y;
	if (FlxG.mouse.pressed) {
		base_x -= FlxG.mouse.deltaScreenX;
		base_y += FlxG.mouse.deltaScreenY;
		updatePos = true;
	}
	if (FlxG.mouse.justReleased) updatePos = true;
	if (updatePos) {
		var maxX:Float = (FlxG.width - gridWidth * uiSmoothScale) * .5 / game.camHUD.zoom;
		var maxHeight:Float = FlxG.height / uiSmoothScale;
		var uiOffset:Float = (FlxG.height - maxHeight) * .5; //displacement from ui center
		clamp_x = Math.max(Math.min(base_x, maxX), -maxX);
		clamp_y = Math.max(Math.min(base_y, maxHeight - base_strum.height + uiOffset), uiOffset);
		updateUIPos(clamp_x, clamp_y);
		if (!FlxG.mouse.pressed) {
			base_x = clamp_x;
			base_y = clamp_y;
		}
	}
	
	if (FlxG.mouse.pressedRight) {
		var w = FlxG.mouse.x - selectionBox.x;
		var h = FlxG.mouse.y - selectionBox.y;
		selectionBox.scale.set(Math.abs(w), Math.abs(h));
		selectionBox.offset.set(-w * .5, -h * .5);
		selectionBox.visible = true;
	} else {
		selectionBox.setPosition(FlxG.mouse.x, FlxG.mouse.y);
		selectionBox.visible = false;
	}
	
	var gridOff = clamp_y + base_yo;
	var dist = curDecStep * .25 * 112;
	
	var targetY = dist;
	smoothGridY += (targetY - smoothGridY) * (charterPaused ? (1 - Math.exp(-e * 21)) : 1);
	grid.y = smoothGridY * downscrollMult + gridOff;
	
	/*for (item in grid.members) {
		if ((item.y * downscrollMult) > (item.height + maxHeight)) {
			grid.remove(item, true);
			item.destroy();
		}
	}*/
	
	charting();
	
	//ass note movement
	for (note in tospawnNotes) {
		if (!noteIsOnRange(note)) continue;
		
		removeNotes.push(note);
		if (frontNotes.members.contains(note)) continue;
		
		frontNotes.add(note);
		var body = note.extraData.get('body');
		if (body != null && !frontNotes.members.contains(body)) {
			frontNotes.insert(0, body);
			frontNotes.insert(0, note.extraData.get('tail'));
		}
	}
	while (removeNotes.length > 0) {
		var note = removeNotes.shift();
		tospawnNotes.remove(note);
	}
	
	var offsetPos:Float = Conductor.songPosition - 1;
	for (note in frontNotes) {
		var grp = (note.mustPress ? game.playerStrums : game.opponentStrums);
		var strum = inArray(grp.members, note.noteData);
		if (strum == null) continue;
		
		noteFollowStrum(note, strum);
		
		var gone:Bool = false;
		if (note.isSustainNote) {
			var par = note.extraData.get('parent');
			var held = note.extraData.get('held');
			if (!held) {
				if ((curDecStep > note.extraData.get('endStep') + 16 || curDecStep < note.strumTime) && !noteIsOnRange(par)) {
					killNotes.push(note);
					continue;
				}
			}
			var clipY:Float = par.y + par.height * .5;
			if (charterPaused || held) {
				if (downscroll) clipY = Math.min(clipY, strum.y + 112 * 4 + strum.height * .5);
				else clipY = Math.max(clipY, strum.y - 112 * 4 + strum.height * .5);
				clipNote(note, clipY, false);
				note.alpha = note.multAlpha;
				continue;
			}
			if (downscroll) clipY = Math.min(clipY, strum.y + strum.height * .5);
			else clipY = Math.max(clipY, strum.y + strum.height * .5);
			clipNote(note, clipY, false);
			gone = (curDecStep > note.extraData.get('startStep') + stepOffset);
			if (gone && note.clipRect != null && note.clipRect.height > 1) {
				strum.playAnim('confirm', true);
				strum.playAnim('hit', true);
				strum.resetAnim = 4 / 24 / game.playbackRate;
			}
			continue;
		} else gone = (curDecStep > note.strumTime + stepOffset);
		
		var alpha:Float = getNoteAlpha(note);
		if (!noteIsOnRange(note)) {
			killNotes.push(note);
			continue;
		}
		
		if (gone != note.extraData.get('gone')) {
			if (gone) {
				if (!charterPaused) {
					if (!note.isSustainNote && !charterPaused) {
						strum.playAnim('confirm', true);
						strum.playAnim('hit', true);
					}
					var end:Bool = note.animation.curAnim.name.endsWith('end');
					strum.resetAnim = ((note.tail.length > 0 && !end) ? 0 : (note.isSustainNote && !end ? 0 : (4 / 24 / game.playbackRate)));
					if (!note.isSustainNote) playSound(Paths.sound('hitsound'), .8);
				}
			}
			note.extraData.set('gone', gone);
		}
		
		note.alpha = Math.min(alpha, 1) * note.multAlpha * (gone ? .3 : 1);
	}
	kills(frontNotes);
	
	updateTexts();
	while (sounds.length > 0) sounds.shift();
	return Function_Continue;
}
function noteIsOnRange(note) {
	return (getNoteAlpha(note) > 0 || (curDecStep > note.strumTime && note.strumTime + note.sustainLength - curDecStep > -16));
}
function getNoteAlpha(note) {
	return (12 - Math.abs((curDecStep - note.strumTime) * .5 + 4));
}
function charting() {
	//1: 49 / 9: 57
	var i = 0;
	var step:Float = Math.round(curDecStep * curQuant / 16) / curQuant * 16;
	var section = inArray(sectionNotes, curSection);
	var quant = (16 / curQuant - .005);
	for (k in [49, 50, 51, 52, 53, 54, 55, 56]) {
		var mustHit:Bool = (i > 3);
		var data:Int = i % 4;
		if (FlxG.keys.anyJustPressed([k])) {
			var make:Bool = true;
			for (note in frontNotes) {
				if (note.isSustainNote || note.mustPress != mustHit || note.noteData != data) continue;
				if (Math.abs(note.strumTime - step) < quant) {
					var body = note.extraData.get('body');
					if (body != null) {
						frontNotes.remove(body, true);
						body.destroy();
						var tail = note.extraData.get('tail');
						frontNotes.remove(tail, true);
						tail.destroy();
					}
					section.notes.remove(note);
					frontNotes.remove(note, true);
					note.destroy();
					make = false;
					break;
				}
			}
			if (make) {
				var note = new Note(step, data, null, false, true);
				note.mustPress = mustHit;
				section.notes.push(note);
				frontNotes.add(note);
				heldNotes.push(note);
			}
		}
		var released:Bool = FlxG.keys.anyJustReleased([k]);
		if (FlxG.keys.anyPressed([k]) || released) {
			for (note in heldNotes) {
				var length = Math.round((curDecStep - note.strumTime) * curQuant / 16) / curQuant * 16;
				var body = note.extraData.get('body');
				if (released && note.mustPress == mustHit && note.noteData == data) {
					if (body != null) {
						body.extraData.remove('held');
						body.extraData.set('endStep', note.strumTime + length);
						note.extraData.get('tail').extraData.remove('held'); //lol
						note.extraData.get('tail').extraData.set('endStep', note.strumTime + length);
					}
					//debugPrint('unheld');
					heldNotes.remove(note);
					break;
				}
				noteChangeLength(note, length, true);
			}
		}
		i ++;
	}
}
function noteMakeSustain(mynote, length) {
	if (length < 1 - 1 / 192) return;
	mynote.sustainLength = length;
	
	var mybody = new Note(mynote.strumTime, mynote.noteData, null, true, true);
	mybody.mustPress = mynote.mustPress;
	mybody.extraData.set('length', length);
	mybody.extraData.set('startStep', mynote.strumTime);
	mybody.extraData.set('endStep', mynote.strumTime + length);
	mybody.extraData.set('parent', mynote);
	
	var mytail = new Note(mynote.strumTime + length, mynote.noteData, null, true, true);
	mytail.mustPress = mynote.mustPress;
	mytail.animation.play(inArray(Note.colArray, mynote.noteData) + 'holdend', true);
	mytail.scale.y = mytail.scale.x;
	mytail.updateHitbox();
	mytail.extraData.set('isTail', true);
	mytail.extraData.set('startStep', mynote.strumTime);
	mytail.extraData.set('endStep', mynote.strumTime + length);
	mytail.extraData.set('parent', mynote);
	
	mybody.extraData.set('tailOff', mytail.height);
	
	mynote.extraData.set('body', mybody);
	mynote.extraData.set('tail', mytail);
}
function noteChangeLength(note, steps, hold) {
	if (note == null) return;
	var quant = (16 / curQuant - .005);
	var body = note.extraData.get('body');
	var length = steps;
	if (length > quant && length >= 1) {
		//length wont be shorter than 1 step so to not make it visible,
		//but note lengths shorter than a step should also be very much possible!
		note.sustainLength = length;
		if (body == null) {
			noteMakeSustain(note, length);
			if (hold) {
				note.extraData.get('body').extraData.set('held', true);
				note.extraData.get('tail').extraData.set('held', true);
			}
			frontNotes.insert(0, note.extraData.get('body'));
			frontNotes.insert(0, note.extraData.get('tail'));
			//debugPrint('CREATE HOLD');
		} else {
			body.extraData.set('length', length);
			note.extraData.get('tail').strumTime = note.strumTime + length;
		}
	} else {
		note.sustainLength = 0;
		if (body != null) {
			frontNotes.remove(body, true);
			body.destroy();
			note.extraData.set('body', null);
			var tail = note.extraData.get('tail');
			frontNotes.remove(tail, true);
			tail.destroy();
			note.extraData.set('tail', null);
			//debugPrint('DESTROY HOLD');
		}
	}
}
function kills(group) {
	while (killNotes.length > 0) {
		var note = killNotes.shift();
		removeNotes.remove(note);
		group.remove(note, true);
		if (!note.isSustainNote) tospawnNotes.push(note);
	}
}
function noteFollowStrum(note, strum) {
	if (note == null || strum == null) return;
	var downscrollMult = (downscroll ? 1 : -1);
	var dist = -112 * note.strumTime * .25 * downscrollMult + grid.y - strum.y - strum.height * .5;
	note.distance = dist;
	note.x = strum.x + (strum.width - note.width) * .5;
	note.y = strum.y + dist + strum.height * (note.isSustainNote ? .5 : 0);
	if (note.extraData.get('isTail')) {
		if (!downscroll) note.y -= note.height;
		note.distance += note.height * downscrollMult; //omfg
	}
	else if (note.isSustainNote) {
		var funnieHeight = note.frameHeight - (note.antialiasing ? Math.min(note.frameHeight * .25, 4) : 0); //"fixes" that blurriness at the end of the hold
		note.scale.y = Math.max((112 * note.extraData.get('length') * .25 - note.extraData.get('tailOff')) / funnieHeight, 0);
		note.updateHitbox();
		if (downscroll) note.y -= note.height;
	}
	return true;
}
function clipNote(note, y, flip) {
	if (note == null || y == null) return;
	var funnieHeight:Float = note.frameHeight - (note.extraData.get('isTail') || !note.antialiasing ? 0 : Math.min(note.frameHeight * .25, 4));
	var clipPoint = Math.max(Math.min( ((downscroll == flip) ? y - note.y : note.y - y + note.height) / note.scale.y , funnieHeight), 0);
	note.clipRect = new FlxRect(0, clipPoint, note.frameWidth, funnieHeight - clipPoint);
}

//math
function num_fixed(n, places) { //"math"
	var rn:Float = round(n, places);
	var dn:String = Std.string(rn);
	if (dn % 1 <= 0) return dn + '.00'; //worst implementation ever
	dn = dn.rpad('0', Std.string(Math.floor(rn)).length + places + 1);
	return dn;
}
function sign(n) return (n > 0) - (n < 0);
function trunc(n) return Math.floor(Math.abs(n)) * sign(n);
function round(n, places) {
	var exp = Math.pow(10, places);
	return Math.round(n * exp) / exp;
}