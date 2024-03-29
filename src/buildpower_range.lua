function widget:GetInfo()
    return {
        name = "Buildpower Range",
        desc = "Display range of builders selected",
        author = "sneyed",
        date = "2024",
        license = "GNU GPL, v2 or later",
        layer = 0,
        enabled = true
    }
end

--[[-------------------------------------------------------------------

  # Buildpower Range

  Display range of builders selected
  Adapted/updated from a 2023 widget by KomodoSwagDragon

--]]-------------------------------------------------------------------

-- Config
local color = {0, 1, 0, 0.55}
local thickness = 1.5
local debugMode = false -- enable to print debugging messages to the console

-- Vars
local selected = {}
local divisions = 128

-- Spring functions
local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitPosition = Spring.GetUnitPosition
local spIsSphereInView = Spring.IsSphereInView

-- Debugging
local logPrefix = "[BPR]: "
local widgetName = "Buildpower Range"
-- Prints a message to the console if debugMode is enabled
local function DebugLog(message)
    if debugMode then Spring.Echo(logPrefix .. tostring(message)) end
end

function DrawCircle(x, y, z, radius)
    gl.Color(color)
    gl.LineWidth(thickness)
    gl.DrawGroundCircle(x, y, z, radius, divisions)
end

local function DrawCircles()
    for unitID, buildDistance in pairs(selected) do
        local x, y, z = spGetUnitPosition(unitID)
        if x ~= nil and y ~= nil and z ~= nil and
            spIsSphereInView(x, y, z, buildDistance) then
            DrawCircle(x, y, z, buildDistance)
        end
    end
end

-- https://beyond-all-reason.github.io/spring/ldoc/modules/LuaHandle.html#Initialize
function widget:Initialize() DebugLog(widgetName .. " widget enabled") end

-- https://beyond-all-reason.github.io/spring/ldoc/modules/LuaHandle.html#Shutdown
function widget:Shutdown() DebugLog(widgetName .. " widget disabled") end

-- https://springrts.com/wiki/Lua:Callins#SelectionChanged
function widget:SelectionChanged(newSelection)
    selected = {}
    for i, unitID in pairs(newSelection) do
        local defID = spGetUnitDefID(unitID)
        local buildDistance = UnitDefs[defID].buildDistance
        local buildSpeed = UnitDefs[defID].buildSpeed
        if buildSpeed > 0 then selected[unitID] = buildDistance end
    end
end

-- https://springrts.com/wiki/Lua:Callins#DrawWorld
function widget:DrawWorld()
    gl.DepthTest(true)
    DrawCircles()
    gl.DepthTest(false)
end
