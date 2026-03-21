--- CMO Lua Mission Builder Library
--- Mission creation helpers for all CMO mission types.
---
--- @module missions.builder
---
--- All missions are created via ScenEdit_AddMission(side, name, type, options).
--- Mission options differ by type — see inline docs and ENUMS.md.
---
--- USAGE EXAMPLE:
---   local MB = dofile('path/to/lib/missions/builder.lua')
---
---   -- Patrol mission (ASW)
---   local m = MB.createASWPatrol('USA', 'Barrier Alpha',
---       {'P1','P2','P3','P4'}, {'p3-guid','lamps-guid'})
---
---   -- CAP mission
---   local cap = MB.createCAP('USA', 'CAP Sierra',
---       {'CAP-N','CAP-E','CAP-S','CAP-W'}, {'f15-1','f15-2'})
---
---   -- Strike mission against specific targets
---   local strike = MB.createStrike('USA', 'Alpha Strike',
---       {'bunker-guid','sam-guid'}, {'f18-1','f18-2'})

local MB = {}

-- ============================================================
-- INTERNAL: SAFE MISSION CREATE
-- ============================================================

--- Internal wrapper for ScenEdit_AddMission.
--- @param side    string
--- @param name    string
--- @param mtype   string  'patrol'|'strike'|'support'|'ferry'|...
--- @param options table
--- @return Mission|nil
local function createMission(side, name, mtype, options)
    local ok, mission = pcall(ScenEdit_AddMission, side, name, mtype, options or {})
    if not ok or not mission then
        print('[MissionBuilder] createMission failed (' .. name .. '): ' .. tostring(mission))
        return nil
    end
    return mission
end

-- ============================================================
-- PATROL MISSIONS
-- ============================================================

--- Create a generic patrol mission with a defined zone.
---
--- @param sideName   string         Side name/GUID
--- @param missionName string
--- @param rpNames    table          Reference point names for the patrol zone
--- @param unitGuids  table|nil      Units to assign immediately
--- @param patrolType string|nil     'air'|'sub'|'naval'|'land' (default 'air')
--- @param options    table|nil      Additional mission options
--- @return Mission|nil
function MB.createPatrol(sideName, missionName, rpNames, unitGuids, patrolType, options)
    options = options or {}
    local missionOptions = {
        type      = patrolType or 'air',
        Zone      = rpNames,
    }
    -- Merge additional options
    for k, v in pairs(options) do missionOptions[k] = v end

    local mission = createMission(sideName, missionName, 'patrol', missionOptions)
    if not mission then return nil end

    -- Assign units if provided
    if unitGuids then
        for _, guid in ipairs(unitGuids) do
            pcall(ScenEdit_AssignUnitToMission, guid, mission.guid)
        end
    end
    return mission
end

--- Create an ASW (Anti-Submarine Warfare) patrol mission.
---
--- @param sideName    string
--- @param missionName string
--- @param rpNames     table     Reference points for patrol zone
--- @param unitGuids   table|nil P-3s, helicopters, or surface ships to assign
--- @param options     table|nil Extra mission options
--- @return Mission|nil
---
--- EXAMPLE:
---   MB.createASWPatrol('USA', 'ASW Barrier', {'B1','B2','B3','B4'}, {'p3-guid'})
function MB.createASWPatrol(sideName, missionName, rpNames, unitGuids, options)
    options = options or {}
    -- ASW-specific defaults
    options.checkArea      = options.checkArea      or rpNames
    options.onethirdrule   = options.onethirdrule   ~= false  -- default true

    return MB.createPatrol(sideName, missionName, rpNames, unitGuids, 'sub', options)
end

--- Create a CAP (Combat Air Patrol) mission.
---
--- @param sideName    string
--- @param missionName string
--- @param rpNames     table
--- @param unitGuids   table|nil  Fighters to assign
--- @param options     table|nil
--- @return Mission|nil
---
--- EXAMPLE:
---   MB.createCAP('USA', 'CAP Alpha', {'C1','C2','C3','C4'}, {'f15-1','f15-2'})
function MB.createCAP(sideName, missionName, rpNames, unitGuids, options)
    options = options or {}
    options.onstation    = options.onstation    or 2
    options.useflightsize = options.useflightsize ~= false

    return MB.createPatrol(sideName, missionName, rpNames, unitGuids, 'air', options)
end

--- Create an anti-surface patrol mission (ASUW).
---
--- @param sideName    string
--- @param missionName string
--- @param rpNames     table
--- @param unitGuids   table|nil
--- @return Mission|nil
function MB.createNavalPatrol(sideName, missionName, rpNames, unitGuids, options)
    return MB.createPatrol(sideName, missionName, rpNames, unitGuids, 'naval', options)
end

-- ============================================================
-- STRIKE MISSIONS
-- ============================================================

--- Create a strike mission against a list of target unit GUIDs.
---
--- @param sideName    string
--- @param missionName string
--- @param targetGuids table    GUIDs of units to strike
--- @param unitGuids   table|nil  Strike aircraft/ships to assign
--- @param strikeType  string|nil 'land'|'sub'|'air' (default 'land')
--- @param options     table|nil
--- @return Mission|nil
---
--- EXAMPLE:
---   MB.createStrike('USA', 'Alpha Strike', {'sam-guid','bunker-guid'}, {'f18-1'})
function MB.createStrike(sideName, missionName, targetGuids, unitGuids, strikeType, options)
    options = options or {}
    local missionOptions = {
        type        = strikeType or 'land',
        OneTimeOnly = options.OneTimeOnly ~= false,
    }
    for k, v in pairs(options) do missionOptions[k] = v end

    local mission = createMission(sideName, missionName, 'strike', missionOptions)
    if not mission then return nil end

    -- Add targets to target list
    for _, tguid in ipairs(targetGuids or {}) do
        pcall(ScenEdit_AssignUnitAsTarget, tguid, mission.guid, sideName)
    end

    -- Assign strikers
    for _, guid in ipairs(unitGuids or {}) do
        pcall(ScenEdit_AssignUnitToMission, guid, mission.guid)
    end

    return mission
end

--- Create a SEAD (Suppression of Enemy Air Defenses) mission.
--- Targets enemy SAM sites and radar units.
---
--- @param sideName    string
--- @param missionName string
--- @param samGuids    table    GUIDs of SAM/radar targets
--- @param unitGuids   table|nil  Wild Weasel / SEAD aircraft
--- @return Mission|nil
function MB.createSEAD(sideName, missionName, samGuids, unitGuids, options)
    options = options or {}
    options.OneTimeOnly = options.OneTimeOnly ~= false
    return MB.createStrike(sideName, missionName, samGuids, unitGuids, 'land', options)
end

-- ============================================================
-- SUPPORT MISSIONS
-- ============================================================

--- Create a support mission (tanker, AEW, jammer, etc.).
---
--- @param sideName      string
--- @param missionName   string
--- @param supportType   string  'tand'|'aew'|'jammer'|'aar'|'lofar'
--- @param rpNames       table|nil  Zone for the support orbit
--- @param unitGuids     table|nil  Support aircraft to assign
--- @param supportedSide string|nil  Side receiving the support
--- @return Mission|nil
---
--- EXAMPLE:
---   MB.createSupport('USA', 'Tanker Track', 'tand',
---       {'TK-N','TK-E','TK-S','TK-W'}, {'kc135-guid'}, 'USA')
function MB.createSupport(sideName, missionName, supportType, rpNames, unitGuids, supportedSide)
    local options = {
        type          = supportType or 'tand',
        SupportedSide = supportedSide or sideName,
    }
    if rpNames then options.Zone = rpNames end

    local mission = createMission(sideName, missionName, 'support', options)
    if not mission then return nil end

    for _, guid in ipairs(unitGuids or {}) do
        pcall(ScenEdit_AssignUnitToMission, guid, mission.guid)
    end
    return mission
end

--- Create an AEW (Airborne Early Warning) mission.
---
--- @param sideName    string
--- @param missionName string
--- @param rpNames     table|nil
--- @param unitGuids   table|nil
--- @return Mission|nil
function MB.createAEW(sideName, missionName, rpNames, unitGuids)
    return MB.createSupport(sideName, missionName, 'aew', rpNames, unitGuids)
end

--- Create a tanker orbit mission.
---
--- @param sideName    string
--- @param missionName string
--- @param rpNames     table
--- @param unitGuids   table|nil  KC-135/KC-46/Il-78 tankers
--- @return Mission|nil
function MB.createTanker(sideName, missionName, rpNames, unitGuids)
    return MB.createSupport(sideName, missionName, 'tand', rpNames, unitGuids)
end

-- ============================================================
-- FERRY MISSION
-- ============================================================

--- Create a ferry mission between two bases or positions.
---
--- @param sideName      string
--- @param missionName   string
--- @param unitGuids     table|nil
--- @param ferryThrottle number|nil  Throttle setting (0=normal, 1=full)
--- @param ferryAlt      number|nil  Altitude in meters
--- @return Mission|nil
---
--- EXAMPLE:
---   MB.createFerry('USA', 'Deploy Alpha', {'f16-1','f16-2'}, 1, 10000)
function MB.createFerry(sideName, missionName, unitGuids, ferryThrottle, ferryAlt)
    local options = {
        FerryThrottle = ferryThrottle or 1,
        FerryAltitude = ferryAlt or 0,
    }
    local mission = createMission(sideName, missionName, 'ferry', options)
    if not mission then return nil end

    for _, guid in ipairs(unitGuids or {}) do
        pcall(ScenEdit_AssignUnitToMission, guid, mission.guid)
    end
    return mission
end

-- ============================================================
-- MISSION OPTIONS HELPERS
-- ============================================================

--- Apply standard patrol mission options to an existing mission.
--- Convenience wrapper for common mission tweaks.
---
--- @param missionGuid string
--- @param opts        table
---   {
---     onstation       = number,  -- Units on-station count
---     onethirdrule    = bool,    -- Use 1/3 fuel rule
---     useflightsize   = bool,    -- Use loadout flight size
---     usegroupsize    = bool,    -- Use group size
---     checkArea       = table,   -- Reference points for check area
---   }
--- @return boolean
function MB.setMissionOptions(missionGuid, opts)
    if not missionGuid or not opts then return false end
    local ok, err = pcall(ScenEdit_SetMission, missionGuid, opts)
    if not ok then
        print('[MissionBuilder] setMissionOptions error: ' .. tostring(err))
        return false
    end
    return true
end

return MB
