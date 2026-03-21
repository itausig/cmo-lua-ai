# CMO Lua API — Data Types Reference

Documentation for all CMO-specific data types, formats, and conventions used across the API.

> **Cross-references:** [FUNCTIONS.md](./FUNCTIONS.md) | [WRAPPERS.md](./WRAPPERS.md) | [ENUMS.md](./ENUMS.md)

---

## Table of Contents

1. [Altitude](#1-altitude)
2. [Latitude & Longitude](#2-latitude--longitude)
3. [DateTime](#3-datetime)
4. [GUID](#4-guid)
5. [KeyStore](#5-keystore)
6. [Arc (Sensor / Mount Coverage)](#6-arc-sensor--mount-coverage)
7. [TargetFilter](#7-targetfilter)
8. [CourseWaypoint](#8-coursewaypoint)
9. [DamageTable](#9-damagetable)
10. [WeatherTable](#10-weathertable)
11. [FuelTable](#11-fueltable)
12. [Score & Points](#12-score--points)
13. [Side Posture String vs. Full String](#13-side-posture-string-vs-full-string)

---

## 1. Altitude

Altitude values in CMO Lua can be expressed in **meters** (default) or **feet** (with `'FT'` suffix). Rules:

| Form | Type | Example | Notes |
|------|------|---------|-------|
| Meters (number) | `number` | `100` | Meters above sea level or above ground |
| Meters (string) | `string` | `'100'` | String form also accepted |
| Feet string | `string` | `'1000 FT'` | Must include `' FT'` suffix (space before FT) |
| Negative meters | `number` | `-200` | Submarine depth below surface |

**Key altitude constants:**

| Description | Value |
|-------------|-------|
| Sea level | `0` |
| Periscope depth (sub) | `-18` (approx.) |
| Low altitude | `150` to `600` |
| Medium altitude | `3000` to `8000` |
| High altitude | `10000` to `15000` |
| Very high altitude | `>15000` |

**Usage in functions:**
```lua
-- Adding units at altitude
ScenEdit_AddUnit({
    side='USA', type='Aircraft', name='F-18 Alpha',
    dbid=278, latitude=36.0, longitude=-10.0,
    altitude='20000 FT'   -- 20,000 feet
})

-- Meters form
ScenEdit_SetUnit({
    name='F-18 Alpha', side='USA',
    altitude=6096    -- 20,000 feet in meters
})

-- Setting a submarine depth
ScenEdit_SetUnit({
    name='USS Hartford', side='USA',
    altitude=-200    -- 200 meters depth
})

-- Reference point with no altitude (surface)
ScenEdit_AddReferencePoint({
    side='USA', name='Alpha',
    lat=36.0, lon=-10.0
    -- No altitude field needed for surface RP
})
```

**Conversion reference:**

| Feet | Meters |
|------|--------|
| 100 ft | 30 m |
| 500 ft | 152 m |
| 1,000 ft | 305 m |
| 5,000 ft | 1,524 m |
| 10,000 ft | 3,048 m |
| 20,000 ft | 6,096 m |
| 40,000 ft | 12,192 m |

---

## 2. Latitude & Longitude

CMO Lua accepts two coordinate formats for lat/lon fields.

### Format 1: Decimal Degrees (number)

The simplest and preferred format for programmatic use.

```lua
-- North/East are positive
-- South/West are negative
latitude  =  38.5      -- 38.5° North
longitude = -122.4     -- 122.4° West
latitude  = -33.87     -- 33.87° South
longitude =  151.21    -- 151.21° East
```

### Format 2: CMO DMS String

Degrees, Minutes, Seconds string format used in CMO's UI.

```
'N DD.MM.SS'   -- North hemisphere
'S DD.MM.SS'   -- South hemisphere
'E DDD.MM.SS'  -- East hemisphere
'W DDD.MM.SS'  -- West hemisphere
```

**Examples:**
```lua
-- New York City
latitude  = 'N 40.42.46'   -- 40°42'46"N
longitude = 'W 074.00.21'  -- 74°00'21"W

-- Sydney
latitude  = 'S 33.51.54'
longitude = 'E 151.12.36'

-- Using decimal in same call
ScenEdit_AddUnit({
    side='USA', type='Ship', name='USS Nimitz',
    dbid=100,
    latitude  = 'N 36.30.00',  -- String form
    longitude = -122.4          -- Decimal form (both work)
})
```

### Conversion Tip

To convert DMS to decimal:
```lua
-- DMS to decimal conversion helper
local function dmsToDecimal(degrees, minutes, seconds, direction)
    local decimal = degrees + (minutes / 60) + (seconds / 3600)
    if direction == 'S' or direction == 'W' then
        decimal = -decimal
    end
    return decimal
end

-- Example: N 38.30.15 -> 38.504166...
local lat = dmsToDecimal(38, 30, 15, 'N')  -- 38.5042°
```

### Important Notes

- CMO uses **geodetic** coordinates (WGS-84)
- Valid range: latitude `-90` to `+90`, longitude `-180` to `+180`
- Functions like `Tool_Range()` and `Tool_Bearing()` always return results using these coordinates
- The `inArea()` method checks if a point is inside the polygon defined by named reference points

---

## 3. DateTime

CMO date-time strings are **locale-dependent** unless a format specifier is provided. Always use explicit format strings in scripts to avoid locale issues.

### Format Specifier Syntax

Use the `!` delimiter to separate the date-time value from its format string:

```
"DATETIME_VALUE!FORMAT_STRING"
```

### Format Codes

| Token | Meaning | Example |
|-------|---------|---------|
| `yyyy` | 4-digit year | `2027` |
| `MM` | 2-digit month | `06` |
| `dd` | 2-digit day | `09` |
| `HH` | Hours (24-hour) | `14` |
| `mm` | Minutes | `30` |
| `ss` | Seconds | `00` |

### Examples

```lua
-- Explicit format (recommended — locale-independent)
ScenEdit_SetStartTime('2027-06-09 06:00:00!yyyy-MM-dd HH:mm:ss')
ScenEdit_SetTime('2027-06-09 14:30:00!yyyy-MM-dd HH:mm:ss')

-- Trigger time
ScenEdit_SetTrigger({
    name = 'H-Hour',
    type = 'Time',
    time = '2027-06-10 02:00:00!yyyy-MM-dd HH:mm:ss'
})

-- Without format specifier (locale-dependent — avoid in scripts)
ScenEdit_SetStartTime('6/9/2027 6:00:00 AM')   -- Works on US locale only
```

### Unix Timestamps

Many functions use Unix timestamps (seconds since January 1, 1970 UTC) for internal time calculations. Use `ScenEdit_CurrentTime()` to get the current scenario time as a Unix timestamp.

```lua
-- Arithmetic with Unix timestamps
local now   = ScenEdit_CurrentTime()
local oneHour = 3600
local inTwoHours = now + (2 * oneHour)
local inOneDay   = now + (24 * oneHour)

-- Store as KeyStore value
ScenEdit_SetKeyValue('event_time', tostring(inTwoHours))

-- Compare times
local scheduled = tonumber(ScenEdit_GetKeyValue('event_time'))
if ScenEdit_CurrentTime() >= scheduled then
    -- Time has arrived
end
```

### Day/Hour Calculations

```lua
-- Common time constants
local SECONDS_PER_MINUTE = 60
local SECONDS_PER_HOUR   = 3600
local SECONDS_PER_DAY    = 86400

-- Check elapsed time since event
local eventTime = tonumber(ScenEdit_GetKeyValue('phase1_start'))
if eventTime then
    local elapsed = ScenEdit_CurrentTime() - eventTime
    local elapsedHours = elapsed / SECONDS_PER_HOUR
    print(string.format('Phase 1 has been running for %.1f hours', elapsedHours))
end
```

---

## 4. GUID

A **GUID** (Globally Unique Identifier) is a 32-character hexadecimal string (with hyphens) that permanently identifies a scenario object.

### Key Properties

- **Read-only**: Once assigned at creation, a GUID never changes
- **Stable**: Persists across save/load, unlike names
- **Unique**: No two objects in the same scenario share a GUID
- **Format**: `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx` (8-4-4-4-12 hex digits)

### Why GUID Matters

```lua
-- BAD: Names can be changed by the player or scripts
local unit = ScenEdit_GetUnit({name='USS Nimitz', side='USA'})

-- GOOD: Store GUID immediately and use it
local unit = ScenEdit_GetUnit({name='USS Nimitz', side='USA'})
if not unit then return end
local nimitzGUID = unit.guid

-- ... later, use GUID to retrieve reliably
local nimitz = ScenEdit_GetUnit({guid=nimitzGUID})
```

### Storing GUIDs

Since GUIDs must survive scenario saves and script re-runs, store them in the KeyStore:

```lua
-- Store GUID at scenario init
local carrier = ScenEdit_GetUnit({name='USS Nimitz', side='USA'})
if carrier then
    ScenEdit_SetKeyValue('carrier_guid', carrier.guid)
end

-- Retrieve in any event script
local guid = ScenEdit_GetKeyValue('carrier_guid')
if guid ~= '' then
    local carrier = ScenEdit_GetUnit({guid=guid})
    if carrier then
        print('Carrier is at ' .. carrier.latitude)
    end
end
```

### GUID vs. Name Comparison

| Property | GUID | Name |
|----------|------|------|
| Stability | Never changes | Can be modified |
| Uniqueness | Guaranteed unique | Not guaranteed unique |
| Readability | Opaque hex string | Human-readable |
| API support | All functions accept it | Most functions accept it |
| Recommended for | Persistent references | Display, quick scripts |

---

## 5. KeyStore

The **KeyStore** is a persistent string dictionary embedded in the scenario save file. It's the primary mechanism for storing state across multiple event script executions.

### API

```lua
ScenEdit_SetKeyValue(key: string, value: string)  -> nil
ScenEdit_GetKeyValue(key: string)                 -> string   -- Returns "" if not found
ScenEdit_ClearKeyValue(key: string)               -> nil
```

### Key Rules

- Both key and value **must be strings**
- `GetKeyValue` returns `""` (empty string), never `nil`
- Persists across save/load
- No size limit is documented; keep values reasonably short
- Keys are **case-sensitive**

### Storing Non-String Types

```lua
-- Numbers: use tostring/tonumber
ScenEdit_SetKeyValue('score_delta', tostring(250))
local delta = tonumber(ScenEdit_GetKeyValue('score_delta')) or 0

-- Booleans: use string conventions
ScenEdit_SetKeyValue('phase2_unlocked', 'true')
local unlocked = ScenEdit_GetKeyValue('phase2_unlocked') == 'true'

-- Tables / lists: use separator encoding
local unitList = 'guid1,guid2,guid3'
ScenEdit_SetKeyValue('target_guids', unitList)
local guids = {}
for guid in ScenEdit_GetKeyValue('target_guids'):gmatch('[^,]+') do
    table.insert(guids, guid)
end

-- JSON-like encoding (if your Lua environment includes json library)
-- ScenEdit_SetKeyValue('state', json.encode({phase=2, targets=3}))
```

### Common Patterns

```lua
-- Pattern 1: Phase/state machine
local function getPhase()
    return tonumber(ScenEdit_GetKeyValue('game_phase')) or 1
end
local function setPhase(n)
    ScenEdit_SetKeyValue('game_phase', tostring(n))
end

-- Transition: advance phase
if getPhase() == 1 then
    setPhase(2)
    ScenEdit_SpecialMessage('USA', 'Phase 2 begins!')
end

-- Pattern 2: One-time events with guard
local fired = ScenEdit_GetKeyValue('reinforcement_fired')
if fired == '' then    -- Not yet fired
    ScenEdit_SetKeyValue('reinforcement_fired', 'true')
    -- Spawn reinforcements...
end

-- Pattern 3: Timestamped events
local startTime = ScenEdit_GetKeyValue('phase2_start')
if startTime == '' then
    ScenEdit_SetKeyValue('phase2_start', tostring(ScenEdit_CurrentTime()))
end

-- Pattern 4: Counter
local function incrementCounter(key)
    local n = tonumber(ScenEdit_GetKeyValue(key)) or 0
    ScenEdit_SetKeyValue(key, tostring(n + 1))
    return n + 1
end
local destroyedCount = incrementCounter('ships_destroyed')
```

### Namespace Convention

To avoid key collisions in complex scenarios, use a consistent prefix:
```lua
-- Good: namespaced keys
ScenEdit_SetKeyValue('MIS01_phase', '2')
ScenEdit_SetKeyValue('MIS01_carrier_guid', carrier.guid)
ScenEdit_SetKeyValue('MIS01_reinforcements_sent', 'true')
```

---

## 6. Arc (Sensor / Mount Coverage)

**Arc** codes define the angular coverage sectors for sensors and weapon mounts. Used in `ScenEdit_UpdateUnit({arc_detect=..., arc_track=...})`.

### Arc Code Format

Arc codes are typically **integer pairs** or **named strings** representing the start and end bearings of a coverage sector:

```
'0,360'    -- Full 360° coverage (omnidirectional)
'315,45'   -- Forward arc (315° to 045°, centered forward)
'135,225'  -- Aft arc
'0,180'    -- Right hemisphere
'180,360'  -- Left hemisphere
```

### Predefined Arc Names

| Name | Degrees | Description |
|------|---------|-------------|
| `'360'` | 0–360 | Full omnidirectional coverage |
| `'FWD'` or `'Forward'` | 315–045 | Forward 90° cone |
| `'AFT'` or `'Aft'` | 135–225 | Aft 90° cone |
| `'PORT'` | 225–315 | Port (left) side |
| `'STBD'` | 045–135 | Starboard (right) side |
| `'UPPER'` | Elevation above horizon | For air-search coverage |
| `'LOWER'` | Elevation below horizon | For surface/sub coverage |

### Usage in ScenEdit_UpdateUnit

```lua
-- Add an omnidirectional radar
ScenEdit_UpdateUnit({
    guid       = 'unit-guid',
    mode       = 'add_sensor',
    dbid       = 5001,      -- Radar DB ID
    arc_detect = '360',     -- Detect all around
    arc_track  = '360'      -- Track all around
})

-- Add a forward-looking fire control radar
ScenEdit_UpdateUnit({
    guid       = 'unit-guid',
    mode       = 'add_sensor',
    dbid       = 5002,
    arc_detect = '0,90',    -- 90° forward cone
    arc_track  = '0,60'     -- 60° tracking arc
})
```

---

## 7. TargetFilter

A `TargetFilter` table restricts what triggers or missions consider as valid targets. Used in trigger definitions and mission options.

### Schema

```lua
{
    TargetSide      = string,   -- Side name; only consider targets from this side
    TargetType      = string,   -- Unit type (see ENUMS.md UnitType)
    TargetSubType   = string,   -- Unit subtype string
    SpecificUnitClass = string, -- Specific class/DB name
    SpecificUnitID  = string    -- Specific unit GUID (most precise)
}
```

All fields are **optional**. Omitted fields are treated as "any". Multiple fields narrow the filter.

### Examples

```lua
-- Filter: any hostile aircraft
{
    TargetSide = 'OPFOR',
    TargetType = 'Aircraft'
}

-- Filter: specifically a carrier
{
    TargetSide     = 'Russia',
    TargetSubType  = 'Carrier'
}

-- Filter: specific unit by GUID
{
    SpecificUnitID = 'a1b2c3d4-...'
}

-- Usage in trigger
ScenEdit_SetTrigger({
    name       = 'DetectCarrier',
    type       = 'UnitDetected',
    detectingSideId = 'USA',
    targetFilter = {
        TargetSide    = 'Russia',
        TargetSubType = 'Carrier'
    }
})
```

---

## 8. CourseWaypoint

The array format passed to `ScenEdit_SetUnit({course=...})` for setting a unit's route.

### Schema

```lua
course = {
    {
        latitude  = number,             -- Decimal degrees (required)
        longitude = number,             -- Decimal degrees (required)
        altitude  = number|string,      -- Optional; inherits previous if omitted
        name      = string,             -- Optional waypoint name
        description = string,           -- Optional description
        desiredAltitude = number,       -- Override altitude at this WP
        desiredSpeed    = number,       -- Override speed at this WP (knots)
        presetAltitude  = string,       -- 'Low'|'Medium'|'High'|'Optimal'
        presetDepth     = string,       -- Submarine: 'Periscope'|'Shallow'|'Deep'
        presetThrottle  = string,       -- 'Loiter'|'Cruise'|'Full'|'Flank'
        TF              = boolean       -- Terrain following at this WP
    },
    -- ... more waypoints
}
```

### Examples

```lua
-- Basic course (ship patrolling a box)
ScenEdit_SetUnit({
    name='Frigate Alpha', side='OPFOR',
    course = {
        {latitude=36.0, longitude=-10.0},
        {latitude=37.0, longitude=-10.0},
        {latitude=37.0, longitude=-8.0},
        {latitude=36.0, longitude=-8.0},
        {latitude=36.0, longitude=-10.0}    -- Return to start
    }
})

-- Aircraft course with altitude changes
ScenEdit_SetUnit({
    name='Strike Alpha', side='USA',
    course = {
        {latitude=36.5, longitude=-12.0, altitude='20000 FT', presetThrottle='Cruise'},
        {latitude=37.0, longitude=-10.5, altitude='500 FT',   presetThrottle='Full', TF=true},  -- Ingress low
        {latitude=37.5, longitude=-9.0,  altitude='500 FT'},  -- Target area
        {latitude=38.0, longitude=-11.0, altitude='20000 FT', presetThrottle='Cruise'}  -- Egress
    }
})

-- Submarine ingress with depth changes
ScenEdit_SetUnit({
    name='USS Hartford', side='USA',
    course = {
        {latitude=36.0, longitude=-15.0, presetDepth='Periscope',  presetThrottle='Loiter'},
        {latitude=36.5, longitude=-12.0, presetDepth='Deep',       presetThrottle='Full'},
        {latitude=37.0, longitude=-10.0, presetDepth='Shallow',    presetThrottle='Drift'}
    }
})
```

---

## 9. DamageTable

Table format used in `ScenEdit_SetUnitDamage()` and returned in `Unit.damage`.

### Schema

```lua
{
    structural = number,    -- Overall structural damage: 0–100 (100 = totally destroyed)
    components = {
        {
            guid   = string,    -- Component GUID
            dp     = number     -- Damage percentage for this component
        },
        -- ...
    }
}
```

### Reading Damage State

```lua
local unit = ScenEdit_GetUnit({name='USS Nimitz', side='USA'})
if not unit then return end

-- Check structural damage
if unit.damage.structural > 50 then
    ScenEdit_SpecialMessage('USA', unit.name .. ' is critically damaged!')
end

-- Check specific components
for _, comp in ipairs(unit.damage.components) do
    if comp.dp > 75 then
        print('Component heavily damaged: ' .. comp.guid)
    end
end
```

### Applying Damage

```lua
-- Set 30% structural damage
ScenEdit_SetUnitDamage({
    side   = 'OPFOR',
    name   = 'Frigate Alpha',
    damage = {structural=30}
})

-- Destroy specific component
ScenEdit_SetUnitDamage({
    side   = 'OPFOR',
    name   = 'Frigate Alpha',
    damage = {
        components = {
            {guid='component-guid-here', dp=100}
        }
    }
})
```

---

## 10. WeatherTable

Used in `ScenEdit_SetWeather()` and returned by `ScenEdit_GetWeather()`.

### Schema

```lua
{
    temperature = number,   -- Surface temperature in Celsius
    rainfall    = number,   -- Rainfall intensity: 0.0 (none) to 1.0 (torrential)
    clouds      = number,   -- Cloud cover: 0.0 (clear) to 1.0 (overcast)
    seastate    = number    -- Beaufort scale: 0 (calm) to 9 (violent storm)
}
```

### Sea State Reference (Beaufort Scale)

| State | Value | Description | Wave Height |
|-------|-------|-------------|-------------|
| Calm | `0` | Glassy | 0 m |
| Light air | `1` | Ripples | 0.1 m |
| Light breeze | `2` | Small waves | 0.2–0.5 m |
| Gentle breeze | `3` | Moderate waves | 0.6–1.0 m |
| Moderate breeze | `4` | Larger waves | 1–2 m |
| Fresh breeze | `5` | Whitecaps | 2–3 m |
| Strong breeze | `6` | Large waves | 3–4 m |
| Near gale | `7` | Heavy sea | 4–6 m |
| Gale | `8` | Very high seas | 6–9 m |
| Violent storm | `9` | Huge waves | >9 m |

### Operational Weather Effects

| Condition | Impact |
|-----------|--------|
| `clouds > 0.7` | Reduced visual sensor range |
| `rainfall > 0.5` | Radar attenuation, reduced VIS |
| `seastate > 5` | Ship speed reduction; helicopter ops restricted |
| `seastate > 7` | Air ops severely restricted |
| `temperature < -10` | Arctic operations effects |

**Example — Dynamic weather progression:**
```lua
-- Storm building over time
local function setStorm(intensity)
    ScenEdit_SetWeather({
        temperature = math.max(8, 18 - intensity * 10),
        rainfall    = math.min(1.0, intensity * 0.4),
        clouds      = math.min(1.0, 0.3 + intensity * 0.6),
        seastate    = math.min(9, math.floor(intensity * 5))
    })
end

-- Check time and escalate weather
local phase = tonumber(ScenEdit_GetKeyValue('weather_phase')) or 0
if phase == 1 then
    setStorm(0.5)   -- Building
elseif phase == 2 then
    setStorm(1.0)   -- Full storm
elseif phase == 3 then
    setStorm(0.3)   -- Clearing
end
```

---

## 11. FuelTable

Returned by `Unit.fuel`. Read-only — use `ScenEdit_RefuelUnit()` to replenish.

### Schema

```lua
{
    current  = number,  -- Current fuel amount (same units as max)
    max      = number,  -- Maximum fuel capacity
    percent  = number   -- 0–100 percent full
}
```

### Fuel State Codes (`Unit.fuelstate`)

| Value | Description | Typical Threshold |
|-------|-------------|-------------------|
| `'OK'` | Normal fuel state | >25% |
| `'Bingo'` | Minimum fuel for recovery | ~15–20% |
| `'Winchester'` | Critical fuel — immediate RTB | <10% |
| `'Empty'` | Out of fuel | 0% |

**Example — Tanker logic:**
```lua
-- Find aircraft needing fuel and assign to tanker mission
local side = VP_GetSide({Side='USA'})
for _, u in ipairs(side:unitsBy('Aircraft')) do
    if u.fuelstate == 'Bingo' and u.mission == nil then
        ScenEdit_AssignUnitToMission(u.guid, 'AAR Tanker Track', false)
    end
end
```

---

## 12. Score & Points

Scores are **integer** values assigned per side. Used in `ScenEdit_GetScore()`, `ScenEdit_SetScore()`.

### Conventions

- Positive points: achievements, enemy losses
- Negative points: penalties, friendly losses
- Setting uses **absolute** values — to add points, read first then add:

```lua
-- Correct: add to existing score
local current = ScenEdit_GetScore('USA')
ScenEdit_SetScore('USA', current + 100, 'Destroyed command bunker')

-- Wrong: overwrites score
ScenEdit_SetScore('USA', 100)   -- Loses all prior points!
```

### Score Trigger Integration

Scores can trigger events using the `'Points'` trigger type:
```lua
ScenEdit_SetTrigger({
    name      = 'VictoryReached',
    type      = 'Points',
    side      = 'USA',
    score     = 500,
    direction = 'above'    -- fires when score exceeds 500
})
```

---

## 13. Side Posture String vs. Full String

The `ScenEdit_SetSidePosture()` function accepts **single-character codes**, while `ScenEdit_GetSidePosture()` returns **full strings**.

| Set code | Get returns | Meaning |
|----------|-------------|---------|
| `'H'` | `'Hostile'` | Hostile — will engage |
| `'F'` | `'Friendly'` | Friendly — will cooperate |
| `'N'` | `'Neutral'` | Neutral — benign |
| `'U'` | `'Unfriendly'` | Unfriendly — not hostile but distrusted |

**Always test the full string when reading posture:**
```lua
-- Setting
ScenEdit_SetSidePosture('Russia', 'USA', 'H')

-- Getting
local posture = ScenEdit_GetSidePosture('Russia', 'USA')
if posture == 'Hostile' then    -- Note: full string, not 'H'
    print('Russia is hostile')
end
```

---

## Summary Cheat Sheet

| Data Type | Valid Forms | Notes |
|-----------|-------------|-------|
| Altitude | `100`, `'100'`, `'1000 FT'`, `-200` | Negative = depth |
| Latitude | `36.5`, `'N 36.30.00'` | Decimal preferred |
| Longitude | `-122.4`, `'W 122.24.00'` | Decimal preferred |
| DateTime | `'2027-06-09 14:00:00!yyyy-MM-dd HH:mm:ss'` | Always use `!format` |
| GUID | `'a1b2c3d4-1234-...'` | Store in KeyStore |
| KeyStore value | `string` only | Use `tostring()`/`tonumber()` |
| Arc | `'360'`, `'0,90'`, `'FWD'` | Degrees or named |
| Score | `number` | Use read-then-set pattern |
| Posture (set) | `'H'`,`'F'`,`'N'`,`'U'` | Single char |
| Posture (get) | `'Hostile'`,`'Friendly'`... | Full string |
| WCS | `0`, `1`, `2` | Not strings |

---

*End of DATA_TYPES.md*

> **See also:** [FUNCTIONS.md](./FUNCTIONS.md) | [WRAPPERS.md](./WRAPPERS.md) | [ENUMS.md](./ENUMS.md)
