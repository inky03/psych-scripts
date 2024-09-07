# "reference" module
**CURRENT VERSION: 1.1.5 (reference115)**<br>
psych versions (known to be) supported: **0.7.3** (sscript 7.7.0), **1.0 ACTIONS** (hscript-iris)

my shitty stupid useless experiment module, using metatables!!<br>
this allows you to make "references" to objects, lua sprites and classes in game without having to type getProperty / setProperty on everything, allowing syntax to look almost similar to using source code / haxe!!

this module adds two important globals; [reference](#reference) and [hscript](#hscript).<br>
usage is explained below, example(a little outdated) provided in **reference_example.lua**<br>

## todo
feel free to pull request....the code sucks.....
- [X] calling destroy() from a reference should also call reference.destroyInstance
- [X] fix access to typed groups (a hacky solution is being used right now for basic uses, but is not applicable for most cases)
- [X] ditch get/setPropertyFromGroup methods (not really necessary..)
- [X] better map access?
- [ ] make ipairs via Iterator actually do its damn job correctly (it works with members so far, atleast...)
- [ ] make code good..
- [ ] optimizations?

## usage
+ begin by importing the module with the following snippet:
	**0.7:**
  ```lua
  reference = require(callMethodFromClass('Paths', 'modFolders', {'scripts/reference.lua'}):gsub('.lua', ''))
  ```
  **1.0:**
  ```lua
  reference = require('mods/' .. modFolder .. '/scripts/reference')
  ```
  this is relative to the folder your mod is in.<br>
  replace the path to the module if necessary!

all set! you can create references and get properties with `ref.property`, set properties with `ref.property = value`, and call methods with `ref.method(arg1, arg2, ...)`
<br>some examples...
```lua
function onCreatePost()
	reference = require(runHaxeCode('return Paths.modFolders("scripts/reference.lua");'):gsub('.lua', '')) -- import module
	
	import 'flixel.FlxG' -- sets FlxG as the flixel.FlxG class
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
	
	import 'flixel.text.FlxText'
	local myOtherObject = FlxText.new('myText', 200, 200, 0, 'abcdef') -- you can also create instances by calling "new" on the class reference!
	myOtherObject.cameras = {game.camGame, game.camHUD} -- arrays work, too!
	myOtherObject.size = 40
	game.add(myOtherObject)
end
```

# reference

this is the foundation of the module, and is used for creating and accessing references to instances!

### reference.preset()
running this will set a couple classes and variables automatically, specially useful for getting started.<br>
imports the following classes:
| Class | Alias |
|  ---: | :---  |
| `flixel.FlxG` | `FlxG` |
| `flixel.FlxSprite` | `FlxSprite` |
| `flixel.math.FlxMath` | `FlxMath` |
| `flixel.text.FlxText` | `FlxText` |
| `backend.Paths` | `Paths` |
| `objects.Character` | `Character` |
| `backend.Conductor` | `Conductor` |
| `backend.ClientPrefs` | `ClientPrefs` |
| `backend.PsychCamera` | `PsychCamera` |
| `backend.Achievements` | `Achievements` |
| `psychlua.ModchartSprite` | `LuaSprite`, `ModchartSprite` |
| `states.PlayState` | `PlayState` |
| `StringTools` | `StringTools` |
| `PlayState.instance` | `game` |

**EXAMPLES**
```lua
reference.preset()
local sprite = FlxSprite:new(100, 100) -- FlxSprite is imported with preset
game.add(sprite) -- game is imported with preset
```

### reference.ref("objectTag", ?"className", ?{arguments})
> [!CAUTION]
> arguments are only used for method arguments and should only be used internally

you may also use syntactic sugar like `reference "objectName/className"`<br>
this is the main function, which returns a **reference** to an object or class.<br>
- `objectTag` is the tag/name of the object to reference.
- `className` is the name of the class to reference.
	- if className is unprovided or a blank string (""), the PlayState instance is used.
	- if not provided and objectTag is a valid class, a reference to the class name provided by it is created instead
- `arguments` method arguments (refer to the caution blob)

**EXAMPLES**<br>
```lua
import 'backend.Paths' -- create a reference to backend.Paths in the global variable "Paths"
reference.new("mouse", "flixel.FlxG") -- creates a reference to "mouse" in the FlxG class
reference.new("boyfriend") -- creates a reference to boyfriend
reference.new("") -- creates a reference to the PlayState instance
reference "boyfriend" -- creates a reference to boyfriend, with syntactic sugar
```

### reference.createInstance("objectTag", "className", ?{arguments})
this function constructs an instance, adding it to the lua variables map. returns a **reference** to the new instance.<br>
you can also use **import** and call "new" on the class reference to create an instance!<br>
- `objectTag` is the tag to assign the new instance to
- `className` is the class type of the new instance
- `arguments` constructor arguments for the new instance

**EXAMPLES**<br>
```lua
-- with createInstance
local sprite = reference.createInstance('myObject', 'flixel.FlxSprite', {100, 100}) -- creates a FlxSprite with the tag "myObject" with the arguments x:100, y:100

-- with import
import 'flixel.FlxSprite'
local sprite = FlxSprite.new('myObject', 100, 100) -- ditto, with different usage
local sprite2 = FlxSprite:new(100, 100) -- calling new with a colon (:) instead of a dot (.) will assign the instance an automatically generated tag. keep track of this instance to not lose it!
```

### reference:destroy()
destroys the instance used by a reference and removes it from the lua variables maps (if applicable). no return value<br>
you can also use `reference.destroy(reference)`.

**EXAMPLES**<br>
```lua
import 'flixel.FlxSprite' -- we create an object first...
local sprite = FlxSprite:new()
sprite:destroy() -- then we destroy it.
reference.destroy(sprite) -- you can do this, alternatively!
```

### reference:reassign("tag")
assign a reference to a new tag, adding it to the lua variables map. returns a **reference** to the instance with the new tag<br>
this may be useful if you want to store references to objects in variables that may be later replaced, for instance.
- `tag` new tag to assign the object to

**EXAMPLES**<br>
```lua
local game = reference ''
game.playerStrums.members[1]:reassign('strumRef') -- assign the first player strum to a new tag "strumRef"
reference('strumRef').x = 100 -- the first player strum, which is now stored with this tag, has its x position changed to 100
```

### reference:ipairs()
returns an index -> value iterator from a **reference** that holds an array or an object that has an Iterator.<br>
you can also use `reference.ipairs(reference)`.

**EXAMPLES**<br>
```lua
local game = reference ''
for i, strum in game.playerStrums:ipairs() do
	strum.x = 50 + i * 100 -- repositions all player strums
end
```

### reference:pairs()
returns a key -> value iterator from a **reference** that holds a map or an object.<br>
you can also use `reference.pairs(reference)`

**EXAMPLES**<br>
```lua
local game = reference ''
for anim, offset in game.boyfriend.animOffsets:pairs() do
	debugPrint(anim .. ' -> ' .. table.concat(offset._value, ', ')) -- prints all animation offsets in the format "animationName -> x, y"
end
```

### reference.cast(reference)
"casts" value of a reference to lua readable value.<br>
you can alternatively access `_value` in a reference to cast it as such: `reference._value`<br>
this is mainly useful to cast values from anonymous objects, maps, tables<br>
if the object/field reference casted is a class type, a table of the form `{class = 'class', fields = {'fieldName'...}}` is returned
- `reference` is the reference to cast

**EXAMPLES**<br>
```lua
local game = reference ''
debugPrint(game.boyfriend.animOffsets) -- only prints a REFERENCE to the animOffsets map, not returning the map itself!!
debugPrint(reference.cast(game.boyfriend.animOffsets)) -- casts the animation offsets map from the boyfriend character, and prints it
debugPrint(game.boyfriend.animOffsets._value) -- same as cast; alternative usage
```

### reference.luaObjectExists("objectTag")
checks if a lua object exists. returns a boolean (true if exists, false otherwise)<br>
- `objectTag` is the tag of the lua object to check

**EXAMPLE**<br>
```lua
reference.luaObjectExists('abcdef') -- checks if lua object/variable with the tag "abcdef" exists
```

### reference.objectExists("objectTag", "className")
checks if an object exists. returns a boolean (true if exists, false otherwise)<br>
- `objectTag` is the name/tag of the object to check
- `className` is the name of the class to check in
	- if className is unprovided or blank (""), the PlayState instance is used.

**EXAMPLE**<br>
```lua
reference.objectExists('mouse', 'flixel.FlxG') -- checks if mouse in flixel.FlxG exists (11 times out of 10, this is true)
reference.objectExists('abcdef') -- checks if object 'abcdef' exists in PlayState instance
```

### reference.hscript("code", ?{variables})
runs hscript code.<br>
you can also use `hscript("code", ?{variables})`, omitting the "reference."<br>
this function will also allow you to pass in references as variables to the script.
see the [hscript](#hscript) section for more information on hscript functions.
- `code` code to run
- `variables` variables to set in the script when it runs

**EXAMPLES**<br>
```lua
local game = reference ''
reference.hscript([[
	debugPrint('testing testing ' + testVar);
	testStrum.setPosition(100, 100);
]], {testVar = 123; testStrum = game.playerStrums.members[1]})
```

### reference.destroyInstance("objectTag")
> [!WARNING]
> this function is now deprecated. use reference:destroy() instead

this function destroys the instance and removes it from the lua variables maps (if applicable). no return value<br>
- `objectTag` is the name or tag of the object to destroy

## variables

### reference.version
returns the current version of the module, as a string. get with `reference.version`.

### reference.indexFromZero
`false` by default! set with `reference.indexFromZero = bool`.<br>
- when disabled, arrays from references are indexed from 1 as is usual from **Lua** array access.
- when enabled, arrays from references are indexed from 0 as is usual from **Haxe** array access.

### reference.warnings
`true` by default! set with `reference.warnings = bool`.<br>
shows useful warnings for debugging when something goes wrong (invalid object, class, etc).

### reference.deprecatedWarnings
`true` by default! set with `reference.deprecatedWarnings = bool`.<br>
shows warnings when attempting to use deprecated functions.

### reference.extreme
`false` by default! set with `reference.extreme = bool`.<br>
EXPERIMENTAL; toggles an alternative way of getting properties, which is hopefully more safe, albeit slower in **SScript**.

### reference.\_hsDisposable
returns the hscript instance used for the `reference.hscript` function.

# hscript

set of functions designed for creating and running hscript code.<br>
these functions are (somewhat) tied to the reference module, which is part of the reason they're in the same file.

### hscript("code", ?{variables})
alias for [reference.hscript](#referencehscriptcode-variables).

### hscript.new("id", "code", ?{variables})
creates a new hscript instance with the corresponding id / tag.<br>
if its called with a semicolon, usage is `hscript:new("code", {variables})`, and the instance is assigned an automatically generated tag. keep track of it!
- `ìd` tag to use for the script instance
- `code` hscript code (as a string)
- `variables` optional; variables to pass to the script when running it

**EXAMPLES**
```lua
hscript.new('testScript', 'debugPrint("hello world!!");') -- create script with the id "testScript"
hscript.list['testScript']:run() -- you may run the script like this...
hscript['testScript']:run() -- or like this!
```

### hscript.import("class", ?"alias")
imports a class for all current and future hscript instances.<br>
returns a boolean; **true** on success, **false** if it failed to import
- `class` name of the class to import
- `alias` optional; alias to import the class as

**EXAMPLES**
```lua
hscript("debugPrint(Difficulty.getString());") -- fails, as Difficulty is not imported!
hscript.import('backend.Difficulty') -- imports backend.Difficulty
hscript("debugPrint(Difficulty.getString());") -- prints difficulty string
hscript.import('backend.Difficulty', 'TestAlias') -- imports backend.Difficulty with the alias TestAlias
hscript("debugPrint(TestAlias.getString());") -- also prints difficulty string
```

### hscript:get("variable")
> [!IMPORTANT]
> the script must have been run first to work as intended!

gets a variable (can be global or local) in the hscript instance.<br>
you can also get a variable in the form `hscriptInstance.variable`
- `variable` name of the variable to get

**EXAMPLES**
```lua
local script = hscript:new([[
	var testBool = true;
	var testInt = 1234;
	var testC = customVar;
]], {customVar = 'hi!!'})
script:run() -- we run the script first, so the variables are initialized
debugPrint(script:get('testBool')) -- prints "true"
debugPrint(script.testInt) -- alternative usage, prints "1234"
debugPrint(script.testC) -- prints "hi!!", the variable we passed to the script
```

### hscript:set("variable", value)
> [!IMPORTANT]
> the script must have been run first to work as intended!

sets a variable (can be global or local) in the hscript instance.<br>
you can also set a variable in the form `hscriptInstance.variable = value`
- `variable` name of the variable to get
- `value` value to set the variable to

**EXAMPLES**
```lua
local script = hscript:new("var testBool = false;")
script:run()
debugPrint(script.testBool) -- prints "false"
script.testBool = true -- sets the testBool to true
debugPrint(script.testBool) -- prints "true"
```

### hscript:run(?"functionName", ?{functionArguments})
> [!IMPORTANT]
> if the main body hasnt been executed yet, executing a function will execute it regardless.

executes code or a function in a previously created hscript instance.<br>
you can also call this in the form `hscriptInstance:functionName(argument1, argument2...)`
if no function name is provided, the main body of the function will run instead.
- `functionName` optional; name of the function to execute
- `functionArguments` optional; arguments to pass to the function to execute

**EXAMPLES**
```lua
local game = reference ''
local script = hscript:new([[
	debugPrint('hi :]');
	function moveBF(x, y) {
		bf.x += x;
		bf.y += y;
	}
]], {bf = game.boyfriend})
script:run() -- executes the script for the first time (only executing the body), printing "hi :]"
script:run('moveBF', {50, 10}) -- runs the moveBF function in the hscript instance
script:moveBF(50, 10) -- ditto, alternative usage
```

### hscript:destroy()
destroys the hscript instance.

**EXAMPLES**
```lua
local script = hscript:new()
script:destroy()
```

### hscript:reset()
wipes the hscript instance.<br>
after wiping the script, you may set the code again with the [code](#hscriptinstancecode) and [vars](#hscriptinstancevars) variables.

**EXAMPLES**
```lua
local script = hscript:new('debugPrint("hi!!");')
script:run() -- prints "hi!!"
script:reset()
script:run() -- prints nothing, as script no longer has this code
```

## variables

### hscript.list
table with the names of all created hscript instances.

### hscriptInstance.code
> [!NOTE]
> code will only be parsed again upon calling `hscriptInstance:run`.

code string for the hscript instance; this can be modified.

**EXAMPLES**
```lua
local script = hscript:new('debugPrint("abcd");')
script:run() -- print "abcd"
script.code = 'debugPrint("efg")'
script:run() -- print "efg"
```

### hscriptInstance.vars
> [!NOTE]
> variables in the script will only be updated upon calling `hscriptInstance:run`.

list of variables to pass to the hscript instance; this can be modified.

**EXAMPLES**
```lua
local script = hscript:new("debugPrint(testVar);")
script:run() -- fails, as no "testVar" variable is set
script.vars = {testVar = 1234} -- add var
script:run() -- print "1234"
```

### hscriptInstance.\_id
identifier / tag for the hscript instance
