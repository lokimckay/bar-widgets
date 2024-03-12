## Official widgets

https://github.com/beyond-all-reason/Beyond-All-Reason/blob/f087279c7c1befcd905f1dcbd496630133e1c2d4/luaui/Widgets

## Docs

- https://springrts.com/wiki/Lua:Main
- https://springrts.com/wiki/Lua_UnitDefs
- https://springrts.com/wiki/Lua_UnsyncedCtrl
- https://springrts.com/wiki/Lua_SyncedRead
- https://springrts.com/wiki/Lua_UnsyncedRead
- https://beyond-all-reason.github.io/spring/ldoc/modules/LuaHandle.html
- https://springrts.com/wiki/Lua:Callins
- gl.\*\*\* - https://springrts.com/wiki/Lua_OpenGL_Api

## Ingame commands

/widgetselector
/reloadui

Eliminate cost, remove los and control all players:
/cheat
/nocost
/godmode 3
/globallos

To read console properly: Hover it and hold SHIFT + CTRL

## Debugging

Handy `dump` function for printing LUA tables to console

```lua
local function dump(o)
	if type(o) == 'table' then
		 local s = '{ '
		 for k,v in pairs(o) do
				if type(k) ~= 'number' then k = '"'..k..'"' end
				s = s .. '['..k..'] = ' .. dump(v) .. ','
		 end
		 return s .. '} '
	else
		 return tostring(o)
	end
end
```

## From Discord

MasterBel2:

```
I don't know where you can find documentation per se, but I know where the code is etc. and can point you to that if it would be useful in the short term. Long-term I probably have enough knowledge now to update / add documentation for stuff on my own that I could start documenting things as I use them, so the reminder is good.

widget:TextCommand is essentially a rename of ConfigureLayout:
https://github.com/beyond-all-reason/Beyond-All-Reason/blob/77c82d5c27d573681255e5a41c23db029746daef/luaui/barwidgets.lua#L1161

https://github.com/beyond-all-reason/spring/blob/5e966db6ee08a79fff5ac473039887d152325c28/cont/base/springcontent/LuaHandler/Utilities/specialCallinHandlers.lua#L66

widgetHandler and widget are defined in
https://github.com/beyond-all-reason/Beyond-All-Reason/blob/77c82d5c27d573681255e5a41c23db029746daef/luaui/barwidgets.lua

WG is also defined there:
https://github.com/beyond-all-reason/Beyond-All-Reason/blob/77c82d5c27d573681255e5a41c23db029746daef/luaui/barwidgets.lua#LL75C38-L75C38
```

## widgetHandler:AddAction

https://github.com/beyond-all-reason/Beyond-All-Reason/blob/f087279c7c1befcd905f1dcbd496630133e1c2d4/luaui/actions.lua#L59

```lua
widgetHandler:AddAction("custom_keybind_name", FunctionName, arguments, types)
```

### Types

https://github.com/beyond-all-reason/Beyond-All-Reason/blob/f087279c7c1befcd905f1dcbd496630133e1c2d4/luaui/actions.lua#L25

- text "t"
- keyPress "p"
- keyRepeat "R"
- keyRelease "r"

Can combine them together "pR"

## Keybinds

https://springrts.com/wiki/Uikeys.txt
https://wiki.libsdl.org/SDL2/SDLKeycodeLookup

## Keybind deprecation

i don't know why your lua file didn't get converted but here's how you can make it do so.

- First, make sure your keybinds are set to custom ingame.
- Close the game
- Make sure your bar_hotkeys_custom.lua file is in your data directory
- Open springsettings.cfg (in your data folder) and find the line with KeybindingFile
- Set it to KeybindingFile = bar_hotkeys_custom.lua
- If you have a uikeys.txt file, delete or rename it
- Launch the game, and start a skirmish

## DrawUnitShapeGL4

https://github.com/beyond-all-reason/Beyond-All-Reason/blob/master/luaui/Widgets/gfx_DrawUnitShape_GL4.lua

DrawUnitShapeGL4(unitDefID, px, py, pz, rotationY, alpha, teamID, teamcoloroverride, highlight)

Documentation for DrawUnitShapeGL4:
unitDefID: which unitDef do you want to draw
px, py, py: where in the world to do you want to draw it
rotationY: Angle in radians on how much to rotate the unit around Y,
0 means it faces south, (+Z),
pi/2 points west (-X)
-pi/2 points east
alpha: the transparency level of the unit
teamID: which teams teamcolor should this unit get, leave nil if you want to keep the original teamID
teamcoloroverride: much we should mix the teamcolor into the model color [0-1]
highlight: how much we should add a highlighting animation to the unit (blends white with [0-1])
returns: a unique handler ID number that you should store and call StopDrawUnitGL4(uniqueID) with to stop drawing it
note that widgets are responsible for stopping the drawing of every unit that they submit!
