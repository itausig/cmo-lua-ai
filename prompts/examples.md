# CMO Lua AI — Prompt/Response Examples

> **Purpose:** These examples demonstrate ideal AI behavior when generating CMO Lua scripts. Use them as few-shot examples in your prompts, or as a quality benchmark for evaluating AI output.

---

## Example 1 — Patrol Mission for F-16s

**Prompt:**
> Create a patrol mission for a flight of 4 F-16s over the Strait of Hormuz. The patrol box should cover the strait. They should maintain 25,000 ft altitude and use the one-third rule.

**Response:**

```lua
--- ============================================================
--- Hormuz CAP Setup
--- Creates a 4-ship F-16 CAP patrol over the Strait of Hormuz.
--- ============================================================

-- ===== CONSTANTS =====
local SIDE       = 'USA'
local BASE_NAME  = 'Al Dhafra AB'
local F16_DBID   = 525         -- F-16C Block 50 (verify in DB viewer)
local F16_LOADOUT = 21600      -- BVR AAM loadout (verify in DB viewer)
local CAP_ALT    = '25000 FT'
local CAP_SPEED  = 450         -- knots

-- Patrol box corners (Strait of Hormuz)
local rpDefs = {
    {name='HORMUZ-RP1', lat=26.8, lon=56.0},
    {name='HORMUZ-RP2', lat=26.8, lon=57.2},
    {name='HORMUZ-RP3', lat=25.8, lon=57.2},
    {name='HORMUZ-RP4', lat=25.8, lon=56.0},
}

-- ===== REFERENCE POINTS =====
for _, rp in ipairs(rpDefs) do
    pcall(ScenEdit_AddReferencePoint, {
        side        = SIDE,
        name        = rp.name,
        latitude    = rp.lat,
        longitude   = rp.lon,
        highlighted = true,
    })
end

-- ===== SPAWN AIRCRAFT =====
local pilots = {'Viper-1','Viper-2','Viper-3','Viper-4'}
local guids  = {}

for i, callsign in ipairs(pilots) do
    local ok, ac = pcall(ScenEdit_AddUnit, {
        side        = SIDE,
        type        = 'Aircraft',
        name        = callsign,
        dbid        = F16_DBID,
        loadoutid   = F16_LOADOUT,
        Base        = BASE_NAME,
        latitude    = 25.25 + (i - 1) * 0.02,
        longitude   = 55.36,
        altitude    = CAP_ALT,
        proficiency = 'Veteran',
    })
    if ok and ac then
        guids[i] = ac.guid
        ScenEdit_SetKeyValue('VIPER_' .. i .. '_GUID', ac.guid)
    end
end

-- ===== CREATE PATROL MISSION =====
local ok, mission = pcall(ScenEdit_AddMission, SIDE, 'Hormuz CAP', 'patrol', {type='air'})
if not ok then
    print('[HormuzCAP] Failed to create mission: ' .. tostring(mission))
    return
end

ScenEdit_SetMission(SIDE, 'Hormuz CAP', {
    patrolzone     = {'HORMUZ-RP1','HORMUZ-RP2','HORMUZ-RP3','HORMUZ-RP4'},
    onethirdrule   = true,
    flightsize     = 2,
    minaircraftreq = 2,
    useflightsize  = true,
    checkzerofuel  = true,
    altitude       = CAP_ALT,
    speed          = CAP_SPEED,
})

-- Assign aircraft
for _, guid in ipairs(guids) do
    pcall(ScenEdit_AssignUnitToMission, guid, 'Hormuz CAP')
end

ScenEdit_SpecialMessage(SIDE, 'Hormuz CAP activated — 4× F-16C on station.')
print('[HormuzCAP] Mission setup complete.')
```

---

## Example 2 — Random Civilian Shipping

**Prompt:**
> Make a script that spawns 6 random civilian cargo ships in the Red Sea, with random headings and speeds. They should be on a neutral "Civilian" side and named with realistic vessel names.

**Response:**

```lua
--- ============================================================
--- Dynamic Civilian Shipping — Red Sea
--- Spawns randomized neutral merchant traffic.
--- ============================================================

local CIVILIAN_SIDE = 'Civilian'
local CARGO_DBID    = 1803    -- Generic Merchant (verify in DB viewer)

-- Red Sea bounding box
local LAT_MIN, LAT_MAX = 12.5, 27.5
local LON_MIN, LON_MAX = 32.5, 43.5

local VESSEL_NAMES = {
    'MV Adriatic Star', 'MV Baltic Horizon', 'MV Cape Everest',
    'MV Desert Wind',   'MV Eastern Sun',    'MV Falcon Spirit',
}

local SPAWN_COUNT = 6

--- Generate a random float in [min, max].
local function randFloat(min, max)
    return min + math.random() * (max - min)
end

math.randomseed(os.time())

for i = 1, SPAWN_COUNT do
    local lat     = randFloat(LAT_MIN, LAT_MAX)
    local lon     = randFloat(LON_MIN, LON_MAX)
    local heading = math.random(0, 359)
    local speed   = math.random(8, 16)   -- knots typical for merchant

    local ok, ship = pcall(ScenEdit_AddUnit, {
        side        = CIVILIAN_SIDE,
        type        = 'Ship',
        name        = VESSEL_NAMES[i],
        dbid        = CARGO_DBID,
        latitude    = lat,
        longitude   = lon,
        heading     = heading,
        speed       = speed,
        proficiency = 'Regular',
    })

    if ok and ship then
        ScenEdit_SetKeyValue('CIVIL_SHIP_' .. i, ship.guid)
        -- Set passive EMCON — civilians don't use military radar
        pcall(ScenEdit_SetEMCON, 'Unit', ship.guid, 'Radar=Passive;Sonar=Passive')
        print(string.format('[Civilian] Spawned %s at %.2f,%.2f hdg=%d spd=%d',
            VESSEL_NAMES[i], lat, lon, heading, speed))
    end
end

print(string.format('[Civilian] %d merchant vessels deployed in the Red Sea.', SPAWN_COUNT))
```

---

## Example 3 — CSAR System

**Prompt:**
> Write a CSAR system for downed pilots. When a Blue aircraft is destroyed, 60% chance the pilot survives and a rescue mission activates.

**Response:**

```lua
--- ============================================================
--- CSAR System — Pilot Recovery
--- Triggered by UnitDestroyed event for Blue aircraft.
--- Spawns downed pilot, activates rescue helicopter mission.
--- ============================================================

-- This script is the Action payload for a UnitDestroyed event
-- targeting Blue aircraft. Paste as ScriptText in the event action.

local BLUE_SIDE      = 'Blue'
local RESCUE_SIDE    = 'Blue'
local PILOT_DBID     = 259       -- Survivor/Downed Pilot facility (verify in DB viewer)
local RESCUE_HEL_GUID_KEY = 'CSAR_HEL_GUID'
local SURVIVAL_CHANCE = 0.60     -- 60% survival probability
local RESCUE_WINDOW_SEC = 7200   -- 2-hour rescue window

math.randomseed(os.time())

local function spawnDownedPilot(lat, lon, pilotName)
    local ok, pilot = pcall(ScenEdit_AddUnit, {
        side      = BLUE_SIDE,
        type      = 'Facility',
        name      = pilotName,
        dbid      = PILOT_DBID,
        latitude  = lat,
        longitude = lon,
    })
    if not ok then
        print('[CSAR] Failed to spawn pilot: ' .. tostring(pilot))
        return nil
    end
    return pilot
end

local function createSARReferencePoint(lat, lon, name)
    pcall(ScenEdit_AddReferencePoint, {
        side        = BLUE_SIDE,
        name        = name,
        latitude    = lat,
        longitude   = lon,
        highlighted = true,
    })
end

local function activateRescueMission(pilotGuid)
    -- Activate pre-built rescue mission (created in GameSetup)
    local missionName = 'CSAR Rescue'
    pcall(ScenEdit_SetMission, RESCUE_SIDE, missionName, {isactive=true})

    -- Assign rescue helicopter
    local helGuid = ScenEdit_GetKeyValue(RESCUE_HEL_GUID_KEY)
    if helGuid ~= '' then
        pcall(ScenEdit_AssignUnitToMission, helGuid, missionName)
    end
end

local function scheduleRescueExpiry(pilotGuid, windowSec)
    -- Register a timed event to remove the pilot if not rescued
    local expiryTime = ScenEdit_CurrentTime() + windowSec
    local eventName  = 'CSARExpiry_' .. string.sub(pilotGuid, 1, 8)

    local ok, ev = pcall(ScenEdit_SetEvent, eventName, {
        mode         = 'add',
        IsActive     = true,
        IsRepeatable = false,
    })
    if not ok then return end

    pcall(ScenEdit_SetTrigger, {mode='add', type='Time', name=eventName..'_T',
        time=expiryTime})
    pcall(ScenEdit_SetEventTrigger, ev.guid, {mode='add', name=eventName..'_T'})

    local script = string.format(
        'local u = ScenEdit_GetUnit({guid="%s"})\r\n' ..
        'if u then\r\n' ..
        '    ScenEdit_DeleteUnit({guid="%s"})\r\n' ..
        '    ScenEdit_SpecialMessage("Blue","CSAR window expired — pilot lost.")\r\n' ..
        '    ScenEdit_SetScore("Blue", ScenEdit_GetScore("Blue") - 50, "Pilot lost")\r\n' ..
        'end\r\n',
        pilotGuid, pilotGuid
    )
    pcall(ScenEdit_SetAction, {mode='add', type='LuaScript',
        name=eventName..'_A', ScriptText=script})
    pcall(ScenEdit_SetEventAction, ev.guid, {mode='add', name=eventName..'_A'})
end

-- ===== MAIN CSAR HANDLER =====
local ok, err = pcall(function()
    local destroyedUnit = ScenEdit_UnitX()
    if not destroyedUnit then return end
    if destroyedUnit.type ~= 'Aircraft' then return end

    local lat  = destroyedUnit.latitude
    local lon  = destroyedUnit.longitude
    local name = destroyedUnit.name

    -- Roll survival
    if math.random() > SURVIVAL_CHANCE then
        ScenEdit_SpecialMessage(BLUE_SIDE,
            string.format('%s lost — no ejection detected.', name))
        return
    end

    -- Spawn downed pilot
    local pilotName = 'CSAR: ' .. name
    local pilot = spawnDownedPilot(lat, lon, pilotName)
    if not pilot then return end

    -- Create SAR reference point
    local rpName = 'SAR-' .. string.sub(pilot.guid, 1, 6)
    createSARReferencePoint(lat, lon, rpName)

    -- Persist pilot GUID for rescue tracking
    ScenEdit_SetKeyValue('CSAR_PILOT_GUID', pilot.guid)

    -- Activate rescue mission
    activateRescueMission(pilot.guid)

    -- Schedule rescue window expiry
    scheduleRescueExpiry(pilot.guid, RESCUE_WINDOW_SEC)

    ScenEdit_SpecialMessage(BLUE_SIDE,
        string.format('%s ejected! CSAR activated — %d-minute rescue window.',
            name, RESCUE_WINDOW_SEC / 60))
    ScenEdit_SetScore(BLUE_SIDE, ScenEdit_GetScore(BLUE_SIDE) - 25, 'Aircraft lost')
end)

if not ok then
    print('[CSAR] Handler error: ' .. tostring(err))
    ScenEdit_SetKeyValue('CSAR_LAST_ERROR', tostring(err))
end
```

---

## Example 4 — Submarine Detection Event

**Prompt:**
> Create an event that triggers when any Red submarine is detected by Blue. Send a special message and activate an ASW prosecution mission.

**Response:**

```lua
--- ============================================================
--- Red Sub Detection Event — Setup Script
--- Run in GameSetup to register the detection event.
--- ============================================================

local function setupSubDetectionEvent()
    -- Create the event
    local ok, ev = pcall(ScenEdit_SetEvent, 'RedSubDetected', {
        mode         = 'add',
        IsActive     = true,
        IsRepeatable = true,
    })
    if not ok then
        print('[ASW] Failed to create event: ' .. tostring(ev))
        return
    end

    -- Trigger: Blue detects a contact classified as submarine
    pcall(ScenEdit_SetTrigger, {
        mode          = 'add',
        type          = 'DetectedContact',
        name          = 'BlueDetectsSub',
        Side          = 'Blue',
        TargetSide    = 'Red',
        TargetType    = 'Submarine',   -- fires only on sub contacts
    })
    pcall(ScenEdit_SetEventTrigger, ev.guid, {mode='add', name='BlueDetectsSub'})

    -- Action: Lua script to notify and activate prosecution
    local actionScript =
        'local contact = ScenEdit_UnitC()\r\n'..
        'if not contact then return end\r\n'..
        '\r\n'..
        '-- Avoid spamming — only react if not already prosecuting\r\n'..
        'if ScenEdit_GetKeyValue("ASW_ACTIVE") == "1" then return end\r\n'..
        'ScenEdit_SetKeyValue("ASW_ACTIVE", "1")\r\n'..
        '\r\n'..
        '-- Store contact location for the prosecution mission\r\n'..
        'local rpOk = pcall(ScenEdit_AddReferencePoint, {\r\n'..
        '    side=\'Blue\', name=\'SUB-CONTACT\',\r\n'..
        '    latitude=contact.latitude, longitude=contact.longitude,\r\n'..
        '    highlighted=true\r\n'..
        '})\r\n'..
        '\r\n'..
        '-- Activate pre-built ASW prosecution mission\r\n'..
        'pcall(ScenEdit_SetMission, \'Blue\', \'ASW Prosecution\', {isactive=true})\r\n'..
        '\r\n'..
        'ScenEdit_SpecialMessage(\'Blue\',\r\n'..
        '    string.format(\'SONAR CONTACT! Possible submarine at %.3f, %.3f. ASW prosecution activated.\',\r\n'..
        '        contact.latitude, contact.longitude))\r\n'

    pcall(ScenEdit_SetAction, {
        mode       = 'add',
        type       = 'LuaScript',
        name       = 'OnRedSubDetected',
        ScriptText = actionScript,
    })
    pcall(ScenEdit_SetEventAction, ev.guid, {mode='add', name='OnRedSubDetected'})

    print('[ASW] Sub detection event registered.')
end

setupSubDetectionEvent()
```

---

## Example 5 — IADS Behavior Script

**Prompt:**
> Script an Integrated Air Defense System (IADS) that turns radars on when threats are detected and goes dark when aircraft are shot down nearby. Check every 60 seconds.

**Response:**

```lua
--- ============================================================
--- IADS Radar Management — Adaptive EMCON
--- Runs every 60 seconds. Activates SAM radars when threats
--- are detected; goes dark when an SAM battery is killed.
--- ============================================================

-- ===== CONSTANTS =====
local RED_SIDE        = 'Red'
local THREAT_RANGE_NM = 150     -- activate when Blue contacts within this range
local SAM_GUID_KEYS   = {       -- KeyStore keys for each SAM battery
    'IADS_SA10_1_GUID',
    'IADS_SA10_2_GUID',
    'IADS_SA6_1_GUID',
    'IADS_EWR_GUID',
}
local RADAR_ACTIVE  = 'Radar=Active;OECM=Active'
local RADAR_PASSIVE = 'Radar=Passive;OECM=Passive'

--- Safely get a unit by KeyStore key.
--- @param key string
--- @return Unit|nil
local function getUnitByKey(key)
    local guid = ScenEdit_GetKeyValue(key)
    if not guid or guid == '' then return nil end
    local ok, u = pcall(ScenEdit_GetUnit, {guid=guid})
    return (ok and u) or nil
end

--- Check if Blue has any contacts within a given range of a point.
--- @param lat number
--- @param lon number
--- @param rangeNm number
--- @return boolean
local function threatNearby(lat, lon, rangeNm)
    local ok, redSide = pcall(VP_GetSide, {Side=RED_SIDE})
    if not ok or not redSide then return false end
    for _, contact in ipairs(redSide.contacts or {}) do
        if contact.latitude and contact.longitude then
            local ok2, dist = pcall(Tool_Range,
                {latitude=lat, longitude=lon},
                {latitude=contact.latitude, longitude=contact.longitude})
            if ok2 and type(dist) == 'number' and dist <= rangeNm then
                return true
            end
        end
    end
    return false
end

--- Set EMCON on all alive SAM batteries.
--- @param emconStr string
local function setAllIADS(emconStr)
    for _, key in ipairs(SAM_GUID_KEYS) do
        local unit = getUnitByKey(key)
        if unit then
            pcall(ScenEdit_SetEMCON, 'Unit', unit.guid, emconStr)
        end
    end
end

-- ===== MAIN IADS LOGIC =====
local ok, err = pcall(function()
    local threatDetected = false

    for _, key in ipairs(SAM_GUID_KEYS) do
        local unit = getUnitByKey(key)
        if unit then
            local threat = threatNearby(unit.latitude, unit.longitude, THREAT_RANGE_NM)
            if threat then
                threatDetected = true
                -- Activate this battery's radar
                pcall(ScenEdit_SetEMCON, 'Unit', unit.guid, RADAR_ACTIVE)
                print(string.format('[IADS] %s radar ACTIVE — threat within %d nm', unit.name, THREAT_RANGE_NM))
            else
                -- No threat nearby — go dark to avoid detection
                pcall(ScenEdit_SetEMCON, 'Unit', unit.guid, RADAR_PASSIVE)
                print(string.format('[IADS] %s radar PASSIVE — no threat', unit.name))
            end
        end
    end

    -- Update IADS state flag
    ScenEdit_SetKeyValue('IADS_HOT', threatDetected and '1' or '0')
end)

if not ok then
    print('[IADS] Error: ' .. tostring(err))
    ScenEdit_SetKeyValue('IADS_ERROR', tostring(err))
end
```

---

## Example 6 — Timed Posture Change

**Prompt:**
> Change Red's posture toward Blue from Neutral to Hostile exactly 4 hours after the scenario starts. Send a message to both sides when it happens.

**Response:**

```lua
--- ============================================================
--- Posture Escalation Event — Setup Script
--- Run in GameSetup. Schedules Neutral->Hostile escalation
--- at T+4 hours.
--- ============================================================

local HOURS = 4
local triggerTime = ScenEdit_CurrentTime() + (HOURS * 3600)

-- Create the escalation event
local ok, ev = pcall(ScenEdit_SetEvent, 'PostureEscalation', {
    mode         = 'add',
    IsActive     = true,
    IsRepeatable = false,
})
if not ok then
    print('[Posture] Failed to create event: ' .. tostring(ev))
    return
end

-- Time trigger
pcall(ScenEdit_SetTrigger, {
    mode = 'add',
    type = 'Time',
    name = 'EscalationTimer',
    time = triggerTime,
})
pcall(ScenEdit_SetEventTrigger, ev.guid, {mode='add', name='EscalationTimer'})

-- Action: change posture + notifications
local script =
    '-- Escalate to Hostile\r\n'..
    'pcall(ScenEdit_SetSidePosture, "Red", "Blue", "H")\r\n'..
    'pcall(ScenEdit_SetSidePosture, "Blue", "Red", "H")\r\n'..
    '\r\n'..
    '-- Notify both sides\r\n'..
    'ScenEdit_SpecialMessage("Blue",\r\n'..
    '    "FLASH TRAFFIC: Diplomatic relations severed. Red forces are now HOSTILE.")\r\n'..
    'ScenEdit_SpecialMessage("Red",\r\n'..
    '    "WAR ORDERS RECEIVED: All Blue forces are designated hostile.")\r\n'..
    '\r\n'..
    '-- Unlock weapons\r\n'..
    'pcall(ScenEdit_SetDoctrine, {side="Red"}, {\r\n'..
    '    weapon_control_status_air=0,\r\n'..
    '    weapon_control_status_surface=0,\r\n'..
    '})\r\n'..
    '\r\n'..
    'ScenEdit_SetKeyValue("WAR_START_TIME", tostring(ScenEdit_CurrentTime()))\r\n'..
    'print("[Posture] Escalation to Hostile complete.")\r\n'

pcall(ScenEdit_SetAction, {
    mode       = 'add',
    type       = 'LuaScript',
    name       = 'EscalateToHostile',
    ScriptText = script,
})
pcall(ScenEdit_SetEventAction, ev.guid, {mode='add', name='EscalateToHostile'})

print(string.format('[Posture] Escalation scheduled for T+%d hours.', HOURS))
```

---

## Example 7 — VLS Magazine Resupply

**Prompt:**
> Write a resupply script that reloads all Blue ships' VLS magazines to full capacity. Run it when the player triggers a special action.

**Response:**

```lua
--- ============================================================
--- VLS Resupply — Reload All Blue Ships
--- Triggered by player special action 'Resupply Fleet'.
--- Respects a 2-hour cooldown between resupply operations.
--- ============================================================

local BLUE_SIDE     = 'Blue'
local COOLDOWN_SEC  = 7200   -- 2 hours between resupplies
local COOLDOWN_KEY  = 'RESUPPLY_LAST_TIME'

local function canResupply()
    local lastTime = tonumber(ScenEdit_GetKeyValue(COOLDOWN_KEY)) or 0
    return (ScenEdit_CurrentTime() - lastTime) >= COOLDOWN_SEC
end

local function resupplyUnit(unit)
    if unit.type ~= 'Ship' then return 0 end
    local reloaded = 0
    for _, magazine in ipairs(unit.magazines or {}) do
        for _, weapon in ipairs(magazine.weapons or {}) do
            if weapon.maxcap and weapon.current < weapon.maxcap then
                -- Reload weapon to full capacity
                local ok = pcall(ScenEdit_SetUnit, {
                    guid      = unit.guid,
                    magazines = {
                        {
                            guid   = magazine.guid,
                            weapons = {{
                                wpnid  = weapon.id,
                                number = weapon.maxcap,
                            }}
                        }
                    }
                })
                if ok then reloaded = reloaded + 1 end
            end
        end
    end
    return reloaded
end

-- ===== MAIN RESUPPLY HANDLER =====
local ok, err = pcall(function()
    if not canResupply() then
        local remaining = COOLDOWN_SEC - (ScenEdit_CurrentTime() -
            (tonumber(ScenEdit_GetKeyValue(COOLDOWN_KEY)) or 0))
        ScenEdit_SpecialMessage(BLUE_SIDE,
            string.format('Resupply unavailable — cooldown: %d minutes remaining.',
                math.ceil(remaining / 60)))
        return
    end

    local ok2, side = pcall(VP_GetSide, {Side=BLUE_SIDE})
    if not ok2 or not side then return end

    local totalShips   = 0
    local totalReloads = 0

    for _, unit in ipairs(side.units or {}) do
        if unit.type == 'Ship' then
            totalShips  = totalShips + 1
            totalReloads = totalReloads + resupplyUnit(unit)
        end
    end

    ScenEdit_SetKeyValue(COOLDOWN_KEY, tostring(ScenEdit_CurrentTime()))

    ScenEdit_SpecialMessage(BLUE_SIDE,
        string.format('Fleet resupply complete. %d ships serviced, %d weapon bays reloaded.',
            totalShips, totalReloads))
    print(string.format('[Resupply] %d ships, %d weapon reloads', totalShips, totalReloads))
end)

if not ok then
    print('[Resupply] Error: ' .. tostring(err))
end
```

---

## Example 8 — Dynamic Weather System

**Prompt:**
> Create a dynamic weather system that changes every 6 hours with realistic random conditions: wind speed/direction, rain, sea state.

**Response:**

```lua
--- ============================================================
--- Dynamic Weather System
--- Changes weather conditions every 6 hours.
--- Run the setup function in GameSetup.
--- ============================================================

local WEATHER_INTERVAL_SEC = 6 * 3600
local WEATHER_EVENT_NAME   = 'WeatherCycle'

-- Weather condition presets (index 1 = fine, higher = worse)
local WEATHER_PRESETS = {
    {name='Clear',       rain=0,  seaState=1, desc='Clear skies, calm seas'},
    {name='Overcast',    rain=0,  seaState=2, desc='Overcast, light swell'},
    {name='Light Rain',  rain=1,  seaState=3, desc='Light rain, moderate swell'},
    {name='Heavy Rain',  rain=3,  seaState=4, desc='Heavy rain, rough seas'},
    {name='Storm',       rain=5,  seaState=5, desc='Storm conditions, high seas'},
    {name='Severe',      rain=5,  seaState=6, desc='Severe storm — all ops affected'},
}

local function applyWeather()
    -- Pick a random preset (weighted toward moderate conditions)
    math.randomseed(os.time())
    local roll    = math.random(1, 10)
    local presetIdx = (roll <= 3) and 1 or
                      (roll <= 6) and 2 or
                      (roll <= 8) and 3 or
                      (roll <= 9) and 4 or
                               5
    local preset = WEATHER_PRESETS[presetIdx]

    local windDir   = math.random(0, 359)
    local windSpeed = math.random(0, preset.seaState * 8)   -- knots, scaled by sea state

    local ok = pcall(ScenEdit_SetWeather, {
        WindDir        = windDir,
        WindSpeed      = windSpeed,
        Rainfall       = preset.rain,
        SeaState       = preset.seaState,
    })

    if ok then
        ScenEdit_SetKeyValue('WEATHER_PRESET',    preset.name)
        ScenEdit_SetKeyValue('WEATHER_SEA_STATE', tostring(preset.seaState))
        ScenEdit_SetKeyValue('WEATHER_WIND_DIR',  tostring(windDir))
        ScenEdit_SetKeyValue('WEATHER_WIND_KTS',  tostring(windSpeed))

        ScenEdit_SpecialMessage('Blue',
            string.format('METOC UPDATE: %s | Wind %03d°/%d kt | Sea state %d',
                preset.desc, windDir, windSpeed, preset.seaState))
        print(string.format('[Weather] %s | wind=%03d/%dkt sea=%d',
            preset.name, windDir, windSpeed, preset.seaState))
    end
end

--- Call this from GameSetup to register the repeating weather event.
local function setupDynamicWeather()
    -- Apply immediately
    applyWeather()

    -- Create repeating event
    local ok, ev = pcall(ScenEdit_SetEvent, WEATHER_EVENT_NAME, {
        mode = 'add', IsActive=true, IsRepeatable=true,
    })
    if not ok then
        print('[Weather] Failed to create event: ' .. tostring(ev))
        return
    end

    pcall(ScenEdit_SetTrigger, {
        mode     = 'add',
        type     = 'RegularTime',
        name     = 'WeatherTimer',
        interval = WEATHER_INTERVAL_SEC,
    })
    pcall(ScenEdit_SetEventTrigger, ev.guid, {mode='add', name='WeatherTimer'})

    -- Action calls the applyWeather logic inline
    local script =
        'math.randomseed(os.time())\r\n'..
        'local roll = math.random(1,10)\r\n'..
        'local presets = {{name="Clear",rain=0,sea=1,desc="Clear skies, calm seas"},\r\n'..
        '  {name="Overcast",rain=0,sea=2,desc="Overcast, light swell"},\r\n'..
        '  {name="Light Rain",rain=1,sea=3,desc="Light rain, moderate swell"},\r\n'..
        '  {name="Heavy Rain",rain=3,sea=4,desc="Heavy rain, rough seas"},\r\n'..
        '  {name="Storm",rain=5,sea=5,desc="Storm conditions"}}\r\n'..
        'local idx=(roll<=3)and 1 or(roll<=6)and 2 or(roll<=8)and 3 or(roll<=9)and 4 or 5\r\n'..
        'local p=presets[idx]\r\n'..
        'local wd=math.random(0,359)\r\n'..
        'local ws=math.random(0,p.sea*8)\r\n'..
        'pcall(ScenEdit_SetWeather,{WindDir=wd,WindSpeed=ws,Rainfall=p.rain,SeaState=p.sea})\r\n'..
        'ScenEdit_SetKeyValue("WEATHER_PRESET",p.name)\r\n'..
        'ScenEdit_SpecialMessage("Blue",string.format("METOC UPDATE: %s | Wind %03d°/%d kt | Sea state %d",p.desc,wd,ws,p.sea))\r\n'

    pcall(ScenEdit_SetAction, {
        mode='add', type='LuaScript', name='WeatherUpdate', ScriptText=script,
    })
    pcall(ScenEdit_SetEventAction, ev.guid, {mode='add', name='WeatherUpdate'})
    print('[Weather] Dynamic weather system active — cycles every 6 hours.')
end

setupDynamicWeather()
```

---

## Example 9 — Delayed Minefield

**Prompt:**
> Script a minefield that arms 90 minutes after scenario start. Before that, mines are inert (set doctrine to Hold fire). Send a message when they arm.

**Response:**

```lua
--- ============================================================
--- Delayed Minefield Activation
--- Mines spawn inert; arm after ARM_DELAY_SEC.
--- ============================================================

local RED_SIDE       = 'Red'
local ARM_DELAY_SEC  = 90 * 60   -- 90 minutes
local MINE_DBID      = 1504      -- Mk-60 CAPTOR mine (verify in DB viewer)
local MINE_COUNT     = 12

-- Minefield corridor (e.g., Hormuz chokepoint)
local MINE_POSITIONS = {}
for i = 1, MINE_COUNT do
    MINE_POSITIONS[i] = {
        lat = 26.5 + (i - 1) * 0.02,
        lon = 56.2 + ((i % 3) * 0.03),
    }
end

-- ===== SPAWN INERT MINES =====
local mineGuids = {}
for i, pos in ipairs(MINE_POSITIONS) do
    local ok, mine = pcall(ScenEdit_AddUnit, {
        side        = RED_SIDE,
        type        = 'Facility',
        name        = string.format('Mine-%02d', i),
        dbid        = MINE_DBID,
        latitude    = pos.lat,
        longitude   = pos.lon,
    })
    if ok and mine then
        mineGuids[i] = mine.guid
        ScenEdit_SetKeyValue('MINE_' .. i .. '_GUID', mine.guid)
        -- Set Hold weapons — mines are inert
        pcall(ScenEdit_SetDoctrine, {guid=mine.guid}, {
            weapon_control_status_subsurface = 2,  -- Hold
        })
    end
end

print(string.format('[Minefield] %d mines deployed (inert) — arming in %d minutes.',
    #mineGuids, ARM_DELAY_SEC / 60))

-- ===== ARMING EVENT =====
local armTime = ScenEdit_CurrentTime() + ARM_DELAY_SEC

-- Build the arm script inline (references mines via KeyStore)
local armLines = {
    'local armed = 0',
    string.format('for i = 1, %d do', MINE_COUNT),
    '    local guid = ScenEdit_GetKeyValue("MINE_"..i.."_GUID")',
    '    if guid ~= "" then',
    '        local ok, u = pcall(ScenEdit_GetUnit, {guid=guid})',
    '        if ok and u then',
    '            pcall(ScenEdit_SetDoctrine, {guid=guid}, {weapon_control_status_subsurface=0})',
    '            armed = armed + 1',
    '        end',
    '    end',
    'end',
    'ScenEdit_SpecialMessage("Red", string.format("MINEFIELD ARMED — %d active mines in the Strait.", armed))',
    'print(string.format("[Minefield] %d mines armed.", armed))',
}
local armScript = table.concat(armLines, '\r\n')

local ok, ev = pcall(ScenEdit_SetEvent, 'MineArmEvent', {
    mode='add', IsActive=true, IsRepeatable=false,
})
if ok then
    pcall(ScenEdit_SetTrigger, {mode='add', type='Time', name='MineArmTimer', time=armTime})
    pcall(ScenEdit_SetEventTrigger, ev.guid, {mode='add', name='MineArmTimer'})
    pcall(ScenEdit_SetAction, {mode='add', type='LuaScript', name='ArmMines', ScriptText=armScript})
    pcall(ScenEdit_SetEventAction, ev.guid, {mode='add', name='ArmMines'})
end
```

---

## Example 10 — Order of Battle Report

**Prompt:**
> Build a script that generates a formatted Order of Battle listing for all Blue units, grouped by type, and sends it to the player as a special message.

**Response:**

```lua
--- ============================================================
--- Order of Battle Report Generator
--- Generates a formatted OOB for the specified side.
--- ============================================================

--- @param sideName string  Side to generate OOB for
--- @return string          Formatted OOB text
local function generateOOB(sideName)
    local ok, side = pcall(VP_GetSide, {Side=sideName})
    if not ok or not side then
        return 'OOB ERROR: Side "' .. sideName .. '" not found.'
    end

    -- Group units by type
    local groups = {
        Aircraft    = {},
        Ship        = {},
        Submarine   = {},
        Facility    = {},
        Satellite   = {},
    }

    for _, u in ipairs(side.units or {}) do
        local t = u.type or 'Unknown'
        if not groups[t] then groups[t] = {} end
        groups[t][#groups[t]+1] = u
    end

    -- Format output
    local lines = {
        string.rep('=', 48),
        string.format('ORDER OF BATTLE — %s', string.upper(sideName)),
        string.format('Time: %s', os.date('!%d %b %Y %H:%MZ',
            (pcall(ScenEdit_CurrentTime) and ScenEdit_CurrentTime() or os.time()))),
        string.rep('=', 48),
    }

    local typeOrder  = {'Aircraft','Ship','Submarine','Facility','Satellite'}
    local typeLabels = {
        Aircraft='AVIATION', Ship='SURFACE', Submarine='SUBSURFACE',
        Facility='SHORE/FACILITY', Satellite='SPACE'
    }

    local totalUnits = 0

    for _, utype in ipairs(typeOrder) do
        local units = groups[utype]
        if units and #units > 0 then
            -- Sort by name
            table.sort(units, function(a, b) return (a.name or '') < (b.name or '') end)
            lines[#lines+1] = ''
            lines[#lines+1] = string.format('--- %s (%d) ---', typeLabels[utype], #units)
            for _, u in ipairs(units) do
                local mission = (u.mission and u.mission ~= '') and (' [' .. u.mission .. ']') or ''
                local damage  = (u.damage and u.damage > 0)
                    and string.format(' DMG:%.0f%%', u.damage) or ''
                lines[#lines+1] = string.format('  %-24s %s%s',
                    u.name, u.proficiency or '?', mission .. damage)
                totalUnits = totalUnits + 1
            end
        end
    end

    lines[#lines+1] = ''
    lines[#lines+1] = string.rep('-', 48)
    lines[#lines+1] = string.format('TOTAL UNITS ON STRENGTH: %d', totalUnits)
    lines[#lines+1] = string.rep('=', 48)

    return table.concat(lines, '\n')
end

-- Generate and send
local report = generateOOB('Blue')
ScenEdit_SpecialMessage('Blue', report)
print(report)
```
