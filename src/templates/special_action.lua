--- ============================================================
--- Special Action Template
--- Command: Modern Operations — Player-Triggered Actions
---
--- PURPOSE:
---   Template for player-triggered special actions registered
---   via ScenEdit_SetSpecialAction. Shows:
---     1. Action validation (prerequisites check)
---     2. Cooldown management via KeyStore
---     3. Player feedback messages
---     4. Multiple action type examples
---
--- USAGE:
---   Register in GameSetup.lua:
---     ScenEdit_SetSpecialAction({
---         mode       = 'add',
---         name       = 'Request Reinforcements',
---         IsActive   = true,
---         ScriptText = '<contents of this file or inline equivalent>',
---     })
---
---   Or store this file and dofile() it from the ScriptText:
---     ScriptText = 'dofile("Lua/Development/MyScenario/special_action.lua")'
--- ============================================================

-- ===== CONFIGURATION =========================================
-- [CUSTOMISE] Set the action type and parameters below.
-- Supported ACTION_TYPE values: 'reinforce', 'resupply', 'intel'

local ACTION_TYPE       = 'reinforce'   -- [CUSTOMISE]
local PLAYER_SIDE       = 'Blue'        -- [CUSTOMISE]
local COOLDOWN_SEC      = 3600          -- seconds between uses (3600 = 1 hour)
local MAX_USES          = 3             -- maximum total uses (0 = unlimited)

-- KeyStore keys (unique per action to avoid collisions)
local COOLDOWN_KEY = 'SA_' .. ACTION_TYPE .. '_LAST_USE'
local USE_COUNT_KEY = 'SA_' .. ACTION_TYPE .. '_COUNT'

-- ===== SHARED UTILITIES ======================================

--- Check if the action is allowed (cooldown + max uses).
--- @return boolean, string  allowed, reason (if denied)
local function checkPrerequisites()
    -- Check max uses
    if MAX_USES > 0 then
        local uses = tonumber(ScenEdit_GetKeyValue(USE_COUNT_KEY)) or 0
        if uses >= MAX_USES then
            return false, string.format(
                'Action unavailable — maximum uses (%d) reached.', MAX_USES)
        end
    end

    -- Check cooldown
    local lastUse = tonumber(ScenEdit_GetKeyValue(COOLDOWN_KEY)) or 0
    local elapsed = ScenEdit_CurrentTime() - lastUse
    if elapsed < COOLDOWN_SEC then
        local remaining = math.ceil((COOLDOWN_SEC - elapsed) / 60)
        return false, string.format(
            'Action on cooldown — %d minute(s) remaining.', remaining)
    end

    return true, 'ok'
end

--- Record that the action was used.
local function recordUse()
    ScenEdit_SetKeyValue(COOLDOWN_KEY, tostring(ScenEdit_CurrentTime()))
    local uses = tonumber(ScenEdit_GetKeyValue(USE_COUNT_KEY)) or 0
    ScenEdit_SetKeyValue(USE_COUNT_KEY, tostring(uses + 1))
end

--- Send feedback to the player.
--- @param msg string
local function feedback(msg)
    pcall(ScenEdit_SpecialMessage, PLAYER_SIDE, msg)
    print(string.format('[SpecialAction:%s] %s', ACTION_TYPE, msg))
end

-- ===== ACTION: REINFORCE =====================================
-- Spawn a reinforcement group at a designated staging area.

local REINFORCE_STAGING_LAT  = 38.0     -- [CUSTOMISE]
local REINFORCE_STAGING_LON  = -71.0    -- [CUSTOMISE]
local REINFORCE_UNITS = {
    -- {name='Reinforce-DDG-1', dbid=2869, type='Ship', heading=270, speed=18},
    -- {name='Reinforce-DDG-2', dbid=2869, type='Ship', heading=270, speed=18},
}

local function actionReinforce()
    local spawnedCount = 0
    local offsetNm = 5  -- spread units apart

    for i, unitDef in ipairs(REINFORCE_UNITS) do
        local lat = REINFORCE_STAGING_LAT + (i - 1) * (offsetNm / 60)
        local ok, unit = pcall(ScenEdit_AddUnit, {
            side        = PLAYER_SIDE,
            type        = unitDef.type or 'Ship',
            name        = unitDef.name,
            dbid        = unitDef.dbid,
            latitude    = lat,
            longitude   = REINFORCE_STAGING_LON,
            heading     = unitDef.heading or 270,
            speed       = unitDef.speed or 15,
            proficiency = unitDef.proficiency or 'Regular',
        })
        if ok and unit then
            ScenEdit_SetKeyValue('REINFORCE_' .. i .. '_GUID', unit.guid)
            spawnedCount = spawnedCount + 1
        end
    end

    feedback(string.format(
        'Reinforcement group arrived: %d unit(s) now available at %.2f, %.2f.',
        spawnedCount, REINFORCE_STAGING_LAT, REINFORCE_STAGING_LON))
end

-- ===== ACTION: RESUPPLY ======================================
-- Reload magazines on all Blue surface ships to full capacity.

local RESUPPLY_SHIPS_ONLY = true    -- if false, also resupply facilities

local function reloadUnit(unit)
    local reloaded = 0
    for _, mag in ipairs(unit.magazines or {}) do
        for _, weapon in ipairs(mag.weapons or {}) do
            if weapon.maxcap and weapon.current < weapon.maxcap then
                local ok = pcall(ScenEdit_SetUnit, {
                    guid      = unit.guid,
                    magazines = {{
                        guid    = mag.guid,
                        weapons = {{wpnid=weapon.id, number=weapon.maxcap}},
                    }},
                })
                if ok then reloaded = reloaded + 1 end
            end
        end
    end
    return reloaded
end

local function actionResupply()
    local ok, side = pcall(VP_GetSide, {Side=PLAYER_SIDE})
    if not ok or not side then
        feedback('Resupply failed — side not found.')
        return
    end

    local totalShips = 0
    local totalMags  = 0

    for _, u in ipairs(side.units or {}) do
        if u.type == 'Ship' or (not RESUPPLY_SHIPS_ONLY and u.type == 'Facility') then
            totalShips = totalShips + 1
            totalMags  = totalMags + reloadUnit(u)
        end
    end

    feedback(string.format(
        'Fleet resupply complete: %d unit(s) serviced, %d weapon bays reloaded.',
        totalShips, totalMags))
end

-- ===== ACTION: REQUEST INTEL =================================
-- Reveal a random enemy unit position (intel surge simulation).

local INTEL_SIDE         = 'Red'       -- side to reveal contacts from
local INTEL_REVEAL_COUNT = 2           -- number of contacts to reveal

local function actionIntel()
    local ok, redSide = pcall(VP_GetSide, {Side=PLAYER_SIDE})
    if not ok or not redSide then
        feedback('Intel request failed — no contacts available.')
        return
    end

    -- Collect unknown or partially classified contacts
    local targets = {}
    for _, contact in ipairs(redSide.contacts or {}) do
        targets[#targets+1] = contact
    end

    if #targets == 0 then
        feedback('Intel request: no new information available.')
        return
    end

    -- Shuffle and take up to INTEL_REVEAL_COUNT
    math.randomseed(os.time())
    for i = #targets, 2, -1 do
        local j = math.random(i)
        targets[i], targets[j] = targets[j], targets[i]
    end

    local revealed = 0
    for i = 1, math.min(INTEL_REVEAL_COUNT, #targets) do
        local c = targets[i]
        if c.latitude and c.longitude then
            pcall(ScenEdit_AddReferencePoint, {
                side        = PLAYER_SIDE,
                name        = string.format('INTEL-%02d', i),
                latitude    = c.latitude,
                longitude   = c.longitude,
                highlighted = true,
            })
            revealed = revealed + 1
        end
    end

    feedback(string.format(
        'Intelligence update: %d contact(s) localized. Check reference points.',
        revealed))
end

-- ===== DISPATCH ==============================================

local ok, err = pcall(function()
    -- Validate prerequisites
    local allowed, reason = checkPrerequisites()
    if not allowed then
        feedback(reason)
        return
    end

    -- Execute the correct action
    if ACTION_TYPE == 'reinforce' then
        actionReinforce()
    elseif ACTION_TYPE == 'resupply' then
        actionResupply()
    elseif ACTION_TYPE == 'intel' then
        actionIntel()
    else
        feedback('Unknown action type: ' .. tostring(ACTION_TYPE))
        return
    end

    -- Record the use only on success
    recordUse()

    -- Remaining uses message
    if MAX_USES > 0 then
        local used = tonumber(ScenEdit_GetKeyValue(USE_COUNT_KEY)) or 0
        local left = MAX_USES - used
        if left == 0 then
            feedback('Note: this action is now exhausted (no uses remaining).')
        else
            feedback(string.format('Note: %d use(s) remaining.', left))
        end
    end
end)

if not ok then
    print('[SpecialAction] ERROR: ' .. tostring(err))
    ScenEdit_SetKeyValue('SA_LAST_ERROR', tostring(err))
    feedback('Action failed due to a script error — check console.')
end
