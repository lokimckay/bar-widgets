function widget:GetInfo()
	return {
		name = "Shop Open",
		desc = "Notify your team automatically when you tech up",
		author = "sneyed",
		date = "2023",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

--[[-------------------------------------------------------------------

	By default, this widget will notify your allies via map ping when you:

	 * start teching up to any T2 factory
	 * finish teching (will offer to sell them a constructor and specify metal cost)
	 * start reclaiming your factory (will remind them to buy a constructor)

	Notifications will only be sent once per game, regardless of factory type

	Modify the config below to customize any of the messages/behaviours

--]]-------------------------------------------------------------------

-- Config
local offerToSell = true -- offer to sell T2 constructors to your allies
local notifyStart = true -- notify your team when you start teching
local notifyFinish = true -- notify your team when you finish teching
local notifyReclaim = true -- notify your team when you start reclaiming your factory

-- Marker toggles 
-- true = map ping marker
-- false = team chat message
local mapMarker = {
	start = true,
	finish = true,
	reclaim = true,
}

-- Messages 
-- Available placeholders: <PLAYER>, <LVL> (2/3), <FACTION> (arm/core), <TYPE> (bots/veh/air/sea), <COST> (metal)
local messages = {
	start = "Teching (T<LVL> <FACTION> <TYPE>)",
	finish = "Selling T<LVL> <FACTION> <TYPE> (<COST>m)",
	finishNoSell = "Finished teching",
	reclaim = "Last chance to buy T<LVL> <FACTION> <TYPE> (<COST>m)",
}

--[[-------------------------------------------------------------------
	Shouldn't need to edit past this point
--]]-------------------------------------------------------------------

-- Debugging
local logPrefix = "[SO]: "
local widgetName = "Shop Open"
local debugMode = false -- enable to print debugging messages to the console

-- Global State
local messagesSent = {}

local function DebugLog(message)
	if debugMode then Spring.Echo(logPrefix .. tostring(message)) end
end

-- Returns true if the given message has not already been sent,
-- and the unitDefID is a factory of interest according to the config
local function ShouldNotify(messageType, unitDefID, unitTeam)

	-- Check if the unit is owned by this player
	local ownedByThisPlayer = Spring.GetPlayerInfo(Spring.GetMyPlayerID()) == Spring.GetPlayerInfo(unitTeam)
	if not ownedByThisPlayer then return false end

	-- Check if message has already been sent
	if messagesSent[messageType] then return false end

	-- Check if config has disabled this message type
	if messageType == "start" and not notifyStart then return false
	elseif messageType == "finish" and not notifyFinish then return false
	elseif messageType == "reclaim" and not notifyReclaim then return false
	end

	-- Check if unitDefID is a factory of interest
	local unitDef = UnitDefs[unitDefID]
	if unitDefID == nil or unitDef == nil then return false end
	return unitDef.isFactory and unitDef.customParams.techlevel == "2"
end

-- Returns either "Bots" / "Veh" / "Air" / "Sea" depending on the factory type
local function GetShortName(name)
	if name == "Advanced Bot Lab" then return "Bots"
	elseif name == "Advanced Vehicle Plant" then return "Veh"
  elseif name == "Advanced Aircraft Plant" then return "Air"
	elseif name == "Advanced Shipyard" then return "Sea"
	else return name
	end
end

-- Returns either "Core" or "Arm" depending on the faction of the given unitDefID
local function GetFaction(unitDefID)
	local substring = UnitDefs[unitDefID].name:sub(1, 3)
	if substring == "cor" then return "Core"
	elseif substring == "arm" then return "Arm"
	else return "unknown"
	end
end

-- Returns the techlevel, faction, name and con cost of the given unitDefID
local function GetFactoryInfo(unitDefID)
	local unitDef = UnitDefs[unitDefID]
	local name = GetShortName(unitDef.translatedHumanName)
	local techlevel = unitDef.customParams.techlevel
	local faction = GetFaction(unitDefID)
	local conID = unitDef.buildOptions[1]
	local conCost = UnitDefs[conID].metalCost
	return techlevel, faction, name, conCost
end

-- Returns a new message with placeholder parameters replaced with the given variables
local function HydrateMessage(rawMessage, techlevel, faction, factory, cost)
	return rawMessage
		:gsub("<LVL>", techlevel or "")
		:gsub("<FACTION>", faction or "")
		:gsub("<TYPE>", factory or "")
		:gsub("<COST>", cost or "")
end

-- Adds a map ping marker at the given unit's position (plus an offset depending on message type)
local function AddMarker(unitID, message, messageType)
	local x, y, z = Spring.GetUnitPosition(unitID)
	local offset = 0

	-- Add an offset so messages dont overlap
	if messageType == "start" then offset = -100
	elseif messageType == "finish" then offset = -50
	end

	Spring.MarkerAddPoint(x, y, z + offset, message)
end

-- Sends a message to the team chat
local function SendMessage(message)
	local playerName = Spring.GetPlayerInfo(Spring.GetMyPlayerID())
	Spring.SendMessageToAllyTeam(Spring.GetMyAllyTeamID(), "["..playerName.."]: "..message)
end

-- Sends a message to the team based on what is being built/reclaimed
local function Notify(messageType, rawMessage, unitID, unitDefID, unitTeam)
	local techlevel, faction, factory, conCost = GetFactoryInfo(unitDefID)
	local message = HydrateMessage(rawMessage, techlevel, faction, factory, conCost)

	if mapMarker[messageType] then
		AddMarker(unitID, message, messageType)
	else
		SendMessage(message)
	end
	
	DebugLog("Sent message: "..message)
	messagesSent[messageType] = true
end

-- https://beyond-all-reason.github.io/spring/ldoc/modules/LuaHandle.html#UnitCreated
function widget:UnitCreated(unitID, unitDefID, unitTeam)
	if ShouldNotify("start", unitDefID, unitTeam) then
		Notify("start", messages["start"], unitID, unitDefID, unitTeam)
	end
end

-- https://beyond-all-reason.github.io/spring/ldoc/modules/LuaHandle.html#UnitFinished
function widget:UnitFinished(unitID, unitDefID, unitTeam)
	if not messagesSent["start"] and notifyStart then return end -- Don't bother if we haven't started teching yet
	if ShouldNotify("finish", unitDefID, unitTeam) then
		Notify("finish", offerToSell and messages["finish"] or messages["finishNoSell"], unitID, unitDefID, unitTeam)
	end
end

-- https://beyond-all-reason.github.io/spring/ldoc/modules/LuaHandle.html#UnitCommand
function widget:UnitCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOpts, cmdTag)
	if cmdID ~= CMD.RECLAIM then return end -- Don't bother if we're not reclaiming
	if not offerToSell then return end -- Don't bother if we're not offering to sell
	if not messagesSent["finish"] and notifyFinish then return end -- Don't bother if we haven't finished teching yet

	local targetId = cmdParams[1]
	local targetTeam = targetId and Spring.GetUnitTeam(targetId)
	local targetDefID = targetId and Spring.GetUnitDefID(targetId)

	if ShouldNotify("reclaim", targetDefID, targetTeam) and (unitTeam == targetTeam) then
		Notify("reclaim", messages["reclaim"], targetId, targetDefID, targetTeam)
	end
end

-- https://beyond-all-reason.github.io/spring/ldoc/modules/LuaHandle.html#Initialize
function widget:Initialize()
	DebugLog(widgetName .. " widget enabled")
end

-- https://beyond-all-reason.github.io/spring/ldoc/modules/LuaHandle.html#Shutdown
function widget:Shutdown()
	DebugLog(widgetName .. " widget disabled")
end
