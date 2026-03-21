# CSAR — Combat Search and Rescue Implementation Guide

Combat Search and Rescue (CSAR) is one of the most commonly requested CMO scripting patterns. This guide covers the full implementation from detection event to pilot rescue.

> **Reference implementation:** [`src/examples/csar_system.lua`](../../src/examples/csar_system.lua)

---

## Architecture Overview

```
UnitDestroyed Event (Blue Aircraft)
    │
    ▼
Survival Roll (configurable %)
    │
    ├── KIA: message, score penalty, return
    │
    └── Survived:
            │
            ▼
        Spawn downed pilot (Facility)
        Create SAR Reference Point
        Persist GUID to KeyStore
        Activate CSAR Rescue Mission
        Assign rescue helicopter
        Schedule rescue window expiry (timed event)
            │
            ├── Regular check: helicopter proximity to pilot?
            │       └── Yes → rescueSuccess()
            │
            └── Window expires → pilot lost, score penalty, cleanup
```

---

## Step 1 — Register the UnitDestroyed Trigger

```lua
-- Create the event
local ok, ev = pcall(ScenEdit_SetEvent, 'CSAR_Handler', {
    mode         = 'add',
    IsActive     = true,
    IsRepeatable = true,  -- must be true — multiple aircraft can be lost
})

-- Trigger on any Blue aircraft destroyed
pcall(ScenEdit_SetTrigger, {
    mode     = 'add',
    type     = 'UnitDestroyed',
    name     = 'BlueAircraftLost',
    unitSide = 'Blue',
    unitType = 'Aircraft',
})
pcall(ScenEdit_SetEventTrigger, ev.guid, {mode='add', name='BlueAircraftLost'})
```

> **Critical:** `IsRepeatable = true` is required. Without it, the event fires only once and subsequent aircraft losses are ignored.

---

## Step 2 — Survival Roll

Inside the event script, roll for pilot survival. Use `math.random()` which returns a float in [0, 1).

```lua
-- Inside event ScriptText (runs in sandbox)
local u = ScenEdit_UnitX()
if not u then return end
if u.type ~= 'Aircraft' then return end

math.randomseed(os.time())
local SURVIVAL_CHANCE = 0.60  -- 60% survival

if math.random() > SURVIVAL_CHANCE then
    ScenEdit_SpecialMessage('Blue', u.name .. ' lost — no ejection detected.')
    return
end
-- If we get here, pilot survived
```

---

## Step 3 — Spawn Downed Pilot

Use a `Facility` type unit to represent the downed pilot. This gives it a map icon and makes it targetable/findable.

```lua
local PILOT_DBID = 259  -- Survivor/Downed Pilot (verify in DB viewer)

local ok, pilot = pcall(ScenEdit_AddUnit, {
    side      = 'Blue',
    type      = 'Facility',
    name      = 'CSAR: ' .. u.name,
    dbid      = PILOT_DBID,
    latitude  = u.latitude,
    longitude = u.longitude,
})
if not ok or not pilot then return end

ScenEdit_SetKeyValue('CSAR_PILOT_GUID', pilot.guid)
ScenEdit_SetKeyValue('CSAR_ACTIVE', '1')
```

> **Why Facility?** Facilities persist on the map, have a visible icon, and don't move — perfect for a downed pilot. They also show up as a target for rescue helicopters to navigate to.

---

## Step 4 — SAR Reference Point

Create a reference point at the pilot location so the rescue crew can navigate there.

```lua
pcall(ScenEdit_AddReferencePoint, {
    side        = 'Blue',
    name        = 'EJECTION-' .. string.sub(pilot.guid, 1, 6),
    latitude    = u.latitude,
    longitude   = u.longitude,
    highlighted = true,   -- shows as yellow star on map
})
```

---

## Step 5 — Activate Rescue Mission

Pre-create an inactive SAR mission in GameSetup, then activate it when needed.

```lua
-- In GameSetup.lua (once):
local ok, sarM = pcall(ScenEdit_AddMission, 'Blue', 'CSAR Rescue', 'patrol', {type='air'})
if ok then
    ScenEdit_SetMission('Blue', 'CSAR Rescue', {isactive=false, flightsize=1})
end

-- In the CSAR event handler:
pcall(ScenEdit_SetMission, 'Blue', 'CSAR Rescue', {isactive=true})

-- Assign the rescue helicopter
local helGuid = ScenEdit_GetKeyValue('CSAR_HEL_GUID')
if helGuid ~= '' then
    pcall(ScenEdit_AssignUnitToMission, helGuid, 'CSAR Rescue')
end
```

---

## Step 6 — Rescue Window Timer

Create a timed event to expire the rescue window. If the helicopter doesn't reach the pilot in time, the pilot is lost.

```lua
local WINDOW_SEC = 7200   -- 2 hours
local expiryTime = ScenEdit_CurrentTime() + WINDOW_SEC
local eventName  = 'CSARExpiry_' .. string.sub(pilot.guid, 1, 8)

local ok, ev = pcall(ScenEdit_SetEvent, eventName, {
    mode='add', IsActive=true, IsRepeatable=false,
})
if ok then
    pcall(ScenEdit_SetTrigger, {mode='add', type='Time',
        name=eventName..'_T', time=expiryTime})
    pcall(ScenEdit_SetEventTrigger, ev.guid, {mode='add', name=eventName..'_T'})

    -- Build expiry script (inline, sandbox-safe)
    local expScript = string.format(
        'local g = ScenEdit_GetKeyValue("CSAR_PILOT_GUID")\r\n'..
        'if g ~= "" then\r\n'..
        '    pcall(ScenEdit_DeleteUnit, {guid=g})\r\n'..
        '    ScenEdit_SetKeyValue("CSAR_PILOT_GUID", "")\r\n'..
        '    ScenEdit_SetKeyValue("CSAR_ACTIVE", "0")\r\n'..
        '    local s = ScenEdit_GetScore("Blue")\r\n'..
        '    ScenEdit_SetScore("Blue", s - 50, "Pilot KIA")\r\n'..
        '    ScenEdit_SpecialMessage("Blue", "CSAR window expired — pilot lost.")\r\n'..
        'end\r\n'
    )
    pcall(ScenEdit_SetAction, {mode='add', type='LuaScript',
        name=eventName..'_A', ScriptText=expScript})
    pcall(ScenEdit_SetEventAction, ev.guid, {mode='add', name=eventName..'_A'})
end
```

---

## Step 7 — Rescue Success Detection

Use a repeating 60-second event to check if the rescue helicopter is close to the pilot.

```lua
-- In GameSetup, create a RepeatTime checker:
local ok, proxEv = pcall(ScenEdit_SetEvent, 'CSAR_ProxCheck', {
    mode='add', IsActive=true, IsRepeatable=true,
})
if ok then
    pcall(ScenEdit_SetTrigger, {mode='add', type='RegularTime',
        name='CSAR_ProxTimer', interval=60})
    pcall(ScenEdit_SetEventTrigger, proxEv.guid, {mode='add', name='CSAR_ProxTimer'})

    local proxScript =
        'if ScenEdit_GetKeyValue("CSAR_ACTIVE") ~= "1" then return end\r\n'..
        'local pg = ScenEdit_GetKeyValue("CSAR_PILOT_GUID")\r\n'..
        'local hg = ScenEdit_GetKeyValue("CSAR_HEL_GUID")\r\n'..
        'if pg == "" or hg == "" then return end\r\n'..
        'local ok1,pilot = pcall(ScenEdit_GetUnit,{guid=pg})\r\n'..
        'local ok2,helo  = pcall(ScenEdit_GetUnit,{guid=hg})\r\n'..
        'if not(ok1 and pilot and ok2 and helo) then return end\r\n'..
        'local ok3,dist = pcall(Tool_Range,\r\n'..
        '    {latitude=helo.latitude,longitude=helo.longitude},\r\n'..
        '    {latitude=pilot.latitude,longitude=pilot.longitude})\r\n'..
        'if not ok3 or not dist or dist > 2 then return end\r\n'..
        '-- RESCUE!\r\n'..
        'pcall(ScenEdit_DeleteUnit,{guid=pg})\r\n'..
        'ScenEdit_SetKeyValue("CSAR_PILOT_GUID","")\r\n'..
        'ScenEdit_SetKeyValue("CSAR_ACTIVE","0")\r\n'..
        'local s = ScenEdit_GetScore("Blue")\r\n'..
        'ScenEdit_SetScore("Blue", s+150, "Pilot rescued")\r\n'..
        'pcall(ScenEdit_SetMission,"Blue","CSAR Rescue",{isactive=false})\r\n'..
        'ScenEdit_SpecialMessage("Blue","CSAR SUCCESS! Pilot recovered. +150 pts.")\r\n'

    pcall(ScenEdit_SetAction, {mode='add', type='LuaScript',
        name='CSAR_ProxAction', ScriptText=proxScript})
    pcall(ScenEdit_SetEventAction, proxEv.guid, {mode='add', name='CSAR_ProxAction'})
end
```

---

## Common Pitfalls

| Problem | Cause | Fix |
|---------|-------|-----|
| Event fires once then stops | `IsRepeatable=false` | Set `IsRepeatable=true` on the UnitDestroyed event |
| Pilot spawns at (0,0) | `ScenEdit_UnitX()` returned nil | Always nil-check before reading `.latitude` |
| Rescue window fires immediately | Wrong time calculation | Use `ScenEdit_CurrentTime() + WINDOW_SEC`, not `os.time()` |
| "Only one CSAR at a time" ignored | Race condition | Check `CSAR_ACTIVE` key at very start of handler |
| `ScenEdit_DeleteUnit` fails | Unit already dead/cleaned up | Always `pcall(ScenEdit_DeleteUnit, ...)` |
| Rescue check never detects proximity | `Tool_Range` error | Wrap in pcall; ensure both units exist before calling |

---

## Variant: Multiple Simultaneous Pilots

To support multiple simultaneous CSAR operations, use a queue pattern:

```lua
-- Track pilot count
local count = (tonumber(ScenEdit_GetKeyValue('CSAR_COUNT')) or 0) + 1
ScenEdit_SetKeyValue('CSAR_COUNT', tostring(count))
ScenEdit_SetKeyValue('CSAR_PILOT_' .. count .. '_GUID', pilot.guid)

-- Proximity check iterates all active pilots
for i = 1, (tonumber(ScenEdit_GetKeyValue('CSAR_COUNT')) or 0) do
    local g = ScenEdit_GetKeyValue('CSAR_PILOT_' .. i .. '_GUID')
    -- ... check proximity for each
end
```

---

## Scoring Reference

| Event | Typical Points |
|-------|---------------|
| Aircraft lost | −25 |
| Pilot not rescued (KIA) | −50 |
| Pilot rescued | +150 |
| Same-turn rescue (< 30 min) | +200 (bonus) |

Adjust these to match your scenario's total score range.
