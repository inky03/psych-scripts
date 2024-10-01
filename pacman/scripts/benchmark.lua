function onCreate()
	runHaxeCode([[
		function testFunc() {
			array = [];
			for (i in 0...1000000) array.push(i % 7);
			return array.length;
		}
		createGlobalCallback('testFunc', testFunc);
	]])
end

function onUpdatePost()
	if keyboardPressed('SHIFT') then
		if keyboardPressed('LEFT') then
			local t = os.clock()
			local r = runHaxeFunction('testFunc')
			debugPrint('rhf ; took ' .. (os.clock() - t) .. 's')
		elseif keyboardPressed('RIGHT') then
			local t = os.clock()
			local r = testFunc()
			debugPrint('callback ; took ' .. (os.clock() - t) .. 's')
		end
	end
end