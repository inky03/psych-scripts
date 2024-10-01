if tween then return end
tween = {}
tween.__index = tween
tween.Manager = {tweens = {}}
tween.Ease = {}
tween.Type = {}

tween.pi2 = math.pi * 2
tween.B1 = 1 / 2.75 -- bounce easing...
tween.B2 = 2 / 2.75
tween.B3 = 1.5 / 2.75
tween.B4 = 2.5 / 2.75
tween.B5 = 2.25 / 2.75
tween.B6 = 2.625 / 2.75
tween.elasticAmp = 1
tween.elasticPeriod = .4
function tween.flip(twn)
	return (function(t) return (1 - twn(1 - t)) end)
end
function tween.inOut(In, Out)
	return (function(t) return (t < .5 and In(t * 2) or Out(t * 2 - 1)) end)
end
function tween.outIn(Out, In)
	return (function(t) return (t < .5 and Out(t * 2) or In(t * 2 - 1)) end)
end
for k, twn in pairs{ --in functions
	quad = function(t) return (t ^ 2) end;
	cube = function(t) return (t ^ 3) end;
	quart = function(t) return (t ^ 4) end;
	quint = function(t) return (t ^ 5) end;
	sine = function(t) return (-math.cos(tween.pi2 * t) + 1) end;
	circ = function(t) return (-math.sqrt(1 - t * t) + 1) end;
	expo = function(t) return math.pow(2, 10 * (t - 1)) end;
	back = function(t) return (t * t * (2.70158 * t - 1.70158)) end; -- what did they mean by this
	elastic = function(t)
		t = t - 1
		return -(tween.elasticAmp * math.pow(2, -- no seriously, what did they mean by this
		10 * t) * math.sin((t - (tween.elasticPeriod / tween.pi2 * math.asin(1 / tween.elasticAmp))) * tween.pi2 / tween.elasticPeriod))
	end
} do
	tween.Ease[k .. 'in'] = twn
	tween.Ease[k .. 'out'] = tween.flip(twn)
	tween.Ease[k .. 'inout'] = tween.inOut(twn, tween.Ease[k .. 'out'])
	tween.Ease[k .. 'outin'] = tween.outIn(tween.Ease[k .. 'out'], twn)
end
--outliers
tween.Ease.linear = function(t) return t end
tween.Ease.bounceout = function(t) -- what the hell
	if t < tween.B1 then return (7.5625 * t * t) end
	if t < tween.B2 then return (7.5625 * (t - tween.B3) ^ 2 + .75) end
	if t < tween.B4 then return (7.5625 * (t - tween.B5) ^ 2 + .9375) end
	return (7.5625 * (t - tween.B6) ^ 2 + .984375)
end
tween.Ease.bouncein = tween.flip(tween.Ease.bounceout)
tween.Ease.bounceinout = tween.inOut(tween.Ease.bouncein, tween.Ease.bounceout)
tween.Ease.smoothstepinout = function(t) return (t * t * (t * -2 + 3)) end
tween.Ease.smoothstepin = function(t) return (2 * tween.Ease.smoothstepinout(t * .5)) end
tween.Ease.smoothstepout = tween.flip(tween.Ease.smoothstepin)
tween.Ease.smootherstepinout = function(t) return (t * t * t * (t * (t * 6 - 15) + 10)) end
tween.Ease.smootherstepin = function(t) return (2 * tween.Ease.smootherstepinout(t * .5)) end
tween.Ease.smootherstepout = tween.flip(tween.Ease.smootherstepin)
for _, ease in ipairs{'bounce'; 'smoothstep'; 'smootherstep'} do
	tween.Ease[ease .. 'outin'] = tween.outIn(tween.Ease[ease .. 'out'], tween.Ease[ease .. 'in'])
end

tween.Type.oneshot = 0
tween.Type.persist = 1 -- todo implement types
tween.Type.looping = 2 -- todo: still implement types
tween.Type.pingpong = 3
tween.Type.backward = 4

function tween.lerp(a, b, t) return a + (b - a) * t end
function tween.getEase(val)
	if type(val) == 'function' and type(val(0)) == 'number' then return val end
	if type(val) == 'string' then return tween.Ease[val:lower()] or tween.Ease.linear end
	return tween.Ease.linear
end
function tween.update(twn, dt)
	if not twn or not twn.playing then return end
	if not twn.base then
		tween.collect = true
		return
	end
	twn.elapsed = twn.elapsed + dt
	local p = math.max(math.min(twn.elapsed / twn.duration, 1), 0)
	local ease = twn.options.ease
	if twn.startVals then
		local prog = ease(p)
		for k, v in pairs(twn.startVals) do
			local tweened = tween.lerp(v, twn.finish[k], prog)
			twn.base[k] = tweened
		end
		local update = twn.options.onUpdate
		if update then update(prog) end
	else
		local tweened = tween.lerp(twn.base, twn.finish, ease(p))
		local update = twn.options.onUpdate
		if update then update(tweened) end
	end
	if twn.elapsed >= twn.duration then
		twn.elapsed = -twn.options.startDelay
		twn.playing = false
		local complete = twn.options.onComplete
		if complete then complete(twn) end
		if twn.options.type == tween.Type.oneshot then twn.collect = true end
	end
end
function tween.tween(start, finish, duration, options, onUpdate)
	if type(start) ~= type(finish) then
		debugPrint('(tween) Start and finish type must match!', 'ff0000')
		return nil
	end
	if type(start) ~= 'table' and type(start) ~= 'number' then
		debugPrint('(tween) Can\'t tween type ' .. type(start) .. '!', 'ff0000')
		return nil
	end
	if type(duration) ~= 'number' then
		debugPrint('(tween) Duration must be a number...', 'ff0000')
		return nil
	end
	local starts
	if type(start) == 'table' then
		starts = {}
		for k, v in pairs(finish) do
			local startVal = start[k]
			if type(startVal) ~= 'number' or type(v) ~= 'number' then
				-- todo: recursion? maybe?? who cares (hint: me)
				debugPrint('(tween) Field "' .. k .. '" is not numeric!', 'ff0000')
				return
			end
			starts[k] = startVal
		end
	end
	local twn = {}
	setmetatable(twn, tween)
	twn.collect = false
	twn.playing = true
	twn.base = start
	twn.startVals = starts
	twn.finish = finish
	twn.duration = duration
	options = (type(options) == 'table' and options or {})
	twn.options = {
		type = options.type or tween.Type.oneshot;
		ease = tween.getEase(options.ease);
		startDelay = options.startDelay or 0;
		loopDelay = options.loopDelay or 0;
		onComplete = options.onComplete;
		onUpdate = options.onUpdate or onUpdate;
	}
	twn.elapsed = -twn.options.startDelay
	twn.cancel = function(self) self.collect = true end
	twn.play = function(self) self.playing = true end
	table.insert(tween.Manager.tweens, twn)
	return twn
end
tween.Manager.update = function(elapsed)
	local self = tween.Manager
	for i, tween in ipairs(self.tweens) do
		if not tween.collect then tween:update(elapsed) end
		if tween.collect then
			table.remove(self.tweens, i)
		end
		::continue::
		--debugPrint(tween.elapsed)
	end
end

return tween