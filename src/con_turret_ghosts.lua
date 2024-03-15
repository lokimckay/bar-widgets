function widget:GetInfo()
	return {
		name = "Con Turret Ghosts",
		desc = "Keep showing construction turret positions when they disappear from LoS",
		author = "sneyed",
		date = "2024",
		license = "GNU GPL v2",
		layer = 0,
		enabled = true,
	}
end

--[[-------------------------------------------------------------------

This widget shows ghost outlines of construction turrets after they disappear from LoS
I don't know why engine doesn't do this already, maybe an oversight?

References
* Unit Nano Ghost by Tom Fyuri 
https://github.com/TomFyuri/BAR-Widgets/blob/main/unit_show_nanos.lua

* Ghost Radar GL4 by very_bad_soldier, Floris (GL4)
https://github.com/beyond-all-reason/Beyond-All-Reason/blob/master/luaui/Widgets/unit_ghostradar_gl4.lua

--]] -------------------------------------------------------------------

-- Config
local shapeOpacity = 0.4
local updateRate = 0.01 -- How often to check if ghosts are back in LoS (in seconds). Increase this if you get performance issues.
--[[-------------------------------------------------------------------
Shouldn't need to edit past this point
--]] -------------------------------------------------------------------

-- Debugging
local logPrefix = "[CTG]: "
local widgetName = "Con Turret Ghosts"
local debugMode = false -- enable to print debugging messages to the console
-- Vars
local myAllyTeamID
local sec = 0
local addHeight = 8 -- Compensate for unit wobbling underground
local gaiaTeamID = Spring.GetGaiaTeamID()
local includedUnitDefIDs = {}
local unitShapes = {}
local turrets = {}

-- Spring Functions
local spGetUnitTeam = Spring.GetUnitTeam -- https://springrts.com/wiki/Lua_SyncedRead#GetUnitTeam
local spGetUnitAllyTeam = Spring.GetUnitAllyTeam -- https://springrts.com/wiki/Lua_SyncedRead#GetUnitAllyTeam
local spGetUnitDefID = Spring.GetUnitDefID -- https://springrts.com/wiki/Lua_SyncedRead#GetUnitDefID
local spGetUnitPosition = Spring.GetUnitPosition -- https://springrts.com/wiki/Lua_SyncedRead#GetUnitPosition
local spGetUnitRotation = Spring.GetUnitRotation -- https://springrts.com/wiki/Lua_SyncedRead#GetUnitRotation
local spIsPosInLos = Spring.IsPosInLos -- https://springrts.com/wiki/Lua_SyncedRead#IsPosInLos
local spIsUnitInLos = Spring.IsUnitInLos -- https://springrts.com/wiki/Lua_SyncedRead#IsUnitInLos
local spGetUnitTransporter = Spring.GetUnitTransporter -- https://springrts.com/wiki/Lua_SyncedRead#GetUnitTransporter
local function DebugLog(message)
	if debugMode then
		Spring.Echo(logPrefix .. tostring(message))
	end
end

-- Returns true if the unit is a Construction Turret
local function IsConTurret(name)
	return string.find(string.lower(name), "turret") ~= nil
end

-- Returns all unitDefIDs that are ConTurrets
local function GetIncludedUnitDefIDs()
	local includedUnitDefIDs = {}
	for unitDefID, unitDef in pairs(UnitDefs) do
		if not unitDef.isBuilding and not unitDef.isFactory then
			local name = unitDef.translatedHumanName
			if IsConTurret(name) then
				includedUnitDefIDs[unitDefID] = true
			end
		end
	end
	return includedUnitDefIDs
end

-- Returns true if this widget can run
local function CheckCompat()
	if not WG.DrawUnitShapeGL4 then
		DebugLog("DrawUnitShapeGL4 not found, disabling " .. widgetName)
		widgetHandler:RemoveWidget()
		return false
	end
	return true
end

-- Add a ghost outline
local function AddUnitShape(unitID, teamID)
	if unitShapes[unitID] then
		RemoveUnitShape(unitID)
	end

	local unitDefID = turrets[unitID].unitDefID
	local px, py, pz = unpack(turrets[unitID].pos)
	local rotationY = turrets[unitID].rot[2] * -1
	DebugLog(
		"Adding unit shape for unitID " .. unitID .. " at " .. px .. ", " .. py .. ", " .. pz .. " with rotation " .. rotationY
	)
	unitShapes[unitID] =
		WG.DrawUnitShapeGL4(
			unitDefID,
			px,
			py + addHeight,
			pz,
			rotationY,
			shapeOpacity,
			teamID,
			nil,
			nil
		)
end

-- Remove an existing ghost outline
local function RemoveUnitShape(unitID)
	if unitShapes[unitID] then
		DebugLog("Removing unit shape for unitID " .. unitID)
		WG.StopDrawUnitShapeGL4(unitShapes[unitID])
		unitShapes[unitID] = nil
	end
end

-- Remove all ghost outlines
local function RemoveAllUnitShapes()
	DebugLog("Removing all unit shapes")
	for unitID, _ in pairs(unitShapes) do
		RemoveUnitShape(unitID)
	end
end

-- If the given unitID was destroyed or moved while out of LoS, remove the ghost outline
local function RemoveOrphans(unitID)
	local turret = turrets[unitID]
	if not turret then return end
	if turret.los then return end -- ignore turrets that haven't even gone out of LoS yet
	if spIsUnitInLos(unitID, myAllyTeamID) then return end -- ignore turrets that still exist and are in LoS
	turret.los = spIsPosInLos(unpack(turret.pos)) -- check if the turret's last known position is in LoS
	if turret.los then -- if it is, remove the ghost outline
		DebugLog("Removing orphaned unit shape " .. unitID)
		RemoveUnitShape(unitID)
		turrets[unitID] = nil
	end
end

-- Updates the position and transporter state of a turret
local function UpdateState(unitID)
	local turret = turrets[unitID]
	if not turret then return end
	turret.transporter = spGetUnitTransporter(unitID)
	local pos = { spGetUnitPosition(unitID) }
	local rot = { spGetUnitRotation(unitID) }
	if pos and pos[1] then
		turret.pos = pos
	end
	if rot and rot[1] then
		turret.rot = rot
	end
end

-- Add a candidate unit if it is a construciton turret
local function InspectUnit(unitID, unitDefID, unitTeam, allyTeam)
	if specFullView then return end
	if allyTeam == myAllyTeamID then return end
	if unitTeam == gaiaTeamID then return end

	if includedUnitDefIDs[unitDefID] and not turrets[unitID] then
		DebugLog("Tracking new turret: " .. unitID .. " on team " .. unitTeam)
		turrets[unitID] = {
			unitDefID = unitDefID,
			teamID = unitTeam,
			los = true,
			transporter = spGetUnitTransporter(unitID),
			pos = { spGetUnitPosition(unitID) },
			rot = { spGetUnitRotation(unitID) },
		}
	elseif turrets[unitID] and unitDefID ~= turrets[unitID].unitDefID then
		DebugLog("Turret " .. unitID .. " was replaced by another unit")
		turrets[unitID] = nil
	end
	RemoveUnitShape(unitID)
end

-- Track all existing turrets (only run once on widget init)
local function InspectAllUnits()
	local allUnits = Spring.GetAllUnits()
	for _, unitID in ipairs(allUnits) do
		local unitDefID = spGetUnitDefID(unitID)
		local unitTeam = spGetUnitTeam(unitID)
		local allyTeam = spGetUnitAllyTeam(unitID)
		InspectUnit(unitID, unitDefID, unitTeam, allyTeam)
	end
end

-- Returns the teamID of the local player
local function GetMyAllyTeamID()
	local _, _, _, teamID, allyTeamID =
		Spring.GetPlayerInfo(Spring.GetMyPlayerID(), false)
	return allyTeamID
end

-- https://beyond-all-reason.github.io/spring/ldoc/modules/LuaHandle.html#Initialize
function widget:Initialize()
	if not CheckCompat() then return end
	DebugLog(widgetName .. " widget enabled")
	includedUnitDefIDs = GetIncludedUnitDefIDs()
	myAllyTeamID = GetMyAllyTeamID()
	spec, specFullView = Spring.GetSpectatingState()
	InspectAllUnits()
end

-- https://beyond-all-reason.github.io/spring/ldoc/modules/LuaHandle.html#PlayerChanged
function widget:PlayerChanged()
	myAllyTeamID = GetMyAllyTeamID()
	spec, specFullView = Spring.GetSpectatingState()
	if specFullView then
		RemoveAllUnitShapes()
	end
end

-- https://beyond-all-reason.github.io/spring/ldoc/modules/LuaHandle.html#Shutdown
function widget:Shutdown()
	if not CheckCompat() then return end
	DebugLog(widgetName .. " widget disabled")
	includedUnitDefIDs = nil
	myAllyTeamID = nil
	RemoveAllUnitShapes()
end

-- https://beyond-all-reason.github.io/spring/ldoc/modules/LuaHandle.html#Update
function widget:Update(dt)
	if not CheckCompat() then return end

	sec = sec + dt
	if sec > updateRate then
		sec = 0
		for unitID, turret in pairs(turrets) do
			RemoveOrphans(unitID)
			UpdateState(unitID)
		end
	end
end

-- https://beyond-all-reason.github.io/spring/ldoc/modules/LuaHandle.html#UnitEnteredLos
function widget:UnitEnteredLos(
unitID,
	unitTeam,
	allyTeam,
	_unitDefID -- provided parameter unitDefID is sometimes nil? why?
)
	local unitDefID = spGetUnitDefID(unitID)
	InspectUnit(unitID, unitDefID, unitTeam, allyTeam)
end

-- https://beyond-all-reason.github.io/spring/ldoc/modules/LuaHandle.html#UnitLeftLos
function widget:UnitLeftLos(unitID, unitTeam)
	if turrets[unitID] and turrets[unitID].transporter == nil then
		turrets[unitID].los = false
		AddUnitShape(unitID, unitTeam)
	end
end

-- https://beyond-all-reason.github.io/spring/ldoc/modules/LuaHandle.html#UnitFinished
function widget:UnitFinished(unitID, unitDefID, unitTeam)
	local allyTeam = spGetUnitAllyTeam(unitID)
	InspectUnit(unitID, unitDefID, unitTeam, allyTeam)
end

-- https://beyond-all-reason.github.io/spring/ldoc/modules/LuaHandle.html#UnitDestroyed
function widget:UnitDestroyed(unitID, unitDefID, unitTeam)
	turrets[unitID] = nil
end
