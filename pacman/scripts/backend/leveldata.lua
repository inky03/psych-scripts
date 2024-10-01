if leveldata then return end
leveldata = {}
leveldata.__index = leveldata

function leveldata.from(tbl, level)
	local new = {}
	local sorted = {}
	for lv, data in pairs(tbl) do table.insert(sorted, tonumber(lv)) end
	table.sort(sorted)
	for _, lv in ipairs(sorted) do
		local data = tbl[tostring(lv)]
		if lv > level then break end
		util.tableAppend(new, data)
	end
	if next(new) == nil then
		if tbl ~= leveldata.fallback then
			new = leveldata.from(leveldata.fallback, math.max(level, 1))
		else
			debugPrint('(leveldata) Failed to get table fallback (level ' .. level .. ')', 'ff0000')
		end
	end
	
	return new
end
function leveldata.fromSet(set, level, maze)
	local new = {}
	
	new = leveldata.from(util.getJSON('mazes/' .. set .. '/general.json').levels or {}, level)
	if maze and maze.meta.level then
		util.tableAppend(new, maze.meta.level)
	end
	
	return new
end

leveldata.fallback = { -- yea...
	['1'] = {
		bonus = 'cherry';
		pacman_speed = {
			normal = 0.8;
			power = 0.9
		};
		ghost_speed = {
			normal = 0.75;
			tunnel = 0.4;
			fright = 0.5;
			elroy1 = 0.8;
			elroy2 = 0.85
		};
		elroy_dots = 20;
		fright_duration = 360;
		mode_switch = { 140; 400; 140; 400; 100; 400; 100 }
	};
	['2'] = {
		bonus = 'strawberry';
		pacman_speed = {
			normal = 0.9;
			power = 0.95
		};
		ghost_speed = {
			normal = 0.85;
			tunnel = 0.45;
			fright = 0.55;
			elroy1 = 0.9;
			elroy2 = 0.95
		};
		elroy_dots = 30;
		fright_duration = 300;
		mode_switch = { 140; 400; 140; 400; 100; 61994; 1 }
	};
	['3'] = {
		bonus = 'orange';
		elroy_dots = 40;
		fright_duration = 240
	};
	['4'] = { fright_duration = 180 };
	['5'] = {
		bonus = 'apple';
		pacman_speed = {
			normal = 1;
			power = 1
		};
		ghost_speed = {
			normal = 0.95;
			tunnel = 0.5;
			fright = 0.6;
			elroy1 = 1;
			elroy2 = 1.05
		};
		fright_duration = 120;
		mode_switch = { 100; 400; 100; 400; 100; 61994; 1 }
	};
	['6'] = {
		elroy_dots = 50;
		fright_duration = 300
	};
	['7'] = {
		bonus = 'melon';
		fright_duration = 120
	};
	['9'] = {
		bonus = 'galaxian';
		elroy_dots = 60;
		fright_duration = 60
	};
	['10'] = { fright_duration = 300 };
	['11'] = {
		bonus = 'bell';
		fright_duration = 120
	};
	['12'] = {
		elroy_dots = 80;
		fright_duration = 60
	};
	['13'] = { bonus = 'key' };
	['14'] = { fright_duration = 180 };
	['15'] = {
		elroy_dots = 100;
		fright_duration = 60
	};
	['17'] = { fright_duration = 0 };
	['18'] = { fright_duration = 60 };
	['19'] = {
		elroy_dots = 120;
		fright_duration = 0
	};
	['21'] = {
		pacman_speed = { normal = 0.9 }
	}
}

return leveldata