import flixel.group.FlxTypedSpriteGroup;

var milestoneGroup:FlxTypedSpriteGroup<FlxSprite>;
var enabled:Bool = false;
var effectStuff:FlxSprite = null;
var milestoneScreentime:Float = -1;
var milestoneComboSetup:Bool = false;
var milestoneCombo:Int = 0;
var milestoneNumbers:Array = [];
var milestoneTimer:FlxTimer = null;

var section = null;
var nextSection = null;
var currentSection:Int = 0;
var previousSection:Int = 0;

function onCreate() {
	enabled = getModSetting('combomilestone');
	if (!enabled) return Function_Continue;
	
	milestoneGroup = new FlxTypedSpriteGroup();
	milestoneGroup.cameras = [game.camHUD];
	game.add(milestoneGroup);
	
	Paths.sound('comboSound');
	Paths.getSparrowAtlas('comboMilestone');
	Paths.getSparrowAtlas('comboMilestoneNumbers');
	return Function_Continue;
}

function onSongStart() {
	if (!enabled) return Function_Continue;
	
	currentSection = game.curSection;
	section = getSection(currentSection);
	nextSection = getSection(currentSection + 1);
	return Function_Continue;
}

function inArray(array, pos) { //array access lags workaround???
    var i = 0;
    for (item in array) {
        if (i == pos) { return item; }
        i ++;
    }
    return null;
}

function getSection(section) return inArray(PlayState.SONG.notes, section);
function onBeatHit() {
	if (!enabled) return Function_Continue;
	
	currentSection = game.curSection; //stupid psych calls beat hit before updating the section
	if (currentSection > previousSection) {
		section = getSection(currentSection);
		nextSection = getSection(currentSection + 1);
	}
	
	var shouldShowComboText = (game.curBeat % 8 == 7 && (section != null && section.mustHitSection) && game.combo >= 5);
	var isEndOfSong = (game.songLength / Conductor.crochet /* fix later lol! */) < Std.int(Conductor.curBeat / 16);
	shouldShowComboText = shouldShowComboText && (isEndOfSong || (nextSection != null && !nextSection.mustHitSection));
	if (shouldShowComboText) {
		var milestone = Milestone(-100, 300, game.combo);
		var frameShit = 1 / 24 * 2;
		if (milestoneTimer != null) milestoneTimer.cancel();
		milestoneTimer = new FlxTimer().start(Conductor.crochet / 1000 * 1.25 - frameShit, forceFinish);
	}
	previousSection = currentSection;
	return Function_Continue;
}

function onUpdate(e) {
	if (effectStuff == null) return Function_Continue;
	
	if (milestoneScreentime >= 0) milestoneScreentime += e;
	var frame:Int = effectStuff.animation.curAnim.curFrame;
	if (frame == 17) effectStuff.animation.pause();
	if (frame == 2 && !milestoneComboSetup) setupCombo(effectStuff.x, effectStuff.y, combo);
	if (frame == 18) for (n in milestoneNumbers) n.animation.reset();
	if (frame >= 20) destroyNums();
	
	return Function_Continue;
}

function destroyNums() {
	while (milestoneNumbers.length > 0) {
		var n = milestoneNumbers.shift();
		milestoneGroup.remove(n);
		n.destroy();
	}
}

function Milestone(x, y, combo) {
	if (effectStuff != null) {
		milestoneGroup.remove(effectStuff);
		effectStuff.destroy();
		destroyNums();
	}
	FlxG.sound.play(Paths.sound('comboSound')); //this is set to happen when setupCombo is called but i think its better if its synced to the beat
	milestoneCombo = combo;
	milestoneScreentime = 0;
	milestoneComboSetup = false;
	effectStuff = new FlxSprite(x, y);
	effectStuff.frames = Paths.getSparrowAtlas('comboMilestone');
	effectStuff.animation.addByPrefix('main', 'NOTE COMBO animation', 24, false);
	effectStuff.animation.play('main');
	effectStuff.animation.finishCallback = () -> {
		milestoneGroup.remove(effectStuff);
		effectStuff.destroy();
		effectStuff = null;
	};
	effectStuff.setGraphicSize(effectStuff.width * .7);
	effectStuff.cameras = [game.camHUD];
	effectStuff.scrollFactor.set(.6, .6);
	milestoneGroup.add(effectStuff);
}
function setupCombo(x, y, combo) {
	milestoneComboSetup = true;
	var i = 0;
	while (milestoneCombo > 0) {
		var num = Std.string(milestoneCombo % 10);
		var combo = new FlxSprite(450 - (100 * i) + x - 20, 20 + 14 * i + y);
		combo.frames = Paths.getSparrowAtlas('comboMilestoneNumbers');
		combo.cameras = [game.camHUD];
		milestoneGroup.add(combo);
		milestoneNumbers.push(combo);
		combo.scrollFactor.set(effectStuff.scrollFactor.x, effectStuff.scrollFactor.y);
		combo.animation.addByPrefix(num, num, 24, false);
		combo.animation.play(num);
		combo.setGraphicSize(combo.width * 0.7);
		
		milestoneCombo = Math.floor(milestoneCombo / 10);
		i ++;
	}
}
function forceFinish() {
	if (milestoneScreentime < .9) new FlxTimer().start(Conductor.crochet / 1000 * .25, forceFinish);
	else effectStuff.animation.play('main', true, false, 18);
}
/*function updateSection() {
	var beats:Int = 0;
	var i:Int = 0;
	for (section in PlayState.SONG.notes) {
		var sectionBeats:Int = section.sectionBeats;
		if (sectionBeats == null) sectionBeats = 4;
		beats += sectionBeats;
		
		if (game.curBeat < beats) return i;
		i ++;
	}
	return null;
}*/