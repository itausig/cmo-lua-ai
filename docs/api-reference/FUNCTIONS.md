# CMO Lua API — Function Reference

Complete reference for all **ScenEdit_\***, **VP_\***, **Tool_\***, **World_\***, and **UI_\*** functions exposed by Command: Modern Operations. Organized by category.

> **Cross-references:** [WRAPPERS.md](./WRAPPERS.md) | [ENUMS.md](./ENUMS.md) | [DATA_TYPES.md](./DATA_TYPES.md)

---

## Error Handling — Read This First

CMO event scripts fail **silently**. If a script error occurs mid-execution, the remaining lines are skipped with no error message. Two patterns protect against this:

```lua
-- Pattern 1: pcall for safe calls
local ok, result = pcall(function()
    return ScenEdit_GetUnit({name='USS Nimitz', side='USA'})
end)
if not ok then
    ScenEdit_SpecialMessage('USA', 'Error: ' .. tostring(result))
end

-- Pattern 2: nil-guard every return value
local unit = ScenEdit_GetUnit({name='USS Nimitz', side='USA'})
if not unit then return end   -- script stops cleanly if unit not found

-- Pattern 3: suppress console errors in automated/event scripts
Tool_EmulateNoConsole(true)
-- ... your logic ...
Tool_EmulateNoConsole(false)
```

---

## Table of Contents

1. [Events](#1-events)
2. [Missions](#2-missions)
3. [Reference Points & Zones](#3-reference-points--zones)
4. [Scenario](#4-scenario)
5. [Units](#5-units)
6. [EMCON](#6-emcon)
7. [Miscellaneous / Tools](#7-miscellaneous--tools)
8. [UI Functions](#8-ui-functions)
9. [Sides & Others](#9-sides--others)
10. [Pro Edition Only](#10-pro-edition-only)

---

## 1. Events

The Event system uses a **Trigger → Condition → Action** (TCA) model. Triggers fire the event, conditions gate it, and actions execute when it fires.

> See [ENUMS.md — Trigger Types](./ENUMS.md#trigger-types), [Action Types](./ENUMS.md#action-types), and [Condition Types](./ENUMS.md#condition-types) for valid type strings.

---

### `ScenEdit_EventX()`

```lua
ScenEdit_EventX() -> Event
```

Returns the **current event** that triggered the executing script. Use inside event action Lua scripts to inspect the triggering context.

**Returns:** [`Event`](./WRAPPERS.md#event) wrapper, or `nil` if called outside an event context.

**Example:**
```lua
local ev = ScenEdit_EventX()
if ev then
    ScenEdit_SpecialMessage('PlayerSide', 'Event fired: ' .. ev.name)
end
```

---

### `ScenEdit_UnitX()`

```lua
ScenEdit_UnitX() -> Unit
```

Returns the **unit that triggered** the currently executing event (e.g., the unit that was detected, destroyed, or entered an area). Only valid inside event scripts with unit-based triggers.

**Returns:** [`Unit`](./WRAPPERS.md#unit) wrapper, or `nil`.

**Example:**
```lua
local u = ScenEdit_UnitX()
if u and u.type == 'Aircraft' then
    ScenEdit_SpecialMessage('PlayerSide', 'Aircraft triggered event: ' .. u.name)
end
```

---

### `ScenEdit_UnitC()`

```lua
ScenEdit_UnitC() -> Contact
```

Returns the **contact** associated with the current event (e.g., the contact that was detected). Valid in `UnitDetected` trigger contexts.

**Returns:** [`Contact`](./WRAPPERS.md#contact) wrapper, or `nil`.

**Example:**
```lua
local c = ScenEdit_UnitC()
if c then
    ScenEdit_SpecialMessage('PlayerSide', 'New contact: ' .. c.type_description)
end
```

---

### `ScenEdit_UnitY()`

```lua
ScenEdit_UnitY() -> Unit
```

Returns the **secondary unit** involved in the current event (e.g., the firer when a `UnitDamaged` event triggers on the damaged unit). Context-dependent.

**Returns:** [`Unit`](./WRAPPERS.md#unit) wrapper, or `nil`.

---

### `ScenEdit_AddSpecialAction(params)`

```lua
ScenEdit_AddSpecialAction({
    name        = string,       -- Display name (required)
    side        = string,       -- Side name or GUID (required)
    description = string,       -- Optional description
    isActive    = boolean,      -- Whether action is available (default true)
    isRepeatable = boolean,     -- Can be triggered multiple times (default true)
    ScriptText  = string        -- Lua code to execute when triggered
}) -> SpecialAction
```

Creates a **Special Action** — a player-triggerable event that appears in the Special Actions menu.

**Returns:** [`SpecialAction`](./WRAPPERS.md#specialaction) wrapper.

**Example:**
```lua
local sa = ScenEdit_AddSpecialAction({
    name = 'Launch TLAM Strike',
    side = 'USA',
    isActive = true,
    isRepeatable = false,
    ScriptText = [[
        local target = ScenEdit_GetUnit({name='Power Plant', side='OPFOR'})
        if target then
            -- strike logic here
        end
    ]]
})
```

---

### `ScenEdit_ExecuteEventAction(eventNameOrId)`

```lua
ScenEdit_ExecuteEventAction(eventNameOrId: string) -> boolean
```

Immediately executes all **actions** of the specified event, bypassing triggers and conditions.

**Parameters:**
| Parameter | Type | Description |
|-----------|------|-------------|
| `eventNameOrId` | `string` | Event name or GUID |

**Returns:** `true` on success, `false` on failure.

**Example:**
```lua
ScenEdit_ExecuteEventAction('Ambush Triggered')
```

---

### `ScenEdit_ExecuteSpecialAction(sideNameOrId, actionNameOrId)`

```lua
ScenEdit_ExecuteSpecialAction(sideNameOrId: string, actionNameOrId: string) -> boolean
```

Programmatically executes a **Special Action** as if the player clicked it.

**Parameters:**
| Parameter | Type | Description |
|-----------|------|-------------|
| `sideNameOrId` | `string` | Side name or GUID |
| `actionNameOrId` | `string` | Action name or GUID |

**Example:**
```lua
ScenEdit_ExecuteSpecialAction('USA', 'Call in Artillery')
```

---

### `ScenEdit_GetEvent(eventNameOrId)`

```lua
ScenEdit_GetEvent(eventNameOrId: string) -> Event
```

Retrieves a specific event by name or GUID.

**Returns:** [`Event`](./WRAPPERS.md#event) wrapper, or `nil` if not found.

**Example:**
```lua
local ev = ScenEdit_GetEvent('Enemy Fleet Detected')
if ev then
    print(ev.isActive)
end
```

---

### `ScenEdit_GetEvents(sideNameOrId)`

```lua
ScenEdit_GetEvents(sideNameOrId: string) -> table<Event>
```

Returns a table of **all events** for the given side.

**Returns:** Array of [`Event`](./WRAPPERS.md#event) wrappers.

**Example:**
```lua
local events = ScenEdit_GetEvents('USA')
for _, ev in ipairs(events) do
    print(ev.name, ev.isActive)
end
```

---

### `ScenEdit_GetSpecialAction(params)`

```lua
ScenEdit_GetSpecialAction({side=string, name=string}) -> SpecialAction
-- or
ScenEdit_GetSpecialAction({side=string, guid=string}) -> SpecialAction
```

Retrieves a Special Action by name or GUID for a given side.

**Returns:** [`SpecialAction`](./WRAPPERS.md#specialaction) wrapper, or `nil`.

---

### `ScenEdit_SetAction(params)`

```lua
ScenEdit_SetAction({
    name        = string,   -- Action name (required)
    description = string,
    type        = string,   -- Action type: 'LuaScript', 'Message', 'Points', etc.
    -- Type-specific fields:
    scriptText  = string,   -- For LuaScript type
    message     = string,   -- For Message type
    side        = string,   -- For Points/Message types
    points      = number    -- For Points type
}) -> table
```

Creates or modifies a **generic action** (used in event TCA chains). See [ENUMS.md — Action Types](./ENUMS.md#action-types).

---

### `ScenEdit_SetCondition(params)`

```lua
ScenEdit_SetCondition({
    name        = string,
    description = string,
    type        = string,   -- 'LuaScript', 'ScenHasStarted', 'SidePosture'
    -- Type-specific fields:
    scriptText  = string,
    sideA       = string,
    sideB       = string,
    posture     = string    -- 'Hostile', 'Friendly', etc.
}) -> table
```

Creates or modifies a **condition** in the TCA system. See [ENUMS.md — Condition Types](./ENUMS.md#condition-types).

---

### `ScenEdit_SetEvent(eventNameOrId, params)`

```lua
ScenEdit_SetEvent(eventNameOrId: string, {
    isActive     = boolean,
    isRepeatable = boolean,
    isShown      = boolean,
    probability  = number   -- 0–100
}) -> Event
```

Modifies an existing event's properties.

**Example:**
```lua
-- Deactivate event after it fires once
local ev = ScenEdit_EventX()
ScenEdit_SetEvent(ev.guid, {isActive=false})
```

---

### `ScenEdit_SetEventAction(eventNameOrId, actionNameOrId, params)`

```lua
ScenEdit_SetEventAction(
    eventNameOrId  : string,
    actionNameOrId : string,
    params         : table
) -> boolean
```

Associates an action with an event and configures its parameters.

---

### `ScenEdit_SetEventCondition(eventNameOrId, conditionNameOrId, params)`

```lua
ScenEdit_SetEventCondition(
    eventNameOrId     : string,
    conditionNameOrId : string,
    params            : table
) -> boolean
```

Associates a condition with an event.

---

### `ScenEdit_SetEventTrigger(eventNameOrId, triggerNameOrId, params)`

```lua
ScenEdit_SetEventTrigger(
    eventNameOrId  : string,
    triggerNameOrId: string,
    params         : table
) -> boolean
```

Associates a trigger with an event and configures its parameters.

---

### `ScenEdit_SetSpecialAction(params)`

```lua
ScenEdit_SetSpecialAction({
    side        = string,
    guid        = string,   -- Required to identify the action
    name        = string,
    description = string,
    isActive    = boolean,
    isRepeatable = boolean,
    ScriptText  = string
}) -> SpecialAction
```

Modifies an existing Special Action.

**Example:**
```lua
-- Disable a special action after first use
local sa = ScenEdit_GetSpecialAction({side='USA', name='Call Airstrike'})
ScenEdit_SetSpecialAction({side='USA', guid=sa.guid, isActive=false})
```

---

### `ScenEdit_SetTrigger(params)`

```lua
ScenEdit_SetTrigger({
    name        = string,
    description = string,
    type        = string,   -- Trigger type (see ENUMS.md)
    -- Type-specific fields vary
}) -> table
```

Creates or modifies a **trigger** in the TCA system. See [ENUMS.md — Trigger Types](./ENUMS.md#trigger-types) for all valid types and their parameters.

---

## 2. Missions

> **Mission types:** `'strike'` | `'patrol'` | `'support'` | `'ferry'` | `'mining'` | `'mineclearing'` | `'escort'` | `'cargo'`

---

### `ScenEdit_AddMission(sideNameOrId, missionName, missionType, missionOptions)`

```lua
ScenEdit_AddMission(
    sideNameOrId  : string,
    missionName   : string,
    missionType   : string,
    missionOptions: table
) -> Mission
```

Creates a new mission for the specified side.

**Mission-type-specific options:**

| Type | Key options |
|------|-------------|
| `'strike'` | `type='land'\|'sub'\|'air'`, `TargetFilterList`, `OneTimeOnly` |
| `'patrol'` | `type='air'\|'sub'\|'naval'\|'land'`, `Zone`, `CheckArea` |
| `'support'` | `type='aew'\|'tand'\|'aar'\|'jammer'\|'lofar'`, `SupportedSide` |
| `'ferry'` | `FerryThrottle`, `FerryAltitude` |
| `'mining'` | `Zone`, `MineType` |
| `'mineclearing'` | `Zone` |
| `'escort'` | `EscortedMission`, `EscortAltitude` |
| `'cargo'` | `AssignedCargo` |

**Returns:** [`Mission`](./WRAPPERS.md#mission) wrapper.

**Example:**
```lua
-- Create an ASW patrol mission
local mission = ScenEdit_AddMission('USA', 'ASW Barrier', 'patrol', {
    type = 'sub',
    Zone = {'WP1', 'WP2', 'WP3', 'WP4'}
})
if mission then
    print('Mission created: ' .. mission.guid)
end
```

---

### `ScenEdit_AssignUnitAsTarget(unitNameOrId, missionNameOrId, sideNameOrId)`

```lua
ScenEdit_AssignUnitAsTarget(
    unitNameOrId    : string,
    missionNameOrId : string,
    sideNameOrId    : string
) -> boolean
```

Adds a unit as a **target** in a strike mission's target list.

**Example:**
```lua
ScenEdit_AssignUnitAsTarget('OPFOR HQ', 'Alpha Strike', 'USA')
```

---

### `ScenEdit_AssignUnitToMission(unitNameOrId, missionNameOrId, escort)`

```lua
ScenEdit_AssignUnitToMission(
    unitNameOrId    : string,
    missionNameOrId : string,
    escort          : boolean   -- If true, assigns as escort rather than primary
) -> boolean
```

Assigns a unit to an existing mission.

**Example:**
```lua
-- Assign aircraft to mission, not as escort
ScenEdit_AssignUnitToMission('F-18 Alpha', 'CAP North', false)
-- Assign as escort
ScenEdit_AssignUnitToMission('EA-18G Growler', 'Alpha Strike', true)
```

---

### `ScenEdit_CreateMissionFlightPlan(params)`

```lua
ScenEdit_CreateMissionFlightPlan({
    mission = string,   -- Mission name or GUID
    side    = string
}) -> boolean
```

Forces generation of flight plans for all aircraft assigned to the mission.

---

### `ScenEdit_DeleteMission(sideNameOrId, missionNameOrId)`

```lua
ScenEdit_DeleteMission(
    sideNameOrId    : string,
    missionNameOrId : string
) -> boolean
```

Deletes a mission. Assigned units are unassigned (not deleted).

**Example:**
```lua
ScenEdit_DeleteMission('USA', 'CAP North')
```

---

### `ScenEdit_ExportMission(sideNameOrId, missionNameOrId)`

```lua
ScenEdit_ExportMission(
    sideNameOrId    : string,
    missionNameOrId : string
) -> string
```

Exports a mission as a **JSON string** for storage or transmission.

---

### `ScenEdit_ImportMission(sideNameOrId, missionJSON)`

```lua
ScenEdit_ImportMission(
    sideNameOrId : string,
    missionJSON  : string
) -> Mission
```

Imports a mission from a JSON string (previously exported with `ScenEdit_ExportMission`).

---

### `ScenEdit_GetMission(sideNameOrId, missionNameOrId)`

```lua
ScenEdit_GetMission(
    sideNameOrId    : string,
    missionNameOrId : string
) -> Mission
```

Retrieves a mission by name or GUID for the specified side.

**Returns:** [`Mission`](./WRAPPERS.md#mission) wrapper, or `nil` if not found.

**Example:**
```lua
local m = ScenEdit_GetMission('USA', 'Alpha Strike')
if m then
    print('Units assigned: ' .. #m.unitlist)
    print('Targets: ' .. #m.targetlist)
end
```

---

### `ScenEdit_GetMissions(sideNameOrId)`

```lua
ScenEdit_GetMissions(sideNameOrId: string) -> table<Mission>
```

Returns all missions for a side.

**Example:**
```lua
local missions = ScenEdit_GetMissions('USA')
for _, m in ipairs(missions) do
    if m.type == 'strike' and m.isactive then
        print('Active strike: ' .. m.name)
    end
end
```

---

### `ScenEdit_SetMission(sideNameOrId, missionNameOrId, params)`

```lua
ScenEdit_SetMission(
    sideNameOrId    : string,
    missionNameOrId : string,
    params          : table     -- Same fields as Mission wrapper
) -> Mission
```

Modifies mission properties. See [`Mission`](./WRAPPERS.md#mission) wrapper for all settable fields.

**Example:**
```lua
-- Deactivate a mission
ScenEdit_SetMission('USA', 'CAP North', {isactive=false})

-- Change patrol zone
ScenEdit_SetMission('USA', 'ASW Barrier', {
    patrolzone = {'WP1','WP2','WP3'}
})
```

---

### `ScenEdit_RemoveUnitAsTarget(unitNameOrId, missionNameOrId, sideNameOrId)`

```lua
ScenEdit_RemoveUnitAsTarget(
    unitNameOrId    : string,
    missionNameOrId : string,
    sideNameOrId    : string
) -> boolean
```

Removes a unit from a strike mission's target list.

---

## 3. Reference Points & Zones

---

### `ScenEdit_AddReferencePoint(params)`

```lua
-- Single point form:
ScenEdit_AddReferencePoint({
    side        = string,       -- Side name or GUID (required)
    name        = string,       -- Point name (required)
    lat         = number|string,-- Latitude (decimal or 'N DD.MM.SS')
    lon         = number|string,-- Longitude (decimal or 'E DDD.MM.SS')
    highlighted = boolean,      -- (optional)
    locked      = boolean,      -- (optional)
    bearingtype = string,       -- 'fixed' | 'rotating' (optional)
    relativeto  = string        -- Unit GUID for rotating bearing (optional)
}) -> ReferencePoint

-- Area (multi-point) form:
ScenEdit_AddReferencePoint({
    side = string,
    area = {
        {name=string, lat=number, lon=number},
        {name=string, lat=number, lon=number},
        -- ...
    }
}) -> table<ReferencePoint>
```

Adds one or more reference points to a side.

**Returns:** [`ReferencePoint`](./WRAPPERS.md#referencepoint) or table thereof.

**Example:**
```lua
-- Single reference point
local rp = ScenEdit_AddReferencePoint({
    side = 'USA',
    name = 'Alpha',
    lat  = 38.5,
    lon  = -122.4
})

-- Define a patrol area using multi-point form
ScenEdit_AddReferencePoint({
    side = 'USA',
    area = {
        {name='PA-1', lat=36.0, lon=-10.0},
        {name='PA-2', lat=37.0, lon=-10.0},
        {name='PA-3', lat=37.0, lon=-8.0},
        {name='PA-4', lat=36.0, lon=-8.0}
    }
})
```

---

### `ScenEdit_AddZone(sideNameOrId, zoneType, params)`

```lua
ScenEdit_AddZone(
    sideNameOrId : string,
    zoneType     : string,  -- 'exclusion' | 'nonavigation' | 'standard' | 'customenvironment'
    params       : table    -- {name, isactive, affects, area, noFire, ...}
) -> Zone
```

Creates a zone for the specified side. See [`Zone`](./WRAPPERS.md#zone) wrapper for all configurable fields.

**Example:**
```lua
ScenEdit_AddZone('USA', 'exclusion', {
    name     = 'No-Fly North',
    isactive = true,
    affects  = 'aircraft',
    area     = {'NF-1','NF-2','NF-3','NF-4'},  -- Reference point names
    markas   = 'hostile'
})
```

---

### `ScenEdit_DeleteReferencePoint(params)`

```lua
ScenEdit_DeleteReferencePoint({
    side = string,
    name = string   -- or guid = string
}) -> boolean
```

Deletes a reference point by name or GUID.

---

### `ScenEdit_GetReferencePoint(params)`

```lua
ScenEdit_GetReferencePoint({
    side = string,
    name = string   -- or guid = string
}) -> ReferencePoint
```

Retrieves a reference point.

**Returns:** [`ReferencePoint`](./WRAPPERS.md#referencepoint) wrapper, or `nil`.

**Example:**
```lua
local rp = ScenEdit_GetReferencePoint({side='USA', name='Alpha'})
if rp then
    print(rp.latitude, rp.longitude)
end
```

---

### `ScenEdit_GetReferencePoints(sideNameOrId)`

```lua
ScenEdit_GetReferencePoints(sideNameOrId: string) -> table<ReferencePoint>
```

Returns all reference points for a side.

---

### `ScenEdit_RemoveZone(sideNameOrId, zoneType, zoneNameOrId)`

```lua
ScenEdit_RemoveZone(
    sideNameOrId : string,
    zoneType     : string,
    zoneNameOrId : string
) -> boolean
```

Removes a zone.

---

### `ScenEdit_SetReferencePoint(params)`

```lua
ScenEdit_SetReferencePoint({
    side      = string,
    name      = string,     -- or guid = string (to identify the point)
    -- Fields to modify:
    newname   = string,
    lat       = number|string,
    lon       = number|string,
    highlighted = boolean,
    locked    = boolean,
    bearingtype = string,
    relativeto  = string,
    relativeDistance = number,
    relativeBearing  = number,
    color     = string
}) -> ReferencePoint
```

Modifies an existing reference point.

**Example:**
```lua
-- Move a reference point
ScenEdit_SetReferencePoint({
    side = 'USA',
    name = 'Alpha',
    lat  = 39.0,
    lon  = -121.0,
    highlighted = true
})
```

---

### `ScenEdit_SetZone(sideNameOrId, zoneType, params)`

```lua
ScenEdit_SetZone(
    sideNameOrId : string,
    zoneType     : string,
    params       : table    -- {name or guid, + fields to modify}
) -> Zone
```

Modifies an existing zone.

---

### `ScenEdit_TransformZone(sideNameOrId, zoneType, zoneNameOrId, transform)`

```lua
ScenEdit_TransformZone(
    sideNameOrId : string,
    zoneType     : string,
    zoneNameOrId : string,
    transform    : table    -- {rotate=degrees, scale=factor, translate={lat,lon}}
) -> Zone
```

Applies geometric transforms to a zone's boundary.

---

## 4. Scenario

---

### `GetScenarioTitle()`

```lua
GetScenarioTitle() -> string
```

Returns the scenario title string.

**Example:**
```lua
local title = GetScenarioTitle()
ScenEdit_SpecialMessage('PlayerSide', 'Scenario: ' .. title)
```

---

### `ScenEdit_CurrentTime()`

```lua
ScenEdit_CurrentTime() -> number
```

Returns the current scenario time as a **Unix timestamp** (seconds since epoch). Use for arithmetic (elapsed time, scheduling).

**Example:**
```lua
local t = ScenEdit_CurrentTime()
-- Schedule an event 2 hours later
local targetTime = t + (2 * 3600)
ScenEdit_SetKeyValue('phase2_time', tostring(targetTime))
```

---

### `ScenEdit_CurrentLocalTime()`

```lua
ScenEdit_CurrentLocalTime() -> string
```

Returns the current scenario time as a **locale-formatted date-time string**.

---

### `ScenEdit_EndScenario()`

```lua
ScenEdit_EndScenario() -> nil
```

Immediately ends the scenario. Typically called in a win/loss action script.

**Example:**
```lua
-- End scenario if player loses all ships
local side = VP_GetSide({Side='USA'})
if #side.units == 0 then
    ScenEdit_SpecialMessage('USA', 'All units lost. Mission failed.')
    ScenEdit_EndScenario()
end
```

---

### `ScenEdit_GetScenHasStarted()`

```lua
ScenEdit_GetScenHasStarted() -> boolean
```

Returns `true` if the scenario clock has started (i.e., not in pre-start editor mode).

---

### `ScenEdit_GetWeather()`

```lua
ScenEdit_GetWeather() -> {
    temperature : number,   -- Celsius
    rainfall    : number,   -- 0.0–1.0
    clouds      : number,   -- 0.0–1.0
    seastate    : number    -- Beaufort scale 0–9
}
```

Returns current global weather settings.

**Example:**
```lua
local wx = ScenEdit_GetWeather()
print(string.format('Temp: %d°C, Sea State: %d', wx.temperature, wx.seastate))
```

---

### `ScenEdit_GetScore(sideNameOrId)`

```lua
ScenEdit_GetScore(sideNameOrId: string) -> number
```

Returns the current score for the specified side.

---

### `ScenEdit_GetTimeOfDay()`

```lua
ScenEdit_GetTimeOfDay() -> string
```

Returns `'Day'`, `'Dusk'`, `'Night'`, or `'Dawn'` based on the current scenario time and scenario location.

---

### `ScenEdit_SetStartTime(dateTimeString)`

```lua
ScenEdit_SetStartTime(dateTimeString: string) -> nil
```

Sets the scenario start time. See [DATA_TYPES.md — DateTime](./DATA_TYPES.md#datetime) for format.

**Example:**
```lua
ScenEdit_SetStartTime('2027-06-09 06:00:00!yyyy-MM-dd HH:mm:ss')
```

---

### `ScenEdit_SetScore(sideNameOrId, score, reason)`

```lua
ScenEdit_SetScore(
    sideNameOrId : string,
    score        : number,
    reason       : string   -- Optional, logged in score history
) -> nil
```

Sets the score for a side to an **absolute** value.

**Example:**
```lua
-- Award points for destroying target
ScenEdit_SetScore('USA', ScenEdit_GetScore('USA') + 100, 'Destroyed command bunker')
```

---

### `ScenEdit_SetTime(dateTimeString)`

```lua
ScenEdit_SetTime(dateTimeString: string) -> nil
```

Jumps the scenario clock to the specified time (use carefully — can break event timing).

---

### `ScenEdit_SetWeather(params)`

```lua
ScenEdit_SetWeather({
    temperature : number,   -- Celsius
    rainfall    : number,   -- 0.0–1.0 (0=none, 1=torrential)
    clouds      : number,   -- 0.0–1.0 (0=clear, 1=overcast)
    seastate    : number    -- Beaufort scale 0–9
}) -> nil
```

Sets global weather.

**Example:**
```lua
-- Storm conditions
ScenEdit_SetWeather({temperature=12, rainfall=0.7, clouds=0.9, seastate=7})
-- Clear
ScenEdit_SetWeather({temperature=22, rainfall=0.0, clouds=0.1, seastate=2})
```

---

### `VP_GetContact(params)`

```lua
VP_GetContact({
    guid = string   -- Contact GUID
}) -> Contact
```

Retrieves a contact by GUID.

**Returns:** [`Contact`](./WRAPPERS.md#contact) wrapper, or `nil`.

---

### `VP_GetScenario()`

```lua
VP_GetScenario() -> Scenario
```

Returns the top-level [`Scenario`](./WRAPPERS.md#scenario) wrapper with metadata about the current scenario.

**Example:**
```lua
local scen = VP_GetScenario()
print(scen.Title)
print(scen.CurrentTime)
print(scen.PlayerSide)
```

---

### `VP_GetSide(params)`

```lua
VP_GetSide({Side = string}) -> Side
```

Returns the [`Side`](./WRAPPERS.md#side) wrapper for the named side.

**Note:** The parameter key is `Side` (capital S).

**Example:**
```lua
local usaSide = VP_GetSide({Side='USA'})
for _, unit in ipairs(usaSide.units) do
    print(unit.name, unit.type)
end
```

---

### `VP_GetSides()`

```lua
VP_GetSides() -> table<Side>
```

Returns all sides in the scenario.

**Example:**
```lua
local sides = VP_GetSides()
for _, s in ipairs(sides) do
    print(s.name, 'Score:', ScenEdit_GetScore(s.name))
end
```

---

### `VP_GetUnit(params)`

```lua
VP_GetUnit({
    guid = string       -- Unit GUID (preferred)
}) -> Unit
-- or
VP_GetUnit({
    name = string,
    side = string
}) -> Unit
```

Retrieves a unit by GUID or name+side.

**Always prefer GUID** — names can change, GUIDs cannot.

**Returns:** [`Unit`](./WRAPPERS.md#unit) wrapper, or `nil`.

**Example:**
```lua
-- By GUID (preferred)
local unit = VP_GetUnit({guid='a1b2c3d4-...'})

-- By name (fragile if names change)
local unit2 = VP_GetUnit({name='USS Nimitz', side='USA'})
if unit2 then
    print(unit2.latitude, unit2.longitude)
end
```

---

## 5. Units

---

### `ScenEdit_AddUnit(params)`

```lua
ScenEdit_AddUnit({
    side         = string,          -- Side name or GUID (required)
    type         = string,          -- 'Aircraft'|'Ship'|'Submarine'|'Facility'|'Satellite'
    name         = string,          -- Unit name (required)
    dbid         = number,          -- Database ID (required)
    latitude     = number|string,   -- (required)
    longitude    = number|string,   -- (required)
    altitude     = number|string,   -- Meters, or '100 FT'. Omit for surface/sub
    loadoutid    = number,          -- Aircraft loadout DB ID
    heading      = number,          -- 0–360 degrees
    autodetectable = boolean,       -- Visible to all sides regardless of sensors
    holdfire     = boolean,
    proficiency  = string,          -- 'Novice'|'Cadet'|'Regular'|'Veteran'|'Ace'
    Base         = string           -- Base unit name/GUID for aircraft
}) -> Unit
```

Spawns a new unit into the scenario.

**Returns:** [`Unit`](./WRAPPERS.md#unit) wrapper.

**Example:**
```lua
-- Spawn an F/A-18 on a carrier
local carrier = ScenEdit_GetUnit({name='USS Nimitz', side='USA'})
local fighter = ScenEdit_AddUnit({
    side      = 'USA',
    type      = 'Aircraft',
    name      = 'VFA-105 Alpha',
    dbid      = 278,            -- F/A-18C Hornet
    latitude  = carrier.latitude,
    longitude = carrier.longitude,
    altitude  = '0 FT',
    loadoutid = 16120,
    heading   = 0,
    proficiency = 'Veteran',
    Base      = carrier.name
})

-- Spawn a ship
local ship = ScenEdit_AddUnit({
    side      = 'OPFOR',
    type      = 'Ship',
    name      = 'Frigate Alpha',
    dbid      = 1150,
    latitude  = 36.5,
    longitude = -10.2,
    heading   = 180
})
```

---

### `ScenEdit_AddReloadsToUnit(params)`

```lua
ScenEdit_AddReloadsToUnit({
    unitname = string,
    wpn_dbid = number,
    wpn_count = number
}) -> boolean
```

Adds weapon reloads directly to a unit's magazines.

---

### `ScenEdit_AddWeaponToUnitMagazine(params)`

```lua
ScenEdit_AddWeaponToUnitMagazine({
    unitname = string,      -- Unit name or GUID
    wpn_dbid = number,      -- Weapon database ID
    number   = number,      -- Quantity to add
    maxcap   = number       -- Optional: cap total to this amount
}) -> boolean
```

Adds weapons to a unit's magazine. Useful for replenishing ammo mid-scenario.

**Example:**
```lua
ScenEdit_AddWeaponToUnitMagazine({
    unitname = 'USS Bunker Hill',
    wpn_dbid = 229,     -- SM-2MR
    number   = 24,
    maxcap   = 122
})
```

---

### `ScenEdit_DeleteUnit(params)`

```lua
ScenEdit_DeleteUnit({
    side = string,
    name = string   -- or guid = string
}) -> boolean
```

Removes a unit from the scenario (not destroyed — simply removed).

**Example:**
```lua
ScenEdit_DeleteUnit({side='USA', name='VFA-105 Alpha'})
```

---

### `ScenEdit_GetDoctrine(params)`

```lua
ScenEdit_GetDoctrine({
    side    = string,   -- Side name (for side doctrine)
    -- or:
    mission = string,   -- Mission name (for mission doctrine)
    -- or:
    name    = string,   -- Unit name (for unit doctrine)
    guid    = string
}) -> Doctrine
```

Retrieves the doctrine settings for a side, mission, or unit. See [`Doctrine`](./WRAPPERS.md#doctrine) wrapper.

**Example:**
```lua
local d = ScenEdit_GetDoctrine({side='USA'})
print(d.weapon_control_status_air)  -- 0=Free, 1=Tight, 2=Hold
```

---

### `ScenEdit_GetDoctrineWRA(params)`

```lua
ScenEdit_GetDoctrineWRA({
    side       = string,
    -- or mission = string,
    -- or name   = string,
    target_type = string    -- Target type code (see ENUMS.md)
}) -> DoctrineWRA
```

Retrieves Weapon Release Authority settings. See [`DoctrineWRA`](./WRAPPERS.md#doctrinewra) wrapper.

---

### `ScenEdit_GetFormation(params)`

```lua
ScenEdit_GetFormation({
    name = string,  -- Group/unit name
    side = string
}) -> table
```

Returns formation data for a unit group.

---

### `ScenEdit_GetLoadout(params)`

```lua
ScenEdit_GetLoadout({
    UnitNameOrID = string,
    LoadoutID    = number   -- Optional; returns current if omitted
}) -> Loadout
```

Returns loadout information for an aircraft. See [`Loadout`](./WRAPPERS.md#loadout) wrapper.

---

### `ScenEdit_GetUnit(params)`

```lua
ScenEdit_GetUnit({
    guid = string           -- Preferred
}) -> Unit
-- or
ScenEdit_GetUnit({
    name = string,
    side = string
}) -> Unit
```

Retrieves a unit. **Always prefer GUID** over name+side.

**Returns:** [`Unit`](./WRAPPERS.md#unit) wrapper, or `nil`.

**Example:**
```lua
local u = ScenEdit_GetUnit({name='USS Nimitz', side='USA'})
if not u then return end    -- nil guard!
print(string.format('%.4f, %.4f alt=%.0fm', u.latitude, u.longitude, u.altitude))
```

---

### `ScenEdit_FillMagsForLoadout(params)`

```lua
ScenEdit_FillMagsForLoadout({
    UnitNameOrID = string,
    LoadoutID    = number,
    MagID        = number   -- Optional: specific magazine GUID
}) -> boolean
```

Fills the magazines required by the specified loadout to capacity.

---

### `ScenEdit_KillUnit(params)`

```lua
ScenEdit_KillUnit({
    side = string,
    name = string   -- or guid = string
}) -> boolean
```

Destroys a unit (triggers destruction events, BDA, scoring).

**Example:**
```lua
-- Destroy a unit and award points
ScenEdit_KillUnit({side='OPFOR', name='Frigate Bravo'})
ScenEdit_SetScore('USA', ScenEdit_GetScore('USA') + 50, 'Sank frigate')
```

---

### `ScenEdit_MergeUnits(unitList)`

```lua
ScenEdit_MergeUnits({
    side  = string,
    units = {string, string, ...}   -- Unit names or GUIDs
}) -> Unit
```

Merges multiple units of the same type into one.

---

### `ScenEdit_RefuelUnit(params)`

```lua
ScenEdit_RefuelUnit({
    unitname = string   -- or guid
}) -> boolean
```

Instantly refuels the unit to capacity (useful for scenario scripting; bypasses AAR).

---

### `ScenEdit_SetDoctrine(params, doctrineTable)`

```lua
ScenEdit_SetDoctrine(
    {side=string},          -- or {mission=string} or {name=string, guid=string}
    {
        weapon_control_status_air       = number,   -- 0=Free,1=Tight,2=Hold
        weapon_control_status_surface   = number,
        weapon_control_status_subsurface= number,
        weapon_control_status_land      = number,
        engage_opportunity_targets      = string,   -- 'yes'|'no'
        bvr_logic                       = string,
        -- ... (see Doctrine wrapper)
    }
) -> Doctrine
```

Sets doctrine for a side, mission, or unit.

**Example:**
```lua
-- Set all weapons free for side
ScenEdit_SetDoctrine({side='USA'}, {
    weapon_control_status_air        = 0,
    weapon_control_status_surface    = 0,
    weapon_control_status_subsurface = 0,
    weapon_control_status_land       = 0,
    engage_opportunity_targets       = 'yes'
})
```

---

### `ScenEdit_SetDoctrineWRA(params, wraTable)`

```lua
ScenEdit_SetDoctrineWRA(
    {side=string, target_type=string},
    {
        -- WRA fields: number of weapons, shooters, etc.
    }
) -> DoctrineWRA
```

Sets Weapon Release Authority for a specific target type.

---

### `ScenEdit_SetEMCON(scope, nameOrId, settingsString)`

```lua
ScenEdit_SetEMCON(
    scope         : string,   -- 'Side' | 'Unit' | 'Mission'
    nameOrId      : string,   -- Side/unit/mission name or GUID
    settingsString: string    -- EMCON state string
) -> nil
```

Sets EMCON (Emission Control) state. The settings string format controls radar, sonar, ECM emission policies.

**EMCON settings string format:** A semicolon-delimited list of `SensorType=State` pairs. States: `Active`, `Passive`, `Nominal`.

**Example:**
```lua
-- Set all sensors to passive for a unit
ScenEdit_SetEMCON('Unit', 'USS Nimitz', 'Radar=Passive;Sonar=Passive')

-- Restore active emissions for entire side
ScenEdit_SetEMCON('Side', 'USA', 'Radar=Active;Sonar=Active;ECM=Active')
```

---

### `ScenEdit_SetLoadout(params)`

```lua
ScenEdit_SetLoadout({
    UnitNameOrID        = string,
    LoadoutID           = number,
    TimeToReady_Minutes = number,   -- How long until loadout is applied
    IgnoreMagazines     = boolean   -- Set true to ignore magazine constraints
}) -> Loadout
```

Changes an aircraft's loadout.

**Example:**
```lua
-- Rearm F-18 with anti-ship loadout, 30-minute turnaround
ScenEdit_SetLoadout({
    UnitNameOrID        = 'VFA-105 Alpha',
    LoadoutID           = 16130,    -- Anti-ship loadout DBID
    TimeToReady_Minutes = 30,
    IgnoreMagazines     = false
})
```

---

### `ScenEdit_SetUnit(params)`

```lua
ScenEdit_SetUnit({
    guid     = string,      -- or name+side
    -- Fields to modify:
    name     = string,
    side     = string,
    latitude = number,
    longitude= number,
    altitude = number|string,
    heading  = number,
    speed    = number,
    course   = {{lat,lon,alt}, ...},
    holdfire = boolean,
    holdposition = boolean,
    autodetectable = boolean,
    proficiency = string,
    mission  = string,      -- Assign to mission by name/GUID
    -- ... (any Unit wrapper field that is writable)
}) -> Unit
```

The primary function for modifying unit state. Accepts any writable [`Unit`](./WRAPPERS.md#unit) field.

**Example:**
```lua
-- Teleport a unit to new position with new heading
ScenEdit_SetUnit({
    name      = 'Frigate Alpha',
    side      = 'OPFOR',
    latitude  = 37.5,
    longitude = -9.8,
    heading   = 270,
    speed     = 15
})

-- Set unit course (series of waypoints)
ScenEdit_SetUnit({
    name   = 'Frigate Alpha',
    side   = 'OPFOR',
    course = {
        {latitude=37.5, longitude=-10.0},
        {latitude=38.0, longitude=-10.5},
        {latitude=38.5, longitude=-11.0}
    }
})
```

---

### `ScenEdit_SetUnitDamage(params)`

```lua
ScenEdit_SetUnitDamage({
    side    = string,
    name    = string,   -- or guid
    damage  = {
        structural = number,    -- 0–100 percent damage
        -- Component damage:
        components = {
            {guid=string, dp=number}
        }
    }
}) -> boolean
```

Applies damage to a unit or its components.

---

### `ScenEdit_SplitUnit(params)`

```lua
ScenEdit_SplitUnit({
    guid  = string,
    units = {string, ...}   -- GUIDs to split off
}) -> table<Unit>
```

Splits units out of a group.

---

### `ScenEdit_TransferCargo(params)`

```lua
ScenEdit_TransferCargo({
    from     = string,  -- Source unit GUID
    to       = string,  -- Destination unit GUID
    cargo    = {string, ...}   -- Cargo item GUIDs
}) -> boolean
```

Transfers cargo between units.

---

### `ScenEdit_UnloadCargo(params)`

```lua
ScenEdit_UnloadCargo({
    unitname = string,
    cargo    = {string, ...}
}) -> boolean
```

Unloads cargo from a unit (drops it at the unit's current position).

---

### `ScenEdit_UpdateUnit(params)`

```lua
ScenEdit_UpdateUnit({
    guid       = string,    -- Unit to modify
    mode       = string,    -- 'add_sensor' | 'remove_sensor' | 'add_weapon' | 'remove_weapon'
    dbid       = number,    -- DB ID of sensor/weapon to add
    -- Sensor-specific:
    arc_detect = string,    -- Arc code for detection (see DATA_TYPES.md)
    arc_track  = string,    -- Arc code for tracking
}) -> Unit
```

Adds or removes sensors and weapons from a unit at runtime.

**Example:**
```lua
-- Add a radar to a unit
ScenEdit_UpdateUnit({
    guid = 'unit-guid-here',
    mode = 'add_sensor',
    dbid = 1234,        -- Sensor DB ID
    arc_detect = '360'
})
```

---

### `ScenEdit_UpdateUnitCargo(params)`

```lua
ScenEdit_UpdateUnitCargo({
    unitname = string,
    -- cargo operations
}) -> boolean
```

Updates cargo manifest on a unit.

---

## 6. EMCON

Advanced EMCON (Emission Control) management functions. See also [`ScenEdit_SetEMCON`](#scenedit_setemconscope-nameorid-settingsstring) in the Units section.

---

### `ScenEdit_ClearAllSideUnitsEmconConfigs(sideNameOrId)`

```lua
ScenEdit_ClearAllSideUnitsEmconConfigs(sideNameOrId: string) -> nil
```

Resets EMCON configuration for **all units** on a side to default.

---

### `ScenEdit_ClearUnitEmconConfigs(unitNameOrId)`

```lua
ScenEdit_ClearUnitEmconConfigs(unitNameOrId: string) -> nil
```

Resets EMCON configuration for a specific unit.

---

### `ScenEdit_DuplicateEmconConfigToSide(sourceUnit, targetSide)`

```lua
ScenEdit_DuplicateEmconConfigToSide(
    sourceUnit : string,    -- Source unit GUID
    targetSide : string     -- Target side name
) -> nil
```

Copies a unit's EMCON configuration to all units on a side.

---

### `ScenEdit_DuplicateEmconConfigToUnit(sourceUnit, targetUnit)`

```lua
ScenEdit_DuplicateEmconConfigToUnit(
    sourceUnit : string,
    targetUnit : string
) -> nil
```

Copies EMCON configuration from one unit to another.

---

### `ScenEdit_GetUnitIntermittentEmissionConfig(params)`

```lua
ScenEdit_GetUnitIntermittentEmissionConfig({
    guid = string
}) -> table
```

Returns the intermittent emission configuration for a unit (schedules for cycling sensor emissions on/off).

---

### `ScenEdit_SetSideEmconAlertness(sideNameOrId, alertnessLevel)`

```lua
ScenEdit_SetSideEmconAlertness(
    sideNameOrId  : string,
    alertnessLevel: string  -- 'Relaxed' | 'Moderate' | 'Aggressive'
) -> nil
```

Sets the EMCON alertness posture for an entire side.

---

### `ScenEdit_SetUnitIntermittentEmissionConfig(params)`

```lua
ScenEdit_SetUnitIntermittentEmissionConfig({
    guid     = string,
    -- Emission schedule config:
    enabled  = boolean,
    interval = number,  -- Seconds between emission cycles
    duration = number   -- Seconds to emit per cycle
}) -> nil
```

Configures intermittent (scheduled) radar/sensor emissions for a unit.

---

### `ScenEdit_SwitchUnitIntermittentEmission(params)`

```lua
ScenEdit_SwitchUnitIntermittentEmission({
    guid    = string,
    enabled = boolean
}) -> nil
```

Enables or disables intermittent emission scheduling for a unit.

---

## 7. Miscellaneous / Tools

---

### `ScenEdit_GetKeyValue(key)`

```lua
ScenEdit_GetKeyValue(key: string) -> string
```

Retrieves a value from the **KeyStore** (persistent string storage saved with the scenario). Returns `""` (empty string) if key does not exist — never `nil`.

> See [DATA_TYPES.md — KeyStore](./DATA_TYPES.md#keystore) for full documentation.

**Example:**
```lua
local phaseStr = ScenEdit_GetKeyValue('current_phase')
local phase = tonumber(phaseStr) or 1
```

---

### `ScenEdit_SetKeyValue(key, value)`

```lua
ScenEdit_SetKeyValue(key: string, value: string) -> nil
```

Stores a string value in the KeyStore. Both `key` and `value` must be strings.

**Example:**
```lua
-- Store numeric state
ScenEdit_SetKeyValue('phase', tostring(3))
ScenEdit_SetKeyValue('player_score', tostring(ScenEdit_GetScore('USA')))

-- Store a timestamp
ScenEdit_SetKeyValue('phase2_start', tostring(ScenEdit_CurrentTime()))
```

---

### `ScenEdit_ClearKeyValue(key)`

```lua
ScenEdit_ClearKeyValue(key: string) -> nil
```

Deletes a key from the KeyStore.

---

### `ScenEdit_RunScript(path)`

```lua
ScenEdit_RunScript(path: string) -> nil
```

Executes a Lua script file. The path is relative to the CMO scenario's Lua folder.

**Example:**
```lua
ScenEdit_RunScript('lib/combat_logic.lua')
```

---

### `ScenEdit_SelectedUnits()`

```lua
ScenEdit_SelectedUnits() -> table<Unit>
```

Returns units currently selected in the UI. Useful for player-interactive scripts triggered by Special Actions.

**Example:**
```lua
local sel = ScenEdit_SelectedUnits()
for _, u in ipairs(sel.units) do
    ScenEdit_SetUnit({guid=u.guid, holdfire=true})
end
```

---

### `ScenEdit_SpecialMessage(sideNameOrId, message)`

```lua
ScenEdit_SpecialMessage(
    sideNameOrId : string,
    message      : string
) -> nil
```

Displays a message in the scenario message log for the specified side. Supports basic HTML formatting.

**Example:**
```lua
ScenEdit_SpecialMessage('USA', '<b>ALERT:</b> Enemy fleet detected at 36N 010W')
```

---

### `ScenEdit_MsgBox(text, buttons)`

```lua
ScenEdit_MsgBox(
    text    : string,
    buttons : number    -- 0=OK, 1=OKCancel, 2=YesNoCancel, 3=YesNo
) -> number             -- Button pressed: 1=OK/Yes, 2=Cancel, 3=No
```

Displays a blocking message box to the user. **Use sparingly** — blocks simulation.

**Example:**
```lua
local result = ScenEdit_MsgBox('Launch nuclear strike?', 3)
if result == 1 then
    -- User chose Yes
    ScenEdit_RunScript('nuclear_strike.lua')
end
```

---

### `ScenEdit_InputBox(text)`

```lua
ScenEdit_InputBox(text: string) -> string
```

Prompts the player to enter text. Returns the entered string, or `""` if cancelled.

---

### `ScenEdit_PlaySound(filename)`

```lua
ScenEdit_PlaySound(filename: string) -> nil
```

Plays an audio file. Path is relative to CMO's sound folder.

---

### `ScenEdit_QueryDB(expression)`

```lua
ScenEdit_QueryDB(expression: string) -> table
```

Queries the CMO database for entries matching the expression. Returns a table of DB entries (with `dbid`, `name`, `type` fields).

**Example:**
```lua
local results = ScenEdit_QueryDB('F/A-18')
for _, entry in ipairs(results) do
    print(entry.dbid, entry.name)
end
```

---

### `ScenEdit_ExportInst()`

```lua
ScenEdit_ExportInst() -> string
```

Exports the current scenario instantiation as a string (for checkpoint/save purposes).

---

### `ScenEdit_ImportInst(data)`

```lua
ScenEdit_ImportInst(data: string) -> boolean
```

Imports a scenario instantiation from a previously exported string.

---

### `Tool_Bearing(from, to)`

```lua
Tool_Bearing(
    from : {latitude=number, longitude=number},
    to   : {latitude=number, longitude=number}
) -> number     -- Bearing in degrees (0–360)
```

Calculates the bearing from one point to another.

**Example:**
```lua
local unit = ScenEdit_GetUnit({name='USS Nimitz', side='USA'})
local target = ScenEdit_GetUnit({name='OPFOR HQ', side='OPFOR'})
local bearing = Tool_Bearing(
    {latitude=unit.latitude, longitude=unit.longitude},
    {latitude=target.latitude, longitude=target.longitude}
)
print('Bearing to target: ' .. bearing)
```

---

### `Tool_BuildBlankScenario()`

```lua
Tool_BuildBlankScenario() -> nil
```

Initializes a blank scenario. Used in scenario-building scripts, not event scripts.

---

### `Tool_DumpEvents()`

```lua
Tool_DumpEvents() -> string
```

Returns a text dump of all events, triggers, conditions, and actions in the scenario. Useful for debugging TCA chains.

---

### `Tool_EmulateNoConsole(bool)`

```lua
Tool_EmulateNoConsole(bool: boolean) -> nil
```

When `true`, suppresses error output to the console. Prevents CMO's error dialog from halting execution. **Always set back to `false` after use**, or wrap in pcall.

**Best practice pattern:**
```lua
Tool_EmulateNoConsole(true)
local ok, err = pcall(function()
    -- risky operations here
    local u = ScenEdit_GetUnit({name='MightNotExist', side='USA'})
    if u then u:delete() end
end)
Tool_EmulateNoConsole(false)
if not ok then
    ScenEdit_SpecialMessage('USA', 'Script error: ' .. tostring(err))
end
```

---

### `Tool_LOS(observer, target)`

```lua
Tool_LOS(
    observer : {latitude=number, longitude=number, altitude=number},
    target   : {latitude=number, longitude=number, altitude=number}
) -> boolean
```

Returns `true` if there is a direct line of sight between two points (terrain not blocked).

---

### `Tool_LOS_Points()`

```lua
Tool_LOS_Points() -> table
```

Returns terrain profile data along the current LOS query path. Used for advanced terrain analysis.

---

### `Tool_Range(from, to)`

```lua
Tool_Range(
    from : {latitude=number, longitude=number},
    to   : {latitude=number, longitude=number}
) -> number     -- Range in nautical miles
```

Calculates the great-circle distance in **nautical miles** between two points.

**Example:**
```lua
local ship = ScenEdit_GetUnit({name='USS Nimitz', side='USA'})
local target = ScenEdit_GetReferencePoint({side='USA', name='IP-Alpha'})
local rangeNM = Tool_Range(
    {latitude=ship.latitude,   longitude=ship.longitude},
    {latitude=target.latitude, longitude=target.longitude}
)
print(string.format('Range to IP: %.1f NM', rangeNM))
```

---

### `Tool_ResetMessageLog()`

```lua
Tool_ResetMessageLog() -> nil
```

Clears the scenario message log.

---

### `World_GetCircleFromPoint(params)`

```lua
World_GetCircleFromPoint({
    latitude  = number,
    longitude = number,
    radius    = number,     -- Nautical miles
    pointCount = number     -- Number of polygon vertices (default 16)
}) -> table<{latitude, longitude}>
```

Returns a table of lat/lon points forming a circle polygon around the given center.

**Example:**
```lua
-- Create a 50NM circle for an exclusion zone
local circle = World_GetCircleFromPoint({
    latitude  = 36.0,
    longitude = -10.0,
    radius    = 50,
    pointCount = 16
})
-- Use points to define a zone or display area
```

---

### `World_GetElevation(params)`

```lua
World_GetElevation({
    latitude  = number,
    longitude = number
}) -> number    -- Elevation in meters (negative for ocean depth)
```

Returns the terrain elevation (or ocean depth as negative) at a point.

**Example:**
```lua
local elev = World_GetElevation({latitude=36.5, longitude=-10.0})
if elev < 0 then
    print(string.format('Ocean depth: %.0f m', math.abs(elev)))
else
    print(string.format('Elevation: %.0f m', elev))
end
```

---

### `World_GetLocation(params)`

```lua
World_GetLocation({
    guid = string   -- Unit or reference point GUID
}) -> {latitude=number, longitude=number, altitude=number}
```

Returns the current location of any entity by GUID.

---

### `World_GetPointFromBearing(params)`

```lua
World_GetPointFromBearing({
    latitude  = number,
    longitude = number,
    bearing   = number,     -- Degrees (0–360)
    distance  = number      -- Nautical miles
}) -> {latitude=number, longitude=number}
```

Calculates a point at a specified bearing and distance from an origin.

**Example:**
```lua
-- Find a point 100NM north of a unit
local unit = ScenEdit_GetUnit({name='USS Nimitz', side='USA'})
local point = World_GetPointFromBearing({
    latitude  = unit.latitude,
    longitude = unit.longitude,
    bearing   = 0,      -- North
    distance  = 100
})
print(point.latitude, point.longitude)
```

---

## 8. UI Functions

> **Note:** UI functions are only effective in interactive play (not in headless/server scenarios or automated tests).

---

### `UI_CallAdvancedDialog(params)`

```lua
UI_CallAdvancedDialog({
    title   = string,
    message = string,
    buttons = table     -- Array of button label strings
}) -> number            -- Index of button pressed
```

Displays an advanced dialog box.

---

### `UI_CallAdvancedHTMLDialog(params)`

```lua
UI_CallAdvancedHTMLDialog({
    title   = string,
    html    = string    -- HTML content to display
}) -> nil
```

Displays an HTML-formatted dialog (supports richer formatting than `ScenEdit_MsgBox`).

---

### `UI_OpenNewDatabaseWindow()`

```lua
UI_OpenNewDatabaseWindow() -> nil
```

Opens the CMO database browser window.

---

### `UI_SelectThisUnit(unitNameOrId)`

```lua
UI_SelectThisUnit(unitNameOrId: string) -> nil
```

Selects and centers the camera on the specified unit in the UI.

---

### `UI_SelectUnitsPrompt_FromSides(params)`

```lua
UI_SelectUnitsPrompt_FromSides({
    sides   = {string, ...},    -- Side names
    message = string
}) -> table<Unit>
```

Prompts the player to select units from the specified sides.

---

### `UI_SelectUnitsPrompt_OwnSide(params)`

```lua
UI_SelectUnitsPrompt_OwnSide({
    message = string
}) -> table<Unit>
```

Prompts the player to select units from the player's own side.

---

### `UI_SetCameraView(params)`

```lua
UI_SetCameraView({
    latitude  = number,
    longitude = number,
    zoom      = number      -- Zoom level
}) -> nil
```

Moves and zooms the map camera to the specified location.

---

### `Tool_UIwindow(params)`

```lua
Tool_UIwindow({
    -- Window configuration
}) -> nil
```

Controls CMO UI window state and positioning.

---

## 9. Sides & Others

---

### `ScenEdit_AddSide(params)`

```lua
ScenEdit_AddSide({
    name = string   -- Side name (required)
}) -> Side
```

Adds a new side to the scenario.

---

### `ScenEdit_RemoveSide(params)`

```lua
ScenEdit_RemoveSide({
    name = string   -- or guid
}) -> boolean
```

Removes a side (and all its units/missions).

---

### `ScenEdit_GetSideIsHuman(sideNameOrId)`

```lua
ScenEdit_GetSideIsHuman(sideNameOrId: string) -> boolean
```

Returns `true` if the side is human-controlled (not AI).

---

### `ScenEdit_GetSideOptions(params)`

```lua
ScenEdit_GetSideOptions({
    side = string
}) -> table
```

Returns the side options table (awareness, proficiency, etc.).

---

### `ScenEdit_GetSidePosture(sideA, sideB)`

```lua
ScenEdit_GetSidePosture(
    sideA : string,
    sideB : string
) -> string     -- 'Hostile'|'Neutral'|'Friendly'|'Unfriendly'
```

Returns sideA's posture toward sideB.

**Example:**
```lua
local posture = ScenEdit_GetSidePosture('USA', 'Russia')
if posture == 'Hostile' then
    ScenEdit_SpecialMessage('USA', 'Russia is hostile!')
end
```

---

### `ScenEdit_SetSideOptions(params)`

```lua
ScenEdit_SetSideOptions({
    side        = string,
    awareness   = string,   -- 'Blind'|'Blissful'|'Withit'|'Omniscient'
    proficiency = string    -- 'Novice'|'Cadet'|'Regular'|'Veteran'|'Ace'
}) -> nil
```

Sets overall side options.

---

### `ScenEdit_SetSidePosture(sideA, sideB, postureCode)`

```lua
ScenEdit_SetSidePosture(
    sideA       : string,
    sideB       : string,
    postureCode : string    -- 'H'|'N'|'F'|'U' (see ENUMS.md)
) -> nil
```

Sets sideA's posture toward sideB.

**Example:**
```lua
-- Make Russia hostile to USA
ScenEdit_SetSidePosture('Russia', 'USA', 'H')
ScenEdit_SetSidePosture('USA', 'Russia', 'H')
```

---

### `ScenEdit_SetUnitSide(params)`

```lua
ScenEdit_SetUnitSide({
    side    = string,   -- Current side
    name    = string,   -- or guid
    newside = string    -- New side name
}) -> Unit
```

Transfers a unit to a different side.

---

### `ScenEdit_PlayerSide()`

```lua
ScenEdit_PlayerSide() -> string
```

Returns the name of the human player's side. Returns `""` if no human player.

---

### `ScenEdit_HostUnitToParent(params)`

```lua
ScenEdit_HostUnitToParent({
    unit   = string,    -- Unit GUID or name
    parent = string     -- Parent unit GUID or name (carrier, base, etc.)
}) -> boolean
```

Assigns a unit to a parent (e.g., base an aircraft on a carrier or airbase).

---

### `ScenEdit_WeaponAllocation(params)`

```lua
ScenEdit_WeaponAllocation({
    unit   = string,
    target = string,
    weapon = number,    -- Weapon DB ID
    qty    = number
}) -> boolean
```

Manually allocates weapons from a unit against a specific target.

---

### `VP_SetTimeCompression(factor)`

```lua
VP_SetTimeCompression(factor: number) -> nil
```

Sets the simulation time compression ratio (1=real-time, 2=2x, 15=15x, etc.).

---

### `ScenEdit_AddExplosion(params)`

```lua
ScenEdit_AddExplosion({
    warheadid = number,     -- Warhead DB ID
    lat       = number,
    lon       = number,
    altitude  = number      -- Meters
}) -> nil
```

Detonates a warhead at a specified location (produces blast effects and damage).

---

### `ScenEdit_AddMinefield(params)`

```lua
ScenEdit_AddMinefield({
    side   = string,
    dbid   = number,        -- Mine type DB ID
    number = number,        -- Number of mines
    delay  = number,        -- Arming delay in seconds
    area   = {              -- Deployment area defined by reference points
        {lat=number, lon=number},
        ...
    }
}) -> boolean
```

Deploys a minefield in the specified area.

---

### `ScenEdit_AddCustomLoss(params)`

```lua
ScenEdit_AddCustomLoss({
    side   = string,
    dbid   = number,
    amount = number
}) -> nil
```

Records a custom loss entry in the side's loss/expenditure log without actually destroying a unit.

---

## 10. Pro Edition Only

These functions require **Command: Modern Operations Professional Edition** (CMO Pro). They enable headless server operation, simulation control, and advanced scenario management.

---

### `VP_PauseSimulation()`

```lua
VP_PauseSimulation() -> nil
```

Pauses the simulation clock. Used in server-controlled scenarios.

---

### `VP_RunSimulation()`

```lua
VP_RunSimulation() -> nil
```

Resumes the simulation after a pause.

---

### `VP_RunForTimeAndHalt(seconds)`

```lua
VP_RunForTimeAndHalt(seconds: number) -> nil
```

Runs the simulation for a specified number of seconds, then pauses.

---

### `VP_RunToTimeAndHalt(unixTimestamp)`

```lua
VP_RunToTimeAndHalt(unixTimestamp: number) -> nil
```

Runs the simulation until a specific scenario time, then pauses.

---

### `ScenEdit_GetSensorData(params)`

```lua
ScenEdit_GetSensorData({
    unit = string   -- Unit GUID
}) -> table         -- Detailed sensor state table
```

Returns detailed real-time sensor data for a unit (detection ranges, current contacts, etc.).

---

### `ScenEdit_ExportScenarioToXML(filepath)`

```lua
ScenEdit_ExportScenarioToXML(filepath: string) -> boolean
```

Exports the full scenario to an XML file at the specified path.

---

### `ScenEdit_ImportScenarioFromXML(filepath)`

```lua
ScenEdit_ImportScenarioFromXML(filepath: string) -> boolean
```

Imports a scenario from an XML file.

---

### `ScenEdit_SetSimulationFidelity(fidelityLevel)`

```lua
ScenEdit_SetSimulationFidelity(fidelityLevel: string) -> nil
-- fidelityLevel: 'Low' | 'Medium' | 'High'
```

Sets the simulation fidelity for performance tuning in large scenarios.

---

### `Tool_SatelliteCoveragePrediction(params)`

```lua
Tool_SatelliteCoveragePrediction({
    satellite = string,     -- Satellite unit GUID
    startTime = number,     -- Unix timestamp
    endTime   = number,
    area      = table       -- Area polygon
}) -> table                 -- Coverage windows {startTime, endTime, coverage}
```

Predicts satellite coverage windows over an area for a given time period.

---

*End of FUNCTIONS.md*

> **See also:** [WRAPPERS.md](./WRAPPERS.md) | [ENUMS.md](./ENUMS.md) | [DATA_TYPES.md](./DATA_TYPES.md)
