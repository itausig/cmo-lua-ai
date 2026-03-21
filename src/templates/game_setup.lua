--- ============================================================
--- GameSetup.lua — Scenario Setup Template
--- Command: Modern Operations Scenario Boilerplate
---
--- PURPOSE:
---   This file runs ONCE at the scenario start time (T=0).
---   Use it to:
---     1. Create sides and set posture
---     2. Spawn all units with initial positions
---     3. Create missions and assign units
---     4. Set up the event system (TCA)
---     5. Configure initial doctrine
---     6. Register special actions
---     7. Initialize KeyStore state
---
--- IMPORTANT:
---   - Do NOT put this in LuaInit.lua; GameSetup runs once,
---     LuaInit runs on every load.
---   - Store all created GUIDs in KeyStore immediately.
---   - Wrap every section in pcall to prevent partial failure
---     from breaking the whole setup.
---
--- COPY THIS FILE to your scenario's Lua folder as GameSetup.lua
--- and customise sections marked [CUSTOMISE].
--- ============================================================

-- ===== VERSION TRACKING =====================================
local SCENARIO_NAME  = 'MyScenario'        -- [CUSTOMISE]
local SETUP_VERSION  = '1.0.0'
local SETUP_DATE     = '2026-01-01'        -- [CUSTOMISE]

-- ===== GUARD: PREVENT RE-RUNNING ============================
-- GameSetup should only run once. If the scenario has been
-- reloaded without a fresh start, skip all spawning.
if ScenEdit_GetKeyValue('SETUP_DONE') == '1' then
    print('[GameSetup] Already run — skipping.')
    return
end

print(string.rep('=', 50))
print(string.format('[GameSetup] %s v%s starting...', SCENARIO_NAME, SETUP_VERSION))
print(string.rep('=', 50))

-- ===== SIDE CONFIGURATION ====================================
-- [CUSTOMISE] Define sides, their display names, and postures.
-- Sides are usually created via the CMO editor; this section
-- sets postures and doctrine between them.

local BLUE_SIDE = 'Blue'   -- [CUSTOMISE] match exact side names in scenario
local RED_SIDE  = 'Red'

local function setupSides()
    -- Set initial posture between sides
    -- H=Hostile, F=Friendly, N=Neutral, U=Unfriendly
    pcall(ScenEdit_SetSidePosture, BLUE_SIDE, RED_SIDE,  'H')
    pcall(ScenEdit_SetSidePosture, RED_SIDE,  BLUE_SIDE, 'H')

    -- Set initial EMCON for sides
    -- pcall(ScenEdit_SetEMCON, 'Side', BLUE_SIDE, 'Radar=Active;Sonar=Active')
    -- pcall(ScenEdit_SetEMCON, 'Side', RED_SIDE,  'Radar=Passive;Sonar=Active')

    print('[GameSetup] Side posture configured.')
end

-- ===== DOCTRINE SETUP ========================================
-- Set weapon control status and engagement rules for each side.
-- WCS: Free=0, Tight=1, Hold=2

local function setupDoctrine()
    pcall(ScenEdit_SetDoctrine, {side=BLUE_SIDE}, {
        weapon_control_status_air        = 0,   -- Free
        weapon_control_status_surface    = 0,
        weapon_control_status_subsurface = 0,
        weapon_control_status_land       = 0,
        ignore_plotted_course            = 'no',
        use_nuclear_weapons              = 'no',
        engage_non_hostile_targets       = 'no',
        fuel_state_planned               = 'Bingo',
        fuel_state_rtb                   = 'Joker',
    })

    pcall(ScenEdit_SetDoctrine, {side=RED_SIDE}, {
        weapon_control_status_air        = 0,
        weapon_control_status_surface    = 0,
        weapon_control_status_subsurface = 0,
        weapon_control_status_land       = 0,
        use_nuclear_weapons              = 'no',
    })

    print('[GameSetup] Doctrine configured.')
end

-- ===== REFERENCE POINTS ======================================
-- [CUSTOMISE] Define reference points for patrol zones, exclusion
-- zones, and navigation waypoints.

local function setupReferencePoints()
    local rps = {
        -- Blue patrol zones
        -- {side=BLUE_SIDE, name='CAP-RP1', lat=38.5, lon=-72.0},
        -- {side=BLUE_SIDE, name='CAP-RP2', lat=39.0, lon=-72.0},
        -- {side=BLUE_SIDE, name='CAP-RP3', lat=39.0, lon=-71.0},
        -- {side=BLUE_SIDE, name='CAP-RP4', lat=38.5, lon=-71.0},

        -- Red patrol zones
        -- {side=RED_SIDE, name='RED-CAP-RP1', lat=36.0, lon=-69.0},
        -- ...
    }

    for _, rp in ipairs(rps) do
        pcall(ScenEdit_AddReferencePoint, {
            side        = rp.side,
            name        = rp.name,
            latitude    = rp.lat,
            longitude   = rp.lon,
            highlighted = false,
        })
    end

    print('[GameSetup] Reference points created.')
end

-- ===== UNIT SPAWNING — BLUE ==================================
-- [CUSTOMISE] Add your Blue force units here.
-- Always: 1) spawn the unit, 2) store GUID in KeyStore.

local function spawnBlueForces()
    -- ---- Surface Group ----
    -- local ok, carrier = pcall(ScenEdit_AddUnit, {
    --     side        = BLUE_SIDE,
    --     type        = 'Ship',
    --     name        = 'USS Nimitz',
    --     dbid        = 316,           -- look up in DB viewer
    --     latitude    = 36.5,
    --     longitude   = -10.5,
    --     heading     = 090,
    --     speed       = 15,
    --     proficiency = 'Veteran',
    -- })
    -- if ok and carrier then
    --     ScenEdit_SetKeyValue('NIMITZ_GUID', carrier.guid)
    --     print('[GameSetup] Spawned USS Nimitz: ' .. carrier.guid)
    -- end

    -- ---- Air Wing ----
    -- local ok2, f18 = pcall(ScenEdit_AddUnit, {
    --     side        = BLUE_SIDE,
    --     type        = 'Aircraft',
    --     name        = 'Hornet-1',
    --     dbid        = 1272,          -- F/A-18C
    --     loadoutid   = 21640,         -- BVR AAM loadout
    --     Base        = 'USS Nimitz',
    --     latitude    = 36.5,
    --     longitude   = -10.5,
    --     proficiency = 'Veteran',
    -- })
    -- if ok2 and f18 then
    --     ScenEdit_SetKeyValue('HORNET1_GUID', f18.guid)
    -- end

    print('[GameSetup] Blue forces spawned.')
end

-- ===== UNIT SPAWNING — RED ===================================
-- [CUSTOMISE] Add your Red force units here.

local function spawnRedForces()
    -- ---- Surface Group ----
    -- local ok, destroyer = pcall(ScenEdit_AddUnit, {
    --     side        = RED_SIDE,
    --     type        = 'Ship',
    --     name        = 'Sovremenny-1',
    --     dbid        = 498,           -- Sovremenny-class destroyer
    --     latitude    = 33.0,
    --     longitude   = -8.0,
    --     heading     = 270,
    --     speed       = 18,
    --     proficiency = 'Regular',
    -- })
    -- if ok and destroyer then
    --     ScenEdit_SetKeyValue('RED_DD1_GUID', destroyer.guid)
    -- end

    -- ---- Submarine ----
    -- local ok2, sub = pcall(ScenEdit_AddUnit, {
    --     side        = RED_SIDE,
    --     type        = 'Submarine',
    --     name        = 'Kilo-1',
    --     dbid        = 228,           -- Kilo-class SSK
    --     latitude    = 34.0,
    --     longitude   = -9.0,
    --     altitude    = -100,          -- 100m depth
    --     heading     = 180,
    --     speed       = 5,
    --     proficiency = 'Veteran',
    -- })
    -- if ok2 and sub then
    --     ScenEdit_SetKeyValue('RED_SSK1_GUID', sub.guid)
    --     pcall(ScenEdit_SetEMCON, 'Unit', sub.guid, 'Radar=Passive;Sonar=Active')
    -- end

    print('[GameSetup] Red forces spawned.')
end

-- ===== MISSION CREATION — BLUE ===============================
-- [CUSTOMISE] Create patrol, strike, and support missions.

local function createBlueMissions()
    -- ---- Combat Air Patrol ----
    -- local ok, capMission = pcall(ScenEdit_AddMission, BLUE_SIDE, 'CAP Alpha', 'patrol', {type='air'})
    -- if ok and capMission then
    --     ScenEdit_SetMission(BLUE_SIDE, 'CAP Alpha', {
    --         patrolzone     = {'CAP-RP1','CAP-RP2','CAP-RP3','CAP-RP4'},
    --         onethirdrule   = true,
    --         flightsize     = 2,
    --         minaircraftreq = 2,
    --         useflightsize  = true,
    --         checkzerofuel  = true,
    --     })
    --     ScenEdit_SetKeyValue('CAP_MISSION_GUID', capMission.guid)
    --     -- Assign aircraft
    --     local hornet1 = ScenEdit_GetKeyValue('HORNET1_GUID')
    --     if hornet1 ~= '' then
    --         pcall(ScenEdit_AssignUnitToMission, hornet1, 'CAP Alpha')
    --     end
    -- end

    -- ---- Strike Mission (initially inactive) ----
    -- local ok2, strikeMission = pcall(ScenEdit_AddMission, BLUE_SIDE, 'Strike Alpha', 'strike', {type='land'})
    -- if ok2 and strikeMission then
    --     ScenEdit_SetMission(BLUE_SIDE, 'Strike Alpha', {isactive=false})
    --     ScenEdit_SetKeyValue('STRIKE_MISSION_GUID', strikeMission.guid)
    -- end

    print('[GameSetup] Blue missions created.')
end

-- ===== MISSION CREATION — RED ================================

local function createRedMissions()
    -- ---- Red Naval Patrol ----
    -- local ok, navPatrol = pcall(ScenEdit_AddMission, RED_SIDE, 'Red NavPat', 'patrol', {type='naval'})
    -- if ok and navPatrol then
    --     ScenEdit_SetMission(RED_SIDE, 'Red NavPat', {
    --         patrolzone   = {'RED-CAP-RP1','RED-CAP-RP2','RED-CAP-RP3','RED-CAP-RP4'},
    --         onethirdrule = false,
    --     })
    -- end

    print('[GameSetup] Red missions created.')
end

-- ===== EVENT SYSTEM SETUP ====================================
-- [CUSTOMISE] Create all scenario events, triggers, and actions.

local function createEvents()
    -- ---- ScenLoaded event (handled by LuaInit — skip here) ----

    -- ---- Example: Timed Phase Transition ----
    -- local phaseTime = ScenEdit_CurrentTime() + (4 * 3600)  -- T+4 hours
    -- local ok, phaseEv = pcall(ScenEdit_SetEvent, 'Phase2Transition', {
    --     mode='add', IsActive=true, IsRepeatable=false,
    -- })
    -- if ok then
    --     pcall(ScenEdit_SetTrigger, {mode='add', type='Time', name='Phase2Timer', time=phaseTime})
    --     pcall(ScenEdit_SetEventTrigger, phaseEv.guid, {mode='add', name='Phase2Timer'})
    --     pcall(ScenEdit_SetAction, {mode='add', type='LuaScript', name='Phase2Action',
    --         ScriptText='ScenEdit_SetKeyValue("SCENARIO_PHASE","2")\r\n'..
    --                    'ScenEdit_SpecialMessage("Blue","Phase 2 commenced.")\r\n'})
    --     pcall(ScenEdit_SetEventAction, phaseEv.guid, {mode='add', name='Phase2Action'})
    -- end

    -- ---- Example: Unit Destroyed event ----
    -- local nimitzGuid = ScenEdit_GetKeyValue('NIMITZ_GUID')
    -- if nimitzGuid ~= '' then
    --     local ok2, lossEv = pcall(ScenEdit_SetEvent, 'CarrierLoss', {
    --         mode='add', IsActive=true, IsRepeatable=false,
    --     })
    --     if ok2 then
    --         pcall(ScenEdit_SetTrigger, {mode='add', type='UnitDestroyed',
    --             name='NimitzDestroyed', unitguid=nimitzGuid})
    --         pcall(ScenEdit_SetEventTrigger, lossEv.guid, {mode='add', name='NimitzDestroyed'})
    --         pcall(ScenEdit_SetAction, {mode='add', type='LuaScript', name='CarrierLossAction',
    --             ScriptText='ScenEdit_SpecialMessage("Blue","USS Nimitz has been sunk! Scenario over.")\r\n'..
    --                        'ScenEdit_SetScore("Blue", -1000, "Carrier lost")\r\n'..
    --                        'ScenEdit_EndScenario()\r\n'})
    --         pcall(ScenEdit_SetEventAction, lossEv.guid, {mode='add', name='CarrierLossAction'})
    --     end
    -- end

    print('[GameSetup] Events created.')
end

-- ===== SPECIAL ACTIONS REGISTRATION =========================
-- [CUSTOMISE] Add player-accessible special actions.

local function registerSpecialActions()
    -- pcall(ScenEdit_SetSpecialAction, {
    --     mode       = 'add',
    --     name       = 'Request CAS',
    --     IsActive   = true,
    --     ScriptText = '-- CAS request logic here',
    -- })

    print('[GameSetup] Special actions registered.')
end

-- ===== INITIAL STATE INITIALIZATION =========================

local function initKeyStore()
    ScenEdit_SetKeyValue('SCENARIO_PHASE', '1')
    ScenEdit_SetKeyValue('WAVE_COUNT',     '0')
    ScenEdit_SetKeyValue('KILL_COUNT',     '0')
    ScenEdit_SetKeyValue('WAR_STARTED',    '0')
    -- [CUSTOMISE] Add all scenario-specific state keys here

    print('[GameSetup] KeyStore initialized.')
end

-- ===== INITIAL MESSAGE TO PLAYER ============================
local function sendBriefing()
    -- [CUSTOMISE] Send a briefing message
    -- ScenEdit_SpecialMessage(BLUE_SIDE, [[
    -- OPERATION [NAME]
    -- ...briefing text...
    -- ]])
end

-- ===== EXECUTE ALL SETUP SECTIONS ===========================
-- Each section wrapped in pcall so a failure in one section
-- does not prevent subsequent sections from running.

local sections = {
    {'Sides',           setupSides},
    {'Doctrine',        setupDoctrine},
    {'ReferencePoints', setupReferencePoints},
    {'BlueForces',      spawnBlueForces},
    {'RedForces',       spawnRedForces},
    {'BlueMissions',    createBlueMissions},
    {'RedMissions',     createRedMissions},
    {'Events',          createEvents},
    {'SpecialActions',  registerSpecialActions},
    {'KeyStore',        initKeyStore},
    {'Briefing',        sendBriefing},
}

local errors = {}
for _, section in ipairs(sections) do
    local name, fn = section[1], section[2]
    local ok, err = pcall(fn)
    if not ok then
        print(string.format('[GameSetup] ERROR in section %s: %s', name, tostring(err)))
        errors[#errors+1] = name .. ': ' .. tostring(err)
    end
end

-- Mark setup as done
ScenEdit_SetKeyValue('SETUP_DONE', '1')

if #errors > 0 then
    ScenEdit_SetKeyValue('SETUP_ERRORS', table.concat(errors, '; '))
    print('[GameSetup] Completed with ' .. #errors .. ' error(s). Check SETUP_ERRORS key.')
else
    print('[GameSetup] Setup completed successfully.')
end

print(string.rep('=', 50))
