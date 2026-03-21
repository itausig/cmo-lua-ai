# CMO Lua Best Practices

Hard-won patterns and anti-patterns from real CMO scenario development. Follow these to write scripts that are reliable, debuggable, and maintainable.

> **Cross-references:** [FUNCTIONS.md](../api-reference/FUNCTIONS.md) | [WRAPPERS.md](../api-reference/WRAPPERS.md) | [DATA_TYPES.md](../api-reference/DATA_TYPES.md) | [EVENT_SYSTEM.md](./EVENT_SYSTEM.md)

---

## 1. Always Use GUIDs Over Names

Unit names can change (a player or script can rename a unit), can be duplicated across sides, and are a frequent source of "unit not found" errors. GUIDs are permanent and unique.

```lua
-- BAD: name can change, or the wrong unit is returned if names overlap
local u = ScenEdit_GetUnit({name='F-15C Eagle'})

-- GOOD: GUID never changes
local u = ScenEdit_GetUnit({guid='a1a52edf-3541-4b55-bea4-58d4e1ab11dc'})
```

**Store GUIDs in the KeyStore immediately after creating units:**

```lua
local ship = ScenEdit_AddUnit({
    side = 'Blue', type = 'Ship', name = 'USS Nimitz',
    dbid = 316, latitude = 36.5, longitude = -10.5
})
-- Store GUID persistently so you can retrieve it from any event script
ScenEdit_SetKeyValue('NIMITZ_GUID', ship.guid)

-- Later, in any event script:
local guid = ScenEdit_GetKeyValue('NIMITZ_GUID')
local carrier = ScenEdit_GetUnit({guid=guid})
```

**The only acceptable use of names** is in initial setup scripts that run before the player can interact with the scenario (i.e., in GameSetup). Even there, prefer GUIDs where possible.

---

## 2. Error Handling

### pcall Wrapping

Event scripts fail silently. Wrapping in `pcall` lets you capture and store errors:

```lua
local ok, err = pcall(function()
    local u = ScenEdit_UnitX()
    if not u then return end
    -- ... your logic ...
    ScenEdit_SetScore('Blue', ScenEdit_GetScore('Blue') + 50, 'Target destroyed')
end)

if not ok then
    ScenEdit_SetKeyValue('last_error', tostring(err))
    -- During development: surface errors visibly
    -- ScenEdit_SpecialMessage('Blue', 'Script error: ' .. tostring(err))
end
```

### Tool_EmulateNoConsole

When testing event script logic in the console, suppress the interactive error dialog so behavior matches how it runs in events:

```lua
Tool_EmulateNoConsole(true)

-- Paste your event script here to test silent failure behavior
local u = ScenEdit_UnitX()  -- returns nil in console — tests your nil guard
if not u then
    print('No triggering unit (expected in console context)')
end

Tool_EmulateNoConsole(false)
```

### Nil-Guard Every Return Value

Every `ScenEdit_GetUnit`, `ScenEdit_GetMission`, `VP_GetUnit` call can return `nil`. Guard every one:

```lua
local u = ScenEdit_GetUnit({guid=myGuid})
if not u then
    ScenEdit_SetKeyValue('warn_missing_unit', myGuid)
    return  -- clean exit, no crash
end

local m = ScenEdit_GetMission('Blue', 'Alpha Strike')
if not m then return end

-- Now safe to use u and m
```

### Reading _errmsg_

After a script runs (or fails to run), CMO sets `_errmsg_` and `_errfnc_`:

```lua
-- Run in console after a suspected event script failure:
print('Last error: ' .. tostring(_errmsg_))
print('In function: ' .. tostring(_errfnc_))
```

---

## 3. Performance

### Avoid Heavy Loops in RegularTime Triggers

`RegularTime` triggers at short intervals (e.g., 60 seconds) run frequently, especially during high time compression. Keep scripts fast.

```lua
-- BAD: iterates ALL units on every fire
ScenEdit_SetAction({
    name       = 'A_BadPoll',
    type       = 'LuaScript',
    scriptText = [[
        local side = VP_GetSide({Side='Blue'})
        for _, u in ipairs(side.units) do
            -- expensive per-unit logic every 60 seconds
        end
    ]]
})

-- BETTER: use early exits, track state, only process what changed
ScenEdit_SetAction({
    name       = 'A_GoodPoll',
    type       = 'LuaScript',
    scriptText = [[
        -- Only run if phase 2 is active
        if ScenEdit_GetKeyValue('phase') ~= '2' then return end

        local phase2Done = ScenEdit_GetKeyValue('phase2_complete')
        if phase2Done == 'true' then return end  -- already done, skip

        -- Only check once the expensive condition
        MYSCEN_CheckPhase2Victory()
    ]]
})
```

**Guidelines:**
- Use `return` early at the top of scripts to skip when the check is irrelevant
- Cache the results of expensive lookups in the KeyStore rather than recomputing them
- Use `UnitDestroyed` or `UnitEntersArea` triggers instead of polling for state changes when possible
- Prefer event-driven logic over timer polling whenever the triggering condition maps to a CMO trigger type

### Cache Unit References by GUID

If you need to process the same units repeatedly, store their GUIDs in the KeyStore rather than searching by name each time:

```lua
-- In GameSetup: build a cache
local side = VP_GetSide({Side='Blue'})
local ships = side:unitsBy('Ship')
local guidList = {}
for _, u in ipairs(ships) do
    table.insert(guidList, u.guid)
end
-- Store as CSV in KeyStore (see KeyStore section below)
ScenEdit_SetKeyValue('BLUE_SHIP_GUIDS', table.concat(guidList, ','))
```

---

## 4. KeyStore for Persistent State

The KeyStore is CMO's per-scenario persistent key/value store. Values survive save/load cycles. It is your only reliable state storage between event script firings.

```lua
-- Write
ScenEdit_SetKeyValue('key', 'value')    -- value MUST be a string

-- Read
local val = ScenEdit_GetKeyValue('key') -- always returns a string or nil
```

### Always namespace your keys

```lua
-- BAD: 'count' is likely to collide with other scripts
ScenEdit_SetKeyValue('count', '5')

-- GOOD: prefix with scenario/system name
ScenEdit_SetKeyValue('CSAR_downed_count', '5')
ScenEdit_SetKeyValue('MYSCEN_phase', '2')
ScenEdit_SetKeyValue('AI_last_attack_time', tostring(ScenEdit_CurrentTime()))
```

### Always tostring() numbers

The KeyStore only accepts strings. `tostring()` is mandatory for numeric values:

```lua
-- BAD: this will error or store incorrectly
ScenEdit_SetKeyValue('score_bonus', 100)

-- GOOD:
ScenEdit_SetKeyValue('score_bonus', tostring(100))

-- Reading back:
local bonus = tonumber(ScenEdit_GetKeyValue('score_bonus')) or 0
```

### Storing tables as CSV or JSON

The KeyStore doesn't support tables natively. Use comma-separated strings for simple lists:

```lua
-- Store a list of GUIDs
local guids = {'guid1', 'guid2', 'guid3'}
ScenEdit_SetKeyValue('DESTROYED_TARGETS', table.concat(guids, ','))

-- Read back
local stored = ScenEdit_GetKeyValue('DESTROYED_TARGETS')
if stored and stored ~= '' then
    for guid in stored:gmatch('[^,]+') do
        print('Destroyed: ' .. guid)
    end
end
```

---

## 5. Discovering Properties with .fields

Every CMO wrapper object has a `.fields` property that lists all available field names and their current values. Use this in the console when you're not sure what properties exist:

```lua
local u = ScenEdit_GetUnit({name='USS Nimitz', side='Blue'})
for field, value in pairs(u.fields) do
    print(field .. ' = ' .. tostring(value))
end
```

This is faster than reading the documentation when you just need to know "what can I access on this object?" The `.fields` table is a snapshot — it's read-only.

---

## 6. EMCON String Format

EMCON settings use a semicolon-separated `Key=Value` string:

```lua
-- Single setting
ScenEdit_SetEMCON('Unit', 'USS Nimitz', 'Radar=Active')

-- Multiple settings
ScenEdit_SetEMCON('Unit', 'USS Nimitz', 'Radar=Active;Sonar=Passive;OECM=Active')

-- Reset to inherit from parent (side or mission)
ScenEdit_SetEMCON('Unit', 'USS Nimitz', 'Radar=Inherit;Sonar=Inherit')
```

**Valid categories:** `Radar`, `Sonar`, `OECM` (Offensive ECM/Jamming)  
**Valid values:** `Active`, `Passive`, `Inherit`

**Scope levels:**
- `'Unit'` → specific unit (by name or GUID)
- `'Mission'` → all units in the named mission
- `'Side'` → all units on the side

Units inherit EMCON from Mission, which inherits from Side, unless explicitly overridden. Use `Inherit` to reset a unit to follow its parent.

---

## 7. Doctrine Chaining

CMO applies doctrine in a hierarchy: **Side → Mission → Unit**. Settings at a lower level override the level above, but unset fields fall through to the parent.

**Set doctrine from broad to narrow:**

```lua
-- 1. Set side-level doctrine first (the default for everything)
ScenEdit_SetDoctrine({side='Blue'}, {
    weapon_control_status_air     = 1,  -- Tight vs air
    weapon_control_status_surface = 0,  -- Free vs surface
    engage_opportunity_targets    = 'no',
    auto_evade                    = 'yes'
})

-- 2. Override for a specific mission (e.g., more aggressive CAP)
ScenEdit_SetDoctrine({mission='CAP North'}, {
    weapon_control_status_air = 0,          -- Free vs air for this mission
    engage_opportunity_targets = 'yes'
})

-- 3. Override for a specific unit (e.g., a jammer that should never fire)
ScenEdit_SetDoctrine({name='EA-18G Growler'}, {
    weapon_control_status_air     = 2,  -- Hold
    weapon_control_status_surface = 2,
    weapon_control_status_subsurface = 2,
    weapon_control_status_land    = 2
})
```

When reading doctrine, `ScenEdit_GetDoctrine({side='Blue'})` shows only side-level settings. Use `{mission=...}` or `{name=...}` to read mission or unit doctrine respectively.

---

## 8. Magazines vs Mounts

These are frequently confused:

| | Magazine | Mount |
|--|---------|-------|
| **What it is** | Storage container for weapons | Active launcher/firing system |
| **Analogy** | A ship's armory | A missile launcher or gun barrel |
| **API** | `unit.magazines` | `unit.mounts` |
| **Use for** | Checking/replenishing ammo stocks | Checking firing status, round counts |

```lua
local unit = ScenEdit_GetUnit({name='USS Bunker Hill', side='Blue'})

-- Check magazine inventory
for _, mag in ipairs(unit.magazines) do
    print('Magazine: ' .. mag.name)
    for _, wpn in ipairs(mag.weapons) do
        print('  ' .. wpn.name .. ': ' .. wpn.count .. '/' .. wpn.maxcount)
    end
end

-- Add weapons to magazine (e.g., at-sea replenishment simulation)
ScenEdit_AddWeaponToUnitMagazine({
    unitname = 'USS Bunker Hill',
    wpn_dbid = 229,     -- SM-2MR Block IIIB
    number   = 24,
    maxcap   = 122      -- don't exceed this total
})
```

---

## 9. Date and Time Handling

`ScenEdit_CurrentTime()` returns a Unix timestamp (seconds since 1970-01-01 00:00:00 UTC).

```lua
-- Get current scenario time as a timestamp
local t = ScenEdit_CurrentTime()

-- Format for display (! prefix = UTC)
print(os.date("!%Y-%m-%d %H:%M:%S", t))  --> 2025-06-09 06:00:00

-- Time arithmetic
local twoHoursLater = t + (2 * 3600)
local thirtyMinsAgo = t - (30 * 60)

-- Store a time for comparison in a later event
ScenEdit_SetKeyValue('phase2_start_time', tostring(t + 7200))

-- Check in a RegularTime event:
local phase2Time = tonumber(ScenEdit_GetKeyValue('phase2_start_time'))
if phase2Time and ScenEdit_CurrentTime() >= phase2Time then
    -- activate phase 2
end
```

**Setting a trigger time from a known date:**

```lua
-- os.time() parses UTC dates if _GMT_ table key is set — but CMO Lua
-- may not have os.time() with table argument. Safest approach:
-- hardcode the Unix timestamp from an external converter.
-- Example: 2025-06-09 08:00:00 UTC = 1749430800 + 7200 = 1749438000
ScenEdit_SetTrigger({
    name = 'T_H_Hour',
    type = 'Time',
    time = 1749438000
})
```

---

## 10. Testing Event Script Behavior in the Console

Use `Tool_EmulateNoConsole(true)` to test event script code interactively:

```lua
-- In the console: simulate running as if you're inside an event script
Tool_EmulateNoConsole(true)

-- Test your event action script here
-- Note: ScenEdit_UnitX() returns nil in console context (no triggering event)
local u = ScenEdit_UnitX()
if not u then
    print('No trigger unit (expected — we are in console)')
else
    print('Trigger unit: ' .. u.name)
end

-- Test error handling
local ok, err = pcall(function()
    error('Simulated error')
end)
print('pcall caught: ' .. tostring(err))

Tool_EmulateNoConsole(false)
```

During development, add a `print()` or `ScenEdit_SpecialMessage` debug line at the start of every event script. Remove them before release. You can also gate debug output with a KeyStore flag:

```lua
-- In LuaInit: set debug mode
ScenEdit_SetKeyValue('DEBUG', 'true')

-- In any event script:
if ScenEdit_GetKeyValue('DEBUG') == 'true' then
    ScenEdit_SpecialMessage('Blue', '[DEBUG] Event fired at ' .. ScenEdit_CurrentTime())
end
```

---

## 11. Fuel Table by Type Code

The `unit.fuel` table is indexed by fuel type code (a number), not by name. Common codes:

| Code | Fuel Type |
|------|-----------|
| `3001` | Aviation Gas (piston aircraft) |
| `3002` | Aviation Fuel (jet aircraft) |
| `4001` | Diesel Fuel (ships, land vehicles) |
| `4002` | Nuclear (nuclear-powered ships/subs) |
| `4003` | Battery (electric/AIP subs) |

```lua
local u = ScenEdit_GetUnit({name='F/A-18 Alpha', side='Blue'})
if not u then return end

-- Iterate fuel types
for fuelCode, fuelData in pairs(u.fuel) do
    print(string.format(
        'Fuel %d: %.0f / %.0f (%.1f%%)',
        fuelCode,
        fuelData.current,
        fuelData.max,
        (fuelData.current / fuelData.max) * 100
    ))
end

-- Check specific fuel type
local avfuel = u.fuel[3002]
if avfuel and (avfuel.current / avfuel.max) < 0.3 then
    ScenEdit_SpecialMessage('Blue', u.name .. ' is below 30% fuel — RTB recommended')
end
```

---

## 12. Contact GUID vs Unit GUID

Contacts are separate objects from units. When a unit detects an enemy, it creates a **contact** on its side — this contact has its **own GUID**, different from the actual unit's GUID.

| Object | GUID | Access |
|--------|------|--------|
| Unit | `unit.guid` | `ScenEdit_GetUnit({guid=...})` |
| Contact | `contact.guid` | `VP_GetContact({guid=...})` |

To get the actual unit from a contact (only works if the contact is fully identified):

```lua
local c = ScenEdit_UnitC()  -- contact in a UnitDetected event
if c then
    print('Contact GUID: ' .. c.guid)
    
    -- Get the real unit (nil if not yet identified)
    if c.actualunitid then
        local realUnit = ScenEdit_GetUnit({guid=c.actualunitid})
        if realUnit then
            print('Actual unit: ' .. realUnit.name .. ' (' .. realUnit.side .. ')')
        end
    else
        print('Contact not yet identified. Classification: ' .. c.classificationlevel)
    end
end
```

When assigning targets in strike missions or using `ScenEdit_AssignUnitAsTarget`, use the **unit GUID**, not the contact GUID.

---

## 13. Multi-Line Script Strings in Actions

When setting `scriptText` on an action, CMO parses the string differently than the Lua console. Multi-line scripts in actions should use `\r\n` (Windows line endings) for maximum compatibility:

```lua
-- Potentially unreliable (Unix line endings):
ScenEdit_SetAction({
    name       = 'A_Example',
    type       = 'LuaScript',
    scriptText = [[
        local u = ScenEdit_UnitX()
        if not u then return end
        print(u.name)
    ]]
})

-- Safe (explicit CRLF):
ScenEdit_SetAction({
    name       = 'A_Example',
    type       = 'LuaScript',
    scriptText =
        "local u = ScenEdit_UnitX()\r\n" ..
        "if not u then return end\r\n" ..
        "ScenEdit_SpecialMessage('Blue', u.name)\r\n"
})

-- Alternative: store the script in an external .lua file and call it
ScenEdit_SetAction({
    name       = 'A_Example',
    type       = 'LuaScript',
    scriptText = "ScenEdit_RunScript('/Development/MyScen/on_unit_destroyed.lua')"
})
```

The external-file approach is cleanest for anything beyond 2–3 lines and avoids the `\r\n` issue entirely.

---

## 14. Debugging: print() vs ScenEdit_SpecialMessage

| Method | Context | Notes |
|--------|---------|-------|
| `print()` | Console only | Output appears in the console output pane. Invisible in events. |
| `ScenEdit_SpecialMessage()` | Events + console | Shows as a player-visible popup. Use for event debugging. |
| `ScenEdit_SetKeyValue()` | Events + console | Write-only "log" you can read later in the console. Good for timestamps and counters. |

**Debugging pattern:**

```lua
-- In an event script (no console output possible):
local function debug(msg)
    -- Append to a debug log in KeyStore
    local existing = ScenEdit_GetKeyValue('debug_log') or ''
    local timestamp = tostring(ScenEdit_CurrentTime())
    ScenEdit_SetKeyValue('debug_log', existing .. '[' .. timestamp .. '] ' .. msg .. '\n')
end

debug('Event fired')
local u = ScenEdit_UnitX()
debug('UnitX = ' .. tostring(u and u.name or 'nil'))

-- Then in the console to read the log:
-- print(ScenEdit_GetKeyValue('debug_log'))
```

---

## 15. Quick Reference Checklist

When writing a new CMO Lua script, run through this checklist:

- [ ] **Names → GUIDs**: Store GUIDs in KeyStore on creation; use GUIDs in all lookups
- [ ] **Nil guards**: Every `GetUnit`, `GetMission`, `GetSide` return is checked for nil
- [ ] **pcall**: Event scripts wrap logic in pcall; errors stored in KeyStore
- [ ] **KeyStore types**: All KeyStore values are strings; numbers use `tostring()`/`tonumber()`
- [ ] **EMCON format**: Semicolons between settings, `Category=Value` format
- [ ] **Doctrine order**: Set side → mission → unit
- [ ] **Multi-line scripts**: Use `\r\n` or extract to external file
- [ ] **RegularTime loops**: Early-exit guards before any loops; minimal computation per fire
- [ ] **Time math**: `ScenEdit_CurrentTime()` + seconds; `os.date("!format", t)` for display
- [ ] **Contact GUID ≠ Unit GUID**: Use `.actualunitid` to bridge
