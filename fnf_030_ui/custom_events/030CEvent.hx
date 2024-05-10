import psychlua.LuaUtils;

/*
fnf 0.3.0 event ""wrapper"" for psych
TODO
- finish the two other events lol!
*/

var cameraFocus:Int = 0;
var camTween:FlxTween = null;

function onSectionHit() {
	game.moveCamera(cameraFocus == 1);
	return Function_Continue;
}
function onEvent(name, va, vb, time) {
	if (name == '030CEvent') {
		var event = parseCEvent(name, va, vb, time);
		switch (event.e) {
			case 'SetCameraBop':
				var rate = Std.parseInt(event.v.rate); //how do i even code rate
				var intensity = Std.parseFloat(event.v.intensity);
				game.camZoomingMult = intensity;
				setVar('hudZoomingMult', intensity);
			case 'PlayAnimation':
				var target = null;
				var targetChar = event.v.target;
				switch (targetChar) {
					case 'boyfriend', 'bf': target = game.boyfriend;
					case 'dad', 'opponent': target = game.dad;
					case 'girllfriend', 'gf': target = game.gf;
				}
				if (target != null) target.playAnim(event.v.anim, event.v.force == 'true');
			case 'FocusCamera':
				cameraFocus = Std.parseInt(event.v.char);
				game.moveCamera(cameraFocus == 1);
			case 'ZoomCamera':
				var targetZoom = Std.parseFloat(event.v.zoom);
				if (camTween != null) camTween.cancel();
				if (event.v.ease == 'INSTANT') game.defaultCamZoom = targetZoom;
				else camTween = FlxTween.num(game.defaultCamZoom, targetZoom, Std.parseFloat(event.v.duration), {ease: LuaUtils.getTweenEaseByString(event.v.ease)}, (v) -> {
					game.defaultCamZoom = v;
				});
		}
	}
	return Function_Continue;
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