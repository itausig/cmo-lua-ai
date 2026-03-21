--- CMO Lua EMCON (Emission Control) Library
--- Readable API for setting emission states on sides, units, and missions.
---
--- @module emcon.emcon
---
--- EMCON controls which sensors and transmitters are active.
--- CMO EMCON strings have the format:
---   "Radar=Active Sonar=Passive OECM=Active ..."
---
--- USAGE EXAMPLE:
---   local EMCON = dofile('path/to/lib/emcon/emcon.lua')
---
---   -- Go dark (all passive)
---   EMCON.goDark('USA', 'side')
---
---   -- Set active radar and passive sonar for a specific unit
---   EMCON.setUnit('unit-guid', {radar='Active', sonar='Passive'})
---
---   -- Build an EMCON string
---   local es = EMCON.buildString({radar='Active', sonar='Passive', oecm='Active'})
---   print(es)  -- "Radar=Active Sonar=Passive OECM=Active"

local EMCON = {}

-- ============================================================
-- EMCON STATE CONSTANTS
-- ============================================================

--- Emission state values.
EMCON.STATE = {
    ACTIVE  = 'Active',
    PASSIVE = 'Passive',
    INHERIT = 'Inherit',  -- Inherit from parent (side/mission)
}

--- EMCON system names recognized by CMO.
EMCON.SYSTEM = {
    RADAR         = 'Radar',
    SONAR         = 'Sonar',
    OECM          = 'OECM',   -- Offensive Electronic Countermeasures
    DECM          = 'DECM',   -- Defensive ECM
    RWR           = 'RWR',    -- Radar Warning Receiver
    IRST          = 'IRST',   -- Infrared Search and Track
    ESM           = 'ESM',    -- Electronic Support Measures
    COMMS         = 'COMMS',  -- Communications
    IFF           = 'IFF',    -- Identification Friend or Foe
}

-- ============================================================
-- EMCON STRING BUILDER
-- ============================================================

--- Build a CMO EMCON string from a settings table.
--- Keys: radar, sonar, oecm, decm, rwr, irst, esm, comms, iff
--- Values: 'Active' | 'Passive' | 'Inherit'
---
--- @param settings table  {radar='Active', sonar='Passive', ...}
--- @return string  EMCON string, e.g. "Radar=Active Sonar=Passive"
---
--- EXAMPLE:
---   local es = EMCON.buildString({radar='Active', sonar='Passive', oecm='Active'})
function EMCON.buildString(settings)
    local parts = {}
    local map = {
        radar = 'Radar',
        sonar = 'Sonar',
        oecm  = 'OECM',
        decm  = 'DECM',
        rwr   = 'RWR',
        irst  = 'IRST',
        esm   = 'ESM',
        comms = 'COMMS',
        iff   = 'IFF',
    }
    -- Preserve a consistent ordering
    local order = {'radar','sonar','oecm','decm','rwr','irst','esm','comms','iff'}
    for _, key in ipairs(order) do
        local val = settings[key]
        if val then
            parts[#parts + 1] = map[key] .. '=' .. tostring(val)
        end
    end
    return table.concat(parts, ' ')
end

--- Parse an EMCON string into a settings table.
---
--- @param emconStr string  e.g. "Radar=Active Sonar=Passive"
--- @return table  {Radar='Active', Sonar='Passive', ...}
function EMCON.parseString(emconStr)
    local t = {}
    if not emconStr then return t end
    for key, val in emconStr:gmatch('(%w+)=(%w+)') do
        t[key] = val
    end
    return t
end

-- ============================================================
-- APPLY EMCON
-- ============================================================

--- Apply EMCON settings to a side, unit, or mission.
---
--- @param target    string  Side name, unit GUID, or mission GUID
--- @param targetType string 'side'|'unit'|'mission'
--- @param emconStr  string  EMCON string (use buildString to create)
--- @return boolean
local function applyEmcon(target, targetType, emconStr)
    local params = { emcon = emconStr }

    if targetType == 'side' then
        params.side = target
    elseif targetType == 'unit' then
        params.guid = target
    elseif targetType == 'mission' then
        params.mission = target
    else
        print('[EMCON] applyEmcon: unknown targetType: ' .. tostring(targetType))
        return false
    end

    local ok, err = pcall(ScenEdit_SetEmcon, targetType, target, emconStr)
    if not ok then
        print('[EMCON] applyEmcon error: ' .. tostring(err))
        return false
    end
    return true
end

--- Set EMCON for a side.
---
--- @param sideName  string
--- @param settings  table   {radar='Active', sonar='Passive', ...}
--- @return boolean
function EMCON.setSide(sideName, settings)
    local es = EMCON.buildString(settings)
    return applyEmcon(sideName, 'side', es)
end

--- Set EMCON for a specific unit.
---
--- @param unitGuid string
--- @param settings table
--- @return boolean
function EMCON.setUnit(unitGuid, settings)
    local es = EMCON.buildString(settings)
    return applyEmcon(unitGuid, 'unit', es)
end

--- Set EMCON for all units in a mission.
---
--- @param missionRef string  Mission GUID or name
--- @param settings   table
--- @return boolean
function EMCON.setMission(missionRef, settings)
    local es = EMCON.buildString(settings)
    return applyEmcon(missionRef, 'mission', es)
end

-- ============================================================
-- PRESET PROFILES
-- ============================================================

--- Set side/unit/mission to EMCON Dark (all passive/off).
--- No radar, passive sonar, no active ECM.
---
--- @param target     string
--- @param targetType string  'side'|'unit'|'mission'
--- @return boolean
function EMCON.goDark(target, targetType)
    local settings = {
        radar = EMCON.STATE.PASSIVE,
        sonar = EMCON.STATE.PASSIVE,
        oecm  = EMCON.STATE.PASSIVE,
        decm  = EMCON.STATE.PASSIVE,
        rwr   = EMCON.STATE.ACTIVE,   -- Keep RWR on for self-protection
        irst  = EMCON.STATE.ACTIVE,   -- Passive IR OK
        esm   = EMCON.STATE.ACTIVE,   -- ESM passive listening OK
        comms = EMCON.STATE.PASSIVE,
        iff   = EMCON.STATE.PASSIVE,
    }
    local es = EMCON.buildString(settings)
    return applyEmcon(target, targetType or 'unit', es)
end

--- Set side/unit/mission to EMCON Active (all sensors active).
---
--- @param target     string
--- @param targetType string
--- @return boolean
function EMCON.goActive(target, targetType)
    local settings = {
        radar = EMCON.STATE.ACTIVE,
        sonar = EMCON.STATE.ACTIVE,
        oecm  = EMCON.STATE.ACTIVE,
        decm  = EMCON.STATE.ACTIVE,
        rwr   = EMCON.STATE.ACTIVE,
        irst  = EMCON.STATE.ACTIVE,
        esm   = EMCON.STATE.ACTIVE,
        comms = EMCON.STATE.ACTIVE,
        iff   = EMCON.STATE.ACTIVE,
    }
    local es = EMCON.buildString(settings)
    return applyEmcon(target, targetType or 'unit', es)
end

--- Set a submarine-optimized EMCON: passive sonar only, radar off.
---
--- @param unitGuid string
--- @return boolean
function EMCON.submarine(unitGuid)
    return EMCON.setUnit(unitGuid, {
        radar = EMCON.STATE.PASSIVE,
        sonar = EMCON.STATE.ACTIVE,     -- Active sonar (set Passive if snorkeling)
        oecm  = EMCON.STATE.PASSIVE,
        esm   = EMCON.STATE.ACTIVE,     -- ESM for radar intercept
        comms = EMCON.STATE.PASSIVE,
        iff   = EMCON.STATE.PASSIVE,
    })
end

--- Set an ASW aircraft EMCON: active sonar + radar for wide-area search.
---
--- @param unitGuid string
--- @return boolean
function EMCON.aswAircraft(unitGuid)
    return EMCON.setUnit(unitGuid, {
        radar = EMCON.STATE.ACTIVE,
        sonar = EMCON.STATE.ACTIVE,
        oecm  = EMCON.STATE.PASSIVE,
        esm   = EMCON.STATE.ACTIVE,
        comms = EMCON.STATE.ACTIVE,
    })
end

--- Toggle EMCON between Active and Passive for a unit based on threat detection.
--- If hostile contacts > 0 nearby, go dark; otherwise go active.
---
--- @param unitGuid     string
--- @param sideName     string   Side of the unit
--- @param threatRadius number   Radius in nm to check for threats (default 50nm)
--- @return boolean  New active state (true = active, false = dark)
function EMCON.threatAdaptive(unitGuid, sideName, threatRadius)
    threatRadius = threatRadius or 50

    local unit = ScenEdit_GetUnit({ guid = unitGuid })
    if not unit then return false end

    local side = VP_GetSide({ Side = sideName })
    if not side then return false end

    local threatCount = 0
    for _, contact in ipairs(side.contacts or {}) do
        if contact.fromside ~= sideName then
            local ok, dist = pcall(Tool_Range,
                { latitude=unit.latitude,    longitude=unit.longitude    },
                { latitude=contact.latitude, longitude=contact.longitude })
            if ok and type(dist) == 'number' and dist <= threatRadius then
                threatCount = threatCount + 1
            end
        end
    end

    if threatCount > 0 then
        EMCON.goDark(unitGuid, 'unit')
        return false   -- went dark
    else
        EMCON.goActive(unitGuid, 'unit')
        return true    -- active
    end
end

return EMCON
