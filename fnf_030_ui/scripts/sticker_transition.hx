import Main;
import Type;
import Reflect;
import flixel.FlxSubState;
import tjson.TJSON as JSON;
import backend.CustomFadeTransition;
import flixel.group.FlxTypedSpriteGroup;

var stickerSubState:FlxState;
var stickerImages:Array = [];
var stickerSounds:Array = [];
var stickerGroup:FlxTypedSpriteGroup;

function onCreatePost() {
	precacheStickers();
	FlxG.state.subStateOpened.add((subState:FlxSubState) -> {
		if (Std.isOfType(subState, CustomFadeTransition) && !subState.isTransIn)
			startStickerTransition(CustomFadeTransition.finishCallback);
	});
}
function precacheStickers() {
	var stickersPath:String = Paths.modFolders('images/transitionSwag/');
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
						var sticky:String = 'transitionSwag/' + sub + '/' + image;
						stickerImages.push(sticky);
						Paths.image(sticky);
					}
				}
			}
		}
	}
	var soundsPath:String = Paths.modFolders('sounds/stickersounds/');
	if (FileSystem.exists(soundsPath)) {
		for (sub in FileSystem.readDirectory(soundsPath)) {
			if (FileSystem.isDirectory(soundsPath + sub)) {
				for (snd in FileSystem.readDirectory(soundsPath + sub)) {
					var soundPath:String = 'stickersounds/' + sub + '/' + snd;
					var dot = soundPath.lastIndexOf('.');
					soundPath = soundPath.substring(0, dot < 0 ? soundPath.length : dot);
					var sound = Paths.sound(soundPath);
					if (sound != null) stickerSounds.push(sound);
				}
			}
		}
	}
}
function spawnStickers(inst:FlxState, callback:Dynamic) {
	var grpStickers = new FlxTypedSpriteGroup();
	grpStickers.cameras = [FlxG.cameras.list[FlxG.cameras.list.length - 1]];
	grpStickers.scrollFactor.set();
	
	var xPos:Float = -100;
	var yPos:Float = -100;
	while (xPos <= FlxG.width + 100) {
		var randomSticky:String = stickerImages[FlxG.random.int(0, stickerImages.length - 1)];
		var stickerSprite:FlxSprite = new FlxSprite(xPos, yPos).loadGraphic(Paths.image(randomSticky));
		stickerSprite.antialiasing = ClientPrefs.data.antialiasing;
		stickerSprite.angle = FlxG.random.int(-60, 70);
		stickerSprite.visible = false;
		grpStickers.add(stickerSprite);
		
		var excludePath = stickerSprite.graphic.key;
		excludePath = excludePath.substr(excludePath.indexOf('images/'));
		if (!Paths.dumpExclusions.contains(excludePath))
			Paths.dumpExclusions.push(excludePath);
		
		xPos += Math.max(stickerSprite.frameWidth * .5, 50);
		if (xPos >= FlxG.width + 100) {
			if (yPos <= FlxG.height + 100) {
				xPos = -100;
				yPos += FlxG.random.float(70, 120);
			}
		}
	}
	
	shuffleArray(grpStickers.members);
	
	var i:Int = 0;
	for (sticker in grpStickers.members) {
		if (grpStickers == null || !grpStickers.exists) return;
		if (sticker == null || !sticker.exists) continue;
		
		var timing = FlxMath.remapToRange(i, 0, grpStickers.members.length, 0, 0.9);
		var isLast:Bool = (i >= grpStickers.members.length - 1);
		new FlxTimer().start(timing, () -> {
			if (stickerSounds.length > 0)
				FlxG.sound.play(stickerSounds[FlxG.random.int(0, stickerSounds.length - 1)]);
			sticker.visible = true;
			var frameTimer:Int = (isLast ? 2 : FlxG.random.int(0, 2));
			new FlxTimer().start((1 / 24) * frameTimer, () -> {
				sticker.scale.x = sticker.scale.y = FlxG.random.float(0.97, 1.02);
				if (isLast)
					new FlxTimer().start(.5, () -> finishTransition(callback));
			});
		});
		i += 1;
	}
	if (grpStickers.length < 1) {
		new FlxTimer().start(.5, () -> finishTransition(callback));
		return;
	}
	
	var lastOne = grpStickers.members[grpStickers.members.length - 1];
	if (lastOne != null) { // original script by emi3
		lastOne.updateHitbox();
		lastOne.screenCenter();
		lastOne.angle = 0;
	}
	
	stickerGroup = grpStickers;
	inst.add(grpStickers);
}
function shuffleArray(array) {
	var maxValidIndex = array.length - 1;
	for (i in 0...maxValidIndex) {
		var j = FlxG.random.int(i, maxValidIndex);
		var tmp = array[i];
		array[i] = array[j];
		array[j] = tmp;
	}
}

function startStickerTransition(callback:Dynamic) {
	var state:FlxState = FlxG.state;
	while (state.subState != null && !Std.isOfType(state.subState, CustomFadeTransition))
		state = state.subState;
	
	var subState = new FlxSubState('stickers');
	state.openSubState(subState);
	stickerSubState = subState;
	
	spawnStickers(subState, callback);
	
	FlxG.signals.preStateSwitch.addOnce(() -> {
		if (stickerSubState != null)
			stickerSubState.members.resize(0);
	});
	
	FlxTween.tween(Main.fpsVar, {alpha: 0}, .25, {ease: FlxEase.sineOut, startDelay: .5});
}
function finishTransition(callback:Dynamic) {
	if (callback != null)
		callback();
}

function onDestroy() {
	if (stickerSubState != null) {
		CustomFadeTransition.finishCallback = null;
		FlxTween.tween(Main.fpsVar, {alpha: 1}, .25, {ease: FlxEase.sineOut, startDelay: .5});
		
		FlxG.signals.postStateSwitch.addOnce(() -> {
			if (stickerGroup == null || !stickerGroup.exists) return;
			
			var i:Int = 0;
			var sounds:Array = stickerSounds;
			var transSubState:FlxSubState = new FlxSubState();
			
			transSubState.add(stickerGroup);
			for (sticker in stickerGroup) {
				sticker.cameras = [FlxG.cameras.list[FlxG.cameras.list.length - 1]];
				var timing = FlxMath.remapToRange(i, 0, stickerGroup.length, 0, 0.9);
				var stickerI:Int = i;
				
				new FlxTimer().start(timing, () -> {
					if (stickerGroup == null || !transSubState.exists) return;
					
					if (sounds.length > 0)
						FlxG.sound.play(sounds[FlxG.random.int(0, sounds.length - 1)]);
					stickerGroup.remove(sticker, true);
					sticker.destroy();
					
					if (stickerGroup.length == 0)
						transSubState.close();
				});
				
				i += 1;
			}
			
			FlxG.state.openSubState(transSubState);
		});
	}
}