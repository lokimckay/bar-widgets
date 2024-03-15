function widget:GetInfo()
  return {
    name = "Trade Info",
    desc = "Displays units lost in recent battles",
    author = "sneyed",
    date = "2023",
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

-- Global constants
local panelRect = nil

-- Debugging
local logPrefix = "[TI]: "
local widgetName = "Trade Info"
local debugMode = true -- enable to print debugging messages to the console

-- Prints a message to the console if debugMode is enabled
local function DebugLog(message)
  if debugMode then Spring.Echo(logPrefix .. tostring(message)) end
end

local function DrawPanel()
  if not panelRect then return end
  glColor(1, 0, 0, 1)
  gl.TexRect(panelRect)
end

local function GetPanelDimensions()
  local viewWidth, viewHeight = Spring.GetViewGeometry()
  local size = 0.1 * math.min(viewWidth, viewHeight) -- 10% of smallest screen dimension
  local center = { x: 0.5 * viewWidth, y: 0.5 * viewHeight }
  local cornerBL = { x: center.x - size, y: panelCenter.y - size }
  local cornerTR = { x: center.x + size, y: panelCenter.y + size }
  local returnRect = { cornerBL.x, cornerBL.y, cornerTR.x, cornerTR.y }
  DebugLog("Panel dimensions: " .. tostring(returnRect))
  return table.unpack(returnRect)
end

-- https://beyond-all-reason.github.io/spring/ldoc/modules/LuaHandle.html#Initialize
function widget:Initialize()
  DebugLog(widgetName .. " widget enabled")
  panelRect = GetPanelDimensions()
end

-- https://beyond-all-reason.github.io/spring/ldoc/modules/LuaHandle.html#Shutdown
function widget:Shutdown()
  DebugLog(widgetName .. " widget disabled")
end

-- https://springrts.com/wiki/Lua:Callins#DrawScreen
function widget:DrawScreen()
  gl.PushMatrix()
  DrawPanel()
  gl.PopMatrix()
end

-- https://springrts.com/wiki/Lua:Callins#Update
function widget:Update()
end