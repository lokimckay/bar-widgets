function widget:GetInfo()
    return {
        name = "Repair Commander Last",
        desc = "Cons, ressers and nanos will repair/build anything other than commanders first",
        author = "sneyed",
        date = "2024",
        license = "GNU GPL, v2 or later",
        version = "2.0",
        layer = 0,
        enabled = true
    }
end

-- Spring Funcs
local spGetUnitHealth = Spring.GetUnitHealth
local spGetAllyTeamList = Spring.GetAllyTeamList
local spGetTeamUnits = Spring.GetTeamUnits
local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitPosition = Spring.GetUnitPosition
local spGetUnitsInCylinder = Spring.GetUnitsInCylinder
local spGetUnitTeam = Spring.GetUnitTeam
local spGetUnitIsDead = Spring.GetUnitIsDead
local spGetUnitCommands = Spring.GetUnitCommands
local spGiveOrderToUnit = Spring.GiveOrderToUnit
local spGetPlayerInfo = Spring.GetPlayerInfo
local spGetUnitSeparation = Spring.GetUnitSeparation

-- Debugging
local logPrefix = "[RCL]: "
local widgetName = "Repair Commander Last"
local widgetSlug = "repair_commander_last"
local debugMode = false -- enable to print debugging messages to the console
-- Prints a message to the console if debugMode is enabled
local function DebugLog(message)
    if debugMode then Spring.Echo(logPrefix .. tostring(message)) end
end

-- Config
local affectMobile = true -- Apply to mobile units (cons & resbots)
local affectImmobile = true -- Apply to immobile units (con turrets)

-- Vars
local repairerDefs = {}
local repairers = {}
local commanders = {}
local comHPs = {}
local lastComHPs = {}
local autoHeals = {}
local allyTeamIDs = spGetAllyTeamList()
local myTeamID = Spring.GetMyTeamID()
local isAlly = {}
local largestUnitRadius = 0

local function GetLargestUnitRadius()
    for unitDefID, unitDef in pairs(UnitDefs) do
        if unitDef.radius > largestUnitRadius then
            largestUnitRadius = unitDef.radius
        end
    end
end

local function GetRepairerDefs()
    for unitDefID, unitDef in pairs(UnitDefs) do
        if unitDef.canRepair and not unitDef.isFactory and
            not unitDef.customParams.iscommander then -- Unit can repair and is not a factory or com
            if (unitDef.canMove == true and affectMobile == true) or
                (unitDef.canMove == false and affectImmobile == true) then -- Unit is allowed as per config
                repairerDefs[unitDefID] = true
            end
        end
    end
end

local function GetRepairers()
    DebugLog("Getting repairers")
    local myUnits = spGetTeamUnits(myTeamID)
    for i = 1, #myUnits do
        local unitID = myUnits[i]
        local unitDefID = spGetUnitDefID(unitID)
        local unitDef = UnitDefs[unitDefID]
        local isDead = spGetUnitIsDead(unitID)
        if (isDead == false) and (repairerDefs[unitDefID]) then
            repairers[unitID] = {
                unitDef.buildDistance, unitDef.canMove, unitDefID
            }
        end
    end
end

local function GetCommanders()
    DebugLog("Getting commanders")
    local allyTeamIDs = spGetAllyTeamList()
    for i = 1, #allyTeamIDs do
        local allyTeamID = allyTeamIDs[i]
        isAlly[allyTeamID] = true
        local teamUnits = spGetTeamUnits(allyTeamID)
        for j = 1, #teamUnits do
            local unitID = teamUnits[j]
            local unitDefID = spGetUnitDefID(unitID)
            local unitDef = UnitDefs[unitDefID]
            if unitDef.customParams.iscommander then
                commanders[unitID] = true
                autoHeals[unitID] = unitDef.autoHeal
            end
        end
    end
end

-- Returns the first damaged unit near x, z within radius
local function GetDamagedUnit(repairerID, x, z, radius)
    if not x or not z or not radius then return nil end
    local searchRadius = radius + largestUnitRadius
    local units = spGetUnitsInCylinder(x, z, searchRadius)
    if not units then return nil end
    for i = 1, #units do
        local uID = units[i]
        local isSelf = uID == unitID
        local inRange = spGetUnitSeparation(uID, repairerID, false, true) <
                            radius -- Factor in unit's model forging into the radius even though it's center is not within cylinder
        local isMyTeam = spGetUnitTeam(uID) == myTeamID
        local isDead = spGetUnitIsDead(uID)
        local uDefID = spGetUnitDefID(uID)
        local uDef = UnitDefs[uDefID]
        local isCom = uDef.customParams.iscommander
        local repairable = uDef.repairable
        if inRange and isMyTeam and repairable and (not isDead) and (not isSelf) and
            (not isCom) then
            local health, maxHealth = spGetUnitHealth(uID)
            if health < maxHealth then
                DebugLog("Found damaged unit nearby: " .. uID .. " (" ..
                             uDef.translatedHumanName .. ")")
                return uID
            end
        end
    end
    return nil
end

local function RetaskRepairer(repairerID, data)
    local buildDist, canMove, unitDefID = data[1], data[2], data[3]
    local cmdQueue = spGetUnitCommands(repairerID, 1)
    if cmdQueue == nil then return end
    local cmd = cmdQueue[1] -- current command
    if cmd == nil then return end
    if cmd.id == CMD.REPAIR then
        local targetID = cmd.params[1]
        local targetDefID = spGetUnitDefID(targetID)
        if targetDefID == nil then return end
        if UnitDefs[targetDefID].customParams.iscommander then
            if canMove then -- Mobile
                local cmdX, cmdZ, cmdRadius = cmd.params[2], cmd.params[4],
                                              cmd.params[5]
                local damagedUnit = GetDamagedUnit(repairerID, cmdX, cmdZ,
                                                   cmdRadius)
                if damagedUnit == nil then return end
                spGiveOrderToUnit(repairerID, CMD.INSERT,
                                  {0, CMD.REPAIR, 0, damagedUnit}, {"alt"}) -- (prepend order to front of queue)
            else -- Immobile
                local posX, _, posZ = spGetUnitPosition(repairerID)
                local damagedUnit = GetDamagedUnit(repairerID, posX, posZ,
                                                   buildDist)
                if damagedUnit == nil then return end
                spGiveOrderToUnit(repairerID, CMD.REPAIR, {damagedUnit}, 0) -- (directly give order instead because of perpetual fight commands)
            end
        end
    end
end

-- Check if any repairer is healing a commander, repair any nearby damaged units instead 
local function RetaskRepairers()
    for repairerID, data in pairs(repairers) do
        RetaskRepairer(repairerID, data)
    end
end

-- Returns true if the commander is being repaired (not just self-healing)
-- Note that if something is damaging the commander, this will return false (probably desired)
local function isComBeingRepaired(unitID)
    local beingRepaired = false
    local health, maxHealth = spGetUnitHealth(unitID)
    if not health or not maxHealth then return false end
    if not (health < maxHealth) then return false end
    local autoHeal = autoHeals[unitID]
    local delta = health - (lastComHPs[unitID] or 0)
    if lastComHPs[unitID] and delta > autoHeal then beingRepaired = true end
    lastComHPs[unitID] = health
    return beingRepaired
end

-- Check if any commanders are being repaired
local function CheckIfComBeingRepaired()
    for unitID, _ in pairs(commanders) do
        if isComBeingRepaired(unitID) then
            DebugLog("Commander " .. unitID .. " is being repaired")
            RetaskRepairers()
        end
    end
end

-- Update tracked units if they have changed
local function Refresh(unitDefID, unitTeam, otherTeam)
    local ally = isAlly[unitTeam] or isAlly[otherTeam]
    local mine = unitTeam == myTeamID or otherTeam == myTeamID
    if ally or mine then
        if mine and repairerDefs[unitDefID] then GetRepairers() end
        if UnitDefs[unitDefID].customParams.iscommander then
            GetCommanders()
        end
    end
end

local function ForceRefresh()
    GetLargestUnitRadius()
    GetRepairerDefs()
    GetRepairers()
    GetCommanders()
end

local function CheckCompat()
    if Spring.IsReplay() or Spring.GetSpectatingState() then
        widgetHandler:RemoveWidget()
    end
end

-- https://beyond-all-reason.github.io/spring/ldoc/modules/LuaHandle.html#Initialize
function widget:Initialize()
    DebugLog(widgetName .. " widget enabled")
    CheckCompat()
    ForceRefresh()
end

-- https://beyond-all-reason.github.io/spring/ldoc/modules/LuaHandle.html#Shutdown
function widget:Shutdown() DebugLog(widgetName .. " widget disabled") end

-- https://beyond-all-reason.github.io/spring/ldoc/modules/LuaHandle.html#Update
function widget:GameFrame() CheckIfComBeingRepaired() end

function widget:UnitCreated(_, defID, team) Refresh(defID, team) end
function widget:UnitDestroyed(_, defID, team) Refresh(defID, team) end
function widget:UnitTaken(_, defID, team, newTeam) Refresh(defID, team, newTeam) end
function widget:UnitGiven(_, defID, team, oldTeam) Refresh(defID, team, oldTeam) end
function widget:PlayerChanged(playerID)
    local _, _, _, teamID = spGetPlayerInfo(playerID)
    local ally = isAlly[teamID]
    if ally then
        CheckCompat()
        ForceRefresh()
    end
end
