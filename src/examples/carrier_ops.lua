--- ============================================================
--- Carrier Battle Group Operations
--- Complete CVN battle group setup with air wing, escorts,
--- CAP, strike, AEW, and tanker missions.
---
--- Scenario: Operation Steel Horizon
--- Setting: Eastern Mediterranean Sea
--- Blue: USN Carrier Strike Group (CSG-8)
--- Red:  (defined in scenario editor)
---
--- Run from: GameSetup.lua
--- ============================================================

-- ===== CONSTANTS =============================================

local BLUE       = 'Blue'
local CVN_LAT    = 34.0
local CVN_LON    = 28.0

-- DB IDs — verify all against your CMO database version (Ctrl+D in-game)
local DBID = {
    -- Ships
    CVN_NIMITZ   = 316,    -- CVN-68 Nimitz
    DDG_BURKEIII = 4558,   -- DDG Arleigh Burke Flight III
    CG_TICOND    = 346,    -- CG-47 Ticonderoga
    SSN_VIRGINIA = 4539,   -- SSN Virginia class

    -- Aircraft
    FA18E_SUPER  = 1479,   -- F/A-18E Super Hornet
    FA18F_SUPER  = 1480,   -- F/A-18F Super Hornet (2-seater)
    EA18G_GROWLER= 1481,   -- EA-18G Growler
    E2D_HAWKEYE  = 1483,   -- E-2D Advanced Hawkeye
    S3B_VIKING   = 1485,   -- S-3B Viking (ASW/tanker)
    MH60R_ROMEO  = 1487,   -- MH-60R Seahawk (ASW helo)
    MH60S_SIERRA = 1488,   -- MH-60S Seahawk (VERTREP/SAR)

    -- Loadouts (verify in DB Viewer → Aircraft → Loadouts)
    FA18E_BVR    = 21640,  -- F/A-18E BVR air intercept
    FA18E_STRIKE = 21645,  -- F/A-18E Precision Strike
    FA18F_ELINT  = 21650,  -- F/A-18F SEAD/Wild Weasel
    EA18G_JAMMER = 21660,  -- EA-18G electronic attack
    E2D_AEW      = 21665,  -- E-2D standard AEW
    S3B_ASW      = 21670,  -- S-3B ASW patrol
}

-- Formation offsets (nm, converted to degrees: 1nm ≈ 1/60°)
local NM = 1.0 / 60.0

local function offset(baseLat, baseLon, dLatNm, dLonNm)
    return baseLat + dLatNm * NM, baseLon + dLonNm * NM
end

-- ===== MODULE RESULT TABLE ===================================
-- Collects GUIDs for reference by other scripts
local CSG = {
    carrier  = nil,
    escorts  = {},
    aircraft = {},
    missions = {},
}

-- ===== CARRIER SPAWN =========================================

local function spawnCarrier()
    local ok, cvn = pcall(ScenEdit_AddUnit, {
        side        = BLUE,
        type        = 'Ship',
        name        = 'USS Nimitz (CVN-68)',
        dbid        = DBID.CVN_NIMITZ,
        latitude    = CVN_LAT,
        longitude   = CVN_LON,
        heading     = 090,
        speed       = 18,
        proficiency = 'Veteran',
    })
    if not ok or not cvn then
        print('[CSG] FATAL: Could not spawn carrier: ' .. tostring(cvn))
        return false
    end
    CSG.carrier = cvn.guid
    ScenEdit_SetKeyValue('CVN_GUID', cvn.guid)

    -- Carrier doctrine: protect itself, return fire only
    pcall(ScenEdit_SetDoctrine, {guid=cvn.guid}, {
        weapon_control_status_air     = 1,  -- Tight (defensive only)
        weapon_control_status_surface = 2,  -- Hold
        ignore_plotted_course         = 'no',
    })

    print('[CSG] Carrier USS Nimitz spawned: ' .. cvn.guid)
    return true
end

-- ===== ESCORT GROUP ==========================================

local ESCORT_DEFS = {
    -- Ahead screen
    {name='USS Leyte Gulf (CG-55)',    dbid=DBID.CG_TICOND,    dlat=15, dlon= 0,  hdg=090, spd=20},
    -- Forward port/starboard
    {name='USS Stout (DDG-55)',         dbid=DBID.DDG_BURKEIII, dlat=10, dlon=-10, hdg=090, spd=20},
    {name='USS McFaul (DDG-74)',        dbid=DBID.DDG_BURKEIII, dlat=10, dlon= 10, hdg=090, spd=20},
    -- Aft screen
    {name='USS Roosevelt (DDG-80)',     dbid=DBID.DDG_BURKEIII, dlat=-10,dlon= -8, hdg=090, spd=20},
    {name='USS Bulkeley (DDG-84)',      dbid=DBID.DDG_BURKEIII, dlat=-10,dlon=  8, hdg=090, spd=20},
}

local function spawnEscorts()
    for i, def in ipairs(ESCORT_DEFS) do
        local lat, lon = offset(CVN_LAT, CVN_LON, def.dlat, def.dlon)
        local ok, ship = pcall(ScenEdit_AddUnit, {
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
        if ok and ship then
            CSG.escorts[i] = ship.guid
            ScenEdit_SetKeyValue('ESCORT_' .. i .. '_GUID', ship.guid)

            -- Set Hawk (short range) SAM doctrine for AAW escorts
            pcall(ScenEdit_SetDoctrine, {guid=ship.guid}, {
                weapon_control_status_air     = 0,  -- Free (protect the carrier)
                weapon_control_status_surface = 1,  -- Tight
                weapon_control_status_subsurface = 0,
            })

            -- Add LAMPS helicopter to each DDG/CG
            local ok2, helo = pcall(ScenEdit_AddUnit, {
                side        = BLUE,
                type        = 'Aircraft',
                name        = string.format('LAMPS-%02d', i),
                dbid        = DBID.MH60R_ROMEO,
                loadoutid   = DBID.S3B_ASW,
                Base        = ship.name,
                latitude    = lat,
                longitude   = lon,
                proficiency = 'Regular',
            })
            if ok2 and helo then
                ScenEdit_SetKeyValue('LAMPS_' .. i .. '_GUID', helo.guid)
            end

            print(string.format('[CSG] Escort %d spawned: %s', i, def.name))
        end
    end
end

-- ===== AIR WING ==============================================

local AIR_WING = {
    -- VFA-87 Golden Warriors (F/A-18E Strike Fighter)
    {name='Eagle-1',  dbid=DBID.FA18E_SUPER,  loadout=DBID.FA18E_BVR,    role='CAP'},
    {name='Eagle-2',  dbid=DBID.FA18E_SUPER,  loadout=DBID.FA18E_BVR,    role='CAP'},
    {name='Eagle-3',  dbid=DBID.FA18E_SUPER,  loadout=DBID.FA18E_BVR,    role='CAP'},
    {name='Eagle-4',  dbid=DBID.FA18E_SUPER,  loadout=DBID.FA18E_BVR,    role='CAP'},

    -- VFA-15 Valions (F/A-18E Strike)
    {name='Valor-1',  dbid=DBID.FA18E_SUPER,  loadout=DBID.FA18E_STRIKE, role='STRIKE'},
    {name='Valor-2',  dbid=DBID.FA18E_SUPER,  loadout=DBID.FA18E_STRIKE, role='STRIKE'},
    {name='Valor-3',  dbid=DBID.FA18E_SUPER,  loadout=DBID.FA18E_STRIKE, role='STRIKE'},
    {name='Valor-4',  dbid=DBID.FA18E_SUPER,  loadout=DBID.FA18E_STRIKE, role='STRIKE'},

    -- VAQ-140 Patriots (EA-18G Jamming)
    {name='Patriot-1',dbid=DBID.EA18G_GROWLER,loadout=DBID.EA18G_JAMMER, role='ECM'},
    {name='Patriot-2',dbid=DBID.EA18G_GROWLER,loadout=DBID.EA18G_JAMMER, role='ECM'},

    -- VAW-126 Seahawks (E-2D AEW)
    {name='Hawkeye-1',dbid=DBID.E2D_HAWKEYE,  loadout=DBID.E2D_AEW,     role='AEW'},
    {name='Hawkeye-2',dbid=DBID.E2D_HAWKEYE,  loadout=DBID.E2D_AEW,     role='AEW'},
}

local function spawnAirWing()
    for i, ac in ipairs(AIR_WING) do
        local ok, unit = pcall(ScenEdit_AddUnit, {
            side        = BLUE,
            type        = 'Aircraft',
            name        = ac.name,
            dbid        = ac.dbid,
            loadoutid   = ac.loadout,
            Base        = 'USS Nimitz (CVN-68)',
            latitude    = CVN_LAT + (i * 0.001),  -- slight spread for parking
            longitude   = CVN_LON,
            proficiency = 'Veteran',
        })
        if ok and unit then
            CSG.aircraft[ac.name] = unit.guid
            ScenEdit_SetKeyValue('AC_' .. ac.name:upper():gsub('[^A-Z0-9]','_'), unit.guid)
        end
    end
    print(string.format('[CSG] Air wing spawned: %d aircraft', #AIR_WING))
end

-- ===== REFERENCE POINTS ======================================

local function createZones()
    local zones = {
        -- Forward CAP box
        {name='CAP-FWD-1', lat=CVN_LAT+1.0, lon=CVN_LON+1.5},
        {name='CAP-FWD-2', lat=CVN_LAT+1.0, lon=CVN_LON+2.5},
        {name='CAP-FWD-3', lat=CVN_LAT+0.0, lon=CVN_LON+2.5},
        {name='CAP-FWD-4', lat=CVN_LAT+0.0, lon=CVN_LON+1.5},
        -- Aft CAP box
        {name='CAP-AFT-1', lat=CVN_LAT+0.5, lon=CVN_LON-1.5},
        {name='CAP-AFT-2', lat=CVN_LAT+0.5, lon=CVN_LON-0.5},
        {name='CAP-AFT-3', lat=CVN_LAT-0.5, lon=CVN_LON-0.5},
        {name='CAP-AFT-4', lat=CVN_LAT-0.5, lon=CVN_LON-1.5},
        -- AEW orbit
        {name='AEW-1', lat=CVN_LAT+1.5, lon=CVN_LON+0.5},
        {name='AEW-2', lat=CVN_LAT+1.5, lon=CVN_LON+1.0},
        {name='AEW-3', lat=CVN_LAT+1.0, lon=CVN_LON+1.0},
        {name='AEW-4', lat=CVN_LAT+1.0, lon=CVN_LON+0.5},
    }
    for _, rp in ipairs(zones) do
        pcall(ScenEdit_AddReferencePoint, {
            side=BLUE, name=rp.name, latitude=rp.lat, longitude=rp.lon,
            highlighted=false,
        })
    end
    print('[CSG] Zone reference points created.')
end

-- ===== MISSIONS ==============================================

local function createMissions()
    -- ---- Forward CAP ----
    local ok1, capFwd = pcall(ScenEdit_AddMission, BLUE, 'CSG-CAP Forward', 'patrol', {type='air'})
    if ok1 and capFwd then
        ScenEdit_SetMission(BLUE, 'CSG-CAP Forward', {
            patrolzone     = {'CAP-FWD-1','CAP-FWD-2','CAP-FWD-3','CAP-FWD-4'},
            onethirdrule   = true,
            flightsize     = 2,
            minaircraftreq = 2,
            useflightsize  = true,
            checkzerofuel  = true,
        })
        CSG.missions.capFwd = capFwd.guid
        -- Assign Eagle-1 and Eagle-2
        for _, nm in ipairs({'Eagle-1','Eagle-2'}) do
            local g = CSG.aircraft[nm]
            if g then pcall(ScenEdit_AssignUnitToMission, g, 'CSG-CAP Forward') end
        end
    end

    -- ---- Aft CAP ----
    local ok2, capAft = pcall(ScenEdit_AddMission, BLUE, 'CSG-CAP Aft', 'patrol', {type='air'})
    if ok2 and capAft then
        ScenEdit_SetMission(BLUE, 'CSG-CAP Aft', {
            patrolzone     = {'CAP-AFT-1','CAP-AFT-2','CAP-AFT-3','CAP-AFT-4'},
            onethirdrule   = true,
            flightsize     = 2,
            minaircraftreq = 2,
            useflightsize  = true,
        })
        for _, nm in ipairs({'Eagle-3','Eagle-4'}) do
            local g = CSG.aircraft[nm]
            if g then pcall(ScenEdit_AssignUnitToMission, g, 'CSG-CAP Aft') end
        end
    end

    -- ---- Strike Package (inactive until ordered) ----
    local ok3, strike = pcall(ScenEdit_AddMission, BLUE, 'CSG-Strike Alpha', 'strike', {type='land'})
    if ok3 and strike then
        ScenEdit_SetMission(BLUE, 'CSG-Strike Alpha', {isactive=false})
        CSG.missions.strike = strike.guid
        ScenEdit_SetKeyValue('STRIKE_MISSION_GUID', strike.guid)
        for _, nm in ipairs({'Valor-1','Valor-2','Valor-3','Valor-4'}) do
            local g = CSG.aircraft[nm]
            if g then pcall(ScenEdit_AssignUnitToMission, g, 'CSG-Strike Alpha') end
        end
    end

    -- ---- AEW ----
    local ok4, aewMission = pcall(ScenEdit_AddMission, BLUE, 'CSG-AEW', 'patrol', {type='air'})
    if ok4 and aewMission then
        ScenEdit_SetMission(BLUE, 'CSG-AEW', {
            patrolzone   = {'AEW-1','AEW-2','AEW-3','AEW-4'},
            onethirdrule = false,
            flightsize   = 1,
        })
        for _, nm in ipairs({'Hawkeye-1','Hawkeye-2'}) do
            local g = CSG.aircraft[nm]
            if g then pcall(ScenEdit_AssignUnitToMission, g, 'CSG-AEW') end
        end
    end

    -- ---- ECM Escort (activates with strike) ----
    local ok5, ecmMission = pcall(ScenEdit_AddMission, BLUE, 'CSG-ECM Support', 'support', {})
    if ok5 and ecmMission then
        ScenEdit_SetMission(BLUE, 'CSG-ECM Support', {isactive=false})
        for _, nm in ipairs({'Patriot-1','Patriot-2'}) do
            local g = CSG.aircraft[nm]
            if g then pcall(ScenEdit_AssignUnitToMission, g, 'CSG-ECM Support') end
        end
    end

    print('[CSG] Missions created.')
end

-- ===== SIDE DOCTRINE =========================================

local function configureDoctrine()
    pcall(ScenEdit_SetDoctrine, {side=BLUE}, {
        weapon_control_status_air        = 0,
        weapon_control_status_surface    = 0,
        weapon_control_status_subsurface = 0,
        use_nuclear_weapons              = 'no',
        engage_non_hostile_targets       = 'no',
        fuel_state_planned               = 'Bingo',
        fuel_state_rtb                   = 'Joker',
    })
end

-- ===== EXECUTE ===============================================

local function setupCSG()
    print('[CSG] Setting up Carrier Strike Group...')

    local ok, err = pcall(function()
        configureDoctrine()
        local carrierOk = spawnCarrier()
        if not carrierOk then
            error('Carrier spawn failed — aborting CSG setup')
        end
        spawnEscorts()
        spawnAirWing()
        createZones()
        createMissions()

        -- Save CSG state for other scripts
        ScenEdit_SetKeyValue('CSG_ESCORTS_COUNT', tostring(#CSG.escorts))
        ScenEdit_SetKeyValue('CSG_AIRCRAFT_COUNT', tostring(#AIR_WING))
    end)

    if ok then
        ScenEdit_SpecialMessage(BLUE,
            'CSG-8 deployed: USS Nimitz and escorts are on station.\n' ..
            'Forward and aft CAP active. AEW on station.\n' ..
            'Strike package armed and ready — activate via orders.')
        print('[CSG] Carrier Strike Group setup complete.')
    else
        print('[CSG] ERROR: ' .. tostring(err))
        ScenEdit_SetKeyValue('CSG_ERROR', tostring(err))
    end

    return CSG
end

return setupCSG()
