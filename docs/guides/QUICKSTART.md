# First CMO Lua Script in 5 Minutes

This guide gets you from zero to a working CMO Lua script. You need basic Lua knowledge — loops, tables, functions. You don't need to know the CMO API at all.

> **Cross-references:** [FUNCTIONS.md](../api-reference/FUNCTIONS.md) | [WRAPPERS.md](../api-reference/WRAPPERS.md) | [EVENT_SYSTEM.md](./EVENT_SYSTEM.md)

---

## Step 1 — Open the Lua Console

In CMO, go to **Editor → Lua Script Console** (shortcut: none by default — access it through the menu).

You'll see a text input area and an output area. Everything you type is executed immediately when you press **Run** (or the play button). This is your sandbox.

> **Tip:** The console is the best way to experiment. Errors show up in red in the output pane. In event scripts, errors are silent — the console is your only interactive debug environment.

---

## Step 2 — Your First Command

Type this in the console and run it:

```lua
print(ScenEdit_CurrentTime())
```

You'll see a large number like `1749430800`. That's the current scenario time as a [Unix timestamp](https://en.wikipedia.org/wiki/Unix_time) — seconds since January 1, 1970. To convert it to a readable date:

```lua
local t = ScenEdit_CurrentTime()
print(os.date("!%Y-%m-%d %H:%M:%S", t))
-- Output: 2025-06-09 06:00:00
```

The `!` prefix in the format string tells `os.date` to use UTC (not your local timezone). CMO scenario time is always UTC.

---

## Step 3 — Add a Unit

Spawn a ship into the scenario:

```lua
ScenEdit_AddUnit({
    side      = 'Blue',
    type      = 'Ship',
    name      = 'USS Test',
    dbid      = 960,
    latitude  = 'N38.50.00',
    longitude = 'W72.00.00'
})
```

**What's happening:**
- `side` — the scenario side name (must match exactly, case-sensitive)
- `type` — one of `'Aircraft'`, `'Ship'`, `'Submarine'`, `'Facility'`, `'Satellite'`
- `dbid` — the database ID of the unit class (960 is a generic destroyer; browse the CMO database editor to find IDs)
- `latitude`/`longitude` — accepts decimal (`38.833`) or DMS string format (`'N38.50.00'`)

If the unit name already exists on that side, the call will fail silently. Always check:

```lua
local u = ScenEdit_AddUnit({
    side      = 'Blue',
    type      = 'Ship',
    name      = 'USS Test',
    dbid      = 960,
    latitude  = 38.833,
    longitude = -72.0
})
if u then
    print('Added unit GUID: ' .. u.guid)
else
    print('Failed to add unit')
end
```

> **Best practice:** Immediately save the returned GUID. Names can change; GUIDs cannot.

---

## Step 4 — Get Unit Info

Retrieve a unit and inspect its properties:

```lua
local u = ScenEdit_GetUnit({name='USS Test', side='Blue'})
if not u then
    print('Unit not found!')
    return
end

print('Name:      ' .. u.name)
print('GUID:      ' .. u.guid)
print('Latitude:  ' .. u.latitude)
print('Longitude: ' .. u.longitude)
print('Speed:     ' .. u.speed)
print('Heading:   ' .. u.heading)
print('Condition: ' .. u.condition)
```

Common fields you'll access constantly:

| Field | Type | Description |
|-------|------|-------------|
| `u.guid` | string | Unique ID — store this |
| `u.latitude` | number | Decimal degrees |
| `u.longitude` | number | Decimal degrees |
| `u.altitude` | number | Meters (negative = depth) |
| `u.speed` | number | Knots |
| `u.heading` | number | 0–360 |
| `u.condition_v` | number | Damage 0–100 (100 = undamaged) |
| `u.fuelstate` | string | `'OK'`, `'Bingo'`, `'Winchester'` |

### Discovering Fields with `.fields`

Any wrapper object has a `.fields` property that lists all available fields:

```lua
local u = ScenEdit_GetUnit({name='USS Test', side='Blue'})
for k, v in pairs(u.fields) do
    print(k, v)
end
```

This is invaluable when you're not sure what properties are available.

---

## Step 5 — Modify a Unit

You can set properties directly on the wrapper or use `ScenEdit_SetUnit`:

```lua
-- Method 1: Direct assignment on wrapper (most properties)
local u = ScenEdit_GetUnit({name='USS Test', side='Blue'})
u.speed   = 15
u.heading = 270

-- Method 2: ScenEdit_SetUnit (same result, useful when you have a GUID)
ScenEdit_SetUnit({
    guid    = u.guid,
    speed   = 15,
    heading = 270
})
```

Both methods work. The `ScenEdit_SetUnit` form is useful when you only have a GUID string (not a live wrapper object).

---

## Step 6 — Set EMCON

EMCON (Emission Control) controls a unit's sensors and transmitters:

```lua
-- Set the unit to radar passive (listening only, not transmitting)
ScenEdit_SetEMCON('Unit', 'USS Test', 'Radar=Passive')

-- Multiple EMCON settings at once (semicolon-separated)
ScenEdit_SetEMCON('Unit', 'USS Test', 'Radar=Active;Sonar=Passive;OECM=Active')
```

**EMCON target types** (first argument):
- `'Unit'` — a specific unit
- `'Mission'` — all units in a mission
- `'Side'` — all units on a side

**EMCON categories:**
- `Radar` — active radar
- `Sonar` — active sonar
- `OECM` — offensive ECM (jamming)

**Values:** `Active`, `Passive`, `Inherit` (inherits from parent level)

```lua
-- Full example: set a mission to radar passive, sonar active
ScenEdit_SetEMCON('Mission', 'ASW Barrier', 'Radar=Passive;Sonar=Active')
```

---

## Step 7 — Create a Patrol Mission with Reference Points

This is the most common scenario building block: a named area patrol.

```lua
-- Step 7a: Define the patrol area with reference points
ScenEdit_AddReferencePoint({side='Blue', name='PP-1', lat=39.0, lon=-73.0})
ScenEdit_AddReferencePoint({side='Blue', name='PP-2', lat=39.0, lon=-70.0})
ScenEdit_AddReferencePoint({side='Blue', name='PP-3', lat=37.0, lon=-70.0})
ScenEdit_AddReferencePoint({side='Blue', name='PP-4', lat=37.0, lon=-73.0})

-- Or use the multi-point form (more compact):
ScenEdit_AddReferencePoint({
    side = 'Blue',
    area = {
        {name='PP-1', lat=39.0, lon=-73.0},
        {name='PP-2', lat=39.0, lon=-70.0},
        {name='PP-3', lat=37.0, lon=-70.0},
        {name='PP-4', lat=37.0, lon=-73.0},
    }
})

-- Step 7b: Create the patrol mission using those reference points
local mission = ScenEdit_AddMission(
    'Blue',              -- side
    'USS Test Patrol',   -- mission name
    'patrol',            -- mission type
    {
        type = 'naval',  -- patrol sub-type: 'air', 'naval', 'sub', 'land'
        Zone = {'PP-1', 'PP-2', 'PP-3', 'PP-4'}  -- reference point names
    }
)
print('Mission GUID: ' .. mission.guid)

-- Step 7c: Assign the unit to the mission
ScenEdit_AssignUnitToMission('USS Test', 'USS Test Patrol')
```

Now USS Test will patrol the defined area autonomously.

---

## Step 8 — Send a Player Message

Use `ScenEdit_SpecialMessage` to display a popup message to the player:

```lua
ScenEdit_SpecialMessage('Blue', 'Hello World!')

-- With HTML formatting
ScenEdit_SpecialMessage('Blue', '<b>FLASH TRAFFIC</b><br>USS Test has entered patrol zone.')
```

The first argument is the side name (the player will only see messages addressed to their side, or to sides they observe). Messages support basic HTML.

This is also how you communicate events to the player from within event action scripts:

```lua
-- Typical usage in an event action:
local u = ScenEdit_UnitX()   -- unit that triggered the event
if u then
    ScenEdit_SpecialMessage('Blue', u.name .. ' has been damaged!')
end
```

---

## Step 9 — Run an External Script File

As your scripts grow, you'll want to split them into files rather than inline everything. Use `ScenEdit_RunScript`:

```lua
-- Run a script from the Lua folder
ScenEdit_RunScript('/Development/MyScenario/GameSetup.lua')

-- Run a helper library
ScenEdit_RunScript('/Development/MyScenario/lib/helpers.lua')
```

**Path conventions:**
- Paths are relative to the **CMO Lua folder**: `[CMO Install Directory]/Lua/`
- Leading `/` maps to that Lua folder root
- Use forward slashes on all platforms

---

## Where Is the Lua Folder?

CMO looks for external Lua files in:

```
[CMO Install Directory]/Lua/
```

Typical locations:
- **Steam (Windows):** `C:\Program Files (x86)\Steam\steamapps\common\Command Modern Operations\Lua\`
- **Matrix/standalone (Windows):** `C:\Matrix Games\Command Modern Operations\Lua\`

Create a `Development/` subdirectory inside `Lua/` and put your scenario scripts there:

```
Lua/
└── Development/
    └── MyScenario/
        ├── LuaInit.lua
        ├── GameSetup.lua
        └── lib/
            └── helpers.lua
```

Then call them from the console or from events:

```lua
ScenEdit_RunScript('/Development/MyScenario/LuaInit.lua')
```

---

## Putting It All Together

Here's a complete "first session" script you can paste into the console:

```lua
-- 1. Check scenario time
local t = ScenEdit_CurrentTime()
print('Scenario time: ' .. os.date("!%Y-%m-%d %H:%M:%S", t))

-- 2. Spawn a ship
local ship = ScenEdit_AddUnit({
    side      = 'Blue',
    type      = 'Ship',
    name      = 'USS Test',
    dbid      = 960,
    latitude  = 38.833,
    longitude = -72.0,
    heading   = 90
})

if not ship then
    print('ERROR: Failed to add unit. Does "Blue" side exist? Does USS Test already exist?')
    return
end

print('USS Test GUID: ' .. ship.guid)

-- 3. Set radar passive
ScenEdit_SetEMCON('Unit', 'USS Test', 'Radar=Passive')

-- 4. Create a patrol area
ScenEdit_AddReferencePoint({
    side = 'Blue',
    area = {
        {name='PP-1', lat=39.5, lon=-73.5},
        {name='PP-2', lat=39.5, lon=-70.5},
        {name='PP-3', lat=37.5, lon=-70.5},
        {name='PP-4', lat=37.5, lon=-73.5},
    }
})

-- 5. Create patrol mission and assign unit
local m = ScenEdit_AddMission('Blue', 'Test Patrol', 'patrol', {
    type = 'naval',
    Zone = {'PP-1','PP-2','PP-3','PP-4'}
})
ScenEdit_AssignUnitToMission('USS Test', 'Test Patrol')

-- 6. Notify the player
ScenEdit_SpecialMessage('Blue', 'USS Test is on patrol. GUID: ' .. ship.guid)

print('Setup complete.')
```

---

## What's Next

- **[EVENT_SYSTEM.md](./EVENT_SYSTEM.md)** — Make things happen automatically with triggers, conditions, and actions
- **[SCENARIO_SETUP.md](./SCENARIO_SETUP.md)** — The LuaInit/GameSetup pattern for structured scenario development
- **[BEST_PRACTICES.md](./BEST_PRACTICES.md)** — Error handling, GUIDs, performance, and the KeyStore
- **[FUNCTIONS.md](../api-reference/FUNCTIONS.md)** — Complete API reference
