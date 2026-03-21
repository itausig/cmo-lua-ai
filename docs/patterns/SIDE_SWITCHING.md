# Side Switching Patterns

How to transfer units between sides in CMO using `ScenEdit_SetUnitSide`. Covers the forum-established pattern for air base transfers, defection scenarios, and captured equipment.

---

## The Core Function

```lua
ScenEdit_SetUnitSide({guid = 'unit-guid', side = 'NewSideName'})
```

This is the only function needed to switch a unit's allegiance. It works on all unit types: ships, aircraft, submarines, facilities, and satellites.

> **Forum reference:** The side-switching pattern was documented by members of the Lua Legion forum thread "Side switching for captured airbases" (matrixgames.com/forums/tt.asp?forumid=1681).

---

## Pattern 1 — Simple Unit Transfer

Transfer a single unit from Red to Blue (captured equipment):

```lua
local function transferUnit(unitGuid, newSide, reason)
    -- Verify unit exists before transfer
    local ok, unit = pcall(ScenEdit_GetUnit, {guid=unitGuid})
    if not ok or not unit then
        print('[Transfer] Unit not found: ' .. tostring(unitGuid))
        return false
    end

    local prevSide = unit.side

    -- Execute transfer
    local ok2, err = pcall(ScenEdit_SetUnitSide, {guid=unitGuid, side=newSide})
    if not ok2 then
        print('[Transfer] Failed: ' .. tostring(err))
        return false
    end

    print(string.format('[Transfer] %s: %s → %s (%s)',
        unit.name, prevSide, newSide, reason or ''))
    return true
end

-- Usage
transferUnit(ScenEdit_GetKeyValue('RED_BASE_GUID'), 'Blue', 'Airfield captured')
```

---

## Pattern 2 — Air Base Transfer with Aircraft

This is the community-established pattern. When an airfield is captured, all aircraft on it need to be transferred too — otherwise you get Blue aircraft parented to a Red base.

```lua
--- Transfer a facility and all aircraft based there to a new side.
--- @param facilityGuid string  GUID of the airfield/base
--- @param newSide      string  Receiving side name
local function captureAirbase(facilityGuid, newSide)
    local ok, base = pcall(ScenEdit_GetUnit, {guid=facilityGuid})
    if not ok or not base then return false end

    local baseName = base.name
    local prevSide = base.side

    -- 1. Transfer the base itself
    local ok2 = pcall(ScenEdit_SetUnitSide, {guid=facilityGuid, side=newSide})
    if not ok2 then
        print('[Capture] Failed to transfer base')
        return false
    end

    -- 2. Find and transfer all aircraft currently based there
    -- We check the old side's units before the transfer, so iterate Red's units
    local ok3, oldSide = pcall(VP_GetSide, {Side=prevSide})
    if ok3 and oldSide then
        for _, unit in ipairs(oldSide.units or {}) do
            if unit.type == 'Aircraft' and unit.base == baseName then
                pcall(ScenEdit_SetUnitSide, {guid=unit.guid, side=newSide})
                print('[Capture] Transferred aircraft: ' .. unit.name)
            end
        end
    end

    -- 3. Remove the base from any Red missions
    -- (missions auto-remove units that no longer belong to the side)

    -- 4. Notify both sides
    pcall(ScenEdit_SpecialMessage, newSide,
        string.format('%s captured! All aircraft and facilities now under your control.', baseName))
    pcall(ScenEdit_SpecialMessage, prevSide,
        string.format('ALERT: %s has fallen to enemy forces!', baseName))

    print(string.format('[Capture] %s transferred from %s to %s', baseName, prevSide, newSide))
    return true
end
```

> **Important:** Check both the facility AND the aircraft based there. CMO does not automatically transfer parented aircraft when the base changes sides.

---

## Pattern 3 — Defection Event

Script a unit defecting to the player's side at a random time.

```lua
local DEFECTION_WINDOW_MIN = 2 * 3600   -- earliest possible defection
local DEFECTION_WINDOW_MAX = 6 * 3600   -- latest possible defection

math.randomseed(os.time())
local defectionTime = ScenEdit_CurrentTime() +
    DEFECTION_WINDOW_MIN +
    math.random() * (DEFECTION_WINDOW_MAX - DEFECTION_WINDOW_MIN)

local ok, ev = pcall(ScenEdit_SetEvent, 'UnitDefects', {
    mode='add', IsActive=true, IsRepeatable=false,
})
if ok then
    pcall(ScenEdit_SetTrigger, {
        mode='add', type='Time', name='DefectionTimer', time=defectionTime,
    })
    pcall(ScenEdit_SetEventTrigger, ev.guid, {mode='add', name='DefectionTimer'})

    local defectScript =
        'local guid = ScenEdit_GetKeyValue("DEFECTOR_GUID")\r\n'..
        'if guid == "" then return end\r\n'..
        'local ok, u = pcall(ScenEdit_GetUnit, {guid=guid})\r\n'..
        'if not ok or not u then return end\r\n'..
        'pcall(ScenEdit_SetUnitSide, {guid=guid, side="Blue"})\r\n'..
        'ScenEdit_SpecialMessage("Blue",\r\n'..
        '    string.format("DEFECTION: %s has switched to our side!", u.name))\r\n'

    pcall(ScenEdit_SetAction, {
        mode='add', type='LuaScript', name='DefectionAction', ScriptText=defectScript,
    })
    pcall(ScenEdit_SetEventAction, ev.guid, {mode='add', name='DefectionAction'})
end
```

---

## Pattern 4 — Side Switch on Score Threshold

Transfer a neutral side's units to Red when Red's score reaches a threshold (allies joining the conflict).

```lua
-- Runs inside a RegularTime event every 60 seconds
local THRESHOLD = 200

local function checkAllyJoin()
    if ScenEdit_GetKeyValue('ALLY_JOINED') == '1' then return end

    local redScore = ScenEdit_GetScore('Red')
    if redScore < THRESHOLD then return end

    -- Transfer all "Neutral" side units to Red
    local ok, neutSide = pcall(VP_GetSide, {Side='Neutral'})
    if not ok or not neutSide then return end

    local transferred = 0
    for _, u in ipairs(neutSide.units or {}) do
        local ok2 = pcall(ScenEdit_SetUnitSide, {guid=u.guid, side='Red'})
        if ok2 then transferred = transferred + 1 end
    end

    ScenEdit_SetKeyValue('ALLY_JOINED', '1')
    ScenEdit_SpecialMessage('Blue',
        string.format('INTEL: Neutral forces have joined Red! %d units transferred.', transferred))
    ScenEdit_SpecialMessage('Red',
        'ALLIANCE: Neutral forces have joined our cause!')
end
```

---

## Pattern 5 — Transfer on Unit Entry Into Zone

Transfer units when they enter a designated zone (e.g., a port that has been captured).

```lua
-- Setup in GameSetup: watch for Red ships entering a port area
local ok, ev = pcall(ScenEdit_SetEvent, 'PortCapture', {
    mode='add', IsActive=true, IsRepeatable=true,
})
if ok then
    pcall(ScenEdit_SetTrigger, {
        mode='add', type='UnitEntersArea', name='EntersPort',
        unitSide='Blue', unitType='Ship',
        area={'PORT-RP1','PORT-RP2','PORT-RP3','PORT-RP4'},
    })
    pcall(ScenEdit_SetEventTrigger, ev.guid, {mode='add', name='EntersPort'})

    local captureScript =
        'local u = ScenEdit_UnitX()\r\n'..
        'if not u then return end\r\n'..
        '-- Transfer any Red shore facility in this zone\r\n'..
        'local portGuid = ScenEdit_GetKeyValue("PORT_FAC_GUID")\r\n'..
        'if portGuid ~= "" and ScenEdit_GetKeyValue("PORT_CAPTURED") ~= "1" then\r\n'..
        '    pcall(ScenEdit_SetUnitSide, {guid=portGuid, side="Blue"})\r\n'..
        '    ScenEdit_SetKeyValue("PORT_CAPTURED","1")\r\n'..
        '    ScenEdit_SetScore("Blue", ScenEdit_GetScore("Blue")+100, "Port captured")\r\n'..
        '    ScenEdit_SpecialMessage("Blue","PORT CAPTURED! Strategic objective secured.")\r\n'..
        'end\r\n'

    pcall(ScenEdit_SetAction, {
        mode='add', type='LuaScript', name='PortCaptureAction', ScriptText=captureScript,
    })
    pcall(ScenEdit_SetEventAction, ev.guid, {mode='add', name='PortCaptureAction'})
end
```

---

## Known Gotchas

| Issue | Notes |
|-------|-------|
| Aircraft don't transfer with their base | Must iterate and transfer manually |
| Mission assignments are lost on transfer | Unit is automatically removed from old-side missions |
| Unit contacts reset on transfer | Blue will no longer "know" about the unit as a contact |
| `side` field on unit wrapper is stale after transfer | Re-fetch unit after `ScenEdit_SetUnitSide` |
| Facilities with sub-units (airbases with parked AC) | All parented aircraft need individual transfer calls |
| Transfer of a unit on a patrol mission | Mission is deactivated for that unit; re-assign to new side's mission |
