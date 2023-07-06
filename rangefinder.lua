function widget:GetInfo()
  return {
    name = "Rangefinder",
    desc = "Displays selected unit(s) weapon range at the cursor's position",
    author = "sneyed",
    date = "2023",
    license = "GNU GPL, v2 or later",
    layer = 0,
    enabled = true,
  }
end

--[[-------------------------------------------------------------------

  # Setup
  ----------------------------------

  1) Copy + paste this widget into your C:\Program Files\Beyond-All-Reason\data\LuaUI\Widgets directory as "rangefinder.lua"

  2) Add the following control bindings to your C:\Program Files\Beyond-All-Reason\data\uikeys.txt file. 
     Choose different keybinds if you like
  
      bind              Alt+r  rangefinder
      bind              Alt+q  rangefinder_cycle_backward
      bind              Alt+e  rangefinder_cycle_forward

  3) Type /widgetselector into ingame chat
  4) Activate the Rangefinder widget

  # Usage
  ----------------------------------

  1) Select any number of units and press whatever your chosen keybind is (Alt+r by default)
     Rangefinder will display the range of the highest range unit.

  2) Keep pressing the same hotkey to cycle forwards through any other units currently selected
  
  3) Alternatively use Alt+e to cycle forwards and Alt+q to cycle backwards

  # Customizing
  ----------------------------------

  Check the config section below to customize sorting preference, circle appearance and more!

--]]-------------------------------------------------------------------

-- Config
local lineWidth = 2
local lineColor = { 1, 0, 0, 0.55 } -- { r, g, b, a }
local textColor = { 1, 1, 1, 1 } 	-- { r, g, b, a }
local textSize = 16
local textOffset = 35
local drawUnitGhost = true -- Draw a ghost of the selected unit at the cursor position
local showGhostInfo = true -- Show unit name and weapon range next to the ghost
local ghostOpacity = 0.5 -- Opacity of the ghosted unit
local cancelOnMouseClick = true -- Deactivate rangefinder if any mouse button is clicked
local sortBy = "maxGroundRange" -- [ "maxGroundRange" | "maxRange" | "count" ] When activating with multiple units selected, which ghost should be preferred?

--[[-------------------------------------------------------------------
  Shouldn't need to edit past this point
--]]-------------------------------------------------------------------

-- Debugging
local logPrefix = "[RF]: "
local widgetName = "Rangefinder"
local debugMode = false -- enable to print debugging messages to the console

-- Global state
local isActive = false -- Enables / disables all frame-by-frame processing
local screenX = nil -- Cursor screen X
local screenY = nil -- Cursor screen Y
local x = nil -- Cursor world X
local y = nil -- Cursor world Y
local z = nil -- Cursor world Z
local selectedUnits = {} -- 1-1 tracking of selected units
local parsedUnits = {} -- Selected unit ranges and counts (including any inside transports)
local selectionStale = false -- Singleton to prevent redundant processing of selected units
local ghost = nil -- UnitDefID to display underneath the cursor
local ghostShapeID = nil -- List of unit ghost shapes
local ghostIdx = 1 -- Index of the current ghost shape (out of all selected units)

-- Prints a message to the console if debugMode is enabled
local function DebugLog(message)
  if debugMode then Spring.Echo(logPrefix .. tostring(message)) end
end

-- Converts a screen position to world coordinates
-- https://springrts.com/wiki/Lua_UnsyncedRead#TraceScreenRay
local function ScreenToWorldPos(sX, sY)
  local _, pos = Spring.TraceScreenRay(sX, sY, true)
  if pos == nil then return nil, nil, nil end
  return pos[1], pos[2], pos[3]
end

-- Draw a circle at the given world position
-- https://springrts.com/wiki/Lua_OpenGL_Api#DrawGroundCircle
local function DrawCircle(x, y, z, radius)
  if not Spring.IsSphereInView(x, y, z, radius) then return end -- Return if circle will not be in view
  gl.DepthTest(true)
  gl.Color(lineColor)
  gl.LineWidth(lineWidth)
  gl.DrawGroundCircle(x, y, z, radius, 128)
end

-- https://springrts.com/wiki/Lua_OpenGL_Api#Text
local function DrawText(text, x, y)
  gl.Color(textColor)
  gl.Text(text, x, y, textSize, "ov")
end

-- Stop drawing the ghost of the selected unit
local function RemoveGhost()
  if not WG.StopDrawUnitShapeGL4 then return end -- Return if GL4 not supported
  if ghostShapeID == nil then return end -- Return if no ghost shape exists
  WG.StopDrawUnitShapeGL4(ghostShapeID)
  ghostShapeID = nil
end

-- Draw a ghost of the selected unit at the given world position
-- https://github.com/beyond-all-reason/Beyond-All-Reason/blob/541414f30776ded59b6e8244c62f0c4a1dbec6c9/luaui/Widgets/gfx_DrawUnitShape_GL4.lua#L264
local function AddGhost(x, y, z, unitDefID, teamID)
  if not WG.DrawUnitShapeGL4 then return end -- Return if GL4 not supported
  if unitDefID == nil then return end -- Return if no unitDefID provided
  if ghostShapeID ~= nil then RemoveGhost() end -- Remove existing ghost if it exists
  ghostShapeID = WG.DrawUnitShapeGL4(unitDefID, x, y, z, 0, ghostOpacity, teamID, nil, nil)
end

-- Returns all weapon ranges of a given unitDefID
local function GetWeaponRanges(unitDefID)
  local weapons = UnitDefs[unitDefID].weapons
  local ranges = {}
  local groundRanges = {}
  for idx = 1, #weapons do
    local weaponDefID = weapons[idx].weaponDef
    local weapon = WeaponDefs[weaponDefID]
    if weapon.range then 
      if weapon.canAttackGround then table.insert(groundRanges, weapon.range) end
      table.insert(ranges, weapon.range)
    end
  end

  -- ground ranges are used for sorting if config is set to "maxRange",
  -- but still need to display air ranges if AA unit ghost is displayed
  return ranges, groundRanges 
  
end

-- Returns a table containing unit counts and ranges within
-- the current selection, including any being transported
local function ParseSelection(selection, sortBy)
  if not selectionStale then return parsedUnits end -- Return existing global values if selection has not changed
  local allUnits = {}

  -- Returns the index of the given defID in the given table "t"
  local function FindIndex(t, defID)
    for i, v in ipairs(t) do
      if v.defID == defID then return i end
    end
    return nil
  end

  -- Adds a unit and relevant calculated data to the given table "t"
  local function AddUnitRecord(t, defID, unitID)
    local existingIndex = FindIndex(t, defID)
    local existingRecord = t[existingIndex]

    if existingRecord then
      existingRecord.count = existingRecord.count + 1
      return
    else
      local ranges, groundRanges = GetWeaponRanges(defID)
      local maxRange = #ranges > 0 and math.max(unpack(ranges)) or 0
      local maxGroundRange = #groundRanges > 0 and math.max(unpack(groundRanges)) or 0
      local name = UnitDefs[defID].translatedHumanName
      local team = Spring.GetUnitTeam(unitID) -- assuming here that multiple same units selected are on the same team
      table.insert(t, {
        defID = defID,
        name = name,
        team = team,
        count = 1,
        ranges = ranges,
        maxRange = maxRange,
        maxGroundRange = maxGroundRange
      })
    end
  end

  for i, unitID in ipairs(selection) do
    local defID = Spring.GetUnitDefID(unitID)
    local unitDef = UnitDefs[defID]
    local isTransport = unitDef.transportCapacity > 0
    if isTransport then -- selected unit is a transport - we only care about any loaded units
      local loadedUnits = Spring.GetUnitIsTransporting(unitID)
      for i, loadedUnitID in ipairs(loadedUnits) do
        local loadedDefID = Spring.GetUnitDefID(loadedUnitID)
        AddUnitRecord(allUnits, loadedDefID, loadedUnitID)
      end
    else -- selected unit is not a transport
      AddUnitRecord(allUnits, defID, unitID)
    end
  end

  table.sort(allUnits, function(a, b) return a[sortBy] > b[sortBy] end)
  return allUnits
end

-- Activate / deactivate main functionality
local function SetActive(state)
  DebugLog("Set active: "..tostring(state))
  if state then
    selectionStale = true
    isActive = true
  else
    RemoveGhost(ghostShapeID)
    ghostIdx = 1
    isActive = false
  end
end

-- Increment/decrement ghostIdx
local function AdjustGhostIdx(amount)
  ghostIdx = ghostIdx + amount
end

-- Triggered when main keybind is pressed
local function OnAction()
  if #selectedUnits == 0 then return end -- Don't activate if no units selected
  if isActive then AdjustGhostIdx(1) else SetActive(true) end
end

-- Increment/decrement ghostIdx to display a different unit in the current selection
local function OnCycle(_, _, _, direction)
  if not isActive then return end -- Return if rangefinder is not active
  if #selectedUnits == 0 then return end -- Return if no units selected
  AdjustGhostIdx(direction)
end

-- https://beyond-all-reason.github.io/spring/ldoc/modules/LuaHandle.html#Initialize
function widget:Initialize()
  DebugLog(widgetName .. " widget enabled")
  widgetHandler:AddAction("rangefinder", OnAction, nil, "p")
  widgetHandler:AddAction("rangefinder_cycle_forward", OnCycle, 1, "p")
  widgetHandler:AddAction("rangefinder_cycle_backward", OnCycle, -1, "p")
end

-- https://beyond-all-reason.github.io/spring/ldoc/modules/LuaHandle.html#Shutdown
function widget:Shutdown()
  SetActive(false)
  widgetHandler:RemoveAction("rangefinder")
  widgetHandler:RemoveAction("rangefinder_cycle_forward")
  widgetHandler:RemoveAction("rangefinder_cycle_backward")
  DebugLog(widgetName .. " widget disabled")
end

-- https://springrts.com/wiki/Lua:Callins#SelectionChanged
function widget:SelectionChanged(newSelection)
  if isActive then SetActive(false) end
  selectionStale = true
  selectedUnits = newSelection
  ghostIdx = 1
end

-- https://springrts.com/wiki/Lua:Callins#DrawWorld
function widget:DrawWorld()
  if not isActive then return end -- Return if not meant to draw anything on this frame
  if x == nil or y == nil or z == nil then return end -- Return if invalid world position
  if ghost.defID == nil or #ghost.ranges == 0 then return end -- Return if no units selected or no ranges to draw

  -- Draw unit ghost
  AddGhost(x, y, z, ghost.defID, ghost.team)

  -- Draw weapon ranges
  for i = 1, #ghost.ranges do
    DrawCircle(x, y, z, ghost.ranges[i])
  end
end

-- https://springrts.com/wiki/Lua:Callins#DrawScreen
function widget:DrawScreen()
  if not isActive then return end -- Return if not meant to draw anything on this frame
  if not showGhostInfo then return end -- Return if config has disabled ghost info
  if screenX == nil or screenY == nil then return end -- Return if invalid screen position
  if ghost == nil then return end -- Return if no units selected or no ranges to draw

  -- Draw unit info
  DrawText(ghost.name.." ("..ghost.maxRange..")", screenX + textOffset, screenY)
end

-- https://springrts.com/wiki/Lua:Callins#Update
function widget:Update()
  if not isActive then return end -- Return if not meant to draw anything on this frame

  -- Update cursor position
  screenX, screenY = Spring.GetMouseState()
  x, y, z = ScreenToWorldPos(screenX, screenY)

  -- Process selection if it has changed
  parsedUnits = ParseSelection(selectedUnits, sortBy)

  -- Select one unit out of the parsedUnits to display
  local wrappedIdx = (ghostIdx - 1) % #parsedUnits + 1
  ghost = parsedUnits[wrappedIdx]

  if ghost == nil then
    DebugLog("No units selected or no ranges to draw")
    SetActive(false) 
  return end -- Return if no units selected or no ranges to draw
end

-- https://springrts.com/wiki/Lua:Callins#KeyPress
function widget:KeyPress(key, mods, isRepeat)
  if isRepeat then return end -- Ignore if key is being held down
  if key == 27 and isActive then SetActive(false) end -- if escape is pressed, deactivate rangefinder
end

-- https://springrts.com/wiki/Lua:Callins#MousePress
function widget:MousePress()
  if isActive and cancelOnMouseClick then SetActive(false) end -- if any mouse button is clicked, deactivate rangefinder
end