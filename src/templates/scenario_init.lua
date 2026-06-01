--- ============================================================
--- LuaInit.lua — Scenario Initialization Template
--- Command: Modern Operations Scenario Boilerplate
---
--- PURPOSE:
---   This file is loaded by CMO every time the scenario is
---   opened (including after load from save). Use it to:
---     1. Re-register event hooks (they don't persist across saves)
---     2. Restore global state from KeyStore
---     3. Load library modules
---     4. Set up self-healing for critical events
---
--- COPY THIS FILE to your scenario's Lua folder as LuaInit.lua
--- and customise the sections marked [CUSTOMISE].
---
--- DEPENDENCIES (optional helper modules you supply in your
--- scenario's own Lua folder — none are shipped in this repo):
---   - utils.lua    (logging/util helpers; optional)
---   - keystore.lua (KeyStore wrapper; optional)
--- Each is loaded defensively via pcall(dofile, ...) below, so
--- the template runs even when they are absent.
--- ============================================================

-- ===== VERSION TRACKING =====================================
local SCENARIO_NAME    = 'MyScenario'       -- [CUSTOMISE]
local SCRIPT_VERSION   = '1.0.0'
local SCRIPT_DATE      = '2026-01-01'       -- [CUSTOMISE]
local AUTHOR           = 'Scenario Author'  -- [CUSTOMISE]
-- ============================================================

-- ===== MODULE LOADING ========================================
-- Adjust paths to match your scenario's folder layout.
-- Use the CMO environment's dofile() to load library files.
-- LuaInit runs before GameSetup, so libraries must be available.

local Utils, KS, EB

local function loadLibraries()
    -- Optional: load core utilities
    -- Adjust the path to match your deployment layout
    local libPath = 'Lua/Development/' .. SCENARIO_NAME .. '/lib/'

    local ok1, utils = pcall(dofile, libPath .. 'utils.lua')
    if ok1 then
        Utils = utils
    else
        -- Fallback: define minimal logging if utils unavailable
        Utils = {
            log    = function(_, msg) print('[INIT] ' .. tostring(msg)) end,
            LOG_INFO  = 1,
            LOG_WARN  = 2,
            LOG_ERROR = 3,
        }
    end

    local ok2, ks = pcall(dofile, libPath .. 'keystore.lua')
    if ok2 then KS = ks end

    local ok3, eb = pcall(dofile, libPath .. 'events/builder.lua')
    if ok3 then EB = eb end
end

loadLibraries()

-- ===== INIT FLAG =============================================
-- Prevent double-initialization if the scenario is re-opened
-- without a full restart (edge case but good practice).
local _initialized = false

-- ===== LOGGING SETUP =========================================
local function initLogging()
    if not Utils then return end
    -- [CUSTOMISE] set log level: LOG_DEBUG=0, LOG_INFO=1, LOG_WARN=2, LOG_ERROR=3
    Utils.setLogLevel(Utils.LOG_INFO)
    -- [CUSTOMISE] set which side receives in-game log messages (nil = none)
    -- Utils.setLogSide('Blue')
end

-- ===== GLOBAL FUNCTIONS ======================================
-- Functions defined here are available to all event scripts
-- because they run in the same Lua state as LuaInit.
-- NOTE: Event script *action text* runs in a separate sandbox —
-- those cannot access these globals. Use KeyStore for cross-event
-- communication instead.

--- Send a timestamped message to a side.
--- @param side    string  Side name or GUID
--- @param message string  Message text
function Msg(side, message)
    pcall(ScenEdit_SpecialMessage, side,
        string.format('[%s] %s', os.date('!%H:%MZ'), message))
end

--- Award or deduct points with an automatic message.
--- @param side   string
--- @param points number  Positive=award, negative=deduct
--- @param reason string
function AwardScore(side, points, reason)
    local ok, current = pcall(ScenEdit_GetScore, side)
    local newScore = (ok and type(current) == 'number' and current or 0) + points
    pcall(ScenEdit_SetScore, side, newScore, reason)
    local verb = points >= 0 and '+' or ''
    print(string.format('[Score] %s %s%d (%s) total=%d', side, verb, points, reason, newScore))
end

--- Safely get a unit by its KeyStore GUID key.
--- @param key string  KeyStore key holding the unit GUID
--- @return Unit|nil
function GetUnitByKey(key)
    local guid = ScenEdit_GetKeyValue(key)
    if not guid or guid == '' then return nil end
    local ok, u = pcall(ScenEdit_GetUnit, {guid=guid})
    return (ok and u) or nil
end

--- Get current scenario time safely.
--- @return number  Unix timestamp, or os.time() as fallback
function Now()
    local ok, t = pcall(ScenEdit_CurrentTime)
    return (ok and t) or os.time()
end

--- Check if a flag is set in KeyStore (value == '1').
--- @param key string
--- @return boolean
function FlagSet(key)
    return ScenEdit_GetKeyValue(key) == '1'
end

--- Set a KeyStore flag to '1'.
--- @param key string
function SetFlag(key)
    ScenEdit_SetKeyValue(key, '1')
end

--- Clear a KeyStore flag (set to '0').
--- @param key string
function ClearFlag(key)
    ScenEdit_SetKeyValue(key, '0')
end

-- ===== SELF-HEALING EVENT ACTIVATION =========================
-- Re-registers events that should be active on every load.
-- CMO event active/inactive state persists in saves, but
-- any events created by scripts at runtime need to be
-- re-verified here.

--- Ensure a named event is active.
--- Safe to call even if the event doesn't exist yet.
--- @param eventName string
local function ensureEventActive(eventName)
    local ok, ev = pcall(ScenEdit_SetEvent, eventName, {
        mode     = 'update',
        IsActive = true,
    })
    if ok and ev then
        print(string.format('[Init] Event "%s" confirmed active', eventName))
    end
end

local function restoreEventHooks()
    -- [CUSTOMISE] Add the names of all events that must be active on load
    local criticalEvents = {
        -- 'OnScenLoad',
        -- 'WeatherCycle',
        -- 'IADSUpdate',
        -- 'CSAR_Handler',
        -- 'Phase2Check',
    }

    for _, name in ipairs(criticalEvents) do
        ensureEventActive(name)
    end
end

-- ===== STATE RESTORATION =====================================
-- Re-read scenario phase and other state from KeyStore.
-- Because event scripts use KeyStore for persistence,
-- state survives saves/loads automatically — just re-read
-- whatever your scenario logic needs at startup.

local PHASE_KEY    = 'SCENARIO_PHASE'   -- [CUSTOMISE] or remove
local INIT_KEY     = 'INIT_DONE'

local function restoreState()
    local phase = ScenEdit_GetKeyValue(PHASE_KEY)
    if phase == '' then phase = '1' end
    print(string.format('[Init] Scenario phase: %s', phase))

    -- [CUSTOMISE] restore other state variables here
    -- local waveCount = tonumber(ScenEdit_GetKeyValue('WAVE_COUNT')) or 0
    -- local warStarted = ScenEdit_GetKeyValue('WAR_STARTED') == '1'
end

-- ===== SCENARIO-LOADED EVENT =================================
-- Register a ScenLoaded trigger so we can run init code
-- the first time the scenario opens (not on every load).

local function registerScenLoadedEvent()
    -- Check if first-run event already exists
    if FlagSet(INIT_KEY) then return end

    local ok, ev = pcall(ScenEdit_SetEvent, 'ScenFirstLoad', {
        mode         = 'add',
        IsActive     = true,
        IsRepeatable = false,
    })
    if not ok then return end

    pcall(ScenEdit_SetTrigger, {mode='add', type='ScenLoaded', name='ScenLoaded_Trigger'})
    pcall(ScenEdit_SetEventTrigger, ev.guid, {mode='add', name='ScenLoaded_Trigger'})

    -- [CUSTOMISE] Replace this script with your first-load logic
    local firstLoadScript =
        'ScenEdit_SetKeyValue("INIT_DONE", "1")\r\n'..
        'print("[ScenLoad] First load complete.")\r\n'..
        '-- ScenEdit_SpecialMessage("Blue", "Welcome to ' .. SCENARIO_NAME .. '")\r\n'

    pcall(ScenEdit_SetAction, {
        mode='add', type='LuaScript', name='ScenFirstLoad_Action',
        ScriptText=firstLoadScript,
    })
    pcall(ScenEdit_SetEventAction, ev.guid, {mode='add', name='ScenFirstLoad_Action'})
end

-- ===== SPECIAL ACTIONS REGISTRATION ==========================
-- Register player-accessible special actions here.
-- These are available in-game via the Special Actions menu.

local function registerSpecialActions()
    -- [CUSTOMISE] Uncomment and add your special actions

    -- ScenEdit_SetSpecialAction({
    --     mode       = 'add',
    --     name       = 'Request Resupply',
    --     IsActive   = true,
    --     ScriptText = 'dofile("path/to/special_action.lua")',
    -- })
end

-- ===== MAIN INITIALIZATION ===================================
local function initialize()
    if _initialized then
        print('[Init] Already initialized — skipping.')
        return
    end

    local ok, err = pcall(function()
        print(string.rep('=', 50))
        print(string.format('[Init] %s v%s (%s) by %s',
            SCENARIO_NAME, SCRIPT_VERSION, SCRIPT_DATE, AUTHOR))
        print(string.format('[Init] CMO Lua Init loading at %s',
            os.date('!%Y-%m-%d %H:%MZ')))
        print(string.rep('=', 50))

        initLogging()
        restoreState()
        restoreEventHooks()
        registerScenLoadedEvent()
        registerSpecialActions()

        _initialized = true
        print('[Init] Initialization complete.')
    end)

    if not ok then
        print('[Init] CRITICAL ERROR during initialization: ' .. tostring(err))
        ScenEdit_SetKeyValue('INIT_ERROR', tostring(err))
        -- Still mark as attempted to prevent infinite retry
        _initialized = true
    end
end

initialize()
