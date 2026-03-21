--- ============================================================
--- Dynamic Campaign System
--- Multi-phase campaign with escalation, reinforcements,
--- dynamic objectives, and persistent state.
---
--- Phases:
---   Phase 1 — Peacetime Patrol (neutral posture)
---   Phase 2 — Crisis (unfriendly, blue launches CAP)
---   Phase 3 — Open War (hostile, full offensive operations)
---   Phase 4 — Endgame (score-based victory/defeat check)
---
--- Features:
---   - Phase transitions driven by score thresholds AND time
---   - Timed reinforcement waves
---   - Escalation ladder: Neutral → Unfriendly → Hostile
---   - Dynamic objective messages via SpecialMessage
---   - Side switching for captured/defecting units
---   - Persistent state across saves via KeyStore
--- ============================================================

-- ===== CONSTANTS =============================================

local BLUE = 'Blue'
local RED  = 'Red'

-- Phase score thresholds (Blue must reach these to advance)
local PHASE_THRESHOLDS = {
    [1] = 0,    -- Start in Phase 1
    [2] = 100,  -- Blue reaches 100 pts → Phase 2 (Crisis)
    [3] = 300,  -- Blue reaches 300 pts → Phase 3 (Open War)
    [4] = 600,  -- Blue reaches 600 pts → Phase 4 (Endgame check)
}

-- Time-based escalation (seconds from scenario start)
local ESCALATION_TIMES = {
    [2] = 4 * 3600,    -- Phase 2 unlocks at T+4h
    [3] = 8 * 3600,    -- Phase 3 unlocks at T+8h
    [4] = 16 * 3600,   -- Phase 4 unlocks at T+16h
}

-- Reinforcement waves (side, dbid, count, timing)
local REINFORCE_WAVES = {
    {wave=1, side=BLUE, phase=2, delay=1800,  name='Blue Wave 1',
     units={{type='Ship',  name='USS Sampson',  dbid=2869, lat=35.0, lon=27.5}}},
    {wave=2, side=BLUE, phase=3, delay=3600,  name='Blue Wave 2',
     units={{type='Aircraft', name='Eagle-5', dbid=1479, loadoutid=21640, base='USS Nimitz (CVN-68)', lat=34.0, lon=28.0},
            {type='Aircraft', name='Eagle-6', dbid=1479, loadoutid=21640, base='USS Nimitz (CVN-68)', lat=34.0, lon=28.0}}},
    {wave=1, side=RED,  phase=2, delay=2400,  name='Red Wave 1',
     units={{type='Ship', name='Krivak-2', dbid=310, lat=30.0, lon=32.0}}},
    {wave=2, side=RED,  phase=3, delay=3000,  name='Red Wave 2',
     units={{type='Submarine', name='Kilo-2', dbid=228, lat=29.0, lon=31.0, depth=-100}}},
}

-- KeyStore keys
local K = {
    PHASE         = 'CAMPAIGN_PHASE',
    PHASE_START   = 'CAMPAIGN_PHASE_START_',
    WAVE_SENT     = 'CAMPAIGN_WAVE_SENT_',
    ESCALATED     = 'CAMPAIGN_ESCALATED',
    WINNER        = 'CAMPAIGN_WINNER',
    SCENARIO_END  = 'CAMPAIGN_ENDED',
}

-- ===== UTILITIES =============================================

local function getPhase()
    return tonumber(ScenEdit_GetKeyValue(K.PHASE)) or 1
end

local function setPhase(n)
    ScenEdit_SetKeyValue(K.PHASE, tostring(n))
    ScenEdit_SetKeyValue(K.PHASE_START .. n, tostring(ScenEdit_CurrentTime()))
    print('[Campaign] Phase set to ' .. n)
end

local function getScore(side)
    local ok, s = pcall(ScenEdit_GetScore, side)
    return (ok and type(s) == 'number') and s or 0
end

local function msg(side, text)
    pcall(ScenEdit_SpecialMessage, side, text)
    print('[Campaign] MSG→' .. side .. ': ' .. text)
end

-- ===== PHASE TRANSITION LOGIC ================================

--- Set posture between all sides based on current phase.
--- @param phase number
local function applyPostureForPhase(phase)
    local posture = {
        [1] = 'N',   -- Neutral
        [2] = 'U',   -- Unfriendly
        [3] = 'H',   -- Hostile
        [4] = 'H',   -- Hostile (endgame)
    }
    local p = posture[phase] or 'N'
    pcall(ScenEdit_SetSidePosture, BLUE, RED, p)
    pcall(ScenEdit_SetSidePosture, RED, BLUE, p)
end

--- Apply doctrine changes for a given phase.
local function applyDoctrineForPhase(phase)
    if phase == 1 then
        -- Peacetime: Hold all weapons
        pcall(ScenEdit_SetDoctrine, {side=BLUE}, {
            weapon_control_status_air=2, weapon_control_status_surface=2,
            weapon_control_status_subsurface=2,
        })
        pcall(ScenEdit_SetDoctrine, {side=RED}, {
            weapon_control_status_air=2, weapon_control_status_surface=2,
        })
    elseif phase == 2 then
        -- Crisis: Tight (defensive only)
        pcall(ScenEdit_SetDoctrine, {side=BLUE}, {
            weapon_control_status_air=1, weapon_control_status_surface=1,
        })
        pcall(ScenEdit_SetDoctrine, {side=RED}, {
            weapon_control_status_air=1, weapon_control_status_surface=1,
        })
    elseif phase >= 3 then
        -- War: Free
        pcall(ScenEdit_SetDoctrine, {side=BLUE}, {
            weapon_control_status_air=0, weapon_control_status_surface=0,
            weapon_control_status_subsurface=0,
        })
        pcall(ScenEdit_SetDoctrine, {side=RED}, {
            weapon_control_status_air=0, weapon_control_status_surface=0,
            weapon_control_status_subsurface=0,
        })
    end
end

--- Mission activations per phase.
local function activateMissionsForPhase(phase)
    if phase == 2 then
        pcall(ScenEdit_SetMission, BLUE, 'CSG-CAP Forward', {isactive=true})
        pcall(ScenEdit_SetMission, BLUE, 'CSG-CAP Aft',     {isactive=true})
        pcall(ScenEdit_SetMission, BLUE, 'CSG-AEW',         {isactive=true})
    elseif phase == 3 then
        pcall(ScenEdit_SetMission, BLUE, 'CSG-Strike Alpha', {isactive=true})
        pcall(ScenEdit_SetMission, BLUE, 'CSG-ECM Support',  {isactive=true})
    end
end

--- Phase briefing messages.
local PHASE_MSGS = {
    [2] = {
        [BLUE] = 'CRISIS: Diplomatic relations have broken down.\n'..
                 'CAP and AEW missions activated. Rules of engagement: Defensive only.\n'..
                 'Do NOT fire unless fired upon.',
        [RED]  = 'CONFRONTATION: Blue forces have been detected.\n'..
                 'All units to defensive posture. Air defense activated.',
    },
    [3] = {
        [BLUE] = 'WAR: HOSTILITIES COMMENCED.\n'..
                 'All Red forces designated hostile. Strike package authorized.',
        [RED]  = 'WAR: Blue forces have opened fire.\n'..
                 'All units weapons free. Attack Blue naval forces.',
    },
    [4] = {
        [BLUE] = 'ENDGAME: The campaign is entering its final phase.\n'..
                 'Destroy all Red combat capability to achieve victory.',
        [RED]  = 'CRITICAL: Combat losses are unsustainable.\n'..
                 'Defend remaining assets at all costs.',
    },
}

--- Execute all phase transition actions.
--- @param newPhase number
local function executePhaseTransition(newPhase)
    local prevPhase = getPhase()
    if newPhase <= prevPhase then return end  -- don't go backwards

    print(string.format('[Campaign] Transitioning Phase %d → %d', prevPhase, newPhase))
    setPhase(newPhase)
    applyPostureForPhase(newPhase)
    applyDoctrineForPhase(newPhase)
    activateMissionsForPhase(newPhase)

    -- Send messages
    local msgs = PHASE_MSGS[newPhase]
    if msgs then
        if msgs[BLUE] then msg(BLUE, msgs[BLUE]) end
        if msgs[RED]  then msg(RED,  msgs[RED])  end
    end
end

-- ===== REINFORCEMENT WAVES ===================================

--- Spawn a single reinforcement wave.
--- @param waveDef table
local function spawnWave(waveDef)
    local waveKey = K.WAVE_SENT .. waveDef.side .. '_' .. waveDef.wave
    if ScenEdit_GetKeyValue(waveKey) == '1' then return end  -- already sent

    print(string.format('[Campaign] Spawning %s', waveDef.name))
    local spawned = 0

    for _, uDef in ipairs(waveDef.units) do
        local params = {
            side        = waveDef.side,
            type        = uDef.type,
            name        = uDef.name,
            dbid        = uDef.dbid,
            latitude    = uDef.lat,
            longitude   = uDef.lon or 0,
            proficiency = uDef.proficiency or 'Regular',
        }
        if uDef.loadoutid then params.loadoutid = uDef.loadoutid end
        if uDef.base      then params.Base      = uDef.base      end
        if uDef.depth     then params.altitude  = uDef.depth     end
        if uDef.heading   then params.heading   = uDef.heading   end

        local ok, unit = pcall(ScenEdit_AddUnit, params)
        if ok and unit then
            spawned = spawned + 1
            ScenEdit_SetKeyValue('REINFORCE_' .. uDef.name:upper():gsub('[^A-Z0-9]','_'), unit.guid)
        end
    end

    ScenEdit_SetKeyValue(waveKey, '1')
    msg(waveDef.side, string.format('Reinforcements arrived: %s (%d unit(s))', waveDef.name, spawned))
end

--- Check and send all due reinforcement waves for current phase.
local function checkReinforcements()
    local phase = getPhase()
    local currentTime = ScenEdit_CurrentTime()

    for _, waveDef in ipairs(REINFORCE_WAVES) do
        if waveDef.phase <= phase then
            -- Check if delay after phase start has elapsed
            local phaseStart = tonumber(ScenEdit_GetKeyValue(K.PHASE_START .. waveDef.phase)) or 0
            if phaseStart > 0 and (currentTime - phaseStart) >= waveDef.delay then
                spawnWave(waveDef)
            end
        end
    end
end

-- ===== VICTORY/DEFEAT CHECK ==================================

local WIN_SCORE   = 800    -- Blue total score for victory
local DEFEAT_SCORE = -200  -- Blue score for defeat (Red wins)

local function checkEndConditions()
    if ScenEdit_GetKeyValue(K.SCENARIO_END) == '1' then return end
    local phase = getPhase()
    if phase < 3 then return end  -- no end check before war

    local blueScore = getScore(BLUE)
    local redScore  = getScore(RED)

    if blueScore >= WIN_SCORE then
        ScenEdit_SetKeyValue(K.WINNER, BLUE)
        ScenEdit_SetKeyValue(K.SCENARIO_END, '1')
        msg(BLUE, string.format('VICTORY! Blue forces have achieved all objectives. Score: %d', blueScore))
        msg(RED,  'DEFEAT: All combat objectives lost. Scenario ended.')
        pcall(ScenEdit_EndScenario)
        return
    end

    if blueScore <= DEFEAT_SCORE or redScore >= WIN_SCORE then
        ScenEdit_SetKeyValue(K.WINNER, RED)
        ScenEdit_SetKeyValue(K.SCENARIO_END, '1')
        msg(BLUE, string.format('DEFEAT: Blue forces have failed. Score: %d', blueScore))
        msg(RED,  string.format('VICTORY! Red forces have repelled Blue aggression. Score: %d', redScore))
        pcall(ScenEdit_EndScenario)
    end
end

-- ===== SIDE SWITCHING ========================================
-- Demonstrates capturing a unit and switching it to another side.

--- Transfer a unit to another side (simulate capture/defection).
--- @param unitGuid string
--- @param newSide  string
--- @param reason   string
local function transferUnit(unitGuid, newSide, reason)
    local ok, err = pcall(ScenEdit_SetUnitSide, {guid=unitGuid, side=newSide})
    if ok then
        print(string.format('[Campaign] Unit %s transferred to %s: %s', unitGuid, newSide, reason))
    else
        print(string.format('[Campaign] Transfer failed: %s', tostring(err)))
    end
    return ok
end

-- ===== MAIN CAMPAIGN ENGINE ==================================
-- Runs every 60 seconds from a RegularTime event.

--- Main campaign loop — checks phase, reinforcements, end conditions.
function campaignTick()
    if ScenEdit_GetKeyValue(K.SCENARIO_END) == '1' then return end

    local currentScore = getScore(BLUE)
    local currentPhase = getPhase()
    local currentTime  = ScenEdit_CurrentTime()

    -- Check for phase advancement (score OR time threshold)
    for phase = currentPhase + 1, 4 do
        local scoreOk = currentScore >= (PHASE_THRESHOLDS[phase] or 9999)
        local timeOk  = currentTime  >= (ESCALATION_TIMES[phase]  or 999999)
        if scoreOk or timeOk then
            executePhaseTransition(phase)
            break  -- one phase at a time
        end
    end

    checkReinforcements()
    checkEndConditions()
end

-- ===== EVENT SETUP ===========================================

local function createCampaignEvents()
    -- 1. ScenLoaded — restore phase on every load
    local ok1, loadEv = pcall(ScenEdit_SetEvent, 'CampaignLoad', {
        mode='add', IsActive=true, IsRepeatable=true,
    })
    if ok1 then
        pcall(ScenEdit_SetTrigger, {mode='add', type='ScenLoaded', name='CampaignScenLoaded'})
        pcall(ScenEdit_SetEventTrigger, loadEv.guid, {mode='add', name='CampaignScenLoaded'})
        local restoreScript =
            'local p = tonumber(ScenEdit_GetKeyValue("CAMPAIGN_PHASE")) or 1\r\n'..
            'print("[Campaign] Loaded in Phase "..p)\r\n'
        pcall(ScenEdit_SetAction, {mode='add', type='LuaScript',
            name='CampaignLoad_Action', ScriptText=restoreScript})
        pcall(ScenEdit_SetEventAction, loadEv.guid, {mode='add', name='CampaignLoad_Action'})
    end

    -- 2. RegularTime tick — main campaign loop
    local ok2, tickEv = pcall(ScenEdit_SetEvent, 'CampaignTick', {
        mode='add', IsActive=true, IsRepeatable=true,
    })
    if ok2 then
        pcall(ScenEdit_SetTrigger, {mode='add', type='RegularTime',
            name='CampaignTick_Timer', interval=60})
        pcall(ScenEdit_SetEventTrigger, tickEv.guid, {mode='add', name='CampaignTick_Timer'})

        -- Inline tick logic (sandbox-safe, uses KeyStore)
        local tickScript =
            'if ScenEdit_GetKeyValue("CAMPAIGN_ENDED") == "1" then return end\r\n'..
            'local phase = tonumber(ScenEdit_GetKeyValue("CAMPAIGN_PHASE")) or 1\r\n'..
            'local blueScore = ScenEdit_GetScore("Blue") or 0\r\n'..
            'local t = ScenEdit_CurrentTime()\r\n'..
            '\r\n'..
            '-- Phase advancement check\r\n'..
            'local thresholds = {0,100,300,600}\r\n'..
            'local times      = {0, 4*3600, 8*3600, 16*3600}\r\n'..
            'for nextPhase = phase+1, 4 do\r\n'..
            '    if blueScore >= thresholds[nextPhase] or t >= (ScenEdit_CurrentTime()-(t%86400) + times[nextPhase]) then\r\n'..
            '        ScenEdit_SetKeyValue("CAMPAIGN_PHASE", tostring(nextPhase))\r\n'..
            '        ScenEdit_SetKeyValue("CAMPAIGN_PHASE_START_"..nextPhase, tostring(t))\r\n'..
            '        local postures = {"N","N","U","H","H"}\r\n'..
            '        pcall(ScenEdit_SetSidePosture,"Blue","Red",postures[nextPhase+1])\r\n'..
            '        pcall(ScenEdit_SetSidePosture,"Red","Blue",postures[nextPhase+1])\r\n'..
            '        ScenEdit_SpecialMessage("Blue","Campaign Phase "..nextPhase.." commenced.")\r\n'..
            '        break\r\n'..
            '    end\r\n'..
            'end\r\n'..
            '\r\n'..
            '-- Endgame check\r\n'..
            'if phase >= 3 and blueScore >= 800 then\r\n'..
            '    ScenEdit_SetKeyValue("CAMPAIGN_ENDED","1")\r\n'..
            '    ScenEdit_SpecialMessage("Blue","VICTORY! Score: "..blueScore)\r\n'..
            '    pcall(ScenEdit_EndScenario)\r\n'..
            'end\r\n'

        pcall(ScenEdit_SetAction, {mode='add', type='LuaScript',
            name='CampaignTick_Action', ScriptText=tickScript})
        pcall(ScenEdit_SetEventAction, tickEv.guid, {mode='add', name='CampaignTick_Action'})
    end

    print('[Campaign] Events created.')
end

-- ===== INIT ==================================================

local function initCampaign()
    local ok, err = pcall(function()
        -- Initialize state only on first run
        if ScenEdit_GetKeyValue(K.PHASE) == '' then
            ScenEdit_SetKeyValue(K.PHASE,         '1')
            ScenEdit_SetKeyValue(K.ESCALATED,     '0')
            ScenEdit_SetKeyValue(K.WINNER,        '')
            ScenEdit_SetKeyValue(K.SCENARIO_END,  '0')
            -- Phase 1 start time
            ScenEdit_SetKeyValue(K.PHASE_START .. '1', tostring(ScenEdit_CurrentTime()))
        end

        -- Apply starting posture (Phase 1 = Neutral)
        applyPostureForPhase(1)
        applyDoctrineForPhase(1)
        createCampaignEvents()
    end)

    if ok then
        print('[Campaign] Dynamic campaign initialized — Phase 1 (Peacetime Patrol).')
        msg(BLUE,
            'OPERATION STEEL HORIZON\n'..
            'Phase 1: Peacetime patrol. Rules of engagement: Weapons HOLD.\n'..
            'Advance to Phase 2 by scoring 100 points or after 4 hours.')
    else
        print('[Campaign] Init error: ' .. tostring(err))
    end
end

initCampaign()
