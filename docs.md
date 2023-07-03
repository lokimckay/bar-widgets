## Links

- https://springrts.com/wiki/Lua:Main
- https://springrts.com/wiki/Lua_UnsyncedCtrl
- https://springrts.com/wiki/Lua_UnsyncedRead
- https://beyond-all-reason.github.io/spring/ldoc/modules/LuaHandle.html
- https://springrts.com/wiki/Lua:Callins

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