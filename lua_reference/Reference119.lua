--[[
	MODULE BY emi3 / superinky
	GAMEBANANA: emi_ // please credit me if you use this!! im eager to see if anyone actually does anything with this
	https://github.com/inky03/psych-scripts/tree/main/lua_reference
]]

if reference then return end
reference = {}
reference.version = '1.1.9'
reference.extreme = false
reference.warnings = true
reference.indexFromZero = false
reference.deprecatedWarnings = true
setmetatable(reference, { __call = function(_, ...) return reference.ref(...) end; })

local errorPrefix = '<' .. scriptName .. '> '
local c_VALUE = '_value'
local printColors = {
	warn = '0xffbf40';
	error = '0xff3040';
}
function reference.warn(warning, col)
	col = (col or 'warn')
	if not reference.warnings and col == 'warn' then return end
	local fullStr = (errorPrefix .. warning)
	if version < '0.7' then
		if version < '0.6.3' then
			debugPrint(fullStr) -- ok buddy
		else
			runHaxeCode('game.addTextToDebug("' .. fullStr:gsub('"', '\\"') .. '", ' .. printColors[col] .. ')')
		end
	else
		debugPrint(fullStr, printColors[col])
	end
end

local isPre07 = version < '0.7'
if not version or version < '0.6.3' then
	reference.warn('Module not supported in versions older than 0.6.3 - please upgrade!', 'error')
	close(true)
	return reference
end

reference._instincrement = 0
reference._meta = { --its a load of garbage
	__index = function(self, var)
		if var == 'new' and self._class ~= '' and (self._obj == '' or not self._obj) then
			return function(tag, ...)
				local args = {...}
				if tag == self then tag = reference.getFreeTag(self._class) end --if calling by :
				return reference.createInstance(tag, self._class, args)
			end
		end
		if var == 'destroy' and self._obj and self._obj ~= '' then return function() reference.destroy(self) end end
		if var == 'reassign' then return function(newTag) return reference.reassign(self, newTag) end end
		if var == 'ipairs' then return function() return reference.ipairs(self) end end -- not sure why it dont work on indexes..
		if var == 'pairs' then return function() return reference.pairs(self) end end
		local indexes = {
			[c_VALUE] = function() return reference.cast(self) end;
			default = function() return reference.getField(self, var) end;
		}
		local f = indexes[var]
		return (f and f() or indexes.default())
	end;
	__newindex = function(self, var, val)
		reference.setField(self, var, val)
	end;
	__call = function(self, ...)
		local args = {...}
		return reference.callMethod(self, args)
	end;
}

local ok, iris = pcall(function() return (callMethodFromClass('Type', 'resolveClass', {'crowplexus.iris.Iris'}) ~= nil) end)
local useIris = ok and iris

reference._baseCode =
	(useIris and [[
		import crowplexus.iris.Iris;
		import crowplexus.hscript.Expr;
	]] or '')
	.. (isPre07 and [[
		var debugPrint = PlayState.instance.addTextToDebug;
	]] or [[
		import states.MainMenuState;
		import psychlua.FunkinLua;
		import psychlua.HScript;
		
		import haxe.ds.ObjectMap;
		import haxe.ds.StringMap;
		import haxe.ds.IntMap;
		import ValueType;			//retweet
		import Reflect;
		import String;
		import Float;
		import Array;
		import Type;
		import Bool;
		import Int;
		import Std;
	]])
	.. [[

	var useIris = (Type.resolveClass('crowplexus.iris.Iris') != null);
	var isFinal = StringTools.startsWith(MainMenuState.psychEngineVersion, '1.0');
	var warnColor = ]] .. printColors.warn .. [[;
	var errorColor = ]] .. printColors.error .. [[;
	var modchartVars = (isFinal ? [game.variables] : [game.modchartSprites, game.modchartTexts, game.variables]);

	function warn(text) debugPrint("]] .. errorPrefix .. [[ " + text, warnColor);
	
	function classOrEnum(n) {
		var r = Type.resolveClass(n);
		if (r == null) r = Type.resolveEnum(n);
		return r;
	}
	function isSpecial(val) return (!Std.isOfType(val, Int) && !Std.isOfType(val, Float) && !Std.isOfType(val, String) && !Std.isOfType(val, Bool) && val != null);
	function isValidClass(classs) return (Std.isOfType(classs, String) && classOrEnum(classs) != null);
	function arrayGet(array, n) return (useIris ? array[n] : array.slice(n, n + 1).shift());
	function isMap(o) return (Std.isOfType(o, StringMap) || Std.isOfType(o, IntMap) || Std.isOfType(o, ObjectMap));
	// return (o.exists != null && o.keyValueIterator != null);
	]] ..
		(isPre07 and 'function isAnon(test) return Reflect.isObject(test);'
		or 'function isAnon(test) return (Type.typeof(test) == ValueType.TObject);')
	.. [[
	
	var luaUtils = Type.resolveClass('psychlua.LuaUtils');
	if (luaUtils == null) {
		luaUtils = FunkinLua;
	}
	function getPropertyFromClass(classVar, variable) { // cuz 0.6.3 is mid
		var cls = classOrEnum(classVar);
		if (cls == null) return null;

		var split = variable.split('.');
		var result;
		if (split.length > 1) {
			var idk = luaUtils.getVarInArray(cls, split[0]);
			for (i in 1...split.length - 1) {
				idk = luaUtils.getVarInArray(idk, split[i]);
			}
			result = luaUtils.getVarInArray(idk, split[split.length - 1]);
		} else {
			result = Reflect.field(cls, variable);
		}
		if (isSpecial(result)) return '##SUPERSPECIAL';
		return result;
	}
	function getPropertySafe(variable) {
		var split = variable.split('.');
		var main = split.shift();
		var allowMaps = false;
		var returned;
		returned = LuaUtils.getObjectDirectly(main);
		if (split.length > 0)
			for (v in split) returned = LuaUtils.getVarInArray(returned, v, isMap(returned));
		if (Std.isOfType(returned, Array) || isMap(returned) || isAnon(returned)) return '##SUPERSPECIAL';
		if (isSpecial(returned)) return '##SPECIAL';
		return returned;
	}
	function representLua(val, inMap) {
		if (!useIris) return val; //because sscript returns are better
		//goofy as shit
		var result = '';
		if (Std.isOfType(val, String)) {
			if (inMap) return '"' + val + '"';
			else if (val == '##REPRESENT') return '##REPRESENT"##REPRESENT"';
		}
		if (Std.isOfType(val, Array)) {
			for (item in val)
				result += '; ' + representLua(item, true);
			result = (inMap ? '{' : '##REPRESENT{') + result.substring(2, result.length) + '}';
			return result;
		}
		if (isMap(val)) {
			for (key in val.keys()) {
				result += '; ' + '[' + representLua(key, true) + ']';
				result += ' = ' + representLua(val.get(key), true);
			}
			result = (inMap ? '{' : '##REPRESENT{') + result.substring(2, result.length) + '}';
			return result;
		}
		if (Std.isOfType(val, String) || Std.isOfType(val, Int) || Std.isOfType(val, Float) || Std.isOfType(val, Bool) || val == null) return val;
		if (!Reflect.isObject(val)) return '"##SPECIAL"';
		if (!isAnon(val)) return '"##SPECIAL"';
		for (field in Reflect.fields(val)) {
			result += '; ' + '["' + field + '"]';
			result += ' = ' + representLua(Reflect.field(val, field), true);
		}
		result = (inMap ? '{' : '##REPRESENT{') + result.substring(2, result.length) + '}';
		return result;
	}
	function isReference(test) {
		if (!isAnon(test)) return false;
		var fields = Reflect.fields(test);
		return (fields.contains('_obj') && fields.contains('_class') && fields.contains('_arguments'));
	}
	function objSplit(str) {
		var split = str.split('.');
		var finalSplit = [];
		for (v in split) {
			var float = Std.parseFloat(v);
			if (!Math.isNaN(float)) v = float;
			finalSplit.push(v);
		}
		return finalSplit;
	}
	function objGet(split, classs, special) {
		var fields = split;
		var point = (classs == '' ? game : classOrEnum(classs));
		if (split.length == 0)
			return point;
		
		var first = fields.shift();
		var f;
		
		if (first != null && first != '' && first != 'game') {
			f = Reflect.getProperty(point, first);
			if (f != null) {
				point = f;
			} else {
				f = getLuaObject(first);
				if (f == '##INVALID') return f;
				point = f;
			}
		} else
			f = point;
		
		for (field in fields) {
			var isArray = Std.isOfType(f, Array);
			if (isArray || isMap(f)) {
				if (isArray) {
					if (field >= f.length) return '##INVALID';
					f = arrayGet(f, field);
				} else {
					if (!f.exists(field)) return '##INVALID';
					f = f[field];
				}
			} else {
				var getfield = Reflect.getProperty(f, field);
				if (getfield == null) getfield = Reflect.field(f, field);
				if (getfield == null && !Reflect.fields(f).contains(field)) return '##INVALID';
				f = getfield;
			}
		}
		return (special || !isSpecial(f) ? f : '##SPECIAL');
	}
	function getLuaObject(tag) {
		for (a in modchartVars) if (a.exists(tag)) return a.get(tag);
		return '##INVALID';
	}
	function objGetFix(val) {
		if (val == '##NULL') return null;
		if (isReference(val)) {
			var args = val._arguments;
			if (args.length > 0) return objCallMethod(objSplit(val._obj), val._class, val._arguments, true); //if must be ran as function
			else return objGet(objSplit(val._obj), val._class, true);
		} else {
			if (Std.isOfType(val, Array)) {
				var farray = [];
				for (i in val) {
					farray.push(objGetFix(i));
				}
				return farray;
			}
			if (isMap(val)) for (i in val.keys()) val[i] = objGetFix(val[i]);
			return val;
		}
	}
	function refCast(ref) {
		if (!isReference(ref)) return null;
		var got = objGetFix(ref);
		var ret = representLua(got, false);
		if (ret == '"##SPECIAL"') return representLua(['class' => Type.getClassName(Type.getClass(got)), 'fields' => Reflect.fields(got)], false);
		return ret;
	}
	function refAssign(ref, tag) {
		if (!isReference(ref)) return false;
		var got = objGetFix(ref);
		if (got != '##INVALID' && got != null) {
			game.variables.set(tag, got);
			return true;
		}
		return false;
	}
	function objGetField(vget, gclasss, special) {
		var got = objGet(vget, gclasss, true);
		if (!special && isSpecial(got)) return '##SPECIAL';
		return got;
	}
	function objSetField(vget, gclasss, vset) {
		var setfield = vget.pop();
		var got = objGet(vget, gclasss, true);
		if (got == '##INVALID') {
			warn('Can\'t get field: Object doesn\'t exist!');
			return null;
		}
		var setter = objGetFix(vset);
		if (setter == '##INVALID') {
			warn('Can\'t get field: Field doesn\'t exist!');
			return null;
		}
		if (Std.isOfType(got, Array) || isMap(got)) { //aaaaa
			got[setfield] = setter;
			return;
		}
		Reflect.setProperty(got, setfield, setter);
	}
	function destroyObj(dobj) {
		var getStr = Std.isOfType(dobj, String);
		var obj = (getStr ? objGet(objSplit(dobj), '', true) : objGetFix(dobj));
		if (obj != '##INVALID' && Reflect.isObject(obj)) {
			if (Reflect.field(obj, 'destroy') != null) {
				if (getStr) {
					for (a in modchartVars) {
						if (a.get(dobj) == obj) a.remove(dobj);
					}
				}
				game.remove(obj, true);
				obj.destroy();
				return true;
			}
		}
		return false;
	}
	function objCallMethod(gobj, classs, arguments, special) {
		var methodName = gobj.pop();
		var obj = objGet(gobj, classs, true);
		if (obj != '##INVALID') {
			var method = Reflect.field(obj, methodName);
			if (Reflect.isFunction(method)) {
				var truArgument = [];
				if (!Std.isOfType(arguments, Array)) arguments = []; //empty array is passed as an anon structure, cause lua sucks
				for (arg in arguments) truArgument.push(objGetFix(arg));
				
				var returned = Reflect.callMethod(obj, method, truArgument);
				if (!special && isSpecial(returned)) return '##SPECIAL';
				return returned;
			} else {
				if (method == '##INVALID') {
					warn('(objCallMethod) Can\'t call method: "' + methodName + '" doesn\'t exist!');
					return null;
				}
				warn('(objCallMethod) Can\'t call method: "' + methodName + '" is not a method!');
				return null;
			}
		}
		warn('(objCallMethod) Can\'t call method: Object doesn\'t exist!');
		return null;
	}
	function destroyRef(gobj, tag) {
		var obj = objGet(gobj, null, true);
		if (obj != '##INVALID' && Reflect.isFunction(Reflect.field(obj, 'destroy'))) {
			if (tag != '##NULL')
				for (a in modchartVars) if (a.exists(tag)) a.remove(tag);
			game.remove(obj, true);
			obj.destroy();
			return true;
		}
		return false;
	}
	function createInstance(tag, classs, args) {
		if (!Std.isOfType(args, Array)) args = [];
		var truArgs = [];
		for (arg in args) truArgs.push(objGetFix(arg));
		var instance = Type.createInstance(Type.resolveClass(classs), truArgs);
		if (isFinal) {
			game.variables.set(tag, instance);
			return;
		}
		switch (classs) {
			case 'flixel.FlxSprite', 'psychlua.ModchartSprite':
				game.modchartSprites.set(tag, instance);
			case 'flixel.text.FlxText':
				game.modchartTexts.set(tag, instance);
			default:
		}
		game.variables.set(tag, instance);
	}
	function dsLength(ref) {
		var obj = objGetFix(ref);
		if (obj == null) return null;
		if (Std.isOfType(obj, Array)) return obj.length;
		else {
			var iter = Reflect.field(obj, 'iterator');
			if (iter != null && Reflect.isFunction(iter)) {
				var i = 0;
				for (_ in obj) i += 1;
				return '##ITER' + i;
			}
			return null;
		}
	}
	function dsKeys(ref) {
		var obj = objGetFix(ref);
		if (obj == null) return null;
		var anon = isAnon(obj);
		if (anon || isMap(obj)) {
			var keys = [];
			for (fi in (anon ? Reflect.fields(obj) : obj.keys())) keys.push(fi);
			return keys;
		} return null;
	}
	createGlobalCallback('_refRunFunc', (name, args) -> {
		if (!Std.isOfType(args, Array)) args = [];
		var returned = this.executeFunction(name, args);
		if (returned != null) {
			if (useIris) {
				return returned.returnValue;
			} else {
				if (returned.succeeded) return returned.returnValue;
			}
		} return null;
	});
	function test(a) return a;
	
	//hscript
	var luas = ['0' => null]; //idk how to init maps without dumb bs
	var hImports = ['0' => null];
	luas.remove('0');
	
	]] .. (isPre07 and [[
	var hscripts = luas.copy();

	function initHS(id) {
		id = id;
		if (hscripts[id] != null) {
			warn('HScript instance "' + id + '" is already initialized!');
			return;
		}
		var hs = hscripts[id] = {
			parser: new Parser(),
			interp: new Interp(),
			program: null,
			exec: false,
			vars: {}
		};
		prepareHS(hs);
	}
	function setHS(id, field, val) {
		var hs = hscripts[id];
		if (hs != null)
			hs.interp.variables.set(field, objGetFix(val));
	}
	function destroyHS(id) hscripts.remove(id);
	function importHS(classN, alias) {
		var classR = classOrEnum(classN);
		hImports[alias] = classR;
		for (hscript in hscripts)
			hscript.interp.variables.set(alias, classR);
	}
	function importOnHS(hs) {
		for (alias in hImports.keys())
			hs.interp.variables.set(alias, hImports[alias]);
	}
	]] or [[
	function initHS(id) {
		id = id;
		if (luas[id] != null) {
			warn('HScript instance "' + id + '" is already initialized!');
			return;
		}
		var lua = luas[id] = new FunkinLua('');
		HScript.initHaxeModule(lua);
		prepareHS(lua.hscript);
	}
	function getHInstance(id) return (luas[id] != null ? luas[id].hscript : null);
	function setHS(id, field, val) {
		var hs = getHInstance(id);
		if (hs != null)
			hs.set(field, objGetFix(val));
	}
	function destroyHS(id) {
		if (luas[id] != null) {
			var lua = luas[id];
			lua.stop();
			luas.remove(id);
		}
	}
	function importHS(classN, alias) {
		var classR = classOrEnum(classN);
		hImports[alias] = classR;
		for (lua in luas) {
			var hs = lua.hscript;
			hs.set(alias, classR);
		}
	}
	function importOnHS(hs) {
		for (alias in hImports.keys())
			hs.set(alias, hImports[alias]);
	}
	]]) .. (useIris and [[
	//HSCRIPT IRIS
	function getHS(id, field) {
		var hs = getHInstance(id);
		if (hs == null) return;
		var returned;

		if (hs.exists(field)) {
			returned = hs.get(field);
		} else {
			returned = hs.call('getLocal_', [field]);
			if (returned != null) returned = returned.methodVal;
		}

		if (Reflect.isFunction(returned)) return '##METHOD';
		if (isSpecial(returned)) return '##SPECIAL';
		else return representLua(returned, false);
	}
	function setHS(id, field, val) {
		var hs = getHInstance(id);
		if (hs == null) return;

		val = objGetFix(val);
		if (hs.exists(field)) hs.set(field, val);
		else hs.call('setLocal_', [field, val]);
	}
	function prepareHS(iris) {
		//set import classes that aren't set by default, that i think Should be really useful
		iris.set('trace', Iris.irisPrint, true);
		iris.set('Reflect', Reflect);
		iris.set('String', String);
		iris.set('Float', Float);
		iris.set('Array', Array);
		iris.set('Type', Type);
		iris.set('Bool', Bool);
		iris.set('Int', Int);
		iris.set('Std', Std);
		importOnHS(iris);
		iris.preset();
	}
	function executeHS(iris) return iris.interp.execute(iris.parser.parseString(iris.scriptCode));
	function runHS(id, code, vars, func, args) {
		var hs = getHInstance(id);
		if (hs == null) return;
		if (!Std.isOfType(args, Array)) args = [];
		var truVars = {};
		for (fi in Reflect.fields(vars))
			Reflect.setField(truVars, fi, objGetFix(Reflect.field(vars, fi)));
		var prevCode = hs.scriptCode;
		code = code + "\nfunction getLocal_(v) { return this.interp.resolve(v); }\nfunction setLocal_(v, val) { this.interp.locals.get(v).r = val; }";
		hs.varsToBring = truVars;
		hs.scriptCode = code;
		var result;
		try {
			if (StringTools.trim(func) == '') {
				result = executeHS(hs);
			} else {
				var truArgs = [];
				for (arg in args) truArgs.push(objGetFix(arg));
				if (prevCode != code) executeHS(hs);
				if (!hs.exists(func)) throw 'Function "' + func + '" doesn\'t exist';
				result = hs.executeFunction(func, args);
			}
			if (result != null && result.signature != null) result = result.returnValue;
		} catch(e:Dynamic) {
			warn('Hscript error from "' + id + '": ' + e);
			result = null;
		}
		return representLua(result, false);
	}
	function resetHS(id) {
		if (!luas.exists(id)) return;
		var hs = luas[id].hscript;
		executeHS(hs);
	}
	]] or (isPre07 and [[
	//HSCRIPT
	function getHS(id, field) {
		var hs = hscripts[id];
		if (hs == null) return;

		var vars = hs.interp.variables;
		var returned = null;

		if (vars.exists(field)) {
			returned = vars.get(field);
		} else {
			try {
				returned = Reflect.callMethod(null, vars.get('getLocal_'), [field]);
			} catch(e:Dynamic) {}
		}

		if (Reflect.isFunction(returned)) return '##METHOD';
		if (isSpecial(returned)) return '##SPECIAL';
		return returned;
	}
	function setHS(id, field, val) {
		var hs = hscripts[id];
		if (hs == null) return;

		var vars = hs.interp.variables;

		val = objGetFix(val);
		if (vars.exists(field)) vars.set(field, val);
		else Reflect.callMethod(null, vars.get('setLocal_'), [field, val]);
	}
	function prepareHS(hs) {
		var vars = hs.interp.variables;
		var imports = [
			'flixel.FlxG',
			'flixel.FlxMath',
			'flixel.FlxCamera',
			'flixel.FlxSprite',
			'flixel.text.FlxText',
			'flixel.util.FlxTimer',
			'flixel.tweens.FlxEase',
			'flixel.addons.display.FlxRuntimeShader',
			'CustomSubstate',
			'Achievements',
			'StringTools',
			'Character',
			'Conductor',
			'PlayState',
			'Alphabet',
			'Paths',
			'Note',
		];
		for (cls in imports) {
			var shortCls = cls.split('.').pop();
			vars.set(shortCls, classOrEnum(cls));
		}
		vars.set('debugPrint', PlayState.instance.addTextToDebug);
		vars.set('game', PlayState.instance);
		vars.set('Reflect', Reflect);
		vars.set('String', String);
		vars.set('Float', Float);
		vars.set('Array', Array);
		vars.set('Type', Type);
		vars.set('Bool', Bool);
		vars.set('Int', Int);
		vars.set('Std', Std);
		vars.set('this', hs);
		importOnHS(hs);
	}
	function runHS(id, code, vars, func, args) {
		var hs = hscripts[id];
		if (hs == null) return;

		var interp = hs.interp;
		var parser = hs.parser;
		if (!Std.isOfType(args, Array)) args = [];
		if (hs.vars != null)
			for (fi in Reflect.fields(hs.vars))
				interp.variables.set(fi, null);
		if (vars != null) {
			var fields = Reflect.fields(vars);
			for (fi in fields) {
				var val = objGetFix(Reflect.field(vars, fi));
				interp.variables.set(fi, val);
				Reflect.setField(hs.vars, fi, val);
			}
		}
		var prevCode = interp.input;
		code = code + "\nfunction getLocal_(v) { return this.interp.resolve(v); }\nfunction setLocal_(v, val) { this.interp.locals.get(v).r = val; }";
		var onlyRun = (StringTools.trim(func) == '');
		try {
			if (onlyRun || !hs.exec) {
				if (prevCode != code) {
					hs.program = parser.parseString(code);
				}
				result = interp.execute(hs.program);
				hs.exec = true;
			}
			if (!onlyRun) {
				var truArgs = [];
				for (arg in args) truArgs.push(objGetFix(arg));
				var fun = interp.variables[func];
				if (fun != null && Reflect.isFunction(fun)) {
					Reflect.callMethod(null, fun, truArgs);
				}
			}
		} catch (e:Dynamic) {
			warn('Hscript error from "' + id + '": ' + e);
			result = null;
		}
		return result;
	}
	]] or [[
	//SSCRIPT
	function getHS(id, field) {
		var hs = getHInstance(id);
		if (hs == null) return;
		var returned;

		if (hs.exists(field)) {
			returned = hs.get(field);
		} else {
			returned = hs.executeFunction('getLocal_', [field]);
			if (returned != null && returned.succeeded) returned = returned.returnValue;
			else if (hs.returnValue != null) returned = hs.returnValue;
		}

		if (Reflect.isFunction(returned)) return '##METHOD';
		if (isSpecial(returned)) return '##SPECIAL';
		else return returned;
	}
	function setHS(id, field, val) {
		var hs = getHInstance(id);
		if (hs == null) return;

		val = objGetFix(val);
		if (hs.exists(field)) hs.set(field, val);
		else hs.executeFunction('setLocal_', [field, val]);
	}
	function prepareHS(tea) importOnHS(tea);
	function executeHS(tea) return tea.executeCode();
	function runHS(id, code, vars, func, args) {
		var hs = getHInstance(id);
		if (hs == null) return;
		if (!Std.isOfType(args, Array)) args = [];
		var truVars = {};
		if (hs.varsToBring != null)
			for (fi in Reflect.fields(hs.varsToBring))
				hs.set(fi, null);
		if (vars != null) {
			var fields = Reflect.fields(vars);
			for (fi in fields) {
				var val = Reflect.field(vars, fi);
				hs.set(fi, objGetFix(val));
				Reflect.setField(truVars, fi, objGetFix(val));
			}
		}
		var prevCode = hs.script;
		code = code + "\nfunction getLocal_(v) { return this.interp.resolve(v); }\nfunction setLocal_(v, val) { this.interp.locals.get(v).r = val; }";
		hs.varsToBring = truVars;
		var result;
		try {
			if (StringTools.trim(func) == '') {
				if (prevCode != code) hs.doString(code);
				result = hs.executeCode();
				var e = hs.parsingException;
				if (e != null) throw StringTools.replace(e.message, 'SScript:', 'SS:');
			} else {
				var truArgs = [];
				for (arg in args) truArgs.push(objGetFix(arg));
				if (prevCode != code) hs.doString(code);
				if (!hs.exists(func)) throw 'Function "' + func + '" doesn\'t exist';
				result = hs.executeFunction(func, args);
			}
			if (result != null) {
				var e = result.exceptions.shift();
				if (e != null) throw e;
				else if (result.succeeded) result = result.returnValue;
				return null;
			} else if (hs.returnValue != null) {
				result = hs.returnValue;
			}
		} catch(e:Dynamic) {
			warn('Hscript error from "' + id + '": ' + e);
			result = null;
		}
		return representLua(result, false);
	}
	function resetHS(id) {
		if (!luas.exists(id)) return;
		var hs = luas[id].hscript;
		hs.doString(hs.script);
		executeHS(hs);
	}
	]]))
function reference.isArray(tbl) return (#tbl > 0 and next(tbl, #tbl) == nil) end
if isPre07 then
	runHaxeCode('setVar("__TEMP", "");')
	setProperty('variables.__TEMP', reference._baseCode)
	local imports = {
		HScript = '';
		Interp = 'hscript';
		Parser = 'hscript';
		StringMap = 'haxe.ds';
		ObjectMap = 'haxe.ds';
		IntMap = 'haxe.ds';
		MainMenuState = '';
		FunkinLua = '';
		Reflect = '';
		String = '';
		Float = '';
		Array = '';
		Type = '';
		Bool = '';
		Math = '';
		Int = '';
		Std = '';
	}
	for cls, pkg in pairs(imports) do addHaxeLibrary(cls, pkg) end
	local function typeToString(t, doMap)
		if type(t) == 'table' then
			local isArray = reference.isArray(t)
			local str = (isArray or doMap) and '[' or '{'
			for k, v in (isArray and ipairs or pairs)(t) do
				if not isArray then str = str .. (doMap and typeToString(k) or tostring(k)) .. (doMap and '=>' or ':') end
				str = str .. typeToString(v) .. ','
			end
			if #str > 1 then str = str:sub(1, #str - 1) end
			str = str .. ((isArray or doMap) and ']' or '}')
			return str
		elseif type(t) == 'string' then
			return '"' .. t .. '"'
		elseif t == nil then
			return 'null'
		else
			return tostring(t)
		end
	end
	runHaxeCode([[
		var refHS = new HScript();
		var parser = new Parser();
		var imports = ]] .. typeToString(imports, true) .. [[;
		for (cls in imports.keys()) {
			var pkg = imports[cls];
			if (pkg != '') pkg += '.';
			refHS.interp.variables.set(cls, Type.resolveClass(pkg + cls));
		}
		refHS.interp.variables.set('createGlobalCallback', () -> {});
		var expr = parser.parseString(getVar("__TEMP"));
		refHS.interp.execute(expr);
		setVar('##REFERENCE_HSCRIPT', refHS);
		setVar('##REFERENCE_PARSER', parser);
	]])
	function callMethodFromClass(cls, func, args)
		return runHaxeCode([[
			var cls = Type.resolveClass(']] .. cls .. [[');
			var func = ']] .. func .. [[';
			if (cls == null) {
				game.addTextToDebug('No class exists with the name of "' + cls + '"', ]] .. printColors.error .. [[);
				return null;
			}
			try {
				var result = Reflect.callMethod(cls, func, ]] .. typeToString(args) .. [[);
				for (type in [Int, Float, String, Bool, Array]) if (Std.isOfType(result, type)) return result;
				if (result == null) return null;
				return '';
			} catch(e:Dynamic) {
				game.addTextToDebug('Invalid function: ' + func, ]] .. printColors.error .. [[);
				return null;
			}
		]])
	end
	reference._run = function(func, args)
		args = args or {}
		return runHaxeCode([[
			var refHS = getVar('##REFERENCE_HSCRIPT');
			var parser = getVar('##REFERENCE_PARSER');
			var func = refHS.interp.variables[']] .. func .. [['];
			if (func != null && Reflect.isFunction(func)) {
				try {
					return Reflect.callMethod(null, func, ]] .. typeToString(args) .. [[);
				} catch(e:Dynamic) {
					game.addTextToDebug('ERROR: ' + e, ]] .. printColors.error .. [[);
				}
			}
			return null;
		]])
	end
else
	runHaxeCode(reference._baseCode)
	reference._run = _refRunFunc --runHaxeFunction
end

--[[ local prevResume = coroutine.resume
local prevYield = coroutine.yield
coroutine.resume = function(...)
	reference._run = _refRunFunc
	return prevResume(...)
end
coroutine.yield = function(...)
	reference._run = runHaxeFunction
	return prevYield(...)
end]]

-- funny import
function import(class)
	if not reference.isValidClass(class) then
		reference.warn('(import) ERROR: Class "' .. class .. '" doesn\'t exist!', 'error')
		return nil
	end
	local cname = reference.basicClassName(class)
	if _G[cname] then
		--reference.warn('(import) Class "' .. class .. '" is already imported on this script!')
		--warning is prob not ideal here
		return _G[cname]
	end
	local ref = reference.ref(class)
	_G[cname] = ref
	return ref
end

-- reference MAIN stuff
function reference.preset()
	import 'flixel.FlxG'
	import 'flixel.FlxSprite'
	import 'flixel.FlxCamera'
	import 'flixel.math.FlxMath'
	import 'flixel.text.FlxText'
	if isPre07 then
		import 'Paths'
		import 'Alphabet'
		import 'Character'
		import 'Conductor'
		import 'PlayState'
		import 'ClientPrefs'
		import 'StringTools'
	else
		import 'backend.Paths'
		import 'objects.Alphabet'
		import 'objects.Character'
		import 'backend.Conductor'
		import 'backend.ClientPrefs'
		import 'backend.PsychCamera'
		import 'backend.Achievements'
		import 'psychlua.ModchartSprite'
		import 'states.PlayState'
		import 'StringTools'
		LuaSprite = ModchartSprite
	end
	game = reference ''
	remove = FlxG.state.remove
	insert = FlxG.state.insert
	add = FlxG.state.add
	setVar = function(field, val)
		game.variables[field] = val
	end
	getVar = function(field)
		return game.variables[field]
	end
	debugPrint = function(text, col)
		game.addTextToDebug(text, type(col) == 'number' and col or (type(col) == 'string' and tonumber(col:gsub('#', ''), 16) or 0xffffff))
	end
end
function reference.hscript(code, vars, func, args)
	local hs = reference._hsDisposable
	hs.code = code; hs.vars = (type(vars) == 'table' and vars or {})
	if func then return hs:run(func, args) end
	return hs:run()
end
function reference.luaObjectExists(obj)
	return (reference._run('getLuaObject', {type(obj) == 'string' and obj or ''}) ~= '##INVALID')
end
function reference.objectExists(obj, class)
	class = (type(class) == 'string' and class or '')
	if class ~= '' and not reference.isValidClass(class) then
		reference.warn('(objectExists) ERROR: Class "' .. class .. '" doesn\'t exist!', 'error')
		return nil
	end
	if not reference.safeProp(obj, class) then
		local objT = obj:gsub('%[', '.'):gsub('[\'%]]', '')
		local get = reference._run('objGet', {reference.splits(objT), class, false})
		return (get ~= '##INVALID')
	end
	return true
end
function reference.ref(obj, class, arguments)
    obj = obj or ''
	if obj == '' and class == '' then
		reference.warn('(ref) ERROR: Variable name can\'t be blank if not referencing a class!', 'error')
		return nil
	end
	
	arguments = (type(arguments) == 'table' and arguments or {})
	if class == nil and reference.isValidClass(obj) then --this is so dumb..
		class = obj
		obj = ''
	else
		class = (type(class) == 'string' and class or '')
		if class ~= '' and not reference.isValidClass(class) then
			reference.warn('(ref) ERROR: Class "' .. tostring(class) .. '" doesn\'t exist!', 'error')
			return nil
		end
	end
	
	obj = (type(obj) == 'string' and ((obj == '' and class == '') and 'game' or obj) or 'game')
	if class ~= '' and not reference.isValidClass(class) then
		reference.warn('(ref) ERROR: Class "' .. tostring(class) .. '" doesn\'t exist!', 'error')
		return nil
	end
	
	local objT = obj:gsub('%[', '.'):gsub('[\'%]]', '') --:gsub('[%])]', ''):gsub('get%(', '')
	if not reference.isValidIdentifier(objT) then
		reference.warn('(ref) ERROR: Identifier "' .. reference.compositeObjClass(obj, class) .. '" is invalid!', 'error')
		return nil
	end
	if not reference.objectExists(obj, class) then
		reference.warn('(ref) WARNING: Object "' .. reference.compositeObjClass(obj, class) .. '" doesn\'t exist yet!')
	end
	local ref = {
		_obj = obj;
		_class = class;
		_arguments = arguments;
	}
	setmetatable(ref, reference._meta)
	return ref
end
function reference.destroy(ref)
	reference._run('destroyRef', {reference.splits(ref._obj), ref._tag or '##NULL'})
end
function reference.destroyInstance(obj)
	if reference.deprecatedWarnings then
		reference.warn('destroyInstance is deprecated. Use reference:destroy() instead')
	end
	return reference._run('destroyObj', {obj})
end
function reference.createInstance(tag, class, arguments)
	if tag == nil or class == nil then
		reference.warn('(createInstance) ERROR: Not enough arguments!', 'error')
		return nil
	end
	if reference.objectExists(tag, class) then
		reference.warn('(createInstance) ERROR: Object "' .. tostring(tag) .. '" already exists!', 'error')
		return nil
	end
	if not reference.isValidClass(class) then
		reference.warn('(createInstance) ERROR: Class "' .. tostring(class) .. '" doesn\'t exist!', 'error')
		return nil
	end
	arguments = arguments or ''
	reference._run('createInstance', {tag, class, arguments})
	local ref = reference.ref(tag)
	rawset(ref, '_tag', tag)
	return ref
end

-- lol
function reference.cast(ref)
	local get = reference.represent(reference._run('refCast', {ref}))
	if type(get) == 'table' then -- well duh i guess
		local finalTable = {}
		if reference.isArray(get) then
			for i, v in ipairs(get) do
				if v == '##SPECIAL' then v = reference.ref(ref._obj .. '[' .. (i - 1) .. ']', ref._class) end
				table.insert(finalTable, v)
			end
		else
			for k, v in pairs(get) do
				if v == '##SPECIAL' then v = reference.ref(ref._obj .. '[' .. k .. ']', ref._class) end
				finalTable[k] = v
			end
		end
		return finalTable
	end
	return get
end
function reference.reassign(ref, tag)
	if tag == ref or type(tag) ~= 'string' then tag = reference.getFreeTag(ref._class) end
	local success = reference._run('refAssign', {ref, tag})
	if success then
		return reference.ref(tag)
	else
		warn('(reassign) Failed to get / assign reference!', 'error')
		return nil
	end
end

-- indexing functions
function reference.callMethod(self, arguments)
	local ref = self
	local call = reference._run('objCallMethod', {reference.splits(ref._obj), ref._class, reference.fixBigInts(arguments), false})
	if call == '##SPECIAL' then
		return reference.ref(ref._obj, ref._class, arguments)
	else
		return call
	end
end
function reference.setField(self, field, val)
	local ref = self
	if type(field) == 'number' and not reference.indexFromZero then field = field - 1 end
	
	local gfield = ref._obj
	if (field ~= '' and field ~= c_VALUE) then
		gfield = gfield .. '.' .. field --(type(field) == 'number' and ('[' .. field .. ']') or ('.' .. field))
	end
	
	local simpleVal = ((not reference.isOneOfUs(val) and not reference.hasReferences(val)) or (reference.isOneOfUs(val) and reference.safeProp(val._obj, val._class) and getProperty(val._obj) ~= val._obj))
	if reference.safeProp(gfield, ref._class) and simpleVal then
		local set = (reference.isOneOfUs(val) and val._obj or val)
		if ref._class == '' then get = setProperty(gfield, reference.fixBigInts(set))
		else get = setPropertyFromClass(ref._class, gfield, reference.fixBigInts(set)) end
	else
		reference._run('objSetField', {reference.splits(gfield), ref._class, val == nil and '##NULL' or reference.fixBigInts(val)})
	end
end
function reference.getField(self, field)
	local ref = self
	if type(field) == 'number' and not reference.indexFromZero then field = field - 1 end
	
	local gfield = ref._obj
	if (field ~= '' and field ~= c_VALUE) then
		gfield = gfield .. '.' .. field --(type(field) == 'number' and ('[' .. field .. ']') or ('.' .. field))
	end
	
	if gfield:sub(1, 1) == '.' then
		gfield = gfield:sub(2)
	end
	
	local isSimple, propGot = reference.safeProp(gfield, ref._class)
	if isSimple then
		if propGot == '##SPECIAL' or propGot == gfield or type(propGot) == 'table' then
			return reference.ref(gfield, ref._class)
		else
			return propGot
		end
	else
		gfield = gfield:gsub('%[', '.'):gsub('[\'%]]', '')
		local get = reference._run('objGetField', {reference.splits(gfield), ref._class, false})
		if get == '##INVALID' then return nil end
		if get == '##SPECIAL' then
			return reference.ref(gfield, ref._class)
		else
			return get
		end
	end
end
function reference.ipairs(ref)
	if ref._obj == '' then warn('(ipairs) Can\'t iterate on this variable!') return ipairs({}) end
	local length = reference._run('dsLength', {ref})
	if length == nil then warn('(ipairs) Variable is not an array!') return ipairs({}) end
	local t = {}
	if stringStartsWith(length, '##ITER') then
		ref = ref.members
		length = length:gsub('##ITER', '')
		length = tonumber(length)
	end
	for i = 1, length do table.insert(t, ref[i]) end
	return ipairs(t)
end
function reference.pairs(ref)
	if ref._obj == '' then reference.warn('(pairs) Can\'t iterate on this variable!') return pairs({}) end
	local fields = reference._run('dsKeys', {ref})
	if type(fields) ~= 'table' then reference.warn('(pairs) Variable is not a map or object!') return pairs({}) end
	local t = {}
	for _, k in ipairs(fields) do
		t[k] = ref[k] --reference.ref(key, ref._class)
	end
	return pairs(t)
end

--hscript

hscript = {list = {}}
setmetatable(hscript, {
	__index = function(self, var) return self.list[var] end;
	__newindex = function(self, var, val) rawset(self.list, var, val) end;
	__call = function(_, code, vars) return reference.hscript(code, vars) end;
})
hscript._meta = {
	__index = function(self, var)
		if hscript[var] then return hscript[var] end
		return self:get(var)
	end;
	__newindex = function(self, var, val)
		if rawget(self, var) then rawset(self, var, val) return end
		if self.vars[var] then self.vars[var] = val end
		self:set(var, val)
	end;
	__call = function(self) return self:run() end;
}
local hscripts = 0

function hscript.new(id, code, vars)
	if id == hscript or id == self then id = nil end
	if id and hscript.list[id] then
		local hs = hscript.list[id]
		hs.code = code; hs.vars = vars
		warn('Hscript instance "' .. id .. '" is already initialized')
		return id
	end
	local code = code or ''
	local vars = (type(vars) == 'table' and vars or {})
	local new = {_started = false, _id = id and tostring(id) or ('hscript_' .. hscripts), code = code, vars = vars}
	reference._run('initHS', {new._id})
	setmetatable(new, hscript._meta)
	hscripts = hscripts + 1
	if id then
		hscript.list[new._id] = new
	end
	return new
end
function hscript.import(class, alias)
	if not reference.isValidClass(class) then
		warn('(hscript.import) ERROR: Class "' .. tostring(class) .. '" doesn\'t exist!', 'error')
		return false
	end
	alias = alias or reference.basicClassName(class)
	if not reference.isValidIdentifier(alias) then
		reference.warn('(hscript.import) ERROR: Identifier "' .. alias .. '" is invalid for alias!', 'error')
		return false
	end
	reference._run('importHS', {class, alias})
	return true
end
function hscript:run(func, args)
	--[[if not self._started then
		warn('Hscript instance "' .. self._id .. '" hasn\'t been started! Please use :start() first')
		return nil
	end]]
	if type(self.vars) ~= 'table' then self.vars = {} end
	return reference.represent(reference._run('runHS', {self._id, self.code, self.vars, type(func) == 'string' and func or '', type(args) == 'table' and args or {}}))
end
function hscript.getHS(id) return (type(id) == 'table' and id or hscript.list[id]) end
function hscript:get(var)
	self = hscript.getHS(self)
	if self.vars[var] then return self.vars[var] end
	local returned = reference._run('getHS', {self._id, var})
	if returned == '##METHOD' then
		return function(...)
			local args = {...}
			if args[1] == self then table.remove(args, 1) end
			return self:run(var, args)
		end
	else
		return reference.represent(returned)
	end
end
function hscript:set(var, val)
	local self = hscript.getHS(self)
	if self.vars[var] then self.vars[var] = val end
	return reference._run('setHS', {self._id, var, val})
end
function hscript:reset()
	local id = self._id
	self:destroy()
	return hscript.new(id)
end
function hscript:destroy()
	reference._run('destroyHS', {self._id})
	hscript.list[self._id] = nil
	self = nil --gootbye
end

reference._hsDisposable = hscript.new()

-- "utils" and stuff
function reference.isValidClass(class)
	return (class ~= nil and class ~= '' and reference.isValidIdentifier(class) and (callMethodFromClass('Type', 'resolveClass', {class})) or callMethodFromClass('Type', 'resolveEnum', {class})) end
function reference.getProperty(var)
	if reference.extreme then
		return reference._run('getPropertySafe', {var})
	else
		local success, prop = pcall(getProperty, var)
		if success then return prop
		else return '##SUPERSPECIAL' end -- most likely a very special fellow
		-- ##SUPERSPECIAL is for what we definitively can not get in lua
	end
end
function reference.getPropertyFromClass(class, var)
	--lazy as shit
	if isPre07 then
		return reference._run('getPropertyFromClass', {class, var})
	else
		local success, prop = pcall(getPropertyFromClass, class, var)
	end
	if success then return prop
	else return '##SUPERSPECIAL' end
end
function reference.safeProp(obj, class)
	if type(obj) == 'table' then return false end
	
	local prop
	if class == '' then
		prop = reference.getProperty(obj)
		if prop == '##SUPERSPECIAL' then return false end
	else
		prop = reference.getPropertyFromClass(class, obj)
		if prop == '##SUPERSPECIAL' then return false end
	end
	if prop == nil then return false end
	return true, prop
end
function reference.fixBigInts(val)
	if type(val) == 'number' and val >= 0x80000000 then
		return val - 0x100000000
	elseif type(val) == 'table' then
		for i, v in ipairs(val) do
			val[i] = reference.fixBigInts(v)
		end
	end
	return val
end
function reference.splits(name)
	local split = stringSplit(name, '.')
	for k, v in ipairs(split) do
		local isStr = (tonumber(v) == nil)
		if not isStr then split[k] = tonumber(v) end
	end
	return split
end
function reference.basicClassName(name)
	local s = stringSplit(name, '.')
	return s[#s]
end
function reference.represent(val)
	if stringStartsWith(val, '##REPRESENT') then
		return loadstring('return ' .. val:sub(12, #val))()
	end
	return val
end
function reference.compositeObjClass(obj, class) return (reference.isValidClass(class) and (class .. (obj ~= '' and ('.' .. obj) or '')) or obj) end
function reference.isValidIdentifier(id) return ((type(id) ~= 'string' or #id:gsub('[%w_.]', '') == 0) and id ~= '##NULL') end --yawnn... im still lazy...
function reference.isOneOfUs(tbl) return (type(tbl) == 'table' and getmetatable(tbl) == reference._meta) end
function reference.hasReferences(tbl)
	if type(tbl) ~= 'table' then return false end
	for _, v in (reference.isArray(tbl) and ipairs or pairs)(tbl) do
		if reference.isOneOfUs(v) then return true end
	end
	return false
end
function reference.getFreeTag(class)
	local tag = 'REFERENCE_SPRITE' .. reference._instincrement .. (class == '' and '' or '_' .. reference.basicClassName(class))
	reference._instincrement = reference._instincrement + 1
	return tag
end

-- class constructor (some sorta syntactic sugar for reference.createInstance)
new = {}
setmetatable(new, { __call = function(_, class) return new.construct(class) end; })
function new.construct(class)
	if reference.deprecatedWarnings then reference.warn('construct is deprecated. Use import "package.Class" instead') end

	if not reference.isValidClass(class) then
		reference.warn('(constructor) Class "' .. tostring(class) .. '" doesn\'t exist!', 'error')
		return nil
	end
	
	return function(tag, ...)
		if type(tag) ~= 'string' then
			reference.warn('(constructor) Tag must be provided as the first argument to construct the instance!', 'error')
			return nil
		end
		return reference.createInstance(tag, class, {...})
	end
end

return reference