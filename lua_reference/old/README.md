## "object reference" module
OUTDATED! theres a NEW BETTER version available in the previous folder

this is a silly experiment i made with metatables!! this allows you to make "references" to objects and lua sprites in game without having to type getProperty / setProperty on everything. do note it may be a little buggy and unfinished as its just more of a proof of concept!

### usage
+ import the module with require `reference = require(runHaxeCode('return Paths.modFolders("scripts/reference");'))` (replace scripts/reference to the appropriate path to the module if necessary)
+ make a reference!! for example `boyfriend = reference.new('boyfriend')` will make a reference for the boyfriend sprite

all set! you can now change get properties with `object.property`, set properties with `object.property = value` and call functions with `object('methodName', arg1, arg2, ...)`
<br>full code example:
```lua
function onCreatePost()
	reference = require(runHaxeCode('return Paths.modFolders("scripts/reference");'))
	boyfriend = reference.new('boyfriend')
	boyfriend.x = 200 --sets bf's x position to 200
	boyfriend.y = boyfriend.x --sets bf's y position to bf's x position
	boyfriend.scale('set', 4, 4) --< this is how you call a method! this calls scale.set on boyfriend to x:4 and y:4
end
```
