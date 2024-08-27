var strumShades:Map = [];
var shadeNotes:Bool = false;
var adaptive:Bool = false;

function getSetting(setting, def) {
	var setting = game.callOnHScript('getScrSetting', [setting, def]);
	return setting;
}
function setStrumShade(strum) strumShades[strum.ID] = ['miss' => grayColors(int2rgb(strum.rgbShader.r)), 'hit' => {fill: strum.rgbShader.r, darkfill: strum.rgbShader.r, ring: strum.rgbShader.b}];
function onCountdownStarted() {
	adaptive = getSetting('adaptivecolors', true); //doesnt support pixel stages
	if (!adaptive) return Function_Continue;
	
	var tex = game.playerStrums.members[0].texture + '_n';
	if (Paths.image(tex) != null && !PlayState.isPixelStage) { 
		shadeNotes = true;
		for (strum in game.strumLineNotes) {
			setStrumShade(strum);
			strum.texture = tex;
		}
	}
	for (note in game.unspawnNotes) {
		if (note.mustPress && note.noteSplashData.r == -1) {
			if (!note.rgbShader.enabled) continue;
			var colors = splashColors(int2rgb(note.rgbShader.r));
			note.noteSplashData.r = colors.fill;
			note.noteSplashData.b = colors.ring;
		}
	}
}

function onUpdatePost(elapsed:Float) {
	if (!adaptive || !shadeNotes) return Function_Continue;
	for (strum in game.strumLineNotes) {
		var mod:String = (strum.animation.curAnim.name == 'pressed' ? 'miss' : 'hit');
		if (strum.useRGBShader && strum.rgbShader.enabled) {
			if (strumShades[strum.ID] == null) setStrumShade(strum);
			strum.rgbShader.r = (strum.animation.curAnim.curFrame < 2 ? strumShades[strum.ID][mod].darkfill : strumShades[strum.ID][mod].fill);
			strum.rgbShader.b = strumShades[strum.ID][mod].ring;
		}
	}
}

function clamp(n, min, max) return Math.min(Math.max(n, min), max);
//horrible, horrible things ahead
function splashColors(col) {
	var rgb = col; //fill
	var hsv = rgb2hsv(rgb);
	var f = 6.77;
	var m = Math.pow(1 - (hsv.saturation * hsv.brightness / 255), 2);
	rgb.red = FlxMath.lerp(clamp(f * (rgb.red - 128) + 128, 0, 255), rgb.red, m);
	rgb.green = FlxMath.lerp(clamp(f * (rgb.green - 128) + 128, 0, 255), rgb.green, m);
	rgb.blue = FlxMath.lerp(clamp(f * (rgb.blue - 128) + 128, 0, 255), rgb.blue, m);
	hsv = rgb2hsv(rgb);
	hsv.saturation = hsv.saturation * Math.min(hsv.brightness / 255 / .25, 1);
	hsv.brightness = hsv.brightness * .5 + 127.5;
	var fill = rgbfloat(hsv2rgb(hsv));
	
	rgb = col; //ring
	hsv = rgb2hsv(rgb);
	rgb.red = rgb.red * .65;
	rgb.green = rgb.green * Math.max(.75 - rgb.blue * .2, 0);
	rgb.blue = Math.min((rgb.blue + 80) * hsv.brightness / 255, 255);
	hsv = rgb2hsv(rgb);
	hsv.saturation = Math.min(1 - Math.pow(1 - hsv.saturation * 1.4, 2), 1) * Math.min(hsv.brightness / 255 / .125, 1);
	hsv.brightness = hsv.brightness * .75 + 255 * .25;
	var ring = rgbfloat(hsv2rgb(hsv));
	return {fill: rgb2int(fill), ring: rgb2int(ring)};
}

function grayColors(col) {
	var rgb = col; //fill
	rgb.red = clamp(rgb.red - 40 - (rgb.blue - rgb.red) * .1 + Math.abs(rgb.red - rgb.blue) * .1 + Math.min(rgb.red - Math.pow(rgb.blue / 255, 2) * 255 * 3 + rgb.green * .4, 0) * .1, 0, 255);
	rgb.green = clamp(rgb.green + (rgb.red + rgb.blue) * .15 + (rgb.green - rgb.blue) * .3, 0, 255);
	rgb.blue = clamp(rgb.blue + (rgb.green - rgb.blue) * .04 + (rgb.red + rgb.blue) * .25 + Math.abs(rgb.red - (rgb.green - rgb.blue)) * .2 - (rgb.red - rgb.blue) * .3, 0, 255);
	var hsv = rgb2hsv(rgb);
	hsv.saturation = clamp(hsv.saturation + (rgb.b + rgb.g - (rgb.b - rgb.r)) * .05 - (1 - hsv.brightness / 255) * .1, 0, 1) * .52;
	hsv.brightness = clamp(hsv.brightness / 255 - ((rgb.b + rgb.g - (rgb.b - rgb.r)) * .04) + (1 - hsv.brightness / 255) * .08, 0, 1) * 255 * .75;
	var fill = rgbfloat(hsv2rgb(hsv));
	
	rgb = fill; //dark fill
	hsv = rgb2hsv(rgb);
	hsv.saturation = Math.min(hsv.saturation + .06, 1);
	hsv.brightness = Math.max(hsv.brightness - 255 * .06, 0);
	var darkfill = rgbfloat(hsv2rgb(hsv));
	return {fill: rgb2int(fill), darkfill: rgb2int(darkfill), ring: 0xff201e31};
}

//RGB FUNCTIONS CAUSE CUSTOMFLXCOLOR IS ASS (notes in note_hud.hx)
function rgbfloat(rgb) return {red: rgb.red * 255, green: rgb.green * 255, blue: rgb.blue * 255};
function rgb2int(rgb) return Math.round(rgb.red) * 65536 + Math.round(rgb.green) * 256 + Math.round(rgb.blue);
function int2rgbfloat(col) return [((col >> 16) & 0xff) / 255, ((col >> 8) & 0xff) / 255, (col & 0xff) / 255];
function int2rgb(col) return {red: (col >> 16) & 0xff, green: (col >> 8) & 0xff, blue: col & 0xff};
function rgb2hsv(col) {
	var hueRad = Math.atan2(Math.sqrt(3) * (col.green - col.blue), 2 * col.red - col.green - col.blue);
	var hue:Float = 0;
	if (hueRad != 0) hue = 180 / Math.PI * hueRad;
	hue = hue < 0 ? hue + 360 : hue;
	var bright:Float = Math.max(col.red, Math.max(col.green, col.blue));
	var sat:Float = (bright - Math.min(col.red, Math.min(col.green, col.blue))) / bright;
	return {hue: hue, saturation: sat, brightness: bright};
}
function hsv2rgb(col) {
	var chroma = col.brightness * col.saturation;
	var match = col.brightness - chroma;
	
	var hue:Float = col.hue % 360;
	var hueD = hue / 60;
	var mid = chroma * (1 - Math.abs(hueD % 2 - 1)) + match;
	chroma += match;
	
	chroma /= 255; //joy emoji
	mid /= 255;
	match /= 255;

	switch (Math.floor(hueD)) {
		case 0: return {red: chroma, green: mid, blue: match};
		case 1: return {red: mid, green: chroma, blue: match};
		case 2: return {red: match, green: chroma, blue: mid};
		case 3: return {red: match, green: mid, blue: chroma};
		case 4: return {red: mid, green: match, blue: chroma};
		case 5: return {red: chroma, green: match, blue: mid};
		default: return null;
	}
}