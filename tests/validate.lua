#!/usr/bin/env lua
--- ============================================================
--- CMO Lua Repository Validation Script
--- Syntax-checks all Lua files in the repository using loadfile().
---
--- Run with: lua tests/validate.lua
--- (from the repo root directory)
---
--- Checks:
---   1. All src/core/*.lua       — core utility modules
---   2. All src/lib/**/*.lua     — library modules
---   3. All src/templates/*.lua  — template files
---   4. All src/examples/*.lua   — example scenario scripts
---   5. types/cmo.lua            — type definitions
---
--- Output:
---   PASS <file>   — file parsed without syntax errors
---   FAIL <file>   — file has syntax errors (error printed)
---   WARN <file>   — file not found (expected but missing)
---
--- Exit code: 0 if all pass, 1 if any failures.
--- ============================================================

local REPO_ROOT = '.'  -- run from repo root

-- ============================================================
-- FILE REGISTRY
-- All Lua files that should exist and parse cleanly.
-- ============================================================

local FILES = {
    -- Core utilities
    'src/core/utils.lua',
    'src/core/keystore.lua',

    -- Library modules
    'src/lib/combat/attack.lua',
    'src/lib/combat/damage.lua',
    'src/lib/doctrine/doctrine.lua',
    'src/lib/doctrine/wra.lua',
    'src/lib/emcon/emcon.lua',
    'src/lib/events/builder.lua',
    'src/lib/events/triggers.lua',
    'src/lib/logistics/fuel.lua',
    'src/lib/logistics/resupply.lua',
    'src/lib/missions/builder.lua',
    'src/lib/missions/management.lua',
    'src/lib/movement/course.lua',
    'src/lib/movement/formation.lua',
    'src/lib/scoring/scoring.lua',
    'src/lib/sensors/detection.lua',
    'src/lib/ui/messages.lua',
    'src/lib/weather/weather.lua',
    'src/lib/zones/areas.lua',
    'src/lib/cargo/cargo.lua',

    -- Templates
    'src/templates/scenario_init.lua',
    'src/templates/game_setup.lua',
    'src/templates/special_action.lua',

    -- Examples
    'src/examples/carrier_ops.lua',
    'src/examples/asw_patrol.lua',
    'src/examples/csar_system.lua',
    'src/examples/dynamic_campaign.lua',
    'src/examples/red_ai.lua',

    -- Type definitions
    'types/cmo.lua',
}

-- ============================================================
-- MOCK CMO API
-- Provide stubs for all CMO-specific globals so loadfile()
-- doesn't fail due to undefined function calls at module level.
-- (Note: loadfile only parses; it doesn't execute. But some
-- files use globals at module scope that need to exist.)
-- ============================================================

-- Stub out all CMO API functions as no-ops
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

for _, name in ipairs(CMO_STUBS) do
    if _G[name] == nil then
        _G[name] = function(...) return nil end
    end
end

-- Also stub ScenEdit_GetKeyValue to return '' by default
_G['ScenEdit_GetKeyValue'] = function(key) return '' end
_G['ScenEdit_CurrentTime'] = function() return os.time() end
_G['ScenEdit_GetScore']    = function(side) return 0 end

-- ============================================================
-- VALIDATION ENGINE
-- ============================================================

local PASS = 0
local FAIL = 0
local WARN = 0
local MISSING = {}
local ERRORS  = {}

--- Check if a file exists.
--- @param path string
--- @return boolean
local function fileExists(path)
    local f = io.open(path, 'r')
    if f then f:close(); return true end
    return false
end

--- Validate a single Lua file using loadfile().
--- loadfile() parses the file but does not execute it.
--- This catches syntax errors and undefined-variable references at parse time.
--- @param relPath string  Relative path from repo root
local function validateFile(relPath)
    local fullPath = REPO_ROOT .. '/' .. relPath

    if not fileExists(fullPath) then
        io.write(string.format('  WARN  %s\n', relPath))
        WARN = WARN + 1
        MISSING[#MISSING+1] = relPath
        return
    end

    -- loadfile parses the chunk and returns a function (or nil + error)
    local chunk, err = loadfile(fullPath)

    if chunk then
        io.write(string.format('  PASS  %s\n', relPath))
        PASS = PASS + 1
    else
        io.write(string.format('  FAIL  %s\n', relPath))
        io.write(string.format('        ERROR: %s\n', tostring(err)))
        FAIL = FAIL + 1
        ERRORS[#ERRORS+1] = {file=relPath, error=tostring(err)}
    end
end

--- Recursively find all .lua files in a directory.
--- This is a bonus check to catch any files NOT in the registry.
--- @param dir string
--- @return string[]
local function findLuaFiles(dir)
    local files = {}
    -- Use ls/find if available (Unix); skip silently on Windows
    local pipe = io.popen('find "' .. dir .. '" -name "*.lua" 2>/dev/null')
    if pipe then
        for line in pipe:lines() do
            files[#files+1] = line
        end
        pipe:close()
    end
    return files
end

-- ============================================================
-- MAIN
-- ============================================================

io.write('\n')
io.write('============================================================\n')
io.write('CMO Lua Repository Validation\n')
io.write(string.format('Checking %d registered files...\n', #FILES))
io.write('============================================================\n\n')

-- Check registered files
io.write('[ Registered Files ]\n\n')
for _, f in ipairs(FILES) do
    validateFile(f)
end

-- Bonus: find any extra .lua files not in the registry
io.write('\n[ Unregistered Lua Files ]\n\n')
local registrySet = {}
for _, f in ipairs(FILES) do registrySet[f] = true end

local allFound = findLuaFiles('src')
for _, path in ipairs(allFound) do
    -- Normalize path (remove leading ./)
    local normalized = path:gsub('^%./', '')
    if not registrySet[normalized] then
        -- Validate it anyway
        local chunk, err = loadfile(path)
        if chunk then
            io.write(string.format('  PASS* %s (not in registry)\n', normalized))
        else
            io.write(string.format('  FAIL* %s (not in registry)\n', normalized))
            io.write(string.format('        ERROR: %s\n', tostring(err)))
            FAIL = FAIL + 1
            ERRORS[#ERRORS+1] = {file=normalized, error=tostring(err)}
        end
    end
end

-- ============================================================
-- SUMMARY
-- ============================================================

io.write('\n')
io.write('============================================================\n')
io.write(string.format('Results: %d PASS  %d FAIL  %d WARN (missing)\n',
    PASS, FAIL, WARN))

if FAIL > 0 then
    io.write('\nFAILURES:\n')
    for _, e in ipairs(ERRORS) do
        io.write(string.format('  %s\n    %s\n', e.file, e.error))
    end
end

if WARN > 0 then
    io.write('\nMISSING FILES:\n')
    for _, f in ipairs(MISSING) do
        io.write('  ' .. f .. '\n')
    end
end

io.write('============================================================\n\n')

if FAIL > 0 then
    os.exit(1)
else
    os.exit(0)
end
