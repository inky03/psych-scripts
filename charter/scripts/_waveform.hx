import openfl.geom.Rectangle;

function makeWaveform(sound, startTime, endTime, width, height, detail, smoothing, color) {
	if (sound == null || endTime < 0 || startTime >= sound.length) return null;
	
	var waveform = new FlxSprite().makeGraphic(width, height, 0, true);
	var _rect = new Rectangle(0, 0, Std.int(width), Std.int(height));
	var midx = width * .5;
	waveform.pixels.fillRect(_rect, 0);
	
	var buffer = sound._sound.__buffer;
	var bytes = buffer.data.buffer;
	
	var length = bytes.length - 1;
	var khz = (buffer.sampleRate / 1000);
	var channels = buffer.channels;
	var stereo = channels > 1;
	
	var index = Std.int(startTime * khz);
	var previ = index;
	
	var samples = (endTime - startTime) * khz;
	var samplesPerRow = samples / height;

	var lmin = 0;
	var lmax = 0;

	var rmin = 0;
	var rmax = 0;
	
	var smoothmin = 0;
	var smoothmax = 0;
	var smooth = Math.min(1 / smoothing, 1);

	var render = 0;
	var div = 1 / 65535;
	
	var step = Math.max(samplesPerRow / detail, 1);
	while (index < length) {
		lmin = lmax = rmin = rmax = 0;
		
		while (previ < index) {
			if (previ >= 0) {
				var p:Int = Math.round(previ) * channels * 2;
				var byte = bytes.getUInt16(p) * div;

				if (byte > .5) lmin = Math.min(lmin, byte - 1);
				else lmax = Math.max(lmax, byte);

				if (stereo) {
					var byte = bytes.getUInt16(p + 2) * div;

					if (byte > .5) rmin = Math.min(lmax, byte - 1);
					else rmax = Math.max(rmax, byte);
				} else {
					rmin = lmin;
					rmax = lmax;
				}
			}
			previ += step;
		}
		previ = index;
		
		var bmin = (lmin + rmin) * .5;
		var bmax = (lmax + rmax) * .5;
		smoothmax += (bmax - smoothmax) * smooth;
		smoothmin += (bmin - smoothmin) * smooth;
		_rect.setTo(midx + smoothmin * width, render, (smoothmax - smoothmin) * width, 1);
		waveform.pixels.fillRect(_rect, color);
		
		render ++;
		index += samplesPerRow;
		if (render > height) break;
	}
	
	return waveform;
}
