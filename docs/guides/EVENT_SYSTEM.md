# The Event System: Triggers, Conditions, Actions

Events are the backbone of CMO scenario scripting. Everything that "happens" in a scenario — unit spawns, score changes, messages, mission activations — is wired through the event system.

> **Cross-references:** [FUNCTIONS.md](../api-reference/FUNCTIONS.md) | [ENUMS.md](../api-reference/ENUMS.md) | [WRAPPERS.md](../api-reference/WRAPPERS.md) | [SCENARIO_SETUP.md](./SCENARIO_SETUP.md)

---

## The TCA Pattern

Every event follows the **Trigger → Condition → Action** model:

```
Trigger   Something happens (time passes, unit detected, unit destroyed...)
    ↓
Condition Optional gate (is side A hostile to B? has scenario started?)
    ↓
Action    Do something (run Lua, show message, change score, end scenario...)
```

An event can have **multiple triggers** (any one firing activates it), **multiple conditions** (all must pass), and **multiple actions** (all execute when it fires).

An event with no conditions always fires when its trigger activates. An event with no triggers never fires on its own — it must be called with `ScenEdit_ExecuteEventAction()`.

---

## Creating Events Programmatically

### Create the Event Container

```lua
-- mode='add' creates a new event
local ev = ScenEdit_SetEvent('MyEvent', {
    mode         = 'add',
    IsRepeatable = true,    -- can fire multiple times
    IsActive     = true,    -- starts active
    IsShown      = true,    -- shows in event log
    Probability  = 100      -- 100% chance of firing (0-100)
})
print('Event GUID: ' .. ev.guid)
```

### Create a Trigger

```lua
-- Time trigger: fires at a specific scenario timestamp
ScenEdit_SetTrigger({
    name = 'T_GameStart',
    type = 'Time',
    time = ScenEdit_CurrentTime()  -- fires right now (use a specific timestamp for real use)
})

-- ScenLoaded trigger: fires every time the scenario loads/reloads
ScenEdit_SetTrigger({
    name = 'T_ScenLoaded',
    type = 'ScenLoaded'
})
```

### Create an Action

```lua
-- LuaScript action: runs Lua code when the event fires
ScenEdit_SetAction({
    name       = 'A_RunInit',
    type       = 'LuaScript',
    scriptText = "ScenEdit_RunScript('/Development/MyScen/LuaInit.lua')"
})
```

### Link Them to the Event

```lua
-- Attach trigger to event
ScenEdit_SetEventTrigger('MyEvent', 'T_ScenLoaded', {mode='add'})

-- Attach action to event
ScenEdit_SetEventAction('MyEvent', 'A_RunInit', {mode='add'})
```

> **Note:** The `{mode='add'}` parameter in `SetEventTrigger` and `SetEventAction` is required to attach a new trigger/action. Without it, the call modifies an existing attachment.

---

## Trigger Types

### `ScenLoaded` — Scenario Load

Fires every time the scenario is opened or resumed from a save. Use this for initialization.

```lua
ScenEdit_SetTrigger({
    name = 'T_OnLoad',
    type = 'ScenLoaded'
})
```

No additional parameters needed.

---

### `Time` — Specific Time

Fires once when the scenario clock reaches a specific timestamp.

```lua
-- Fire at epoch time 1749430800 (some specific date/time in UTC)
ScenEdit_SetTrigger({
    name = 'T_HourTwo',
    type = 'Time',
    time = 1749430800
})

-- Fire 2 hours after current scenario time
ScenEdit_SetTrigger({
    name = 'T_TwoHoursIn',
    type = 'Time',
    time = ScenEdit_CurrentTime() + (2 * 3600)
})
```

---

### `RegularTime` — Repeating Timer

Fires repeatedly at a fixed interval (in seconds). Use for polling and periodic checks.

```lua
-- Fire every 60 seconds
ScenEdit_SetTrigger({
    name        = 'T_EveryMinute',
    type        = 'RegularTime',
    interval    = 60
})
```

> **PERFORMANCE WARNING:** At 1x time compression, a 60-second interval fires every real minute. At 60x compression, it fires every real second. Avoid heavy computation inside `RegularTime` event scripts — cache unit references, use early-exit guards, and keep scripts tight.

---

### `RandomTime` — Random Interval

Fires at a randomly chosen time within a range.

```lua
ScenEdit_SetTrigger({
    name    = 'T_RandomReinforcement',
    type    = 'RandomTime',
    TStart  = ScenEdit_CurrentTime() + 3600,   -- not before 1 hour in
    TEnd    = ScenEdit_CurrentTime() + 10800    -- not after 3 hours in
})
```

---

### `UnitEntersArea` — Zone Entry

Fires when a unit matching the filter crosses into a defined area.

```lua
-- Define the area reference points first, then:
ScenEdit_SetTrigger({
    name         = 'T_EnemyEntersZone',
    type         = 'UnitEntersArea',
    AreaName     = {'Zone-NW', 'Zone-NE', 'Zone-SE', 'Zone-SW'},  -- reference point names
    TargetFilter = {
        TargetSide = 'Red',      -- which side owns the unit
        TargetType = '2'         -- UnitType: 1=Aircraft, 2=Ship, 3=Sub, 4=Facility
    }
})
```

Inside the fired event's action script, `ScenEdit_UnitX()` returns the unit that entered the area.

---

### `UnitRemainsInArea` — Zone Dwell

Fires when a unit has been inside an area for a minimum duration.

```lua
ScenEdit_SetTrigger({
    name         = 'T_EnemyDwelling',
    type         = 'UnitRemainsInArea',
    AreaName     = {'Zone-NW', 'Zone-NE', 'Zone-SE', 'Zone-SW'},
    Duration     = 600,   -- seconds (unit must be in area this long)
    TargetFilter = {TargetSide='Red'}
})
```

---

### `UnitDestroyed` — Unit Death

Fires when a unit matching the filter is destroyed.

```lua
ScenEdit_SetTrigger({
    name         = 'T_ShipSunk',
    type         = 'UnitDestroyed',
    TargetFilter = {
        TargetSide    = 'Blue',
        TargetType    = '2',    -- Ship
        SPECIFICUNIT  = 'guid-of-specific-unit'  -- optional: only this unit
    }
})
```

`ScenEdit_UnitX()` in the action script is the destroyed unit.

---

### `UnitDetected` — Detection Event

Fires when a unit from one side detects a unit from another side.

```lua
ScenEdit_SetTrigger({
    name         = 'T_EnemySub_Detected',
    type         = 'UnitDetected',
    TargetFilter = {
        TargetSide    = 'Red',
        TargetType    = '3'  -- Submarine
    }
})
```

Inside the action:
- `ScenEdit_UnitX()` — the unit being detected (the contact)
- `ScenEdit_UnitY()` — the unit doing the detecting
- `ScenEdit_UnitC()` — the contact object (has `.actualunitid`, `.classificationlevel`, etc.)

---

### `UnitDamaged` — Damage Event

Fires when a unit takes damage.

```lua
ScenEdit_SetTrigger({
    name         = 'T_FriendlyDamaged',
    type         = 'UnitDamaged',
    TargetFilter = {TargetSide='Blue'}
})
```

In the action: `ScenEdit_UnitX()` is the damaged unit. `ScenEdit_UnitY()` is the unit that inflicted the damage (if applicable).

---

### `UnitBaseStatus` — Base/RTB Events

Fires when a unit changes base status (launches, lands, RTBs).

```lua
ScenEdit_SetTrigger({
    name         = 'T_AircraftLanded',
    type         = 'UnitBaseStatus',
    BaseStatus   = 'AtBase',    -- 'AtBase', 'Airborne', 'OnPatrol'
    TargetFilter = {TargetSide='Blue', TargetType='1'}  -- Aircraft
})
```

---

### `Points` — Score Threshold

Fires when a side's score reaches or exceeds a threshold.

```lua
ScenEdit_SetTrigger({
    name           = 'T_Score500',
    type           = 'Points',
    TargetSide     = 'Blue',
    PointValue     = 500
})
```

---

### `UnitEmissions` — Emission Detection

Fires when a specific type of emission is detected from a unit.

```lua
ScenEdit_SetTrigger({
    name         = 'T_RadarEmission',
    type         = 'UnitEmissions',
    EmissionType = 'Radar',
    TargetFilter = {TargetSide='Red'}
})
```

---

### `UnitCargoMoved` — Cargo Transport

Fires when cargo is picked up or dropped off.

```lua
ScenEdit_SetTrigger({
    name       = 'T_CargoDelivered',
    type       = 'UnitCargoMoved',
    CargoEvent = 'Delivered'   -- 'PickedUp' or 'Delivered'
})
```

---

### `ScenEnded` — Scenario End

Fires when the scenario ends (win, loss, or timeout). Use for cleanup or final scoring.

```lua
ScenEdit_SetTrigger({
    name = 'T_GameOver',
    type = 'ScenEnded'
})
```

---

## The TargetFilter Table

`TargetFilter` is the selector used by unit-based triggers. All fields are optional — omit fields to match everything.

```lua
TargetFilter = {
    TargetSide     = 'Red',       -- Side name
    TargetType     = '2',         -- UnitType code (as string): 1=Air, 2=Ship, 3=Sub, 4=Facility, 5=Satellite
    TargetSubType  = '5023',      -- Unit subtype code (from ENUMS.md)
    SpecificUnitClass = 1234,     -- DB ID (number) — match only this unit class
    SPECIFICUNIT   = 'unit-guid'  -- Match only this specific unit by GUID
}
```

> **UnitType codes** (use as strings): `'1'`=Aircraft, `'2'`=Ship, `'3'`=Submarine, `'4'`=Facility, `'5'`=Satellite. These are passed as strings even though they look like numbers.

---

## Condition Types

Conditions gate whether the event's actions run. All attached conditions must return true.

### `LuaScript` — Custom Logic

The most flexible condition. Your script must return `true` or `false`.

```lua
ScenEdit_SetCondition({
    name       = 'C_ScenHasStarted',
    type       = 'LuaScript',
    scriptText = 'return ScenEdit_GetScenHasStarted()'
})

-- More complex condition
ScenEdit_SetCondition({
    name       = 'C_ShipAlive',
    type       = 'LuaScript',
    scriptText = [[
        local u = ScenEdit_GetUnit({name='USS Nimitz', side='USA'})
        return u ~= nil and not u.IsDestroyed
    ]]
})
```

> **CRITICAL:** LuaScript conditions must `return true` or `return false`. A script that returns nothing evaluates as false.

---

### `SidePosture` — Posture Check

Fires only when side A has a specific posture toward side B.

```lua
ScenEdit_SetCondition({
    name    = 'C_HostileToRed',
    type    = 'SidePosture',
    sideA   = 'Blue',
    sideB   = 'Red',
    Posture = 'H'   -- 'H'=Hostile, 'F'=Friendly, 'U'=Unfriendly, 'N'=Neutral
})
```

---

### `ScenHasStarted` — Clock Running

True only after the scenario clock has started (not during pre-start editor mode).

```lua
ScenEdit_SetCondition({
    name = 'C_Started',
    type = 'ScenHasStarted'
})
```

---

## Action Types

### `LuaScript` — Run Code

The most powerful action. Runs arbitrary Lua code.

```lua
ScenEdit_SetAction({
    name       = 'A_SpawnReinforcements',
    type       = 'LuaScript',
    scriptText = [[
        ScenEdit_AddUnit({
            side      = 'Red',
            type      = 'Ship',
            name      = 'Reinforcement Alpha',
            dbid      = 1150,
            latitude  = 38.0,
            longitude = 15.0
        })
        ScenEdit_SpecialMessage('Red', 'Reinforcements have arrived.')
    ]]
})
```

> **CRITICAL — Multi-line scripts:** When setting `scriptText` to a multi-line string via Lua's `[[...]]` syntax, the newlines are `\n`. However, some CMO builds require `\r\n` (Windows line endings) for multi-line event action scripts to parse correctly. If a multi-line script misbehaves, switch to explicit `\r\n`:

```lua
ScenEdit_SetAction({
    name       = 'A_MultiLine',
    type       = 'LuaScript',
    scriptText = "local u = ScenEdit_UnitX()\r\nif not u then return end\r\nScenEdit_SpecialMessage('Blue', u.name)"
})
```

---

### `Message` — Show Text

Displays a message to a side's player. Simpler than the LuaScript equivalent.

```lua
ScenEdit_SetAction({
    name    = 'A_WelcomeMessage',
    type    = 'Message',
    message = 'Welcome to the scenario.',
    side    = 'Blue'
})
```

---

### `Points` — Change Score

Adds (or subtracts) points from a side.

```lua
ScenEdit_SetAction({
    name   = 'A_AwardPoints',
    type   = 'Points',
    side   = 'Blue',
    points = 100
})
```

---

### `ChangeMissionStatus` — Activate/Deactivate Mission

Activates or deactivates a mission.

```lua
ScenEdit_SetAction({
    name          = 'A_ActivateStrike',
    type          = 'ChangeMissionStatus',
    mission       = 'Alpha Strike',
    side          = 'Blue',
    missionStatus = true   -- true=activate, false=deactivate
})
```

---

### `EndScenario` — End the Game

Ends the scenario immediately.

```lua
ScenEdit_SetAction({
    name = 'A_GameOver',
    type = 'EndScenario'
})
```

---

### `TeleportInArea` — Move a Unit

Teleports units matching a filter to a random position inside an area.

```lua
ScenEdit_SetAction({
    name         = 'A_SpawnInZone',
    type         = 'TeleportInArea',
    AreaName     = {'Spawn-1', 'Spawn-2', 'Spawn-3', 'Spawn-4'},
    TargetFilter = {TargetSide='Red', SPECIFICUNIT='unit-guid'}
})
```

---

## Linking TCAs: Full Example

Here's a complete event that fires when an enemy ship enters a patrol zone and sends a message:

```lua
-- 1. Create event
ScenEdit_SetEvent('Enemy In Zone', {
    mode         = 'add',
    IsRepeatable = true,
    IsActive     = true
})

-- 2. Define patrol area (if not already done)
ScenEdit_AddReferencePoint({
    side = 'Blue',
    area = {
        {name='Watch-NW', lat=40.0, lon=-20.0},
        {name='Watch-NE', lat=40.0, lon=-15.0},
        {name='Watch-SE', lat=37.0, lon=-15.0},
        {name='Watch-SW', lat=37.0, lon=-20.0},
    }
})

-- 3. Create trigger
ScenEdit_SetTrigger({
    name         = 'T_EnemyInWatch',
    type         = 'UnitEntersArea',
    AreaName     = {'Watch-NW', 'Watch-NE', 'Watch-SE', 'Watch-SW'},
    TargetFilter = {TargetSide='Red', TargetType='2'}  -- Red ships
})

-- 4. Create action (use \r\n for multi-line safety)
ScenEdit_SetAction({
    name       = 'A_AlertEnemyInZone',
    type       = 'LuaScript',
    scriptText = "local u = ScenEdit_UnitX()\r\n" ..
                 "if not u then return end\r\n" ..
                 "ScenEdit_SpecialMessage('Blue', 'ALERT: Enemy ship ' .. u.name .. ' entered Watch Zone!')\r\n" ..
                 "ScenEdit_SetScore('Blue', ScenEdit_GetScore('Blue') - 10, 'Enemy breached perimeter')"
})

-- 5. Link trigger and action to event
ScenEdit_SetEventTrigger('Enemy In Zone', 'T_EnemyInWatch', {mode='add'})
ScenEdit_SetEventAction('Enemy In Zone',  'A_AlertEnemyInZone', {mode='add'})

print('Event wired successfully.')
```

---

## Inspecting Events with ScenEdit_GetEvent

Retrieve an event and inspect its structure:

```lua
local ev = ScenEdit_GetEvent('Enemy In Zone')
if ev then
    print('GUID:        ' .. ev.guid)
    print('Active:      ' .. tostring(ev.isActive))
    print('Repeatable:  ' .. tostring(ev.isRepeatable))
    print('Probability: ' .. ev.probability)
    print('Triggers:    ' .. #ev.triggers)
    print('Conditions:  ' .. #ev.conditions)
    print('Actions:     ' .. #ev.actions)
end
```

The `level` parameter on `ScenEdit_GetEvent(name, level)` controls detail depth (0–4). Higher levels return more nested data.

---

## Special Variables in Event Scripts

When a Lua action script runs inside an event, these global variables are available:

| Variable | Function | Description |
|----------|----------|-------------|
| `ScenEdit_UnitX()` | Function | The unit that triggered the event (unit-based triggers) |
| `ScenEdit_UnitY()` | Function | The secondary unit (e.g., the shooter in a UnitDamaged event) |
| `ScenEdit_UnitC()` | Function | The contact associated with the event (UnitDetected triggers) |
| `ScenEdit_EventX()` | Function | The current event itself |
| `_errfnc_` | string | Name of the function that caused an error (set by CMO on script error) |
| `_errmsg_` | string | The error message string (set by CMO on script error) |

```lua
-- Example: in a UnitDetected action
local detected  = ScenEdit_UnitX()   -- the unit that was detected
local detector  = ScenEdit_UnitY()   -- the unit that detected it
local contact   = ScenEdit_UnitC()   -- contact object from the detector's side

if detected and detector then
    ScenEdit_SpecialMessage(
        detector.side,
        detector.name .. ' detected ' .. detected.type .. ' at range ' ..
        math.floor(detector:rangetotarget(contact.guid)) .. ' NM'
    )
end
```

---

## Error Handling in Event Scripts

**Event scripts fail silently.** If a Lua error occurs in an action script, execution stops at that line with no error message visible to you or the player. This is the most common source of invisible bugs.

### Pattern 1: pcall Wrapping

```lua
local ok, err = pcall(function()
    local u = ScenEdit_UnitX()
    if not u then return end
    -- ... your logic ...
end)

if not ok then
    -- Log to KeyStore so you can check it later
    ScenEdit_SetKeyValue('last_event_error', tostring(err))
    -- Or send to a debug side if one exists
    -- ScenEdit_SpecialMessage('Debug', 'Event error: ' .. tostring(err))
end
```

### Pattern 2: Nil Guards on Every Return

```lua
local u = ScenEdit_UnitX()
if not u then return end  -- bail cleanly if no triggering unit

local target = ScenEdit_GetUnit({name='Target Alpha', side='Red'})
if not target then return end

-- Now safe to use both
```

### Pattern 3: Tool_EmulateNoConsole

When testing event script code in the console, call this first:

```lua
Tool_EmulateNoConsole(true)
-- ... paste your event action script here to test it ...
Tool_EmulateNoConsole(false)
```

This makes the console behave like an event script context — suppressing interactive error popups so you see the same silent behavior events produce. Essential for testing error handling logic.

### Checking _errmsg_

After an event fires, if you suspect an error occurred:

```lua
-- Run this in the console to check the last error
print(_errmsg_)
print(_errfnc_)
```

---

## Self-Deactivating Events

A common pattern: an event that fires once and disables itself.

```lua
-- In the event's action script:
local ev = ScenEdit_EventX()
if ev then
    ScenEdit_SetEvent(ev.guid, {isActive=false, isRepeatable=false})
end
-- ... rest of action ...
```

Or set `IsRepeatable=false` when creating the event — it will deactivate automatically after firing once.

---

## Executing Events Programmatically

You can fire an event's actions immediately from code, bypassing triggers and conditions:

```lua
-- Force fire all actions of this event
ScenEdit_ExecuteEventAction('Enemy In Zone')
```

This is useful for testing and for manual event chains.
