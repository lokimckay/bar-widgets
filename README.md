# BAR Widgets

Beyond All Reason widgets I've created

## Docs

Useful docs for creating widgets

- https://springrts.com/wiki/Lua:Main
- https://springrts.com/wiki/Lua_UnsyncedCtrl
- https://springrts.com/wiki/Lua_UnsyncedRead
- https://beyond-all-reason.github.io/spring/ldoc/modules/LuaHandle.html
- https://springrts.com/wiki/Lua:Callins

## Community

Check out the [main community repo](https://github.com/zxbc/BAR_widgets/tree/main)

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