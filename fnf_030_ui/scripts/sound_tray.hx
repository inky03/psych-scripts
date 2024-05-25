import openfl.utils.Assets;
import openfl.display.Sprite;
import openfl.display.Bitmap;
import openfl.display.BitmapData;
import flixel.system.FlxAssets;

var soundTray;
var backingBar:Bitmap;

var revert:Bool = true;

//due to Certain limitations (I CANT OVERRIDE THE SOUNDTRAY FUNCTIONS),
//the rest of the soundtray code is in hud.hx (with the fps counter overrides)
function onCreate() {
	soundTray = FlxG.game.soundTray;
	if (soundTray == null || soundTray._bars == null || !revert) {
		revert = false;
		return Function_Continue;
	}
	
	var graphicScale:Float = .3;
	var i:Int = 1;
	for (bar in soundTray._bars) {
		var graphic = Paths.image('soundtray/bars_' + i);
		if (graphic == null) continue;
		bar.bitmapData = graphic.bitmap;
		bar.x = 9;
		bar.y = 5;
		bar.scaleX = graphicScale;
		bar.scaleY = graphicScale;
		bar.smoothing = true;
		i ++;
	}
	var bg = soundTray.getChildAt(0);
	var graphic = Paths.image('soundtray/volumebox');
	if (graphic != null) bg.bitmapData = graphic.bitmap;
	bg.scaleX = graphicScale;
	bg.scaleY = graphicScale;
	bg.smoothing = true;
	soundTray.screenCenter();
	var test = soundTray.getChildAt(1); //remove backing bar if hadnt been removed for any reason??
	if (Std.isOfType(test, Bitmap)) soundTray.removeChildAt(1);
	var text = soundTray.getChildAt(1);
	text.visible = false;
	
	backingBar = new Bitmap();
	graphic = Paths.image('soundtray/bars_10'); //add backing bar
	if (graphic != null) backingBar.bitmapData = graphic.bitmap;
	backingBar.scaleX = graphicScale;
	backingBar.scaleY = graphicScale;
	backingBar.x = 9;
	backingBar.y = 5;
	backingBar.alpha = .4;
	soundTray.addChildAt(backingBar, 1);
	soundTray.silent = true;	
}

function onDestroy() {
	if (!revert) return;
	
	soundTray.silent = false;
	soundTray.removeChildAt(1);
	//we revert the soundtray to what it once was
	var bg = soundTray.getChildAt(0);
	bg.bitmapData = new BitmapData(80, 30, true, 0x7f000000);
	bg.scaleX = 1;
	bg.scaleY = 1;
	bg.smoothing = false;
	var text = soundTray.getChildAt(1);
	text.visible = true;
	var i:Int = 0;
	for (bar in soundTray._bars) {
		bar.bitmapData = new BitmapData(4, i + 1, false, -1);
		bar.x = 10 + i * 6;
		bar.y = 14 - i;
		bar.scaleX = 1;
		bar.scaleY = 1;
		bar.smoothing = false;
		bar.visible = true;
		i ++;
	}
	soundTray.screenCenter();
	soundTray.alpha = 1;
}