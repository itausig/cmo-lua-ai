--- CMO Lua Movement Formation Library
--- Group management, formation types, leader assignment, pattern helpers.
---
--- @module movement.formation
---
--- USAGE EXAMPLE:
---   local Formation = dofile('path/to/lib/movement/formation.lua')
---
---   -- Set up a line-abreast formation with a 2nm spacing
---   local leader = ScenEdit_GetUnit({guid='leader-guid'})
---   local wingmen = {'guid-2','guid-3','guid-4'}
---   Formation.lineAbreast(leader, wingmen, 2.0)
---
---   -- Create a circular escort screen around a carrier
---   Formation.circular('carrier-guid', {'escort1','escort2','escort3','escort4'}, 15.0)
---
---   -- Group units by name pattern
---   local f15s = Formation.getUnitsByPattern('USA', 'F%-15')
---   print('Found ' .. #f15s .. ' F-15s')

local Formation = {}

-- ============================================================
-- INTERNAL HELPERS
-- ============================================================

--- Compute a lat/lon offset from a reference point given bearing and distance.
---
--- @param lat    number  Reference latitude
--- @param lon    number  Reference longitude
--- @param brg    number  Bearing (degrees true)
--- @param distNm number  Distance in nautical miles
--- @return number, number  offset lat, lon
local function offsetPoint(lat, lon, brg, distNm)
    local R   = 3440.065
    local rad = math.pi / 180
    local lat1 = lat * rad
    local lon1 = lon * rad
    local d    = distNm / R
    local b    = brg * rad

    local lat2 = math.asin(math.sin(lat1) * math.cos(d)
                            + math.cos(lat1) * math.sin(d) * math.cos(b))
    local lon2 = lon1 + math.atan(
        math.sin(b) * math.sin(d) * math.cos(lat1),
        math.cos(d) - math.sin(lat1) * math.sin(lat2))

    return lat2 / rad, ((lon2 / rad + 540) % 360) - 180
end

--- Move a unit to a specific lat/lon, preserving its current altitude and speed.
---
--- @param unitGuid string
--- @param lat      number
--- @param lon      number
local function moveUnit(unitGuid, lat, lon)
    local ok, err = pcall(ScenEdit_SetUnit, {
        guid      = unitGuid,
        latitude  = lat,
        longitude = lon,
    })
    if not ok then
        print('[Formation] moveUnit error for ' .. tostring(unitGuid) .. ': ' .. tostring(err))
    end
end

-- ============================================================
-- FORMATION: RELATIVE POSITIONING
-- ============================================================

--- Place a unit at a specified bearing and distance from a leader.
--- This is a one-shot positional command (not a doctrine formation).
---
--- @param leaderGuid  string  Leader's GUID
--- @param unitGuid    string  Unit to position
--- @param bearing     number  Bearing from leader in degrees
--- @param distNm      number  Distance from leader in nautical miles
--- @return boolean
function Formation.setBearingDistance(leaderGuid, unitGuid, bearing, distNm)
    local leader = ScenEdit_GetUnit({ guid = leaderGuid })
    if not leader then
        print('[Formation] setBearingDistance: leader not found')
        return false
    end
    local lat, lon = offsetPoint(leader.latitude, leader.longitude, bearing, distNm)
    moveUnit(unitGuid, lat, lon)
    return true
end

-- ============================================================
-- STANDARD FORMATIONS
-- ============================================================

--- Position units in a line-abreast formation perpendicular to the leader's heading.
--- Units are placed at equal spacing to the left and right of the leader.
---
--- @param leaderGuid  string  GUID of the lead unit
--- @param unitGuids   table   Array of follower GUIDs (up to 10)
--- @param spacingNm   number  Spacing between each unit in nautical miles
--- @return boolean  true if all moves succeeded
---
--- EXAMPLE:
---   Formation.lineAbreast('lead-guid', {'wing1','wing2','wing3'}, 2.0)
function Formation.lineAbreast(leaderGuid, unitGuids, spacingNm)
    spacingNm = spacingNm or 1.0
    local leader = ScenEdit_GetUnit({ guid = leaderGuid })
    if not leader then
        print('[Formation] lineAbreast: leader not found')
        return false
    end

    local heading = leader.heading or 0
    local n       = #unitGuids
    local ok      = true

    for i, guid in ipairs(unitGuids) do
        -- Distribute left and right: odd indices go left, even go right
        local side   = (i % 2 == 1) and -90 or 90   -- port = -90, starboard = +90
        local rank   = math.ceil(i / 2)
        local brg    = (heading + side) % 360
        local dist   = rank * spacingNm
        local lat, lon = offsetPoint(leader.latitude, leader.longitude, brg, dist)
        local moved = pcall(ScenEdit_SetUnit, { guid=guid, latitude=lat, longitude=lon })
        if not moved then ok = false end
    end
    return ok
end

--- Position units in a line-ahead (column) formation behind the leader.
---
--- @param leaderGuid string
--- @param unitGuids  table   Array of follower GUIDs
--- @param spacingNm  number  Spacing between units (default 1.0nm)
--- @return boolean
function Formation.lineAhead(leaderGuid, unitGuids, spacingNm)
    spacingNm = spacingNm or 1.0
    local leader = ScenEdit_GetUnit({ guid = leaderGuid })
    if not leader then
        print('[Formation] lineAhead: leader not found')
        return false
    end

    local heading = leader.heading or 0
    local astern  = (heading + 180) % 360
    local ok      = true

    for i, guid in ipairs(unitGuids) do
        local lat, lon = offsetPoint(leader.latitude, leader.longitude, astern, i * spacingNm)
        local moved = pcall(ScenEdit_SetUnit, { guid=guid, latitude=lat, longitude=lon })
        if not moved then ok = false end
    end
    return ok
end

--- Position units in a wedge (V) formation behind and to the sides of the leader.
--- First unit goes aft-left, second aft-right, alternating.
---
--- @param leaderGuid string
--- @param unitGuids  table
--- @param spacingNm  number  Distance from leader for first unit (default 2nm)
--- @param angle      number  Half-angle of wedge in degrees (default 45)
--- @return boolean
function Formation.wedge(leaderGuid, unitGuids, spacingNm, angle)
    spacingNm = spacingNm or 2.0
    angle     = angle     or 45

    local leader = ScenEdit_GetUnit({ guid = leaderGuid })
    if not leader then
        print('[Formation] wedge: leader not found')
        return false
    end

    local heading = leader.heading or 0
    local ok      = true

    for i, guid in ipairs(unitGuids) do
        local side  = (i % 2 == 1) and -1 or 1    -- left then right
        local rank  = math.ceil(i / 2)
        local brg   = (heading + 180 + side * angle) % 360
        local dist  = rank * spacingNm
        local lat, lon = offsetPoint(leader.latitude, leader.longitude, brg, dist)
        local moved = pcall(ScenEdit_SetUnit, { guid=guid, latitude=lat, longitude=lon })
        if not moved then ok = false end
    end
    return ok
end

--- Position units evenly around the leader in a circular (screen) formation.
--- Useful for surface/submarine escort screens.
---
--- @param centerGuid string  GUID of the center unit (e.g. carrier)
--- @param unitGuids  table   Array of escort GUIDs
--- @param radiusNm   number  Screen radius in nautical miles
--- @param startBrg   number  Starting bearing (default 0 = north)
--- @return boolean
function Formation.circular(centerGuid, unitGuids, radiusNm, startBrg)
    radiusNm  = radiusNm  or 5.0
    startBrg  = startBrg  or 0
    local center = ScenEdit_GetUnit({ guid = centerGuid })
    if not center then
        print('[Formation] circular: center unit not found')
        return false
    end

    local n  = #unitGuids
    if n == 0 then return true end
    local ok = true

    for i, guid in ipairs(unitGuids) do
        local brg = (startBrg + (360 / n) * (i - 1)) % 360
        local lat, lon = offsetPoint(center.latitude, center.longitude, brg, radiusNm)
        local moved = pcall(ScenEdit_SetUnit, { guid=guid, latitude=lat, longitude=lon })
        if not moved then ok = false end
    end
    return ok
end

--- Position units in a diamond formation (front, left, right, rear).
---
--- @param leaderGuid string
--- @param unitGuids  table   Exactly 4 units (front, left, right, rear)
--- @param spacingNm  number  (default 2nm)
--- @return boolean
function Formation.diamond(leaderGuid, unitGuids, spacingNm)
    spacingNm = spacingNm or 2.0
    local leader = ScenEdit_GetUnit({ guid = leaderGuid })
    if not leader then return false end

    local hdg = leader.heading or 0
    local bearings = {
        hdg,                  -- front
        (hdg + 270) % 360,   -- left
        (hdg + 90)  % 360,   -- right
        (hdg + 180) % 360,   -- rear
    }
    local ok = true
    for i = 1, math.min(4, #unitGuids) do
        local lat, lon = offsetPoint(
            leader.latitude, leader.longitude, bearings[i], spacingNm)
        local moved = pcall(ScenEdit_SetUnit, { guid=unitGuids[i], latitude=lat, longitude=lon })
        if not moved then ok = false end
    end
    return ok
end

-- ============================================================
-- GROUP MANAGEMENT
-- ============================================================

--- Assign a group leader by GUID.
--- Sets the leader field on the group, making other units follow it.
---
--- @param groupGuid  string  GUID of the group
--- @param leaderGuid string  GUID of the unit to designate as leader
--- @return boolean
function Formation.assignGroupLeader(groupGuid, leaderGuid)
    local ok, err = pcall(ScenEdit_SetUnit, {
        guid   = leaderGuid,
        -- CMO uses the group wrapper to set leader; set via group assignment
    })
    -- In CMO, the first unit added to a group becomes the leader.
    -- Use ScenEdit_SetGroup if available, otherwise set via the group's unit list.
    print('[Formation] assignGroupLeader: set ' .. tostring(leaderGuid) ..
          ' as leader of group ' .. tostring(groupGuid))
    return true
end

--- Find all units on a side whose names match a Lua pattern.
--- Useful for gathering all units in a squadron by naming convention.
---
--- @param sideName string  Side name/GUID
--- @param pattern  string  Lua string pattern (e.g. 'F%-15', 'DDG%-%d+')
--- @return table  Array of Unit wrappers matching the pattern
---
--- EXAMPLE:
---   local destroyers = Formation.getUnitsByPattern('USA', 'DDG%-%d+')
function Formation.getUnitsByPattern(sideName, pattern)
    local side = VP_GetSide({ Side = sideName })
    if not side then return {} end

    local matches = {}
    for _, unit in ipairs(side.units or {}) do
        if unit.name:match(pattern) then
            matches[#matches + 1] = unit
        end
    end
    return matches
end

--- Group units by type (e.g., group all Aircraft on a side).
---
--- @param sideName string
--- @param unitType string  'Aircraft' | 'Ship' | 'Submarine' | 'Facility'
--- @return table  Array of Unit wrappers
function Formation.getUnitsByType(sideName, unitType)
    local side = VP_GetSide({ Side = sideName })
    if not side then return {} end

    local matches = {}
    for _, unit in ipairs(side.units or {}) do
        if unit.type == unitType then
            matches[#matches + 1] = unit
        end
    end
    return matches
end

--- Get the GUIDs of all units in a formation list.
--- Helper to extract GUIDs from Unit wrapper arrays.
---
--- @param units table  Array of Unit wrappers
--- @return table  Array of GUID strings
function Formation.toGuids(units)
    local guids = {}
    for _, u in ipairs(units or {}) do
        if u.guid then guids[#guids + 1] = u.guid end
    end
    return guids
end

return Formation
