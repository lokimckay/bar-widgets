function widget:GetInfo()
    return {
        name = "Scuttle decloak range",
        desc = "When a scuttle is selected, display its decloak range (orange) and selfd explosion radius (red)",
        author = "sneyed",
        license = "GNU GPL, v2 or later",
        layer = 0,
        enabled = true -- loaded by default
    }
end

-- Based on EMP + decloak range by [teh]decay and Floris

--------------------------------------------------------------------------------
-- Config
--------------------------------------------------------------------------------

local onlyDrawRangeWhenSelected = true
local fadeOnCameraDistance = true
local showLineGlow = true -- a thicker but faint 2nd line will be drawn underneath
local opacity = 1.3
local fade = 1.2 -- lower value: fades out sooner
local circleDivs = 64 -- detail of range circle

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
local spGetAllUnits = Spring.GetAllUnits
local spGetCameraPosition = Spring.GetCameraPosition
local spValidUnitID = Spring.ValidUnitID
local spGetUnitPosition = Spring.GetUnitPosition
local spIsSphereInView = Spring.IsSphereInView
local spIsUnitSelected = Spring.IsUnitSelected
local spGetMyTeamID = Spring.GetMyTeamID
local spGetMyPlayerID = Spring.GetMyPlayerID
local spGetSpectatingState = Spring.GetSpectatingState

-- State
local scuttles = {}
local isScuttle = {}
local spec, fullview = Spring.GetSpectatingState()
local myTeamID = spGetMyTeamID()
local myPlayerID = Spring.GetMyPlayerID()
local chobbyInterface

-- Debugging
local logPrefix = "[SDR]: "
local widgetName = "Scuttle decloak range"
local debugMode = true -- enable to print debugging messages to the console
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

function ReloadUnits()
    scuttles = {}
    local visibleUnits = spGetAllUnits()
    if visibleUnits ~= nil then
        for i = 1, #visibleUnits do
            local unitID = visibleUnits[i]
            local unitDefID = spGetUnitDefID(unitID)
            if isScuttle[unitDefID] then
                AddScuttle(unitID, unitDefID)
            end
        end
    end
end

function widget:Initialize()
    DebugLog(widgetName .. " widget enabled")
    ReloadUnits()
end

function widget:PlayerChanged(playerID)
    local prevTeamID = myTeamID
    local prevFullview = fullview
    myTeamID = spGetMyTeamID()
    myPlayerID = spGetMyPlayerID()
    spec, fullview = spGetSpectatingState()
    if playerID == myPlayerID and
        (fullview ~= prevFullview or myTeamID ~= prevTeamID) then
        ReloadUnits()
    end
end

function widget:UnitCreated(unitID, unitDefID, teamID, builderID)
    if not spValidUnitID(unitID) then return end
    if isScuttle[unitDefID] then AddScuttle(unitID, unitDefID) end
end

function widget:UnitFinished(unitID, unitDefID, unitTeam)
    if isScuttle[unitDefID] then AddScuttle(unitID, unitDefID) end
end

function widget:UnitTaken(unitID, unitDefID, unitTeam, newTeam)
    if isScuttle[unitDefID] then AddScuttle(unitID, unitDefID) end
end

function widget:UnitGiven(unitID, unitDefID, unitTeam, oldTeam)
    if isScuttle[unitDefID] then AddScuttle(unitID, unitDefID) end
end

function widget:UnitEnteredLos(unitID, unitTeam, allyTeam, unitDefID)
    if not fullview and isScuttle[unitDefID] then
        AddScuttle(unitID, unitDefID)
    end
end

function widget:UnitLeftLos(unitID, unitDefID, unitTeam)
    if not fullview then if scuttles[unitID] then scuttles[unitID] = nil end end
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

    for unitID, prop in pairs(scuttles) do
        local decloakRange = prop[1]
        local selfDRadius = prop[2]
        local x, y, z = spGetUnitPosition(unitID)
        if ((onlyDrawRangeWhenSelected and spIsUnitSelected(unitID)) or
            onlyDrawRangeWhenSelected == false) and
            spIsSphereInView(x, y, z, math.max(decloakRange, selfDRadius)) then
            local camDistance = math.diag(camX - x, camY - y, camZ - z)

            local lineWidthMinus = (camDistance / 2000)
            if lineWidthMinus > 2 then lineWidthMinus = 2 end
            local lineOpacityMultiplier = 0.9
            if fadeOnCameraDistance then
                lineOpacityMultiplier = (1100 / camDistance) * fade
                if lineOpacityMultiplier > 1 then
                    lineOpacityMultiplier = 1
                end
            end
            if lineOpacityMultiplier > 0.15 then
                if showLineGlow then
                    glLineWidth(10)
                    if decloakRange > 0 then
                        glColor(1, .6, .3, .03 * lineOpacityMultiplier * opacity)
                        glDrawGroundCircle(x, y, z, decloakRange, circleDivs)
                    end
                    if selfDRadius > 0 then
                        glColor(1, 0, 0, .03 * lineOpacityMultiplier * opacity)
                        glDrawGroundCircle(x, y, z, selfDRadius, circleDivs)
                    end
                end
                glLineWidth(2.2 - lineWidthMinus)
                if decloakRange > 0 then
                    glColor(1, .6, .3, .44 * lineOpacityMultiplier * opacity)
                    glDrawGroundCircle(x, y, z, decloakRange, circleDivs)
                end
                if selfDRadius > 0 then
                    glColor(1, 0, 0, .44 * lineOpacityMultiplier * opacity)
                    glDrawGroundCircle(x, y, z, selfDRadius, circleDivs)
                end
            end
        end
    end

    glDepthTest(false)
end
