# "reference" module
my shitty stupid useless experiment module, using metatables!!<br>
this allows you to make "references" to objects, lua sprites and classes in game without having to type getProperty / setProperty on everything, allowing syntax to look almost similar to using source code / haxe!!

usage is explained below, example(a little outdated) provided in **reference_example.lua**<br>

## todo
feel free to pull request....the code sucks.....
- [ ] FIX DESTROYINSTANCE FUNCTION (it actually kind of doesnt work too much rn... hehehe......im jumping off a cliff)
- [ ] calling destroy() from a reference should also call reference.destroyInstance
- [ ] fix access to typed groups (a hacky solution is being used right now for basic uses, but is not applicable for most cases)
- [ ] ditch get/setPropertyFromGroup methods (not really necessary..)
- [ ] better map access?
- [ ] make code good..........
- [ ] is it possible to optimize methods inside methods?

## usage
+ begin by importing the module with the following snippet:
  ```lua
  reference = require(runHaxeCode('return Paths.modFolders("scripts/reference.lua");'):gsub('.lua', ''))`
  ```
  this is relative to the folder your mod is in.<br>
  replace the modFolders path to the appropriate path to the module if necessary!

all set! you can now for instance, get properties with `object.property`, set properties with `object.property = value`, and call methods with `object.method(arg1, arg2, ...)`
<br>some examples...
```lua
function onCreatePost()
	reference = require(runHaxeCode('return Paths.modFolders("scripts/reference.lua");'):gsub('.lua', '')) -- import module
	
	FlxG = reference.ref('flixel.FlxG')
	game = reference '' -- makes a REFERENCE to PlayState instance. syntactic sugar for ref
	Paths = reference 'backend.Paths'
	boyfriend = reference 'boyfriend'
	
	FlxG.mouse.visible = true
	boyfriend.x = 200
	boyfriend.y = boyfriend.x
	boyfriend.scale.set(4, 4)
	
	-- creating instances
	local myObject = reference.createInstance('myObject', 'flixel.FlxSprite', {100, 100})
	myObject.loadGraphic(Paths.image('icons/icon-bf'))
	game.add(myObject)
	
	local myOtherObject = new 'flixel.text.FlxText'('myText', 200, 200, 0, 'abcdef') -- syntactic sugar for createInstance
	myOtherObject.cameras = {game.camGame, game.camHUD} -- arrays work, too!
	myOtherObject.size = 40
	game.add(myOtherObject)
end
```

## main functions

### ref("objectTag", ?"className", ?{arguments})
> [!CAUTION]
> arguments are only used for method arguments and should only be used internally

called via `reference.ref("objectTag", "className", {arguments})`<br>
you may also use syntactic sugar like `reference "objectName/className"`
this function is the main point of the module, and returns a REFERENCE to an object or class<br>
- `objectTag` is the tag of the object to reference.
- `className` is the name of the class to reference.
	- if className is unprovided or blank (""), the PlayState instance is used.
	- if not provided and objectTag is a valid class, a reference to the class name provided by it is created instead
- `arguments` method arguments (refer to the caution blob)

**EXAMPLES**<br>
```lua
reference.new("mouse", "flixel.FlxG") -- creates a reference to "mouse" in the FlxG class
reference.new("backend.Paths") -- creates a reference to the Paths class in backend
reference.new("boyfriend") -- creates a reference to boyfriend
reference.new("") -- creates a reference to the PlayState instance
reference "boyfriend" -- creates a reference to boyfriend, with syntactic sugar
```

### createInstance("objectTag", "className", ?{arguments})
called via `reference.createInstance("objectTag", "className", {arguments})`<br>
you may also use syntactic sugar like `new "className"("objectTag", arguments...)`<br>
this function constructs an instance, adding it to the lua variables map. returns REFERENCE to the new instance.<br>
- `objectTag` is the tag to assign the new instance to
- `className` is the class type of the new instance
- `arguments` constructor arguments for the new instance

**EXAMPLES**<br>
```lua
reference.createInstance('myObject', 'flixel.FlxSprite', {100, 100}) -- creates a FlxSprite instance with the tag "myObject" with the arguments x:100, y:100
new 'flixel.FlxSprite'('myObject', 100, 100) -- syntactic sugar for reference.createInstance. the first argument in the function MUST BE the tag
```

### destroyInstance("objectTag")
called via `reference.destroyInstance("objectTag")`<br>
this function destroys the instance and removes it from the lua variables map. no return value<br>
- `objectTag` is the name or tag of the object to destroy

### cast(reference)
"casts" value of a reference to lua readable.<br>
you can also get this by accessing `_value` in a reference as such: `reference._value`<br>
this is mainly useful to cast values from anonymous objects, maps, tables<br>
if the object/field reference casted is from a class, a table of the form `{class = 'class', fields = {'fieldName'...}}` is returned
- `reference` is the reference to cast

**EXAMPLE**<br>
```lua
local boyfriend = reference 'boyfriend'
debugPrint(boyfriend.healthColorArray) -- this will only return the reference to healthColorArray
debugPrint(reference.cast(boyfriend.healthColorArray)) -- "cast" reference value, getting the intended array
debugPrint(boyfriend.healthColorArray._value) -- you can use _value instead of calling cast too (and is easier to type...)
```

### luaObjectExists("objectTag")
checks if a lua object exists. returns a boolean (true if exists, false otherwise)<br>
- `objectTag` is the tag of the lua object to check

**EXAMPLE**<br>
```lua
reference.luaObjectExists('abcdef') -- checks if lua object 'abcdef' exists
```

### objectExists("objectTag", "className")
checks if an object exists. returns a boolean (true if exists, false otherwise)<br>
- `objectTag` is the name/tag of the object to check
- `className` is the name of the class to check in
	- if className is unprovided or blank (""), the PlayState instance is used.

**EXAMPLE**<br>
```lua
reference.objectExists('mouse', 'flixel.FlxG') -- checks if mouse in flixel.FlxG exists (11 times out of 10, this is true)
reference.objectExists('abcdef') -- checks if object 'abcdef' exists in PlayState instance
```

## variables

### indexFromZero
`false` by default! set with `reference.indexFromZero = bool`.<br>
- when disabled, arrays from references are indexed from 1 as is usual from ***LUA*** ARRAY ACCESS.
- when enabled, arrays from references are indexed from 0 as is usual from ***HAXE*** ARRAY ACCESS.

### warnings
`true` by default! set with `reference.warnings = bool`.<br>
shows useful warnings for debugging when something goes wrong (invalid object, class, etc).
