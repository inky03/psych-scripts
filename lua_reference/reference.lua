reference = {}

addHaxeLibrary('LuaUtils', 'psychlua')
_meta = { --its a load of garbage
	__index = function(t, k)
		return returnProp(t.tag, k)
	end;
	__newindex = function(t, k, v)
		local method = getMethod(t.tag)
		if method then
			if isHProp(v) then
				runHaxeCode([[
					var obj = LuaUtils.getObjectDirectly("]] .. formatString(t.tag) .. [[");
					if (obj != null) {
						Reflect.setProperty(obj, "]] .. formatString(k) .. [[", ]] .. toHString(v) .. [[);
					}
					return;
				]])
			else
				setProperty(t.tag .. '.' .. k, v)
			end
		end
	end;
	__call = function(t, f, ...)
		local args = {...}
		if getProperty(t.tag) ~= nil and getProperty(t.tag) ~= t.tag then
			return callMethod(t.tag .. '.' .. f, args)
		else
			local obj = t.tag:find('%.') and stringSplit(t.tag, '.')[1] or t.tag
			local props = t.tag:find('%.') and t.tag:sub(t.tag:find('%.'), #t.tag) or ''
			return runHaxeCode([[
				var obj = LuaUtils.getObjectDirectly("]] .. formatString(obj) .. [[");
				if (obj != null) return Reflect.callMethod(obj]] .. props .. [[, "]] .. formatString(f) .. [[", ]] .. toHString(args) .. [[);
				return null;
			]])
		end
		--debugPrint('CALLED')
	end;
	__tostring = function(t)
		return t.tag
	end;
}

function reference:new(tag)
	if not getMethod(tag) then debugPrint('(reference) failed to get object (' .. tag .. ')', 'ORANGE') end
	local ref = {tag = tag}
	setmetatable(ref, _meta)
	--debugPrint('new ' .. tag)
	return ref
end

function isArray(t)
	if type(t) ~= 'table' then return false end
	if #t > 0 then return true end
	for _, _ in pairs(t) do return false end
	return true
end
function isHProp(val)
	return getmetatable(val) == _meta
end
function toHString(val, opening, closing)
	local t = type(val)
	if t == 'string' then return '\'' .. val .. '\'' end
	if t == 'number' or t == 'boolean' then return tostring(val) end
	if t ~= 'table' then return 'null' end --unsupported
	--if isHProp then return tostring(val) end
	
	local r
	local opening = opening or '['
	local closing = closing or ']'
	if isArray(val) then
		r = opening
		for _, v in ipairs(val) do r = r .. v .. ', ' end
		if (r ~= opening) then r = r:sub(1, #r - 2) end
		r = r .. closing
	else
		r = opening
		for k, v in pairs(val) do r = r .. k .. ' => ' .. toHString(v) .. ', ' end
		if (r ~= opening) then r = r:sub(1, #r - 2) end
		r = r .. closing
	end
	return r
end
function getMethod(tag)
	if not isValid(tag) then return false end
	--debugPrint(tag)
	if getProperty(tag) ~= nil or getProperty(tag) == tag or runHaxeCode("return game.getLuaObject(\"" .. formatString(tag) .. "\") != null;") then return true end
	return false
end
function formatString(str) return str:gsub('"', '\\"') end
function isValid(tag) return (#tag:gsub('[%w_.]', '') == 0) end --yawn im lazy
function returnProp(tag, k)
	local prop = type(k) == 'number' and ('[' .. k .. ']') or ('.' .. k)
	local get = getProperty(tag .. prop)
	if (get == tag .. prop or get == nil) then
		if not isValid(k) then return nil end
		local obj = tag:match('%.') and stringSplit(tag, '.')[1] or tag
		local props = tag:find('%.') and tag:sub(tag:find('%.'), #tag) or ''
		local cmd = ([[
			var obj = LuaUtils.getObjectDirectly("]] .. formatString(obj) .. [[");
			if (obj != null) return Reflect.getProperty(obj]] .. props .. [[, "]] .. formatString(k) .. [[");
			return;
		]])
		get = runHaxeCode(cmd)
		if get == nil then --failed
			return nil
		elseif get == cmd then --"failed" (cant return proper value but also cant return null)
			return reference:new(tag .. prop)
		end
		return get
	end
	return get
end

return reference