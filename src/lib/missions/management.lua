--- CMO Lua Mission Management Library
--- Unit assignment, activation, transfer, status checks, safe deletion.
---
--- @module missions.management
---
--- USAGE EXAMPLE:
---   local MM = dofile('path/to/lib/missions/management.lua')
---
---   -- Assign multiple units to a mission by GUID
---   MM.assignUnits('mission-guid', {'unit1-guid','unit2-guid','unit3-guid'})
---
---   -- Get all units currently on a mission
---   local units = MM.getAssignedUnits('mission-guid', 'USA')
---
---   -- Deactivate a mission temporarily
---   MM.setActive('mission-guid', false)
---
---   -- Safely delete a mission (unassigns units first)
---   MM.deleteMission('USA', 'mission-guid')

local MM = {}

-- ============================================================
-- ASSIGNMENT
-- ============================================================

--- Assign a single unit to a mission.
--- Prefers GUID over name. Returns false silently if already assigned.
---
--- @param unitGuid    string  GUID of the unit
--- @param missionGuid string  GUID of the mission
--- @param asEscort    boolean (default false) Assign as escort sub-mission
--- @return boolean
function MM.assignUnit(unitGuid, missionGuid, asEscort)
    if not unitGuid or not missionGuid then
        print('[MissionMgr] assignUnit: unitGuid and missionGuid required')
        return false
    end
    local ok, err = pcall(ScenEdit_AssignUnitToMission, unitGuid, missionGuid, asEscort or false)
    if not ok then
        print('[MissionMgr] assignUnit error: ' .. tostring(err))
        return false
    end
    return true
end

--- Assign multiple units to a mission.
---
--- @param missionGuid string
--- @param unitGuids   table   Array of unit GUIDs
--- @param asEscort    boolean
--- @return number  Count of successful assignments
function MM.assignUnits(missionGuid, unitGuids, asEscort)
    local count = 0
    for _, guid in ipairs(unitGuids or {}) do
        if MM.assignUnit(guid, missionGuid, asEscort) then
            count = count + 1
        end
    end
    return count
end

--- Unassign a unit from its current mission (without deleting the unit).
---
--- @param unitGuid string
--- @return boolean
function MM.unassignUnit(unitGuid)
    local unit = ScenEdit_GetUnit({ guid = unitGuid })
    if not unit then return false end
    if not unit.mission then return true end   -- already unassigned

    -- Assigning to empty string removes from mission
    local ok, err = pcall(ScenEdit_AssignUnitToMission, unitGuid, '')
    if not ok then
        print('[MissionMgr] unassignUnit error: ' .. tostring(err))
        return false
    end
    return true
end

--- Unassign all units from a mission.
---
--- @param missionGuid string
--- @param sideName    string
--- @return number  Count of units unassigned
function MM.unassignAllUnits(missionGuid, sideName)
    local units = MM.getAssignedUnits(missionGuid, sideName)
    local count = 0
    for _, unit in ipairs(units) do
        if MM.unassignUnit(unit.guid) then count = count + 1 end
    end
    return count
end

-- ============================================================
-- MISSION QUERY
-- ============================================================

--- Get the Mission wrapper for a mission by name or GUID.
---
--- @param sideName    string
--- @param missionRef  string  Mission name or GUID
--- @return Mission|nil
function MM.getMission(sideName, missionRef)
    local ok, mission = pcall(ScenEdit_GetMission, sideName, missionRef)
    if ok and mission then return mission end
    return nil
end

--- Get all units currently assigned to a mission.
--- Searches the side's unit list for units with matching mission GUID.
---
--- @param missionGuid string  GUID of the mission
--- @param sideName    string  Side that owns the mission
--- @return table  Array of Unit wrappers assigned to this mission
function MM.getAssignedUnits(missionGuid, sideName)
    local side = VP_GetSide({ Side = sideName })
    if not side then return {} end

    local assigned = {}
    for _, unit in ipairs(side.units or {}) do
        if unit.mission == missionGuid then
            assigned[#assigned + 1] = unit
        end
    end
    return assigned
end

--- Count the number of active (non-destroyed) units on a mission.
---
--- @param missionGuid string
--- @param sideName    string
--- @return number
function MM.countActiveUnits(missionGuid, sideName)
    local units   = MM.getAssignedUnits(missionGuid, sideName)
    local active  = 0
    for _, unit in ipairs(units) do
        if not unit.IsDestroyed then active = active + 1 end
    end
    return active
end

-- ============================================================
-- ACTIVATION / DEACTIVATION
-- ============================================================

--- Activate or deactivate a mission.
---
--- @param missionRef string   Mission name or GUID
--- @param sideName   string
--- @param active     boolean
--- @return boolean
function MM.setActive(missionRef, sideName, active)
    local ok, err = pcall(ScenEdit_SetMission, sideName, missionRef, {
        isActive = (active ~= false),
    })
    if not ok then
        print('[MissionMgr] setActive error: ' .. tostring(err))
        return false
    end
    return true
end

--- Activate a mission.
--- @param missionRef string
--- @param sideName   string
--- @return boolean
function MM.activate(missionRef, sideName)
    return MM.setActive(missionRef, sideName, true)
end

--- Deactivate a mission (units remain assigned but mission is suspended).
--- @param missionRef string
--- @param sideName   string
--- @return boolean
function MM.deactivate(missionRef, sideName)
    return MM.setActive(missionRef, sideName, false)
end

-- ============================================================
-- TRANSFER UNITS BETWEEN MISSIONS
-- ============================================================

--- Transfer units from one mission to another.
--- Units are unassigned from the source and assigned to the destination.
---
--- @param fromMissionGuid string  Source mission GUID
--- @param toMissionGuid   string  Destination mission GUID
--- @param sideName        string
--- @param unitGuids       table|nil  Specific GUIDs to transfer; nil = all
--- @return number  Count of units transferred
---
--- EXAMPLE:
---   MM.transferUnits('cap-mission-guid', 'strike-mission-guid', 'USA')
function MM.transferUnits(fromMissionGuid, toMissionGuid, sideName, unitGuids)
    local toTransfer
    if unitGuids then
        toTransfer = {}
        for _, guid in ipairs(unitGuids) do
            toTransfer[#toTransfer + 1] = ScenEdit_GetUnit({ guid = guid })
        end
    else
        toTransfer = MM.getAssignedUnits(fromMissionGuid, sideName)
    end

    local count = 0
    for _, unit in ipairs(toTransfer) do
        if unit and not unit.IsDestroyed then
            MM.unassignUnit(unit.guid)
            if MM.assignUnit(unit.guid, toMissionGuid) then
                count = count + 1
            end
        end
    end
    return count
end

-- ============================================================
-- STATUS / PROGRESS
-- ============================================================

--- Check whether a mission has achieved its primary objectives.
--- For strike missions: returns true when all targets are destroyed.
--- For patrol missions: always returns false (ongoing).
---
--- @param missionRef string  Mission name or GUID
--- @param sideName   string
--- @return boolean
function MM.isComplete(missionRef, sideName)
    local mission = MM.getMission(sideName, missionRef)
    if not mission then return false end

    -- Strike: check if all targets are destroyed
    if mission.typeS == 'strike' and mission.targetlist then
        for _, target in ipairs(mission.targetlist) do
            local unit = ScenEdit_GetUnit({ guid = target.guid })
            if unit and not unit.IsDestroyed then
                return false   -- at least one target survives
            end
        end
        return true
    end

    return false
end

--- Get a summary status string for a mission.
---
--- @param missionRef string
--- @param sideName   string
--- @return string  Human-readable status
function MM.getStatus(missionRef, sideName)
    local mission = MM.getMission(sideName, missionRef)
    if not mission then return 'NOT FOUND' end

    local active = MM.countActiveUnits(mission.guid, sideName)
    local status = mission.isActive and 'ACTIVE' or 'INACTIVE'

    return string.format('%s | %s | %d units on station | type=%s',
        mission.name, status, active, mission.typeS or '?')
end

-- ============================================================
-- SAFE DELETE
-- ============================================================

--- Safely delete a mission.
--- Unassigns all units first to avoid orphaned assignments,
--- then deletes the mission.
---
--- @param sideName    string
--- @param missionRef  string  Mission name or GUID
--- @return boolean
---
--- EXAMPLE:
---   MM.deleteMission('USA', 'CAP Alpha')
function MM.deleteMission(sideName, missionRef)
    local mission = MM.getMission(sideName, missionRef)
    if not mission then
        print('[MissionMgr] deleteMission: mission not found: ' .. tostring(missionRef))
        return false
    end

    -- Unassign all units first
    MM.unassignAllUnits(mission.guid, sideName)

    -- Delete the mission
    local ok, err = pcall(ScenEdit_DeleteMission, sideName, mission.guid)
    if not ok then
        print('[MissionMgr] deleteMission error: ' .. tostring(err))
        return false
    end
    return true
end

return MM
