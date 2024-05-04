import psychlua.LuaUtils;

/*
fnf 0.3.0 event ""wrapper"" for psych
TODO
- finish the two other events lol!
*/

var cameraFocus:Int = 0;
var camTween:FlxTween = null;

function onSectionHit() game.moveCamera(cameraFocus == 1);
function onEvent(name, va, vb, time) {
	if (name == '030CEvent') {
		var event = parseCEvent(name, va, vb, time);
		switch (event.e) {
			case 'FocusCamera':
				cameraFocus = Std.parseInt(event.v.char);
				game.moveCamera(cameraFocus == 1);
			case 'ZoomCamera':
				var targetZoom = Std.parseFloat(event.v.zoom);
				game.defaultCamZoom = targetZoom;
				if (camTween != null) camTween.cancel();
				if (event.v.ease == 'INSTANT') game.camGame.zoom = targetZoom;
				else camTween = FlxTween.tween(game.camGame, {zoom: targetZoom}, Std.parseFloat(event.v.duration), {ease: LuaUtils.getTweenEaseByString(event.v.ease)});
		}
	}
}
function parseCEvent(name, va, vb, time) {
	var event = {e: '', t: time, v: {}};
	var values = {};
	va = va.split(',');
	vb = vb.split(',');
	for (i in 0...va.length) {
		if (i == 0) event.e = va[i];
		else Reflect.setField(values, va[i], vb[i]);
	}
	event.v = values;
	return event;
}