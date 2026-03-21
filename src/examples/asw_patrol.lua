--- ============================================================
--- ASW Patrol Scenario
--- Anti-Submarine Warfare patrol setup.
--- Based on community Cookbook patterns (Craigkn/Lua Legion).
---
--- Features:
---   - Surface ships with towed array sonar (ScenEdit_UpdateUnit)
---   - Ship-based ASW helicopters (LAMPS)
---   - Maritime patrol aircraft (P-8 Poseidon)
---   - ASW patrol and prosecution zones
---   - Configurable ASW doctrine
---   - Contact detection event with prosecution mission activation
---
--- Run from: GameSetup.lua
--- ============================================================

-- ===== CONSTANTS =============================================

local BLUE = 'Blue'
local RED  = 'Red'

-- Operating area: Norwegian Sea (adjust as needed)
local AO_LAT = 67.0
local AO_LON =  5.0

-- DB IDs — verify in DB viewer (Ctrl+D)
local DBID = {
    -- Ships
    FFG_PERRY      = 232,   -- FFG-7 Oliver Hazard Perry
    DDG_BURKEII    = 2869,  -- DDG Arleigh Burke Flight II
    FRIGATE_NORW   = 6800,  -- Fridtjof Nansen (adjust per scenario)

    -- Sensors (towed arrays)
    TB16_SONAR     = 6099,  -- TB-16 Fat Line towed array
    SQS53C_SONAR   = 7001,  -- SQS-53C hull sonar

    -- Aircraft
    P8_POSEIDON    = 4410,  -- P-8A Poseidon MPA
    MH60R_ROMEO    = 1487,  -- MH-60R Seahawk LAMPS III
    SH60B_LAMPS    = 1486,  -- SH-60B LAMPS III

    -- Aircraft loadouts
    P8_ASW         = 21700, -- P-8A ASW (torpedoes + sonobuoys)
    MH60R_ASW      = 21710, -- MH-60R ASW
    SH60B_ASW      = 21715, -- SH-60B ASW

    -- Submarines (Red)
    KILO_SSK       = 228,   -- Kilo-class SSK (Project 877)
    VICTOR3_SSN    = 235,   -- Victor III SSN
}

-- State table
local ASW = {
    ships    = {},
    aircraft = {},
    missions = {},
}

-- ===== HELPERS ===============================================

local function nm(degrees) return degrees / 60.0 end

local function spawnUnit(params)
    local ok, unit = pcall(ScenEdit_AddUnit, params)
    if ok and unit then
        return unit
    end
    print(string.format('[ASW] Failed to spawn %s: %s', params.name or '?', tostring(unit)))
    return nil
end

--- Add a towed array sonar to a surface ship.
--- This is the Cookbook pattern from Craigkn (Lua Legion).
--- @param unitGuid string  GUID of the ship
--- @param sensorDbid number  Sensor DB ID (e.g., 6099 = TB-16)
local function addTowedArray(unitGuid, sensorDbid)
    local ok, err = pcall(ScenEdit_UpdateUnit, {
        guid       = unitGuid,
        mode       = 'add_sensor',
        dbid       = sensorDbid,
        arc_detect = {'360'},
        arc_track  = {'360'},
    })
    if not ok then
        print(string.format('[ASW] addTowedArray failed for %s: %s', unitGuid, tostring(err)))
    end
    return ok
end

--- Configure ASW doctrine for a ship: weapons free against subs.
--- @param unitGuid string
local function setAswDoctrine(unitGuid)
    pcall(ScenEdit_SetDoctrine, {guid=unitGuid}, {
        weapon_control_status_subsurface = 0,  -- Free against subs
        weapon_control_status_air        = 1,  -- Tight for AAW
        weapon_control_status_surface    = 2,  -- Hold surface fire
    })
end

-- ===== REFERENCE POINTS ======================================

local function createZones()
    local zones = {
        -- Main ASW patrol box
        {n='ASW-RP1', la=AO_LAT+1.0, lo=AO_LON-1.0},
        {n='ASW-RP2', la=AO_LAT+1.0, lo=AO_LON+1.0},
        {n='ASW-RP3', la=AO_LAT-1.0, lo=AO_LON+1.0},
        {n='ASW-RP4', la=AO_LAT-1.0, lo=AO_LON-1.0},
        -- Prosecution zone (tighter box for active attack)
        {n='ASW-PROS1', la=AO_LAT+0.3, lo=AO_LON-0.3},
        {n='ASW-PROS2', la=AO_LAT+0.3, lo=AO_LON+0.3},
        {n='ASW-PROS3', la=AO_LAT-0.3, lo=AO_LON+0.3},
        {n='ASW-PROS4', la=AO_LAT-0.3, lo=AO_LON-0.3},
        -- MPA holding/patrol orbit
        {n='MPA-RP1', la=AO_LAT+2.0, lo=AO_LON-1.5},
        {n='MPA-RP2', la=AO_LAT+2.0, lo=AO_LON+1.5},
        {n='MPA-RP3', la=AO_LAT+1.5, lo=AO_LON+1.5},
        {n='MPA-RP4', la=AO_LAT+1.5, lo=AO_LON-1.5},
    }
    for _, rp in ipairs(zones) do
        pcall(ScenEdit_AddReferencePoint, {
            side=BLUE, name=rp.n, latitude=rp.la, longitude=rp.lo,
            highlighted=false,
        })
    end
    print('[ASW] Zones created.')
end

-- ===== SURFACE SHIPS =========================================

local SHIP_DEFS = {
    {name='USS Simpson (FFG-56)',   dbid=DBID.FFG_PERRY,    dlat= 0.5, dlon=-0.5, hdg=045, spd=12},
    {name='USS Doyle (FFG-39)',     dbid=DBID.FFG_PERRY,    dlat=-0.5, dlon= 0.5, hdg=045, spd=12},
    {name='USS Mahan (DDG-72)',     dbid=DBID.DDG_BURKEII,  dlat= 0.0, dlon= 0.0, hdg=045, spd=15},
}

local function spawnSurface()
    for i, def in ipairs(SHIP_DEFS) do
        local lat = AO_LAT + def.dlat
        local lon = AO_LON + def.dlon

        local ship = spawnUnit({
            side        = BLUE,
            type        = 'Ship',
            name        = def.name,
            dbid        = def.dbid,
            latitude    = lat,
            longitude   = lon,
            heading     = def.hdg,
            speed       = def.spd,
            proficiency = 'Veteran',
        })

        if ship then
            ASW.ships[i] = ship.guid
            ScenEdit_SetKeyValue('ASW_SHIP_' .. i .. '_GUID', ship.guid)

            -- Add towed array sonar (TB-16)
            addTowedArray(ship.guid, DBID.TB16_SONAR)
            setAswDoctrine(ship.guid)

            -- Set passive EMCON for sonar effectiveness
            pcall(ScenEdit_SetEMCON, 'Unit', ship.guid, 'Radar=Passive;Sonar=Active;OECM=Passive')

            -- Spawn LAMPS helicopter on each ship
            local helo = spawnUnit({
                side        = BLUE,
                type        = 'Aircraft',
                name        = string.format('LAMPS-%s', def.name:match('%((.-)%)') or i),
                dbid        = DBID.MH60R_ROMEO,
                loadoutid   = DBID.MH60R_ASW,
                Base        = def.name,
                latitude    = lat,
                longitude   = lon,
                proficiency = 'Regular',
            })
            if helo then
                ScenEdit_SetKeyValue('LAMPS_' .. i .. '_GUID', helo.guid)
            end

            print(string.format('[ASW] Ship %d spawned: %s (towed array added)', i, def.name))
        end
    end
end

-- ===== MARITIME PATROL AIRCRAFT ==============================

local function spawnMPA()
    local mpaDefs = {
        {name='Patrol-1', dlat=2.0, dlon=-1.0},
        {name='Patrol-2', dlat=2.0, dlon= 1.0},
    }
    for i, def in ipairs(mpaDefs) do
        local mpa = spawnUnit({
            side        = BLUE,
            type        = 'Aircraft',
            name        = def.name,
            dbid        = DBID.P8_POSEIDON,
            loadoutid   = DBID.P8_ASW,
            Base        = 'Andøya AB',   -- [CUSTOMISE] nearest air base
            latitude    = AO_LAT + def.dlat,
            longitude   = AO_LON + def.dlon,
            altitude    = '15000 FT',
            proficiency = 'Veteran',
        })
        if mpa then
            ASW.aircraft[i] = mpa.guid
            ScenEdit_SetKeyValue('MPA_' .. i .. '_GUID', mpa.guid)
        end
    end
    print('[ASW] MPA aircraft spawned.')
end

-- ===== RED SUBMARINES (THREAT) ===============================

local function spawnRedSubmarines()
    local subs = {
        {name='B-800',    dbid=DBID.KILO_SSK,   lat=AO_LAT-2.0, lon=AO_LON+0.5, depth=-80,  hdg=000, spd=5},
        {name='K-292',    dbid=DBID.VICTOR3_SSN, lat=AO_LAT+3.0, lon=AO_LON-1.0, depth=-150, hdg=180, spd=8},
    }
    for i, sub in ipairs(subs) do
        local unit = spawnUnit({
            side        = RED,
            type        = 'Submarine',
            name        = sub.name,
            dbid        = sub.dbid,
            latitude    = sub.lat,
            longitude   = sub.lon,
            altitude    = sub.depth,
            heading     = sub.hdg,
            speed       = sub.spd,
            proficiency = 'Veteran',
        })
        if unit then
            ScenEdit_SetKeyValue('RED_SUB_' .. i .. '_GUID', unit.guid)
            -- Submarines run deep and quiet
            pcall(ScenEdit_SetEMCON, 'Unit', unit.guid, 'Radar=Passive;Sonar=Active;OECM=Passive')
            setAswDoctrine(unit.guid)
        end
    end
    print('[ASW] Red submarines deployed.')
end

-- ===== MISSIONS ==============================================

local function createMissions()
    -- ---- Surface ASW Patrol ----
    local ok1, navPat = pcall(ScenEdit_AddMission, BLUE, 'ASW Surface Patrol', 'patrol', {type='naval'})
    if ok1 and navPat then
        ScenEdit_SetMission(BLUE, 'ASW Surface Patrol', {
            patrolzone     = {'ASW-RP1','ASW-RP2','ASW-RP3','ASW-RP4'},
            onethirdrule   = false,
            checkzerofuel  = true,
        })
        ASW.missions.navPat = navPat.guid
        -- Assign all surface ships
        for _, guid in ipairs(ASW.ships) do
            pcall(ScenEdit_AssignUnitToMission, guid, 'ASW Surface Patrol')
        end
    end

    -- ---- MPA ASW Patrol ----
    local ok2, mpaPat = pcall(ScenEdit_AddMission, BLUE, 'ASW MPA Patrol', 'patrol', {type='air'})
    if ok2 and mpaPat then
        ScenEdit_SetMission(BLUE, 'ASW MPA Patrol', {
            patrolzone     = {'MPA-RP1','MPA-RP2','MPA-RP3','MPA-RP4'},
            onethirdrule   = true,
            flightsize     = 1,
            checkzerofuel  = true,
        })
        for _, guid in ipairs(ASW.aircraft) do
            pcall(ScenEdit_AssignUnitToMission, guid, 'ASW MPA Patrol')
        end
    end

    -- ---- Prosecution mission (inactive until contact) ----
    local ok3, pros = pcall(ScenEdit_AddMission, BLUE, 'ASW Prosecution', 'patrol', {type='naval'})
    if ok3 and pros then
        ScenEdit_SetMission(BLUE, 'ASW Prosecution', {
            patrolzone   = {'ASW-PROS1','ASW-PROS2','ASW-PROS3','ASW-PROS4'},
            isactive     = false,
            checkzerofuel = true,
        })
        ASW.missions.pros = pros.guid
        ScenEdit_SetKeyValue('ASW_PROS_MISSION_GUID', pros.guid)
    end

    print('[ASW] Missions created.')
end

-- ===== CONTACT DETECTION EVENT ===============================

local function createDetectionEvent()
    local ok, ev = pcall(ScenEdit_SetEvent, 'SubContactDetected', {
        mode='add', IsActive=true, IsRepeatable=true,
    })
    if not ok then return end

    -- Trigger: Blue detects a sub-classified contact
    pcall(ScenEdit_SetTrigger, {
        mode       = 'add',
        type       = 'DetectedContact',
        name       = 'BlueDetectsSub',
        Side       = BLUE,
        TargetSide = RED,
        TargetType = 'Submarine',
    })
    pcall(ScenEdit_SetEventTrigger, ev.guid, {mode='add', name='BlueDetectsSub'})

    -- Action: activate prosecution, drop reference point
    local actionScript =
        'local contact = ScenEdit_UnitC()\r\n'..
        'if not contact then return end\r\n'..
        '\r\n'..
        '-- One prosecution at a time\r\n'..
        'if ScenEdit_GetKeyValue("ASW_ACTIVE") == "1" then return end\r\n'..
        'ScenEdit_SetKeyValue("ASW_ACTIVE", "1")\r\n'..
        '\r\n'..
        '-- Place contact reference point\r\n'..
        'pcall(ScenEdit_AddReferencePoint, {\r\n'..
        '    side="Blue", name="SUB-CONTACT",\r\n'..
        '    latitude=contact.latitude, longitude=contact.longitude,\r\n'..
        '    highlighted=true\r\n'..
        '})\r\n'..
        '\r\n'..
        '-- Activate prosecution mission\r\n'..
        'pcall(ScenEdit_SetMission, "Blue", "ASW Prosecution", {isactive=true})\r\n'..
        '\r\n'..
        'ScenEdit_SpecialMessage("Blue", string.format(\r\n'..
        '    "SONAR CONTACT! Possible submarine at %.3f, %.3f (hdg=%s spd=%s).\\nASW Prosecution activated.",\r\n'..
        '    contact.latitude, contact.longitude,\r\n'..
        '    tostring(contact.heading), tostring(contact.speed)))\r\n'

    pcall(ScenEdit_SetAction, {
        mode='add', type='LuaScript', name='OnSubContact', ScriptText=actionScript,
    })
    pcall(ScenEdit_SetEventAction, ev.guid, {mode='add', name='OnSubContact'})
    print('[ASW] Contact detection event registered.')
end

-- ===== EXECUTE ===============================================

local function setupASW()
    local ok, err = pcall(function()
        createZones()
        spawnSurface()
        spawnMPA()
        spawnRedSubmarines()
        createMissions()
        createDetectionEvent()

        -- Side doctrine — ASW-first
        pcall(ScenEdit_SetDoctrine, {side=BLUE}, {
            weapon_control_status_subsurface = 0,
            weapon_control_status_air        = 1,
            weapon_control_status_surface    = 1,
        })
    end)

    if ok then
        ScenEdit_SpecialMessage(BLUE,
            'ASW patrol established.\n'..
            'Three surface ships with towed arrays are screening the patrol zone.\n'..
            'Two P-8s maintain MPA coverage overhead.\n'..
            'Submarine contacts will activate the prosecution mission automatically.')
        print('[ASW] Setup complete.')
    else
        print('[ASW] ERROR: ' .. tostring(err))
    end

    return ASW
end

return setupASW()
