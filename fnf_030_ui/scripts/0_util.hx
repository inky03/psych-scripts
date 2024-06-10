import tjson.TJSON as JSON;
import states.MainMenuState;
using StringTools;

//utilities to fix compatibility issues maybe????

/*
getScrSetting: fetch setting from script.
should have failsafes for versions pre 0.7.2 (no mod settings), not inside packed mod folders, and that one mobile user
*/
var warned:Bool = false;
var version = MainMenuState.psychEngineVersion.trim();
version = Std.parseFloat(version.substring(2, version.length));
var scriptMod = null;
if (this.modFolder == '' || this.modFolder == null) { //workaround for that one mobile user
	scriptMod = this.toString(); //since modFolder does NOT WORK FOR SOME DAMN REASON
	scriptMod = scriptMod.substring(scriptMod.indexOf('mods/') + 5, scriptMod.length);
	scriptMod = scriptMod.substring(0, scriptMod.indexOf('/scripts/'));
} else scriptMod = this.modFolder; //we find it directly from the script path

function getDefaultSetting(save, def) {
	var settings = Paths.modsJson('settings');
	if (FileSystem.exists(settings)) {
		var content = File.getContent(settings);
		var json = JSON.parse(content);
		for (setting in json) if (setting.save == save) return (setting.value != null ? setting.value : def);
	}
	return def;
}
function getScrSetting(save, def) {
	/*version < 7.2 cause mod settings were added in 0.7.2
	version >= 0.1 cause 1.0.0 will return 0 lol!*/
	if (version < 7.2 && version >= 0.1) //is unsupported
		return getDefaultSetting(save, def);
	else if (scriptMod != null) {
		if (FlxG.save.data.modSettings == null) return getDefaultSetting(save, def); //What
		var settings = FlxG.save.data.modSettings.get(scriptMod);
		if (settings != null && settings.exists(save)) return settings.get(save);
		else return getDefaultSetting(save, def);
	} else { //is not inside packed mod folder
		if (!warned) {
			debugPrint('Settings have been changed to defaults.', 0xffd080);
			debugPrint('!WARNING (WEEKEND INTERFACE)! Please put this mod inside a packed mod folder!!', 0xffd080);
		}
		warned = true;
		return getDefaultSetting(save, def);
	}
}
setVar('scrPsychVer', version);