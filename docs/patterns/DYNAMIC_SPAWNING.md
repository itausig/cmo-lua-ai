# Dynamic Unit Spawning Patterns

Patterns for spawning units at runtime: random positions, timed reinforcements, triggered spawns, and spawn-on-destroy replacement.

---

## Pattern 1 — Random Position Within Bounding Box

Spawn a unit at a random position inside a rectangular area defined by lat/lon bounds.

```lua
--- @param minLat number, maxLat number, minLon number, maxLon number
--- @return number lat, number lon
local function randomPosition(minLat, maxLat, minLon, maxLon)
    math.randomseed(os.time())
    local lat = minLat + math.random() * (maxLat - minLat)
    local lon = minLon + math.random() * (maxLon - minLon)
    return lat, lon
end

local lat, lon = randomPosition(12.0, 15.0, 43.0, 48.0)
local ok, ship = pcall(ScenEdit_AddUnit, {
    side      = 'Red',
    type      = 'Ship',
    name      = 'Patrol-1',
    dbid      = 1803,
    latitude  = lat,
    longitude = lon,
    heading   = math.random(0, 359),
    speed     = math.random(8, 16),
})
```

---

## Pattern 2 — Random Position Within Reference Point Polygon

Spawn within the bounding box of a set of reference points. More flexible than hardcoded coordinates.

```lua
--- Get bounding box of an array of reference points.
--- @param rpNames table   Array of reference point names (all on same side)
--- @param side    string
--- @return number minLat, maxLat, minLon, maxLon
local function getRPBounds(rpNames, side)
    local minLat, maxLat =  90, -90
    local minLon, maxLon = 180, -180

    local ok, s = pcall(VP_GetSide, {Side=side})
    if not ok or not s then return 0,0,0,0 end

    -- Build lookup from side's reference points
    local rpMap = {}
    for _, rp in ipairs(s.rps or {}) do
        rpMap[rp.name] = rp
    end

    for _, name in ipairs(rpNames) do
        local rp = rpMap[name]
        if rp then
            minLat = math.min(minLat, rp.latitude)
            maxLat = math.max(maxLat, rp.latitude)
            minLon = math.min(minLon, rp.longitude)
            maxLon = math.max(maxLon, rp.longitude)
        end
    end
    return minLat, maxLat, minLon, maxLon
end

local minLat, maxLat, minLon, maxLon =
    getRPBounds({'SPAWN-RP1','SPAWN-RP2','SPAWN-RP3','SPAWN-RP4'}, 'Red')

math.randomseed(os.time())
local lat = minLat + math.random() * (maxLat - minLat)
local lon = minLon + math.random() * (maxLon - minLon)
```

---

## Pattern 3 — Timed Reinforcement Wave

Schedule units to arrive at a specific scenario time.

```lua
--- Register a reinforcement wave to arrive at triggerTime.
--- @param waveName    string
--- @param triggerTime number  Unix timestamp (use ScenEdit_CurrentTime() + offset)
--- @param units       table   Array of unit definition tables
--- @param side        string
local function scheduleReinforcement(waveName, triggerTime, units, side)
    local ok, ev = pcall(ScenEdit_SetEvent, waveName, {
        mode='add', IsActive=true, IsRepeatable=false,
    })
    if not ok then return end

    pcall(ScenEdit_SetTrigger, {
        mode='add', type='Time', name=waveName..'_T', time=triggerTime,
    })
    pcall(ScenEdit_SetEventTrigger, ev.guid, {mode='add', name=waveName..'_T'})

    -- Build unit spawn script
    local lines = {}
    for i, u in ipairs(units) do
        lines[#lines+1] = string.format(
            'pcall(ScenEdit_AddUnit,{side="%s",type="%s",name="%s",dbid=%d,'..
            'latitude=%f,longitude=%f,heading=%d,speed=%d,proficiency="%s"})',
            side, u.type, u.name, u.dbid,
            u.lat, u.lon, u.heading or 270, u.speed or 15, u.prof or 'Regular')
    end
    lines[#lines+1] = string.format(
        'ScenEdit_SpecialMessage("%s","Reinforcements arrived: %s")', side, waveName)

    local script = table.concat(lines, '\r\n')
    pcall(ScenEdit_SetAction, {
        mode='add', type='LuaScript', name=waveName..'_A', ScriptText=script,
    })
    pcall(ScenEdit_SetEventAction, ev.guid, {mode='add', name=waveName..'_A'})
end

-- Usage: wave arrives 4 hours from now
scheduleReinforcement('Wave2', ScenEdit_CurrentTime() + 4*3600, {
    {type='Ship', name='Reinforce-DDG', dbid=2869, lat=35.0, lon=27.5},
    {type='Ship', name='Reinforce-FFG', dbid=232,  lat=35.1, lon=27.5},
}, 'Blue')
```

---

## Pattern 4 — Triggered Spawn (On Event)

Spawn units when a specific game event fires (enemy detected, objective reached, etc.).

```lua
-- Step 1: Create the event (in GameSetup)
local ok, ev = pcall(ScenEdit_SetEvent, 'EnemyDetectedSpawn', {
    mode='add', IsActive=true, IsRepeatable=false,
})

-- Step 2: Connect to a detection trigger
pcall(ScenEdit_SetTrigger, {
    mode='add', type='DetectedContact', name='RedContactTrigger',
    Side='Blue', TargetSide='Red',
})
pcall(ScenEdit_SetEventTrigger, ev.guid, {mode='add', name='RedContactTrigger'})

-- Step 3: Action spawns reinforcement
local spawnScript =
    'if ScenEdit_GetKeyValue("RESPONSE_SENT") == "1" then return end\r\n'..
    'ScenEdit_SetKeyValue("RESPONSE_SENT","1")\r\n'..
    'pcall(ScenEdit_AddUnit,{\r\n'..
    '    side="Blue",type="Aircraft",name="Alert-1",dbid=1479,loadoutid=21640,\r\n'..
    '    Base="USS Nimitz (CVN-68)",latitude=34.0,longitude=28.0,proficiency="Veteran"\r\n'..
    '})\r\n'..
    'ScenEdit_SpecialMessage("Blue","Alert aircraft scrambled!")\r\n'

pcall(ScenEdit_SetAction, {
    mode='add', type='LuaScript', name='EnemyDetectedSpawn_A', ScriptText=spawnScript,
})
pcall(ScenEdit_SetEventAction, ev.guid, {mode='add', name='EnemyDetectedSpawn_A'})
```

---

## Pattern 5 — Spawn-on-Destroy Replacement

When a unit is destroyed, spawn a replacement. Useful for persistent patrols.

```lua
-- Track unit by KeyStore GUID key
ScenEdit_SetKeyValue('PATROL_1_GUID', spawnedUnit.guid)

-- UnitDestroyed event with replacement logic
local replaceScript =
    'local u = ScenEdit_UnitX()\r\n'..
    'if not u then return end\r\n'..
    '-- Check if this is our watched unit\r\n'..
    'if u.guid ~= ScenEdit_GetKeyValue("PATROL_1_GUID") then return end\r\n'..
    '\r\n'..
    '-- Spawn replacement with random offset\r\n'..
    'math.randomseed(os.time())\r\n'..
    'local lat = 35.0 + (math.random()-0.5)*0.2\r\n'..
    'local lon = 27.0 + (math.random()-0.5)*0.2\r\n'..
    'local ok, newUnit = pcall(ScenEdit_AddUnit,{\r\n'..
    '    side="Blue",type="Ship",name="Patrol-1",dbid=2869,\r\n'..
    '    latitude=lat,longitude=lon,heading=270,speed=18\r\n'..
    '})\r\n'..
    'if ok and newUnit then\r\n'..
    '    ScenEdit_SetKeyValue("PATROL_1_GUID", newUnit.guid)\r\n'..
    '    pcall(ScenEdit_AssignUnitToMission, newUnit.guid, "Blue NavPat")\r\n'..
    'end\r\n'
```

---

## Pattern 6 — Spawning Multiple Units With Spacing

Spread units in a grid or line formation.

```lua
--- Spawn a line of ships spaced `spacingNm` nm apart.
--- @param side       string
--- @param originLat  number
--- @param originLon  number
--- @param heading    number  Formation heading (degrees)
--- @param count      number
--- @param spacingNm  number  NM between units
--- @param unitDef    table   {name, dbid, speed, proficiency}
local function spawnLine(side, originLat, originLon, heading, count, spacingNm, unitDef)
    local NM_TO_DEG = 1.0 / 60.0
    local headRad   = math.rad(heading)
    local dLat      = math.cos(headRad) * spacingNm * NM_TO_DEG
    local dLon      = math.sin(headRad) * spacingNm * NM_TO_DEG

    for i = 1, count do
        local lat = originLat + (i - 1) * dLat
        local lon = originLon + (i - 1) * dLon
        local ok, u = pcall(ScenEdit_AddUnit, {
            side        = side,
            type        = 'Ship',
            name        = unitDef.name .. '-' .. i,
            dbid        = unitDef.dbid,
            latitude    = lat,
            longitude   = lon,
            heading     = heading,
            speed       = unitDef.speed or 15,
            proficiency = unitDef.proficiency or 'Regular',
        })
        if ok and u then
            ScenEdit_SetKeyValue('LINE_UNIT_' .. i, u.guid)
        end
    end
end

-- Spawn 4 destroyers in a line, 5nm apart, heading northeast
spawnLine('Blue', 34.0, 28.0, 045, 4, 5, {name='Escort', dbid=2869, speed=18})
```

---

## Pattern 7 — Randomized Civilian Shipping

Spawn civilian traffic with realistic random parameters.

```lua
local CIVILIAN  = 'Civilian'
local SHIP_DBID = 1803   -- Generic merchant
local NAMES     = {'MV Artemis','MV Borealis','MV Corsair','MV Delphi','MV Echo'}

-- Bounding box (e.g., Red Sea)
local LAT_MIN, LAT_MAX = 12.5, 27.5
local LON_MIN, LON_MAX = 32.5, 43.5

math.randomseed(os.time())

for i = 1, 5 do
    local lat = LAT_MIN + math.random() * (LAT_MAX - LAT_MIN)
    local lon = LON_MIN + math.random() * (LON_MAX - LON_MIN)
    local hdg = math.random(0, 359)
    local spd = math.random(8, 16)

    local ok, ship = pcall(ScenEdit_AddUnit, {
        side      = CIVILIAN,
        type      = 'Ship',
        name      = NAMES[i],
        dbid      = SHIP_DBID,
        latitude  = lat,
        longitude = lon,
        heading   = hdg,
        speed     = spd,
    })
    if ok and ship then
        pcall(ScenEdit_SetEMCON, 'Unit', ship.guid, 'Radar=Passive;Sonar=Passive')
    end
end
```

---

## Anti-Patterns to Avoid

| Anti-pattern | Problem | Fix |
|-------------|---------|-----|
| Spawning in a loop without delay | All units appear at exact same time/location | Stagger via timed events or spacing offset |
| No nil-check on spawn return | Script crashes if DB ID invalid | Always check `if ok and unit then` |
| Hardcoded lat/lon strings | Brittle; hard to tune | Use constants at top of script |
| No GUID storage | Can't reference unit later | `ScenEdit_SetKeyValue(key, unit.guid)` immediately |
| Spawning aircraft without `loadoutid` | No weapons | Always specify `loadoutid` for aircraft |
| Spawning inside a mission area without assigning | Unit spawns but ignores mission | `ScenEdit_AssignUnitToMission` after spawn |
