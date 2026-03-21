# Random Events Patterns

Patterns for introducing randomness into CMO scenarios: random weather, random unit positions, random event timing, random civilian traffic, and random encounter generation.

---

## Randomization Foundations in CMO Lua

CMO uses Lua 5.1. The `math.random()` function works as expected:

```lua
math.randomseed(os.time())   -- always seed before a random session

math.random()          -- float in [0, 1)
math.random(n)         -- integer in [1, n]
math.random(m, n)      -- integer in [m, n]

-- Float in [min, max]:
local function randFloat(min, max) return min + math.random() * (max - min) end

-- Weighted random pick (weights must sum to 1.0):
local function weightedPick(items)
    local r = math.random()
    local cumulative = 0
    for _, item in ipairs(items) do
        cumulative = cumulative + item.weight
        if r <= cumulative then return item end
    end
    return items[#items]  -- fallback
end
```

> **Important:** `os.time()` gives the real-world Unix time, not scenario time. For scenario-time-seeded randomness, use `ScenEdit_CurrentTime()` mixed with `os.time()`.

---

## Pattern 1 — Random Weather

```lua
local WEATHER_PRESETS = {
    {name='Clear',     weight=0.30, rain=0, sea=1, windMax=10},
    {name='Overcast',  weight=0.25, rain=0, sea=2, windMax=20},
    {name='LightRain', weight=0.20, rain=1, sea=3, windMax=25},
    {name='HeavyRain', weight=0.15, rain=3, sea=4, windMax=35},
    {name='Storm',     weight=0.10, rain=5, sea=5, windMax=50},
}

local function applyRandomWeather()
    math.randomseed(os.time() + ScenEdit_CurrentTime())

    -- Weighted pick
    local r = math.random()
    local cumulative = 0
    local preset = WEATHER_PRESETS[#WEATHER_PRESETS]
    for _, p in ipairs(WEATHER_PRESETS) do
        cumulative = cumulative + p.weight
        if r <= cumulative then preset = p; break end
    end

    local windDir = math.random(0, 359)
    local windSpd = math.random(0, preset.windMax)

    pcall(ScenEdit_SetWeather, {
        WindDir   = windDir,
        WindSpeed = windSpd,
        Rainfall  = preset.rain,
        SeaState  = preset.sea,
    })

    -- Store for reference
    ScenEdit_SetKeyValue('WEATHER_NAME', preset.name)
    ScenEdit_SetKeyValue('WEATHER_SEA',  tostring(preset.sea))

    pcall(ScenEdit_SpecialMessage, 'Blue',
        string.format('METOC: %s | Wind %03d°/%d kt | Sea state %d',
            preset.name, windDir, windSpd, preset.sea))
end
```

**Register as a repeating event every 6 hours:**
```lua
local ok, ev = pcall(ScenEdit_SetEvent, 'WeatherCycle', {
    mode='add', IsActive=true, IsRepeatable=true,
})
if ok then
    pcall(ScenEdit_SetTrigger, {mode='add', type='RegularTime',
        name='WeatherTimer', interval=6*3600})
    pcall(ScenEdit_SetEventTrigger, ev.guid, {mode='add', name='WeatherTimer'})
    -- Build inline script here (see csar_system.lua for the pattern)
end
```

---

## Pattern 2 — Random Unit Starting Positions

Scatter units randomly within a zone at scenario start:

```lua
--- Spawn `count` units in a bounding box with random positions.
--- @param side     string
--- @param count    number
--- @param unitDef  table   {type, baseName, dbid, ...}
--- @param bounds   table   {minLat, maxLat, minLon, maxLon}
local function scatterSpawn(side, count, unitDef, bounds)
    math.randomseed(os.time())
    local spawned = {}

    for i = 1, count do
        local lat = bounds.minLat + math.random() * (bounds.maxLat - bounds.minLat)
        local lon = bounds.minLon + math.random() * (bounds.maxLon - bounds.minLon)
        local hdg = math.random(0, 359)
        local spd = unitDef.speed or math.random(5, 20)

        local params = {
            side        = side,
            type        = unitDef.type,
            name        = string.format('%s-%02d', unitDef.baseName, i),
            dbid        = unitDef.dbid,
            latitude    = lat,
            longitude   = lon,
            heading     = hdg,
            speed       = spd,
            proficiency = unitDef.proficiency or 'Regular',
        }
        if unitDef.loadoutid then params.loadoutid = unitDef.loadoutid end
        if unitDef.base      then params.Base      = unitDef.base      end

        local ok, unit = pcall(ScenEdit_AddUnit, params)
        if ok and unit then
            spawned[#spawned+1] = unit.guid
            ScenEdit_SetKeyValue(unitDef.baseName .. '_' .. i .. '_GUID', unit.guid)
        end
    end
    return spawned
end

-- Example: scatter 6 Red patrol boats in the Arabian Gulf
scatterSpawn('Red', 6, {type='Ship', baseName='PatBoat', dbid=1502, speed=25},
    {minLat=25.0, maxLat=27.5, minLon=50.0, maxLon=56.5})
```

---

## Pattern 3 — Random Event Timing

Instead of fixed event times, schedule events at random intervals:

```lua
--- Schedule a repeating event at randomized intervals within a range.
--- Each time the event fires, it reschedules itself.
--- @param minInterval number  Minimum seconds between firings
--- @param maxInterval number  Maximum seconds between firings
local function scheduleRandomEvent(eventName, minInterval, maxInterval, scriptText)
    math.randomseed(os.time())
    local interval = minInterval + math.random() * (maxInterval - minInterval)
    local nextTime = ScenEdit_CurrentTime() + interval

    local ok, ev = pcall(ScenEdit_SetEvent, eventName, {
        mode='add', IsActive=true, IsRepeatable=false,  -- fires once, self-reschedules
    })
    if not ok then return end

    pcall(ScenEdit_SetTrigger, {mode='add', type='Time', name=eventName..'_T', time=nextTime})
    pcall(ScenEdit_SetEventTrigger, ev.guid, {mode='add', name=eventName..'_T'})

    -- Wrap script with self-rescheduling logic
    local fullScript =
        scriptText .. '\r\n'..
        '-- Reschedule\r\n'..
        'math.randomseed(os.time())\r\n'..
        'local nextInterval = ' .. minInterval .. ' + math.random() * ' ..
            (maxInterval - minInterval) .. '\r\n'..
        'local nextT = ScenEdit_CurrentTime() + nextInterval\r\n'..
        'local bok, bev = pcall(ScenEdit_SetEvent,"' .. eventName .. '_Next",{\r\n'..
        '    mode="add",IsActive=true,IsRepeatable=false})\r\n'..
        'if bok then\r\n'..
        '    pcall(ScenEdit_SetTrigger,{mode="add",type="Time",name="'..eventName..'_NT",time=nextT})\r\n'..
        '    pcall(ScenEdit_SetEventTrigger,bev.guid,{mode="add",name="'..eventName..'_NT"})\r\n'..
        '    -- (re-add same action to new event)\r\n'..
        'end\r\n'

    pcall(ScenEdit_SetAction, {mode='add', type='LuaScript', name=eventName..'_A',
        ScriptText=fullScript})
    pcall(ScenEdit_SetEventAction, ev.guid, {mode='add', name=eventName..'_A'})
end

-- Example: random intel report between 1 and 3 hours
scheduleRandomEvent('RandomIntel', 3600, 10800,
    'ScenEdit_SpecialMessage("Blue","SIGINT: Encrypted radio traffic detected.")\r\n')
```

---

## Pattern 4 — Random Encounter Generator

Spawn a random threat encounter during scenario play:

```lua
local ENCOUNTERS = {
    {
        name    = 'Patrol Boat Skirmish',
        weight  = 0.40,
        units   = {{type='Ship', dbid=1502, count=2}},  -- Fast Attack Craft
        message = 'Unknown patrol craft approaching!',
    },
    {
        name    = 'Air Contact',
        weight  = 0.30,
        units   = {{type='Aircraft', dbid=300, loadoutid=21500, count=1}},
        message = 'Unidentified aircraft on intercept course!',
    },
    {
        name    = 'Submarine Contact',
        weight  = 0.20,
        units   = {{type='Submarine', dbid=228, count=1}},
        message = 'SONAR: Possible submarine contact!',
    },
    {
        name    = 'Nothing',
        weight  = 0.10,
        units   = {},
        message = 'SIGINT: False alarm — no contact.',
    },
}

local function generateEncounter(spawnLat, spawnLon, side, alertSide)
    math.randomseed(os.time() + ScenEdit_CurrentTime())

    -- Pick encounter type
    local r = math.random()
    local cumulative = 0
    local encounter = ENCOUNTERS[#ENCOUNTERS]
    for _, e in ipairs(ENCOUNTERS) do
        cumulative = cumulative + e.weight
        if r <= cumulative then encounter = e; break end
    end

    if encounter.name == 'Nothing' then
        pcall(ScenEdit_SpecialMessage, alertSide, encounter.message)
        return
    end

    -- Spawn units with small random offsets
    local spawned = {}
    for _, uDef in ipairs(encounter.units) do
        for i = 1, uDef.count do
            local lat = spawnLat + (math.random() - 0.5) * 0.1
            local lon = spawnLon + (math.random() - 0.5) * 0.1
            local params = {
                side      = side,
                type      = uDef.type,
                name      = encounter.name .. '-' .. i,
                dbid      = uDef.dbid,
                latitude  = lat,
                longitude = lon,
                heading   = math.random(0, 359),
                speed     = math.random(10, 25),
            }
            if uDef.loadoutid then params.loadoutid = uDef.loadoutid end
            local ok, unit = pcall(ScenEdit_AddUnit, params)
            if ok and unit then spawned[#spawned+1] = unit.guid end
        end
    end

    pcall(ScenEdit_SpecialMessage, alertSide,
        string.format('ENCOUNTER: %s — %s', encounter.name, encounter.message))
end
```

---

## Pattern 5 — Random Mechanical Failure / Attrition

Randomly damage or mission-abort aircraft during operations:

```lua
-- Runs on a RepeatTime trigger every 30 minutes
local FAILURE_CHANCE = 0.05   -- 5% chance per aircraft per 30 minutes

local function rollMechanicalFailures()
    math.randomseed(os.time())
    local ok, side = pcall(VP_GetSide, {Side='Blue'})
    if not ok or not side then return end

    for _, u in ipairs(side.units or {}) do
        if u.type == 'Aircraft' and u.mission and u.mission ~= '' then
            if math.random() < FAILURE_CHANCE then
                -- Abort mission and return to base
                pcall(ScenEdit_SetUnit, {guid=u.guid, mission=''})
                pcall(ScenEdit_SpecialMessage, 'Blue',
                    string.format('%s: mechanical abort — RTB for inspection.', u.name))
            end
        end
    end
end
```

---

## Tips for Reproducible Randomness

Sometimes you want a "random but repeatable" scenario (same seed = same events):

```lua
-- Seed from scenario start time only (not wall clock)
-- This gives same results on replay if started at same time
local seed = ScenEdit_CurrentTime()
math.randomseed(seed)
ScenEdit_SetKeyValue('RANDOM_SEED', tostring(seed))
print('[Random] Seed: ' .. seed)
```

To allow replays with the same random sequence, store and restore the seed from KeyStore.
