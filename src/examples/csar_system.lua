--- ============================================================
--- CSAR System — Combat Search and Rescue
--- Full implementation: pilot survival, spawn, rescue mission,
--- timer, scoring, and cleanup.
---
--- Setup function: call setupCSAR() from GameSetup.lua
--- Handler (event action): the UnitDestroyed event calls
---   the CSAR handler script inline.
---
--- Architecture:
---   GameSetup.lua
---     → setupCSAR() registers the UnitDestroyed trigger
---     → pre-creates the rescue helicopter and SAR mission
---   Event fires when a Blue aircraft is destroyed
---     → csarHandler() runs as the event action
---     → Rolls pilot survival, spawns pilot facility
---     → Creates SAR reference point
---     → Activates rescue mission with helicopter
---     → Schedules 2-hour rescue window expiry event
---   If pilot rescued (proximity check by rescue helo)
---     → csarSuccess() awards score, cleans up
---   If window expires
---     → Pilot removed, score deducted
--- ============================================================

-- ===== CONSTANTS =============================================

local BLUE            = 'Blue'
local PILOT_SIDE      = 'Blue'

-- Survival and scoring
local SURVIVAL_CHANCE  = 0.60     -- 60% survival probability on ejection
local RESCUE_WINDOW    = 7200     -- seconds — 2-hour rescue window
local SCORE_LOSS_AC    = 25       -- points deducted for lost aircraft
local SCORE_PILOT_KIA  = 50       -- points deducted if pilot not rescued
local SCORE_PILOT_SAVE = 150      -- points awarded for successful rescue

-- Rescue helicopter base
local RESCUE_BASE      = 'USS Nimitz (CVN-68)'  -- [CUSTOMISE]

-- DB IDs — verify in DB viewer
local DBID = {
    PILOT_FAC  = 259,    -- Downed Pilot / Survivor facility
    HH60_SAR   = 1490,   -- HH-60G Pave Hawk (SAR helicopter)
    MH60S_SAR  = 1488,   -- MH-60S Seahawk (SAR capable)
    HH60_LOAD  = 21720,  -- HH-60G SAR loadout
    RESCUE_PROX_NM = 2,  -- nm radius for successful rescue detection
}

-- KeyStore keys
local K = {
    RESCUE_HEL = 'CSAR_RESCUE_HEL_GUID',
    ACTIVE     = 'CSAR_ACTIVE',
    PILOT_GUID = 'CSAR_PILOT_GUID',
    PILOT_NAME = 'CSAR_PILOT_NAME',
    PILOT_LAT  = 'CSAR_PILOT_LAT',
    PILOT_LON  = 'CSAR_PILOT_LON',
    WINDOW_END = 'CSAR_WINDOW_END',
    ERROR      = 'CSAR_LAST_ERROR',
    TOTAL_SAVES = 'CSAR_SAVES',
    TOTAL_KIA   = 'CSAR_KIA',
}

-- ===== SHARED HELPERS ========================================

local function safeGet(guid)
    if not guid or guid == '' then return nil end
    local ok, u = pcall(ScenEdit_GetUnit, {guid=guid})
    return (ok and u) or nil
end

local function now()
    local ok, t = pcall(ScenEdit_CurrentTime)
    return (ok and t) or os.time()
end

-- ===== SETUP: RESCUE HELICOPTER ==============================

--- Pre-spawn the rescue helicopter so it can be assigned quickly.
--- It starts on the carrier and is assigned to the SAR mission on demand.
local function spawnRescueHelicopter()
    -- Check if already spawned
    if ScenEdit_GetKeyValue(K.RESCUE_HEL) ~= '' then return end

    local ok, helo = pcall(ScenEdit_AddUnit, {
        side        = BLUE,
        type        = 'Aircraft',
        name        = 'PEDRO-1 (HH-60G)',
        dbid        = DBID.HH60_SAR,
        loadoutid   = DBID.HH60_LOAD,
        Base        = RESCUE_BASE,
        latitude    = 34.0,    -- [CUSTOMISE] carrier position
        longitude   = 28.0,
        proficiency = 'Veteran',
    })
    if ok and helo then
        ScenEdit_SetKeyValue(K.RESCUE_HEL, helo.guid)
        print('[CSAR] Rescue helicopter pre-positioned: ' .. helo.guid)
    else
        print('[CSAR] WARNING: Could not spawn rescue helicopter: ' .. tostring(helo))
    end
end

--- Create the SAR patrol mission (initially inactive).
local function createSARMission()
    local ok, m = pcall(ScenEdit_AddMission, BLUE, 'CSAR Rescue', 'patrol', {type='air'})
    if ok and m then
        ScenEdit_SetMission(BLUE, 'CSAR Rescue', {
            isactive = false,
            flightsize = 1,
            checkzerofuel = true,
        })
        print('[CSAR] SAR mission created (inactive).')
    end
end

-- ===== SETUP: EVENT REGISTRATION =============================

--- Generate the event action script text (inline Lua for the event sandbox).
--- We use KeyStore for all state since event scripts can't reference upvalues.
local function buildHandlerScript()
    return
        '-- CSAR Handler: fires on UnitDestroyed for Blue aircraft\r\n'..
        'local ok, err = pcall(function()\r\n'..
        '    local u = ScenEdit_UnitX()\r\n'..
        '    if not u then return end\r\n'..
        '    if u.type ~= "Aircraft" then return end\r\n'..
        '\r\n'..
        '    local lat  = u.latitude\r\n'..
        '    local lon  = u.longitude\r\n'..
        '    local name = u.name\r\n'..
        '\r\n'..
        '    -- Score: aircraft loss\r\n'..
        '    local score = ScenEdit_GetScore("Blue")\r\n'..
        '    ScenEdit_SetScore("Blue", score - 25, "Aircraft lost: "..name)\r\n'..
        '\r\n'..
        '    -- Roll pilot survival (60% chance)\r\n'..
        '    math.randomseed(os.time())\r\n'..
        '    if math.random() > 0.60 then\r\n'..
        '        ScenEdit_SpecialMessage("Blue", name.." lost — no ejection detected.")\r\n'..
        '        return\r\n'..
        '    end\r\n'..
        '\r\n'..
        '    -- Only one CSAR active at a time\r\n'..
        '    if ScenEdit_GetKeyValue("CSAR_ACTIVE") == "1" then\r\n'..
        '        ScenEdit_SpecialMessage("Blue", "MAYDAY! "..name.." ejected — CSAR already in progress.")\r\n'..
        '        return\r\n'..
        '    end\r\n'..
        '    ScenEdit_SetKeyValue("CSAR_ACTIVE", "1")\r\n'..
        '\r\n'..
        '    -- Spawn downed pilot as a Facility\r\n'..
        '    local pilotName = "CSAR: "..name\r\n'..
        '    local pok, pilot = pcall(ScenEdit_AddUnit, {\r\n'..
        '        side="Blue", type="Facility", name=pilotName,\r\n'..
        '        dbid=259, latitude=lat, longitude=lon\r\n'..
        '    })\r\n'..
        '    if not pok or not pilot then return end\r\n'..
        '\r\n'..
        '    -- Persist state\r\n'..
        '    ScenEdit_SetKeyValue("CSAR_PILOT_GUID", pilot.guid)\r\n'..
        '    ScenEdit_SetKeyValue("CSAR_PILOT_NAME", name)\r\n'..
        '    ScenEdit_SetKeyValue("CSAR_PILOT_LAT",  tostring(lat))\r\n'..
        '    ScenEdit_SetKeyValue("CSAR_PILOT_LON",  tostring(lon))\r\n'..
        '\r\n'..
        '    -- SAR reference point\r\n'..
        '    local rpName = "EJECTION-"..string.sub(pilot.guid,1,6)\r\n'..
        '    pcall(ScenEdit_AddReferencePoint, {\r\n'..
        '        side="Blue", name=rpName,\r\n'..
        '        latitude=lat, longitude=lon, highlighted=true\r\n'..
        '    })\r\n'..
        '\r\n'..
        '    -- Activate SAR mission and assign helo\r\n'..
        '    pcall(ScenEdit_SetMission, "Blue", "CSAR Rescue", {isactive=true})\r\n'..
        '    local helGuid = ScenEdit_GetKeyValue("CSAR_RESCUE_HEL_GUID")\r\n'..
        '    if helGuid ~= "" then\r\n'..
        '        pcall(ScenEdit_AssignUnitToMission, helGuid, "CSAR Rescue")\r\n'..
        '    end\r\n'..
        '\r\n'..
        '    -- Schedule rescue window expiry\r\n'..
        '    local expiryTime = ScenEdit_CurrentTime() + 7200\r\n'..
        '    ScenEdit_SetKeyValue("CSAR_WINDOW_END", tostring(expiryTime))\r\n'..
        '    local evName = "CSARExpiry_"..string.sub(pilot.guid,1,6)\r\n'..
        '    local eok, ev = pcall(ScenEdit_SetEvent, evName, {\r\n'..
        '        mode="add", IsActive=true, IsRepeatable=false\r\n'..
        '    })\r\n'..
        '    if eok then\r\n'..
        '        pcall(ScenEdit_SetTrigger, {mode="add",type="Time",name=evName.."_T",time=expiryTime})\r\n'..
        '        pcall(ScenEdit_SetEventTrigger, ev.guid, {mode="add",name=evName.."_T"})\r\n'..
        '        local expScript =\r\n'..
        '            "local g=ScenEdit_GetKeyValue(\\"CSAR_PILOT_GUID\\")\\r\\n"...\r\n'..
        '            "if g~=\\"\\" then\\r\\n"...\r\n'..
        '            "  local ok2,u2=pcall(ScenEdit_GetUnit,{guid=g})\\r\\n"...\r\n'..
        '            "  if ok2 and u2 then\\r\\n"...\r\n'..
        '            "    pcall(ScenEdit_DeleteUnit,{guid=g})\\r\\n"...\r\n'..
        '            "    local n=tonumber(ScenEdit_GetKeyValue(\\"CSAR_KIA\\")) or 0\\r\\n"...\r\n'..
        '            "    ScenEdit_SetKeyValue(\\"CSAR_KIA\\",tostring(n+1))\\r\\n"...\r\n'..
        '            "    local s=ScenEdit_GetScore(\\"Blue\\")\\r\\n"...\r\n'..
        '            "    ScenEdit_SetScore(\\"Blue\\",s-50,\\"Pilot KIA\\")\\r\\n"...\r\n'..
        '            "    ScenEdit_SpecialMessage(\\"Blue\\",\\"CSAR window expired — pilot lost.\\")\\r\\n"...\r\n'..
        '            "  end\\r\\n"...\r\n'..
        '            "  ScenEdit_SetKeyValue(\\"CSAR_ACTIVE\\",\\"0\\")\\r\\n"...\r\n'..
        '            "end\\r\\n"\r\n'..
        '        pcall(ScenEdit_SetAction,{mode="add",type="LuaScript",name=evName.."_A",ScriptText=expScript})\r\n'..
        '        pcall(ScenEdit_SetEventAction, ev.guid, {mode="add",name=evName.."_A"})\r\n'..
        '    end\r\n'..
        '\r\n'..
        '    ScenEdit_SpecialMessage("Blue", string.format(\r\n'..
        '        "MAYDAY! %s ejected at %.3f, %.3f. CSAR activated — 120-minute rescue window.",\r\n'..
        '        name, lat, lon))\r\n'..
        'end)\r\n'..
        'if not ok then\r\n'..
        '    ScenEdit_SetKeyValue("CSAR_LAST_ERROR", tostring(err))\r\n'..
        'end\r\n'
end

--- Register the UnitDestroyed event that drives the CSAR system.
local function registerCSAREvent()
    local ok, ev = pcall(ScenEdit_SetEvent, 'CSAR_Handler', {
        mode='add', IsActive=true, IsRepeatable=true,
    })
    if not ok then
        print('[CSAR] Failed to create CSAR_Handler event: ' .. tostring(ev))
        return
    end

    -- Trigger: any Blue unit destroyed
    pcall(ScenEdit_SetTrigger, {
        mode     = 'add',
        type     = 'UnitDestroyed',
        name     = 'BlueUnitDestroyed',
        unitSide = BLUE,
        unitType = 'Aircraft',
    })
    pcall(ScenEdit_SetEventTrigger, ev.guid, {mode='add', name='BlueUnitDestroyed'})

    pcall(ScenEdit_SetAction, {
        mode       = 'add',
        type       = 'LuaScript',
        name       = 'CSAR_Action',
        ScriptText = buildHandlerScript(),
    })
    pcall(ScenEdit_SetEventAction, ev.guid, {mode='add', name='CSAR_Action'})
    print('[CSAR] UnitDestroyed event registered.')
end

-- ===== RESCUE SUCCESS CHECKER ================================
-- Call this from a RepeatTime event every 60 seconds.
-- Checks if the rescue helicopter is close to the downed pilot.

--- @return boolean  true if a pilot was rescued
function checkCSARSuccess()
    if ScenEdit_GetKeyValue(K.ACTIVE) ~= '1' then return false end

    local pilotGuid = ScenEdit_GetKeyValue(K.PILOT_GUID)
    local helGuid   = ScenEdit_GetKeyValue(K.RESCUE_HEL)
    if pilotGuid == '' or helGuid == '' then return false end

    local pilot = safeGet(pilotGuid)
    local helo  = safeGet(helGuid)
    if not pilot or not helo then return false end

    -- Check proximity
    local ok, dist = pcall(Tool_Range,
        {latitude=helo.latitude,  longitude=helo.longitude},
        {latitude=pilot.latitude, longitude=pilot.longitude})
    if not ok or not dist then return false end

    if dist <= DBID.RESCUE_PROX_NM then
        -- SUCCESS
        local saves = (tonumber(ScenEdit_GetKeyValue(K.TOTAL_SAVES)) or 0) + 1
        ScenEdit_SetKeyValue(K.TOTAL_SAVES, tostring(saves))
        ScenEdit_SetKeyValue(K.ACTIVE, '0')

        -- Remove pilot
        pcall(ScenEdit_DeleteUnit, {guid=pilotGuid})
        ScenEdit_SetKeyValue(K.PILOT_GUID, '')

        -- Award score
        local score = ScenEdit_GetScore(BLUE)
        ScenEdit_SetScore(BLUE, score + SCORE_PILOT_SAVE,
            'Pilot rescued: ' .. ScenEdit_GetKeyValue(K.PILOT_NAME))

        -- Deactivate SAR mission
        pcall(ScenEdit_SetMission, BLUE, 'CSAR Rescue', {isactive=false})

        ScenEdit_SpecialMessage(BLUE, string.format(
            'CSAR SUCCESS! %s recovered. +%d points. Total rescues: %d.',
            ScenEdit_GetKeyValue(K.PILOT_NAME), SCORE_PILOT_SAVE, saves))

        print('[CSAR] Pilot rescued successfully.')
        return true
    end

    return false
end

-- ===== REGISTER SUCCESS-CHECK EVENT ==========================

local function registerSuccessChecker()
    local ok, ev = pcall(ScenEdit_SetEvent, 'CSAR_ProxCheck', {
        mode='add', IsActive=true, IsRepeatable=true,
    })
    if not ok then return end

    pcall(ScenEdit_SetTrigger, {mode='add', type='RegularTime',
        name='CSAR_ProxTrigger', interval=60})
    pcall(ScenEdit_SetEventTrigger, ev.guid, {mode='add', name='CSAR_ProxTrigger'})

    local proxScript =
        'if ScenEdit_GetKeyValue("CSAR_ACTIVE") ~= "1" then return end\r\n'..
        'local pg = ScenEdit_GetKeyValue("CSAR_PILOT_GUID")\r\n'..
        'local hg = ScenEdit_GetKeyValue("CSAR_RESCUE_HEL_GUID")\r\n'..
        'if pg == "" or hg == "" then return end\r\n'..
        'local ok1, pilot = pcall(ScenEdit_GetUnit, {guid=pg})\r\n'..
        'local ok2, helo  = pcall(ScenEdit_GetUnit, {guid=hg})\r\n'..
        'if not (ok1 and pilot and ok2 and helo) then return end\r\n'..
        'local ok3, dist = pcall(Tool_Range,\r\n'..
        '    {latitude=helo.latitude, longitude=helo.longitude},\r\n'..
        '    {latitude=pilot.latitude, longitude=pilot.longitude})\r\n'..
        'if not ok3 or not dist or dist > 2 then return end\r\n'..
        '-- Rescue!\r\n'..
        'local saves = (tonumber(ScenEdit_GetKeyValue("CSAR_SAVES")) or 0) + 1\r\n'..
        'ScenEdit_SetKeyValue("CSAR_SAVES", tostring(saves))\r\n'..
        'ScenEdit_SetKeyValue("CSAR_ACTIVE", "0")\r\n'..
        'pcall(ScenEdit_DeleteUnit, {guid=pg})\r\n'..
        'ScenEdit_SetKeyValue("CSAR_PILOT_GUID", "")\r\n'..
        'local s = ScenEdit_GetScore("Blue")\r\n'..
        'ScenEdit_SetScore("Blue", s + 150, "Pilot rescued")\r\n'..
        'pcall(ScenEdit_SetMission, "Blue", "CSAR Rescue", {isactive=false})\r\n'..
        'local pn = ScenEdit_GetKeyValue("CSAR_PILOT_NAME")\r\n'..
        'ScenEdit_SpecialMessage("Blue", string.format(\r\n'..
        '    "CSAR SUCCESS! %s recovered. +150 pts. Rescues: %d.", pn, saves))\r\n'

    pcall(ScenEdit_SetAction, {
        mode='add', type='LuaScript', name='CSAR_ProxAction', ScriptText=proxScript,
    })
    pcall(ScenEdit_SetEventAction, ev.guid, {mode='add', name='CSAR_ProxAction'})
    print('[CSAR] Proximity check event registered.')
end

-- ===== MAIN SETUP ============================================

--- Call from GameSetup.lua to initialize the CSAR system.
function setupCSAR()
    local ok, err = pcall(function()
        -- Initialize KeyStore
        ScenEdit_SetKeyValue(K.ACTIVE,      '0')
        ScenEdit_SetKeyValue(K.PILOT_GUID,  '')
        ScenEdit_SetKeyValue(K.RESCUE_HEL,  '')
        ScenEdit_SetKeyValue(K.TOTAL_SAVES, '0')
        ScenEdit_SetKeyValue(K.TOTAL_KIA,   '0')
        ScenEdit_SetKeyValue(K.ERROR,       '')

        spawnRescueHelicopter()
        createSARMission()
        registerCSAREvent()
        registerSuccessChecker()
    end)

    if ok then
        print('[CSAR] System initialized.')
        ScenEdit_SpecialMessage(BLUE,
            'CSAR system active. Rescue helicopter PEDRO-1 on standby.\n'..
            'Pilots have a 60% chance of survival. 2-hour rescue window.')
    else
        print('[CSAR] Setup error: ' .. tostring(err))
        ScenEdit_SetKeyValue(K.ERROR, tostring(err))
    end
end

setupCSAR()
