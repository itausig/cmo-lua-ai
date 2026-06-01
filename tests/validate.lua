#!/usr/bin/env lua
--- ============================================================
--- CMO Lua Repository Validation Script
--- Syntax-checks all Lua files in the repository using loadfile(),
--- and syntax-checks the Lua scripts that example modules generate
--- for CMO event actions (the `ScriptText` passed to
--- ScenEdit_SetAction), which loadfile() alone cannot catch.
---
--- Run with: lua tests/validate.lua
--- (from the repo root directory)
---
--- Checks:
---   1. Every file in the registry exists and parses with loadfile().
---   2. Any .lua file under src/ NOT in the registry also parses.
---   3. Generated event-action scripts produced by src/examples/*.lua
---      parse with loadstring().
---
--- Output:
---   PASS <file>   — parsed without syntax errors
---   FAIL <file>   — missing (but registered) or has syntax errors
---
--- Exit code: 0 only if every check passes; 1 otherwise.
--- ============================================================

local REPO_ROOT = '.'  -- run from repo root

-- ============================================================
-- FILE REGISTRY
-- All Lua files that should exist and parse cleanly. Keep this
-- in sync with the actual repository layout — a registered file
-- that is missing is a FAILURE, not a warning.
-- ============================================================

local FILES = {
    -- Library modules
    'src/lib/cargo/cargo.lua',
    'src/lib/doctrine/doctrine.lua',
    'src/lib/doctrine/wra.lua',
    'src/lib/emcon/emcon.lua',
    'src/lib/scoring/scoring.lua',
    'src/lib/ui/messages.lua',
    'src/lib/weather/weather.lua',
    'src/lib/zones/areas.lua',

    -- Templates
    'src/templates/scenario_init.lua',
    'src/templates/game_setup.lua',
    'src/templates/special_action.lua',

    -- Examples
    'src/examples/carrier_ops.lua',
    'src/examples/csar_system.lua',
    'src/examples/dynamic_campaign.lua',
    'src/examples/red_ai.lua',

    -- Type definitions
    'types/cmo.lua',
}

-- Files whose top-level execution is safe to run under stubs in order
-- to capture and syntax-check the event-action scripts they generate.
local EMBEDDED_SCRIPT_FILES = {
    'src/examples/carrier_ops.lua',
    'src/examples/csar_system.lua',
    'src/examples/dynamic_campaign.lua',
    'src/examples/red_ai.lua',
}

-- ============================================================
-- MOCK CMO API
-- Provide stubs for all CMO-specific globals so executing a
-- module at load time (to capture generated scripts) does not
-- fail due to undefined function calls.
-- ============================================================

local CMO_STUBS = {
    'ScenEdit_AddUnit', 'ScenEdit_GetUnit', 'ScenEdit_SetUnit', 'ScenEdit_DeleteUnit',
    'ScenEdit_UpdateUnit', 'ScenEdit_SetUnitSide', 'ScenEdit_AssignUnitToMission',
    'ScenEdit_UnitX', 'ScenEdit_UnitY', 'ScenEdit_UnitC',
    'ScenEdit_AddMission', 'ScenEdit_SetMission', 'ScenEdit_DeleteMission',
    'ScenEdit_SetEvent', 'ScenEdit_SetTrigger', 'ScenEdit_SetEventTrigger',
    'ScenEdit_SetCondition', 'ScenEdit_SetEventCondition',
    'ScenEdit_SetAction', 'ScenEdit_SetEventAction',
    'ScenEdit_SetSpecialAction',
    'ScenEdit_SetSidePosture', 'ScenEdit_SetDoctrine', 'ScenEdit_SetEMCON',
    'ScenEdit_AddReferencePoint', 'ScenEdit_DeleteReferencePoint',
    'ScenEdit_SetKeyValue', 'ScenEdit_GetKeyValue',
    'ScenEdit_GetScore', 'ScenEdit_SetScore',
    'ScenEdit_SpecialMessage', 'ScenEdit_EndScenario',
    'ScenEdit_CurrentTime', 'ScenEdit_SetWeather',
    'ScenEdit_GetTimeOfDay', 'ScenEdit_TransferUnit',
    'ScenEdit_GetUnits', 'ScenEdit_GetMission',
    'ScenEdit_AddContact', 'ScenEdit_RemoveContact',
    'ScenEdit_GetScenarioInfo', 'ScenEdit_SetScenarioInfo',
    'ScenEdit_GetSide',
    'VP_GetSide', 'VP_GetUnit', 'VP_GetContact',
    'Tool_Range', 'Tool_Bearing', 'Tool_LOS', 'Tool_EmulateNoConsole',
    'World_GetElevation', 'UI_SetCameraView',
    'ScenEdit_AddTCAtoEvent', 'ScenEdit_AddEvent',
    'ScenEdit_AddTrigger', 'ScenEdit_AddCondition', 'ScenEdit_AddAction',
}

-- Capture of every event-action script that modules generate.
local CAPTURED_SCRIPTS = {}

--- Reset all CMO global stubs to safe defaults and arm script capture.
--- Stubs return a table-with-guid so that `result.guid` chains work,
--- and ScenEdit_SetAction/AddAction record any ScriptText they receive.
local function installStubs()
    local function capture(t)
        if type(t) == 'table' and type(t.ScriptText) == 'string' then
            CAPTURED_SCRIPTS[#CAPTURED_SCRIPTS + 1] = t.ScriptText
        end
        return { guid = 'stub-guid' }
    end

    for _, name in ipairs(CMO_STUBS) do
        _G[name] = function() return { guid = 'stub-guid' } end
    end

    -- Sensible typed defaults so module-level logic can run far enough
    -- to build its generated scripts.
    _G.ScenEdit_GetKeyValue = function() return '' end
    _G.ScenEdit_CurrentTime = function() return 1000 end
    _G.ScenEdit_GetScore    = function() return 0 end
    _G.ScenEdit_SetEvent    = function(name) return { guid = 'ev-' .. tostring(name) } end
    _G.ScenEdit_UnitX       = function()
        return { type = 'Aircraft', name = 'TestUnit', latitude = 10, longitude = 20 }
    end
    _G.ScenEdit_UnitY       = function() return { guid = 'stub-y' } end
    _G.ScenEdit_AddUnit     = function() return { guid = 'unit-guid' } end
    _G.ScenEdit_AddMission  = function() return { guid = 'mission-guid' } end
    _G.VP_GetSide           = function() return { units = {}, contacts = {}, missions = {}, rps = {} } end
    _G.Tool_Range           = function() return 999 end
    _G.ScenEdit_SetAction   = capture
    _G.ScenEdit_AddAction   = capture
end

-- ============================================================
-- VALIDATION ENGINE
-- ============================================================

local PASS = 0
local FAIL = 0
local ERRORS = {}

local function recordPass(label)
    io.write(string.format('  PASS  %s\n', label))
    PASS = PASS + 1
end

local function recordFail(label, err)
    io.write(string.format('  FAIL  %s\n', label))
    if err then io.write(string.format('        ERROR: %s\n', tostring(err))) end
    FAIL = FAIL + 1
    ERRORS[#ERRORS + 1] = { file = label, error = err and tostring(err) or 'missing file' }
end

local function fileExists(path)
    local f = io.open(path, 'r')
    if f then f:close(); return true end
    return false
end

--- Validate a single Lua file using loadfile() (parse only).
local function validateFile(relPath)
    local fullPath = REPO_ROOT .. '/' .. relPath
    if not fileExists(fullPath) then
        recordFail(relPath, 'registered file is missing')
        return
    end
    local chunk, err = loadfile(fullPath)
    if chunk then recordPass(relPath) else recordFail(relPath, err) end
end

--- Recursively find all .lua files under a directory (Unix `find`).
local function findLuaFiles(dir)
    local files = {}
    local pipe = io.popen('find "' .. dir .. '" -name "*.lua" 2>/dev/null')
    if pipe then
        for line in pipe:lines() do files[#files + 1] = line end
        pipe:close()
    end
    return files
end

--- Execute a module under stubs to capture the event-action scripts it
--- generates, then syntax-check each captured script with loadstring().
--- The module is run inside pcall so runtime errors never abort the suite;
--- only the SYNTAX of generated scripts is asserted here.
local function validateEmbeddedScripts(relPath)
    local fullPath = REPO_ROOT .. '/' .. relPath
    if not fileExists(fullPath) then
        recordFail(relPath .. ' [embedded]', 'file missing')
        return
    end

    local chunk, loadErr = loadfile(fullPath)
    if not chunk then
        recordFail(relPath .. ' [embedded]', 'loadfile: ' .. tostring(loadErr))
        return
    end

    local before = #CAPTURED_SCRIPTS
    installStubs()
    -- Silence module prints while executing.
    local realPrint = _G.print
    _G.print = function() end
    pcall(chunk)
    _G.print = realPrint

    local captured = #CAPTURED_SCRIPTS - before
    if captured == 0 then
        -- No generated scripts in this module; nothing to assert.
        return
    end

    local localFail = 0
    for i = before + 1, #CAPTURED_SCRIPTS do
        local script = CAPTURED_SCRIPTS[i]
        local c, e = loadstring(script, relPath .. ':generated#' .. (i - before))
        if not c then
            recordFail(string.format('%s [generated script #%d]', relPath, i - before), e)
            localFail = localFail + 1
        end
    end
    if localFail == 0 then
        recordPass(string.format('%s [%d generated script(s)]', relPath, captured))
    end
end

-- ============================================================
-- MAIN
-- ============================================================

io.write('\n')
io.write('============================================================\n')
io.write('CMO Lua Repository Validation\n')
io.write(string.format('Checking %d registered files...\n', #FILES))
io.write('============================================================\n\n')

-- 1. Registered files must exist and parse.
io.write('[ Registered Files ]\n\n')
for _, f in ipairs(FILES) do
    validateFile(f)
end

-- 2. Any extra .lua file under src/ must also parse.
io.write('\n[ Unregistered Lua Files ]\n\n')
local registrySet = {}
for _, f in ipairs(FILES) do registrySet[f] = true end
local extras = 0
for _, path in ipairs(findLuaFiles('src')) do
    local normalized = path:gsub('^%./', '')
    if not registrySet[normalized] then
        extras = extras + 1
        local chunk, err = loadfile(path)
        if chunk then
            recordPass(normalized .. ' (not in registry)')
        else
            recordFail(normalized .. ' (not in registry)', err)
        end
    end
end
if extras == 0 then io.write('  (none)\n') end

-- 3. Syntax-check generated event-action scripts.
io.write('\n[ Generated Event-Action Scripts ]\n\n')
for _, f in ipairs(EMBEDDED_SCRIPT_FILES) do
    validateEmbeddedScripts(f)
end

-- ============================================================
-- SUMMARY
-- ============================================================

io.write('\n')
io.write('============================================================\n')
io.write(string.format('Results: %d PASS  %d FAIL\n', PASS, FAIL))

if FAIL > 0 then
    io.write('\nFAILURES:\n')
    for _, e in ipairs(ERRORS) do
        io.write(string.format('  %s\n    %s\n', e.file, e.error))
    end
end

io.write('============================================================\n\n')

os.exit(FAIL > 0 and 1 or 0)
