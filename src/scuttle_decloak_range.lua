function widget:GetInfo()
    return {
        name = "Scuttle decloak range",
        desc = "When a scuttle is selected, display its decloak range (orange) and selfd explosion radius (red)",
        author = "sneyed",
        license = "GNU GPL, v2 or later",
        layer = 0,
        enabled = true
    }
end

-- Based on EMP + decloak range by [teh]decay and Floris

--------------------------------------------------------------------------------
-- Config
--------------------------------------------------------------------------------

local fadeOnZoom = true
local showLineGlow = true -- a thicker but faint 2nd line will be drawn underneath
local opacity = 1.3
local fade = 1.2 -- lower value: fades out sooner
local circleDivs = 64 -- detail of range circle
local decloakCol = {1, .6, .3} -- orange
local selfDCol = {1, 0, 0} -- red

---------------------------------------------------------------------
-- Shouldn't need to edit past this point
---------------------------------------------------------------------

-- OpenGL functions
local glColor = gl.Color
local glLineWidth = gl.LineWidth
local glDepthTest = gl.DepthTest
local glDrawGroundCircle = gl.DrawGroundCircle

-- Spring functions
local spGetUnitDefID = Spring.GetUnitDefID
local spGetCameraPosition = Spring.GetCameraPosition
local spGetUnitPosition = Spring.GetUnitPosition
local spIsSphereInView = Spring.IsSphereInView
local spGetUnitIsCloaked = Spring.GetUnitIsCloaked

-- State
local selectedUnits = {}
local scuttles = {}
local isScuttle = {}
local chobbyInterface

-- Debugging
local logPrefix = "[SDR]: "
local widgetName = "Scuttle decloak range"
local debugMode = false -- enable to print debugging messages to the console
-- Prints a message to the console if debugMode is enabled
local function DebugLog(message)
    if debugMode then Spring.Echo(logPrefix .. tostring(message)) end
end

for uDefID, uDef in pairs(UnitDefs) do
    if string.find(uDef.name, 'corsktl') then
        local selfdBlastId =
            WeaponDefNames[string.lower(uDef['selfDExplosion'])].id
        isScuttle[uDefID] = {
            uDef.decloakDistance, WeaponDefs[selfdBlastId]['damageAreaOfEffect']
        }
    end
end

function AddScuttle(unitID, unitDefID)
    local data = isScuttle[unitDefID]
    scuttles[unitID] = {data[1], data[2]} -- decloakdistance, selfdblastradius
end

function DrawRanges(unitID, x, y, z, props, thickness, alpha)
    local decloakRange = props[1]
    local selfDRadius = props[2]
    local isCloaked = spGetUnitIsCloaked(unitID)
    local drawDecloak = isCloaked and decloakRange > 0
    local drawSelfD = selfDRadius > 0
    if drawDecloak or drawSelfD then glLineWidth(thickness) end
    if drawDecloak then DrawCircle(x, y, z, decloakRange, decloakCol, alpha) end
    if drawSelfD then DrawCircle(x, y, z, selfDRadius, selfDCol, alpha) end
end

function DrawCircle(x, y, z, radius, rgb, alpha)
    glColor(rgb[1], rgb[2], rgb[3], alpha * opacity)
    glDrawGroundCircle(x, y, z, radius, circleDivs)
end

function widget:Initialize() DebugLog(widgetName .. " widget enabled") end

function widget:SelectionChanged(selection)
    if selection == selectedUnits then return end
    selectedUnits = selection
    scuttles = {}
    if selection == nil then return end
    if not selection[1] then return end
    for i, unitID in pairs(selection) do
        local uDefID = spGetUnitDefID(unitID)
        local unitDef = UnitDefs[uDefID]
        if isScuttle[uDefID] then AddScuttle(unitID, uDefID) end
    end
end

function widget:UnitDestroyed(unitID, unitDefID, unitTeam)
    if scuttles[unitID] then scuttles[unitID] = nil end
end

function widget:RecvLuaMsg(msg, playerID)
    if msg:sub(1, 18) == 'LobbyOverlayActive' then
        chobbyInterface = (msg:sub(1, 19) == 'LobbyOverlayActive1')
    end
end

function widget:DrawWorldPreUnit()
    if chobbyInterface then return end
    if Spring.IsGUIHidden() then return end
    local camX, camY, camZ = spGetCameraPosition()
    glDepthTest(true)
    for unitID, props in pairs(scuttles) do
        local decloakRange = props[1]
        local selfDRadius = props[2]
        local x, y, z = spGetUnitPosition(unitID)
        if spIsSphereInView(x, y, z, math.max(decloakRange, selfDRadius)) then
            local camDist = math.diag(camX - x, camY - y, camZ - z)
            local lineThickness = 2.2 - math.min(camDist / 2000, 2)
            local fadedOpacity = math.min((1100 / camDist) * fade, 1)
            local alpha = fadeOnZoom and fadedOpacity or 0.9
            if alpha > 0.15 then
                if showLineGlow then
                    DrawRanges(unitID, x, y, z, props, 10, 0.03 * alpha)
                end
                DrawRanges(unitID, x, y, z, props, lineThickness, 0.44 * alpha)
            end
        end
    end
    glDepthTest(false)
end
