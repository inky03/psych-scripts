util = {}

util.percentToSpeed = 1.25 -- hehe
function util.shaderSet(ref, uniforms, normalize)
	local norm = {['r'] = true; ['g'] = true; ['b'] = true}
	local shd = ref
	for uniform, val in pairs(uniforms) do
		if normalize and norm[uniform] then -- utterly deranged
			for i, v in ipairs(val) do val[i] = v / 255 end
		end
		if type(val) == 'number' then shd.setFloat(uniform, val)
		elseif type(val) == 'table' then shd.setFloatArray(uniform, val) -- whatever nobody uses bool array
		elseif type(val) == 'boolean' then shd.setBool(uniform, val)
		elseif val == 'true' or val == 'false' then shd.setBool(uniform, val == 'true')
		else --[[ nothing ]] end
	end
end
function util.isInt(n) return (n == math.floor(n)) end
function util.round(n) return (n > 0 and math.floor(n + .5) or math.ceil(n  - .5)) end
function util.sign(n) return (n > 0 and 1 or (n < 0 and -1 or 0)) end
function util.euclideanDist(pointA, pointB) return math.sqrt((pointB.X - pointA.X) ^ 2 + (pointB.Y - pointA.Y) ^ 2) end
function util.isArray(tbl) return (#tbl > 0 and next(tbl, #tbl) == nil) end
function util.tableAppend(tbl, new)
	for k, v in pairs(new) do
		if tbl[k] ~= nil and type(v) == 'table' then
			util.tableAppend(tbl[k], v)
		else
			tbl[k] = v
		end
	end
	return tbl
end
function util.tableFallback(tbl, entry, data)
	if tbl[entry] == nil then
		tbl[entry] = data
	elseif type(data) == 'table' then
		for field, val in (util.isArray(data) and ipairs or pairs)(data) do
			util.tableFallback(tbl[entry], field, val)
		end
	end
end
function util.tableCopy(tbl)
	if type(tbl) ~= 'table' then return nil end
	local copy = {}
	for k, v in (util.isArray(tbl) and ipairs or pairs)(tbl) do
		copy[k] = (type(v) == 'table' and util.tableCopy(v) or v)
	end
	return copy
end
function util.arrayOperate(array, op, ...)
	if not util.isArray(array) then return array end
	local operation
	if op == '+' then operation = function(a, b) return a + b end
	elseif op == '-' then operation = function(a, b) return a - b end
	elseif op == '*' then operation = function(a, b) return a * b end
	elseif op == '/' then operation = function(a, b) return a / b end
	elseif op == '%' then operation = function(a, b) return a % b end
	elseif math[op] then operation = function(...) return math[op](...) end
	end
	local num
	local ok = {...}
	local arrayCopy = util.tableCopy(array)
	for i, v in ipairs(arrayCopy) do
		if type(v) == 'number' then
			local val = ok[1] -- im lazey
			if type(val) == 'number' then num = val
			elseif util.isArray(val) then num = val[math.min(i, #val)]
			else num = nil
			end
			arrayCopy[i] = operation(v, num or 1)
		end
	end
	return arrayCopy
end
function util.tableEquals(tbl, tble, recursive, onlyStructure, onlyType)
	local onlyType = onlyType or false
	local recursive = recursive or true
	local onlyStructure = onlyStructure or false
	local fields = {}
	for k, v in pairs(tbl) do
		fields[k] = true
		table.insert(fields, k)
		local compVal = tble[k]
		if type(v) == 'table' then
			if not recursive then goto ignore end
			if type(compVal) == 'table' then
				if not util.tableEquals(v, compVal, recursive, onlyStructure) then
					return false
				end
			else
				return false
			end
			::ignore::
		elseif reference and reference.isOneOfUs(v) then
			if not reference.isOneOfUs(compVal) then
				return false
			end
		elseif not onlyStructure then
			if onlyType then
				if type(v) ~= type(compVal) then
					return false
				end
			elseif v ~= compVal then
				return false
			end
		end
	end
	local fCount = 0
	for k, v in pairs(tble) do
		if not fields[k] then return false end
		fCount = fCount + 1
	end
	if fCount ~= #fields then return false end
	return true
end
function util.tableCount(tbl)
	local n = 0
	for _ in pairs(tbl) do n = n + 1 end
	return n
end
function util.getJSON(path)
	local jsonContent = getTextFromFile(path)
	if jsonContent ~= nil then return JSON.parse(jsonContent)._value
	else return {} end
end

return util