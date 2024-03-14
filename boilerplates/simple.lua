function widget:GetInfo()
  return {
    name = "WidgetName",
    desc = "WidgetDescription",
    author = "sneyed",
    date = "2024",
    license = "GNU GPL, v2 or later",
    layer = 0,
    enabled = true,
  }
end

--[[-------------------------------------------------------------------

  Widget description here

--]]-------------------------------------------------------------------

-- Config

--[[-------------------------------------------------------------------
  Shouldn't need to edit past this point
--]]-------------------------------------------------------------------

-- Debugging
local logPrefix = "[WN]: "
local widgetName = "WidgetName"
local debugMode = false -- enable to print debugging messages to the console

-- Prints a message to the console if debugMode is enabled
local function DebugLog(message)
  if debugMode then Spring.Echo(logPrefix .. tostring(message)) end
end

-- https://beyond-all-reason.github.io/spring/ldoc/modules/LuaHandle.html#Initialize
function widget:Initialize()
  DebugLog(widgetName .. " widget enabled")
end

-- https://beyond-all-reason.github.io/spring/ldoc/modules/LuaHandle.html#Shutdown
function widget:Shutdown()
  DebugLog(widgetName .. " widget disabled")
end

-- https://springrts.com/wiki/Lua:Callins#SelectionChanged
function widget:SelectionChanged(newSelection)
end

-- https://springrts.com/wiki/Lua:Callins#DrawWorld
function widget:DrawWorld()
end

-- https://springrts.com/wiki/Lua:Callins#DrawScreen
function widget:DrawScreen()
end

-- https://springrts.com/wiki/Lua:Callins#Update
function widget:Update()
end