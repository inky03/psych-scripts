if reference then return end
luaDebugMode = true

-- reference
reference = {}
reference.indexFromZero = false
reference.warnings = true
setmetatable(reference, {
	__index = reference;
	__call = function(_, ...) return reference.ref(...) end;
})

local colors = {
	warn = '0xffbf40';
	error = '0xff4020';
}
local errorPrefix = '<' .. scriptName .. '> '
local c_VALUE = '_value'

_meta = { --its a load of garbage
	__index = function(t, var)
		local indexes = {
			[c_VALUE] = function() return reference.cast(t) end;
			default = function() return reference.getField(t, var) end;
		}
		local f = indexes[var]
		return f and f() or indexes.default()
	end;
	__newindex = function(t, var, val)
		reference.setField(t, var, val)
	end;
	__call = function(t, ...)
		return reference.callMethod(t, {...})
	end;
}

runHaxeCode([[
	import ValueType;
	import haxe.ds.StringMap;
	import haxe.ds.IntMap;
	import haxe.ds.ObjectMap;
	
	var warnColor = ]] .. colors.warn .. [[;
	
	function isValidClass(class) return (Std.isOfType(class, String) && Type.resolveClass(class) != null);
	function arrayGet(array, n) return array.slice(n, n + 1).shift();
	function isMap(o) return (Std.isOfType(o, StringMap) || Std.isOfType(o, IntMap) || Std.isOfType(o, ObjectMap));
	function warn(text) debugPrint("]] .. errorPrefix .. [[ " + text, warnColor); //haha i need to fix this..
	
	function isAnon(test) return (Type.typeof(test) == ValueType.TObject);
	function isReference(test) {
		if (!isAnon(test)) return false;
		var fields = Reflect.fields(test);
		return (fields.contains('_obj') && fields.contains('_class') && fields.contains('_arguments'));
	}
	function objSplit(str) {
		var split = str.split('.');
		var finalSplit:Array = [];
		for (v in split) {
			var float = Std.parseFloat(v);
			if (!Math.isNaN(float)) v = float;
			finalSplit.push(v);
		}
		return finalSplit;
	}
	function objGet(split, class, special) {
		var fields = split;
		var point = (class == '' ? game : Type.resolveClass(class));
		if (split.length == 0) {
			return point;
		}
		
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
		} else {
			f = point;
		}
		
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
				if (getfield == null && !Reflect.fields(f).contains(field)) return '##INVALID';
				f = getfield;
			}
		}
		return (special || !isSpecial(f) ? f : '##SPECIAL');
	}
	function getLuaObject(tag) {
		for (a in [game.modchartSprites, game.modchartTexts, game.variables]) if (a.exists(tag)) return a.get(tag);
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
	function isSpecial(val) return (!Std.isOfType(val, Int) && !Std.isOfType(val, Float) && !Std.isOfType(val, String) && !Std.isOfType(val, Bool) && val != null);
	function refCast(ref) {
		if (!isReference(ref)) return null;
		var got = objGetFix(ref);
		var fields = Reflect.fields(got);
		if (!isAnon(got) && fields != null && fields.length > 0) return ['class' => Type.getClassName(Type.getClass(got)), 'fields' => fields];
		return got;
	}
	function objGetField(vget, gclass, special) {
		var got = objGet(vget, gclass, true);
		if (!special && isSpecial(got, special)) return '##SPECIAL';
		return got;
	}
	function objSetField(vget, gclass, vset) {
		var setfield = vget.pop();
		var got = objGet(vget, gclass, true);
		if (got == '##INVALID') {
			reference.warn('Can\'t get field: Object doesn\'t exist!');
			return null;
		}
		var setter = objGetFix(vset);
		if (setter == '##INVALID') {
			reference.warn('Can\'t get field: Field doesn\'t exist!');
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
					for (a in [game.modchartSprites, game.modchartTexts, game.variables]) {
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
	function objCallMethod(gobj, class, arguments, special) {
		var methodName = gobj.pop();
		var obj = objGet(gobj, class, true);
		if (obj != '##INVALID') {
			var method = Reflect.field(obj, methodName);
			if (Reflect.isFunction(method)) {
				var truArgument:Array = [];
				if (isAnon(arguments)) arguments = []; //empty array is passed as an anon structure, cause lua sucks
				for (arg in arguments) truArgument.push(objGetFix(arg));
				
				var returned = Reflect.callMethod(obj, method, truArgument);
				if (!special && isSpecial(returned)) return '##SPECIAL';
				return returned;
			} else {
				if (method == '##INVALID') {
					reference.warn('(objCallMethod) Can\'t call method: "' + methodName + '" doesn\'t exist!');
					return null;
				}
				reference.warn('(objCallMethod) Can\'t call method: "' + methodName + '" is not a method!');
				return null;
			}
		}
		reference.warn('(objCallMethod) Can\'t call method: Object doesn\'t exist!');
		return null;
	}
	function createInstance(tag, class, args) {
		if (args == '##NULL') args = [];
		var instance = Type.createInstance(Type.resolveClass(class), args);
		switch (class) {
			case 'flixel.FlxSprite', 'psychlua.ModchartSprite':
				game.modchartSprites.set(tag, instance);
			case 'flixel.text.FlxText':
				game.modchartTexts.set(tag, instance);
			default:
				game.variables.set(tag, instance);
		}
	}
]])

function reference.luaObjectExists(obj)
	return (runHaxeFunction('getLuaObject', {type(obj) == 'string' and obj or ''}) ~= '##INVALID')
end
function reference.objectExists(obj, class)
	class = (type(class) == 'string' and class or '')
	if class ~= '' and not reference.isValidClass(class) then
		reference.warn('(objectExists) ERROR: Class "' .. class .. '" doesn\'t exist!', 'error')
		return nil
	end
	local get = reference.isSimple(obj, class)
	if not get then
		local objT = obj:gsub('%[', '.'):gsub('[\'%]]', '')
		get = runHaxeFunction('objGet', {reference.splits(objT), class, false})
		return (get ~= '##INVALID')
	end
	return true
end
function reference.ref(obj, class, arguments)
    obj = obj or ''
	if obj == '' and class == '' then
		reference.warn('(new) ERROR: Object name can\'t be blank!', 'error')
		return nil
	end
	
	arguments = (type(arguments) == 'table' and arguments or {})
	if class == nil and reference.isValidClass(obj) then --this is so dumb..
		class = obj
		obj = ''
	else
		class = (type(class) == 'string' and class or '')
		if class ~= '' and not reference.isValidClass(class) then
			reference.warn('(new) ERROR: Class "' .. tostring(class) .. '" doesn\'t exist!', 'error')
			return nil
		end
	end
	
	obj = (type(obj) == 'string' and ((obj == '' and class == '') and 'game' or obj) or 'game')
	if class ~= '' and not reference.isValidClass(class) then
		reference.warn('(new) ERROR: Class "' .. tostring(class) .. '" doesn\'t exist!', 'error')
		return nil
	end
	
	local objT = obj:gsub('%[', '.'):gsub('[\'%]]', '') --:gsub('[%])]', ''):gsub('get%(', '')
	if not reference.isValidIdentifier(objT) then
		reference.warn('(new) ERROR: Identifier "' .. reference.compositeObjClass(obj, class) .. '" is invalid!', 'error')
		return nil
	end
	if not reference.objectExists(obj, class) then
		reference.warn('(new) WARNING: Object "' .. reference.compositeObjClass(obj, class) .. '" doesn\'t exist yet!')
	end
	local ref = {
		_obj = obj;
		_class = class;
		_arguments = arguments;
	}
	setmetatable(ref, _meta)
	return ref
end
function reference.destroyInstance(obj)
	return runHaxeFunction('destroyObj', {obj})
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
	arguments = ((type(arguments) == 'table' and #arguments > 0) and arguments or '##NULL')
	runHaxeFunction('createInstance', {tag, class, arguments})
	--createInstance(tag, class, arguments)
	local ref = reference.ref(tag)
	return ref
end
function reference.func()
	return scriptName
end

-- lol
function reference.cast(ref)
	return runHaxeFunction('refCast', {ref})
end

-- indexing functions
function reference.callMethod(self, arguments)
	local ref = self
	local call = runHaxeFunction('objCallMethod', reference.fixBigInts{reference.splits(ref._obj), ref._class, arguments, false})
	if call == '##SPECIAL' then
		return reference.ref(ref._obj, ref._class, arguments);
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
	
	local simpleVal = ((not reference.isOneOfUs(val) and not reference.hasReferences(val)) or (reference.isOneOfUs(val) and reference.isSimple(val._obj, val._class) and getProperty(val._obj) ~= val._obj))
	if reference.isSimple(gfield, ref._class) and simpleVal then
		local set = (reference.isOneOfUs(val) and val._obj or val)
		if ref._class == '' then get = setProperty(gfield, reference.fixBigInts(set))
		else get = setPropertyFromClass(ref._class, gfield, reference.fixBigInts(set)) end
	else
		runHaxeFunction('objSetField', reference.fixBigInts{reference.splits(gfield), ref._class, val == nil and '##NULL' or val})
	end
end
function reference.getField(self, field)
	local ref = self
	if type(field) == 'number' and not reference.indexFromZero then field = field - 1 end
	
	local gfield = ref._obj
	if (field ~= '' and field ~= c_VALUE) then
		gfield = gfield .. '.' .. field --(type(field) == 'number' and ('[' .. field .. ']') or ('.' .. field))
	end
	
	local get
	if reference.isSimple(gfield, ref._class) then
		if ref._class == '' then get = getProperty(gfield)
		else get = getPropertyFromClass(ref._class, gfield) end
		
		if type(get) == 'table' or get == gfield then
			return reference.ref(gfield, ref._class)
		else
			return get
		end
	else
		gfield = gfield:gsub('%[', '.'):gsub('[\'%]]', '')
		get = runHaxeFunction('objGetField', {reference.splits(gfield), ref._class, false})
		if get == '##INVALID' then return nil end
		if get == '##SPECIAL' then
			return reference.ref(gfield, ref._class)
		else
			return get
		end
	end
end

-- "utils" and stuff
function reference.isValidClass(class) return (class ~= nil and class ~= '' and reference.isValidIdentifier(class) and runHaxeFunction('isValidClass', {class})) end
function reference.isSimple(obj, class)
	if type(obj) == 'table' then return false end
	
	local get
	local split = reference.splits(obj)
	if #split > 0 and (stringStartsWith(split[#split], 'members') or stringStartsWith(split[#split], 'cameras') or stringStartsWith(split[#split], 'filters')) then
		return false --this is garbage but i dont want to loop through the object fields to find groups...i may end it
	end
	if class == '' then get = (getProperty(obj) ~= nil)
	else get = (getPropertyFromClass(class, obj) ~= nil) end
	
	return get
	--[=[
	local split = reference.splits(obj:gsub('%[', '.'):gsub('[\'%]]', ''))
	local g = ''
	if split[#split] == 'rgbShader' then debugPrint(split) end
	if #split > 1 then
		split[1] = split[1] .. '.' .. split[2]
		table.remove(split, 2)
	end
	for i, v in ipairs(split) do
		local num = type(v) == 'number'
		if i > 1 and not num then g = g .. '.' end
		g = g .. (num and ('[' .. v .. ']') or (v))
		local get = getProperty(g)
		if split[#split] == 'rgbShader' then debugPrint(g) end
		if get == nil or get == g then return false end
	end
	return true
	this is just a mess...(and it doesnt even work (and it even CRASHES the game but that may be cause of faulty assignment))
	]=]
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
function reference.compositeObjClass(obj, class) return (reference.isValidClass(class) and (class .. (obj ~= '' and ('.' .. obj) or '')) or obj) end
function reference.isValidIdentifier(id) return (type(id) ~= 'string' or #id:gsub('[%w_.]', '') == 0) end --yawnn... im still lazy...
function reference.isOneOfUs(tbl) return (type(tbl) == 'table' and getmetatable(tbl) == _meta) end
function reference.hasReferences(tbl)
	if type(tbl) ~= 'table' then return false end
	for _, v in (isArray(tbl) and ipairs or pairs)(tbl) do
		if reference.isOneOfUs(v) then return true end
	end
	return false
end
function isArray(tbl) return #tbl > 0 and next(tbl, #tbl) == nil end
function reference.warn(warning, col)
	col = (col or 'warn')
	if not reference.warnings and col == 'warn' then return end
	debugPrint(errorPrefix .. warning, colors[col])
end

-- class constructor (some sorta syntactic sugar for reference.createInstance)
new = {}
setmetatable(new, {
	__call = function(_, class) return new.constructor(class) end;
})
function new.constructor(class)
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