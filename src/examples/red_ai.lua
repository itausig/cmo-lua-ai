--- ============================================================
--- Red Force AI — Advanced Adaptive Opponent
--- Reactive doctrine, adaptive EMCON, coordinated attacks,
--- reserve force commitment, and IADS behavior.
---
--- Run every 120 seconds via RepeatTime event.
--- All state stored in KeyStore (sandbox-safe).
---
--- Features:
---   - Reactive doctrine changes based on loss thresholds
---   - Adaptive EMCON (go dark when being hunted)
---   - Coordinated strike packages (timing + ECM + strike)
---   - Reserve force commit based on threat level
---   - Randomized attack timing (unpredictability)
---   - IADS: radar on/off based on detected threats
--- ============================================================

-- ===== CONSTANTS =============================================

local RED  = 'Red'
local BLUE = 'Blue'

-- Loss thresholds that change Red AI behavior
local LOSS_CAUTIOUS    = 3   -- Red changes to defensive after 3 losses
local LOSS_DESPERATE   = 6   -- Red commits reserves and attacks after 6 losses
local LOSS_WITHDRAW    = 10  -- Red withdraws remaining forces

-- Threat distance that activates IADS (nm)
local IADS_ACTIVATION_RANGE = 150

-- Strike package timing — hours between coordinated attacks
local MIN_STRIKE_INTERVAL = 2 * 3600   -- minimum 2 hours between strikes
local MAX_STRIKE_INTERVAL = 5 * 3600   -- maximum 5 hours

-- Randomization seed (reset each tick)
math.randomseed(os.time())

-- KeyStore keys
local K = {
    LOSSES           = 'RED_AI_LOSSES',
    LAST_STRIKE      = 'RED_AI_LAST_STRIKE',
    NEXT_STRIKE      = 'RED_AI_NEXT_STRIKE',
    STATE            = 'RED_AI_STATE',  -- 'aggressive','defensive','desperate','withdrawn'
    IADS_HOT         = 'RED_AI_IADS_HOT',
    RESERVES_COMMITTED = 'RED_AI_RESERVES_COMMITTED',
    ERROR            = 'RED_AI_ERROR',

    -- Unit GUID keys (set by GameSetup)
    SAM1_GUID        = 'RED_SAM1_GUID',
    SAM2_GUID        = 'RED_SAM2_GUID',
    SAM3_GUID        = 'RED_SAM3_GUID',
    EWR_GUID         = 'RED_EWR_GUID',
    STRIKE_1_GUID    = 'RED_STRIKE1_GUID',
    STRIKE_2_GUID    = 'RED_STRIKE2_GUID',
    ESCORT_GUID      = 'RED_ESCORT_GUID',
    RESERVE_SUB_GUID = 'RED_RESERVE_SUB_GUID',
    RESERVE_AC_GUID  = 'RED_RESERVE_AC_GUID',
}

-- ===== UTILITIES =============================================

local function safeGet(guid)
    if not guid or guid == '' then return nil end
    local ok, u = pcall(ScenEdit_GetUnit, {guid=guid})
    return (ok and u) or nil
end

local function getKeyNum(key)
    return tonumber(ScenEdit_GetKeyValue(key)) or 0
end

local function setKeyNum(key, val)
    ScenEdit_SetKeyValue(key, tostring(val))
end

local function now()
    local ok, t = pcall(ScenEdit_CurrentTime)
    return (ok and t) or os.time()
end

--- Count remaining Red units (alive) of a given type.
--- @param unitType string|nil  nil = all types
--- @return number
local function countRedUnits(unitType)
    local ok, side = pcall(VP_GetSide, {Side=RED})
    if not ok or not side then return 0 end
    local count = 0
    for _, u in ipairs(side.units or {}) do
        if unitType == nil or u.type == unitType then
            count = count + 1
        end
    end
    return count
end

--- Count Blue contacts visible to Red (threat level indicator).
--- @return number
local function countBlueThreatContacts()
    local ok, side = pcall(VP_GetSide, {Side=RED})
    if not ok or not side then return 0 end
    return #(side.contacts or {})
end

--- Check if any Blue contact is within range_nm of a point.
--- @param lat number, lon number, rangeNm number
--- @return boolean
local function blueThreatNearby(lat, lon, rangeNm)
    local ok, side = pcall(VP_GetSide, {Side=RED})
    if not ok or not side then return false end
    for _, c in ipairs(side.contacts or {}) do
        if c.latitude and c.longitude then
            local ok2, dist = pcall(Tool_Range,
                {latitude=lat, longitude=lon},
                {latitude=c.latitude, longitude=c.longitude})
            if ok2 and type(dist) == 'number' and dist <= rangeNm then
                return true
            end
        end
    end
    return false
end

-- ===== STATE MACHINE =========================================

local function getState()
    return ScenEdit_GetKeyValue(K.STATE)
end

local function setState(newState)
    local prev = getState()
    if prev == newState then return end
    ScenEdit_SetKeyValue(K.STATE, newState)
    print(string.format('[RedAI] State: %s → %s', prev, newState))
end

--- Evaluate and update Red's tactical state based on losses.
local function updateState()
    local losses = getKeyNum(K.LOSSES)
    local alive  = countRedUnits()

    if ScenEdit_GetKeyValue(K.RESERVES_COMMITTED) ~= '1' and losses >= LOSS_DESPERATE then
        setState('desperate')
    elseif losses >= LOSS_CAUTIOUS then
        setState('defensive')
    elseif losses >= LOSS_WITHDRAW then
        setState('withdrawn')
    else
        setState('aggressive')
    end
end

-- ===== DOCTRINE MANAGEMENT ===================================

--- Apply doctrine changes based on current state.
local function applyDoctrine()
    local state = getState()

    if state == 'aggressive' then
        pcall(ScenEdit_SetDoctrine, {side=RED}, {
            weapon_control_status_air        = 0,  -- Free
            weapon_control_status_surface    = 0,
            weapon_control_status_subsurface = 0,
            ignore_plotted_course            = 'no',
        })
    elseif state == 'defensive' then
        pcall(ScenEdit_SetDoctrine, {side=RED}, {
            weapon_control_status_air        = 1,  -- Tight
            weapon_control_status_surface    = 1,
            weapon_control_status_subsurface = 0,
        })
    elseif state == 'desperate' then
        -- Desperate: full WCS free, no rules
        pcall(ScenEdit_SetDoctrine, {side=RED}, {
            weapon_control_status_air        = 0,
            weapon_control_status_surface    = 0,
            weapon_control_status_subsurface = 0,
        })
    elseif state == 'withdrawn' then
        pcall(ScenEdit_SetDoctrine, {side=RED}, {
            weapon_control_status_air        = 2,  -- Hold
            weapon_control_status_surface    = 2,
            weapon_control_status_subsurface = 1,
        })
    end
end

-- ===== ADAPTIVE EMCON ========================================
-- Go dark (radar passive) when a Red unit is being targeted.
-- Activate radar only when threats are nearby and we're aggressive.

local IADS_UNIT_KEYS = {K.SAM1_GUID, K.SAM2_GUID, K.SAM3_GUID}
local EWR_KEYS       = {K.EWR_GUID}

local function manageEMCON()
    local state      = getState()
    local blueCount  = countBlueThreatContacts()
    local isHot      = blueCount >= 1

    -- EWR: always on in aggressive, off in withdrawn/defensive (to avoid detection)
    for _, key in ipairs(EWR_KEYS) do
        local unit = safeGet(ScenEdit_GetKeyValue(key))
        if unit then
            local emcon = (state == 'aggressive' or state == 'desperate')
                and 'Radar=Active'
                or  'Radar=Passive'
            pcall(ScenEdit_SetEMCON, 'Unit', unit.guid, emcon)
        end
    end

    -- SAM radars: activate only when threat nearby (pop-up doctrine)
    for _, key in ipairs(IADS_UNIT_KEYS) do
        local unit = safeGet(ScenEdit_GetKeyValue(key))
        if unit then
            local threat = blueThreatNearby(unit.latitude, unit.longitude, IADS_ACTIVATION_RANGE)
            local emcon
            if state == 'withdrawn' then
                emcon = 'Radar=Passive;OECM=Passive'
            elseif threat and state ~= 'defensive' then
                emcon = 'Radar=Active;OECM=Active'   -- light up when target detected
            else
                emcon = 'Radar=Passive;OECM=Passive' -- dark when safe or defensive
            end
            pcall(ScenEdit_SetEMCON, 'Unit', unit.guid, emcon)
        end
    end

    setKeyNum(K.IADS_HOT, isHot and 1 or 0)
end

-- ===== COORDINATED STRIKE MANAGEMENT ========================

--- Determine if it's time to launch a coordinated strike.
--- @return boolean
local function isStrikeDue()
    local state      = getState()
    local nextStrike = getKeyNum(K.NEXT_STRIKE)
    local current    = now()

    -- No strikes in withdrawn state
    if state == 'withdrawn' then return false end
    -- Desperate: attack immediately if not on cooldown
    if state == 'desperate' and current >= nextStrike then return true end
    -- Aggressive: follow scheduled timing
    if state == 'aggressive' and current >= nextStrike then return true end
    return false
end

--- Schedule the next strike at a random interval.
local function scheduleNextStrike()
    local interval = MIN_STRIKE_INTERVAL +
        math.random() * (MAX_STRIKE_INTERVAL - MIN_STRIKE_INTERVAL)
    local nextTime = now() + interval
    setKeyNum(K.NEXT_STRIKE, nextTime)
    print(string.format('[RedAI] Next strike scheduled in %.0f minutes.', interval / 60))
end

--- Activate the pre-built Red strike package mission.
local function launchStrikePackage()
    local state = getState()

    -- Step 1: ECM escort (if available)
    pcall(ScenEdit_SetMission, RED, 'Red Strike Alpha', {isactive=true})

    -- Step 2: Strike aircraft (2 minutes after ECM)
    -- Schedule via a timed event
    local strikeTime = now() + 120
    local ok, ev = pcall(ScenEdit_SetEvent, 'RedStrikeDelay_' .. now(), {
        mode='add', IsActive=true, IsRepeatable=false,
    })
    if ok then
        pcall(ScenEdit_SetTrigger, {mode='add', type='Time',
            name='StrikeDelay_T', time=strikeTime})
        pcall(ScenEdit_SetEventTrigger, ev.guid, {mode='add', name='StrikeDelay_T'})
        pcall(ScenEdit_SetAction, {mode='add', type='LuaScript',
            name='StrikeDelay_A',
            ScriptText='pcall(ScenEdit_SetMission,"Red","Red Strike Package",{isactive=true})\r\n'})
        pcall(ScenEdit_SetEventAction, ev.guid, {mode='add', name='StrikeDelay_A'})
    end

    setKeyNum(K.LAST_STRIKE, now())
    scheduleNextStrike()

    print(string.format('[RedAI] Strike package launched. State=%s', state))
end

-- ===== RESERVE FORCE COMMITMENT ==============================

--- Commit reserve forces when losses reach the desperate threshold.
local function commitReserves()
    if ScenEdit_GetKeyValue(K.RESERVES_COMMITTED) == '1' then return end

    -- Activate reserve submarine from KeyStore
    local subGuid = ScenEdit_GetKeyValue(K.RESERVE_SUB_GUID)
    if subGuid ~= '' then
        local sub = safeGet(subGuid)
        if sub then
            -- Set sub to attack doctrine and activate
            pcall(ScenEdit_SetDoctrine, {guid=subGuid}, {
                weapon_control_status_subsurface = 0,
                weapon_control_status_surface    = 0,
            })
            pcall(ScenEdit_SetEMCON, 'Unit', subGuid, 'Sonar=Active;Radar=Passive')
            pcall(ScenEdit_AssignUnitToMission, subGuid, 'Red Sub Attack')
            print('[RedAI] Reserve submarine committed.')
        end
    end

    -- Activate reserve aircraft
    local acGuid = ScenEdit_GetKeyValue(K.RESERVE_AC_GUID)
    if acGuid ~= '' then
        pcall(ScenEdit_AssignUnitToMission, acGuid, 'Red Strike Package')
        print('[RedAI] Reserve aircraft committed.')
    end

    ScenEdit_SetKeyValue(K.RESERVES_COMMITTED, '1')
    pcall(ScenEdit_SpecialMessage, RED, 'RESERVE FORCES COMMITTED — all units engaged.')
end

-- ===== LOSS TRACKING =========================================

--- Count Red combat losses from side wrapper.
--- Uses a simple heuristic: compare unit count to initial count.
local function trackLosses()
    local currentAlive = countRedUnits()
    local initialCount = getKeyNum('RED_INITIAL_COUNT')
    if initialCount == 0 then
        -- First tick: set baseline
        setKeyNum('RED_INITIAL_COUNT', currentAlive)
        return
    end
    local losses = math.max(0, initialCount - currentAlive)
    setKeyNum(K.LOSSES, losses)
end

-- ===== MAIN AI TICK ==========================================

--- Main Red AI tick — called every 120 seconds.
--- This function body can be used directly as a ScriptText
--- in a RepeatTime event action.
function redAITick()
    local ok, err = pcall(function()
        trackLosses()
        updateState()
        applyDoctrine()
        manageEMCON()

        local state  = getState()
        local losses = getKeyNum(K.LOSSES)

        -- Reserve commitment
        if losses >= LOSS_DESPERATE then
            commitReserves()
        end

        -- Strike management
        if isStrikeDue() then
            launchStrikePackage()
        end

        -- Withdraw check
        if state == 'withdrawn' then
            local ok2, side = pcall(VP_GetSide, {Side=RED})
            if ok2 and side then
                for _, u in ipairs(side.units or {}) do
                    -- Remove from missions and set slow retreat speed
                    if u.mission then
                        pcall(ScenEdit_SetUnit, {guid=u.guid, speed=5})
                    end
                end
            end
        end

        -- Debug log
        print(string.format('[RedAI] State=%s Losses=%d Contacts=%d IADS=%s',
            state, losses, countBlueThreatContacts(),
            ScenEdit_GetKeyValue(K.IADS_HOT) == '1' and 'HOT' or 'COLD'))
    end)

    if not ok then
        print('[RedAI] Tick error: ' .. tostring(err))
        ScenEdit_SetKeyValue(K.ERROR, tostring(err))
    end
end

-- ===== EVENT REGISTRATION ====================================

local function setupRedAI()
    -- Initialize state
    ScenEdit_SetKeyValue(K.STATE,    'aggressive')
    ScenEdit_SetKeyValue(K.LOSSES,   '0')
    ScenEdit_SetKeyValue(K.IADS_HOT, '0')
    ScenEdit_SetKeyValue(K.RESERVES_COMMITTED, '0')

    -- Schedule first strike in 2-5 hours
    local firstStrike = now() + MIN_STRIKE_INTERVAL +
        math.random() * (MAX_STRIKE_INTERVAL - MIN_STRIKE_INTERVAL)
    setKeyNum(K.NEXT_STRIKE, firstStrike)

    -- Create the AI tick event
    local ok, ev = pcall(ScenEdit_SetEvent, 'RedAI_Tick', {
        mode='add', IsActive=true, IsRepeatable=true,
    })
    if not ok then
        print('[RedAI] Failed to create tick event: ' .. tostring(ev))
        return
    end

    pcall(ScenEdit_SetTrigger, {mode='add', type='RegularTime',
        name='RedAI_Timer', interval=120})
    pcall(ScenEdit_SetEventTrigger, ev.guid, {mode='add', name='RedAI_Timer'})

    -- Build the inline tick script for the event sandbox
    -- The full logic is encoded inline to avoid dofile() sandbox limitations
    local tickScript =
        'local state = ScenEdit_GetKeyValue("RED_AI_STATE")\r\n'..
        'local losses = tonumber(ScenEdit_GetKeyValue("RED_AI_LOSSES")) or 0\r\n'..
        '\r\n'..
        '-- Count Red units for loss tracking\r\n'..
        'local ok1, redSide = pcall(VP_GetSide, {Side="Red"})\r\n'..
        'local alive = ok1 and redSide and #(redSide.units or {}) or 0\r\n'..
        'local initial = tonumber(ScenEdit_GetKeyValue("RED_INITIAL_COUNT")) or 0\r\n'..
        'if initial == 0 then\r\n'..
        '    ScenEdit_SetKeyValue("RED_INITIAL_COUNT", tostring(alive))\r\n'..
        'else\r\n'..
        '    losses = math.max(0, initial - alive)\r\n'..
        '    ScenEdit_SetKeyValue("RED_AI_LOSSES", tostring(losses))\r\n'..
        'end\r\n'..
        '\r\n'..
        '-- Update state\r\n'..
        'if losses >= 10 then state = "withdrawn"\r\n'..
        'elseif losses >= 6 then state = "desperate"\r\n'..
        'elseif losses >= 3 then state = "defensive"\r\n'..
        'else state = "aggressive" end\r\n'..
        'ScenEdit_SetKeyValue("RED_AI_STATE", state)\r\n'..
        '\r\n'..
        '-- Apply doctrine\r\n'..
        'local wcs = (state=="aggressive" or state=="desperate") and 0 or\r\n'..
        '            (state=="defensive") and 1 or 2\r\n'..
        'pcall(ScenEdit_SetDoctrine, {side="Red"},\r\n'..
        '    {weapon_control_status_air=wcs, weapon_control_status_surface=wcs})\r\n'..
        '\r\n'..
        '-- IADS management\r\n'..
        'local ok2, rs = pcall(VP_GetSide,{Side="Red"})\r\n'..
        'local contacts = ok2 and rs and #(rs.contacts or {}) or 0\r\n'..
        'local samKeys = {"RED_SAM1_GUID","RED_SAM2_GUID","RED_SAM3_GUID","RED_EWR_GUID"}\r\n'..
        'for _, k in ipairs(samKeys) do\r\n'..
        '    local g = ScenEdit_GetKeyValue(k)\r\n'..
        '    if g ~= "" then\r\n'..
        '        local emcon = (contacts > 0 and state ~= "withdrawn")\r\n'..
        '            and "Radar=Active;OECM=Active" or "Radar=Passive;OECM=Passive"\r\n'..
        '        pcall(ScenEdit_SetEMCON,"Unit",g,emcon)\r\n'..
        '    end\r\n'..
        'end\r\n'..
        '\r\n'..
        '-- Commit reserves when desperate\r\n'..
        'if losses >= 6 and ScenEdit_GetKeyValue("RED_AI_RESERVES_COMMITTED") ~= "1" then\r\n'..
        '    ScenEdit_SetKeyValue("RED_AI_RESERVES_COMMITTED","1")\r\n'..
        '    local rg = ScenEdit_GetKeyValue("RED_RESERVE_SUB_GUID")\r\n'..
        '    if rg ~= "" then pcall(ScenEdit_AssignUnitToMission, rg, "Red Sub Attack") end\r\n'..
        '    pcall(ScenEdit_SpecialMessage,"Red","RESERVE FORCES COMMITTED")\r\n'..
        'end\r\n'..
        '\r\n'..
        '-- Strike timing\r\n'..
        'local nextStrike = tonumber(ScenEdit_GetKeyValue("RED_AI_NEXT_STRIKE")) or 0\r\n'..
        'local t = ScenEdit_CurrentTime()\r\n'..
        'if t >= nextStrike and state ~= "withdrawn" then\r\n'..
        '    pcall(ScenEdit_SetMission,"Red","Red Strike Alpha",{isactive=true})\r\n'..
        '    local interval = 7200 + math.random()*10800\r\n'..
        '    ScenEdit_SetKeyValue("RED_AI_NEXT_STRIKE", tostring(t + interval))\r\n'..
        '    ScenEdit_SetKeyValue("RED_AI_LAST_STRIKE", tostring(t))\r\n'..
        '    print("[RedAI] Strike launched.")\r\n'..
        'end\r\n'..
        '\r\n'..
        'print(string.format("[RedAI] state=%s losses=%d contacts=%d", state, losses, contacts))\r\n'

    pcall(ScenEdit_SetAction, {
        mode='add', type='LuaScript', name='RedAI_Action', ScriptText=tickScript,
    })
    pcall(ScenEdit_SetEventAction, ev.guid, {mode='add', name='RedAI_Action'})

    print('[RedAI] Red Force AI initialized.')
    print(string.format('[RedAI] First strike in ~%.0f hours.',
        (firstStrike - now()) / 3600))
end

setupRedAI()
