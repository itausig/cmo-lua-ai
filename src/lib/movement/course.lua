--- CMO Lua Movement Course Library
--- Waypoint management, patrol patterns, sprint-and-drift, RTB helpers.
---
--- @module movement.course
---
--- USAGE EXAMPLE:
---   local Course = dofile('path/to/lib/movement/course.lua')
---
---   -- Set a simple two-waypoint course
---   Course.setCourse('unit-guid', {
---       {latitude=36.0, longitude=-10.0},
---       {latitude=37.0, longitude=-9.0},
---   })
---
---   -- Create a patrol box around a point, 20nm radius
---   Course.patrolBox('unit-guid', 36.5, -10.0, 20, 4)
---
---   -- Racetrack pattern
---   Course.racetrack('unit-guid', 36.0, -10.0, 37.0, -9.0, 5000)
---
---   -- Send unit home
---   Course.rtb('unit-guid')

local Course = {}

-- ============================================================
-- CORE: SET COURSE
-- ============================================================

--- Set a unit's course to a list of waypoints.
--- Each waypoint should have {latitude, longitude} and optionally {altitude}.
--- Clears the existing course and replaces it.
---
--- @param unitGuid  string  GUID of the unit
--- @param waypoints table   Array of {latitude=number, longitude=number, altitude=number|nil}
--- @param append    boolean If true, append to existing course (default false = replace)
--- @return boolean  true on success
---
--- EXAMPLE:
---   Course.setCourse('guid', {{latitude=36.0,longitude=-10.0},{latitude=37.0,longitude=-9.0}})
function Course.setCourse(unitGuid, waypoints, append)
    if not unitGuid then
        print('[Course] setCourse: unitGuid required')
        return false
    end
    if type(waypoints) ~= 'table' or #waypoints == 0 then
        print('[Course] setCourse: waypoints must be a non-empty array')
        return false
    end

    local unit = ScenEdit_GetUnit({ guid = unitGuid })
    if not unit then
        print('[Course] setCourse: unit not found: ' .. tostring(unitGuid))
        return false
    end

    local course = {}
    if append and unit.course then
        for _, wp in ipairs(unit.course) do
            course[#course + 1] = wp
        end
    end
    for _, wp in ipairs(waypoints) do
        course[#course + 1] = {
            latitude  = wp.latitude  or wp.lat,
            longitude = wp.longitude or wp.lon,
            altitude  = wp.altitude,
        }
    end

    local ok, err = pcall(function()
        unit = ScenEdit_SetUnit({ guid = unitGuid, course = course })
    end)
    if not ok then
        print('[Course] setCourse error: ' .. tostring(err))
        return false
    end
    return true
end

--- Add a single waypoint to the end of a unit's current course.
---
--- @param unitGuid string
--- @param lat      number
--- @param lon      number
--- @param alt      number|nil  Altitude in meters (nil = current)
--- @return boolean
function Course.addWaypoint(unitGuid, lat, lon, alt)
    return Course.setCourse(unitGuid, {{ latitude=lat, longitude=lon, altitude=alt }}, true)
end

--- Clear all waypoints from a unit (stops it in place).
---
--- @param unitGuid string
--- @return boolean
function Course.clearCourse(unitGuid)
    local ok, err = pcall(ScenEdit_SetUnit, { guid = unitGuid, course = {} })
    if not ok then
        print('[Course] clearCourse error: ' .. tostring(err))
        return false
    end
    return true
end

-- ============================================================
-- SET MOVEMENT PARAMETERS
-- ============================================================

--- Set desired altitude for a unit.
---
--- @param unitGuid  string  GUID
--- @param altMeters number  Altitude in meters (negative for submarines = depth)
--- @param manual    boolean If true, pin altitude (default false)
--- @return boolean
function Course.setAltitude(unitGuid, altMeters, manual)
    local ok, err = pcall(ScenEdit_SetUnit, {
        guid            = unitGuid,
        desiredAltitude = altMeters,
        manualAltitude  = (manual == true),
    })
    if not ok then
        print('[Course] setAltitude error: ' .. tostring(err))
        return false
    end
    return true
end

--- Set desired speed for a unit in knots.
---
--- @param unitGuid string
--- @param knots    number
--- @param manual   boolean  (default false)
--- @return boolean
function Course.setSpeed(unitGuid, knots, manual)
    local ok, err = pcall(ScenEdit_SetUnit, {
        guid         = unitGuid,
        desiredSpeed = knots,
        manualSpeed  = (manual == true),
    })
    if not ok then
        print('[Course] setSpeed error: ' .. tostring(err))
        return false
    end
    return true
end

--- Set desired heading for a unit in degrees (0–360).
---
--- @param unitGuid string
--- @param heading  number  Degrees true north (0–360)
--- @return boolean
function Course.setHeading(unitGuid, heading)
    local ok, err = pcall(ScenEdit_SetUnit, {
        guid           = unitGuid,
        desiredHeading = heading % 360,
    })
    if not ok then
        print('[Course] setHeading error: ' .. tostring(err))
        return false
    end
    return true
end

-- ============================================================
-- PATROL PATTERNS
-- ============================================================

--- Create a square patrol box from a center point and half-width radius.
--- Generates four corner waypoints and sets the course as a loop.
---
--- @param unitGuid   string
--- @param centerLat  number  Center latitude
--- @param centerLon  number  Center longitude
--- @param radiusNm   number  Half-width/height of the box in nautical miles
--- @param numLegs    number  Number of box legs (4=square, 8=octagon); default 4
--- @param altMeters  number|nil  Altitude (nil = unchanged)
--- @return boolean
function Course.patrolBox(unitGuid, centerLat, centerLon, radiusNm, numLegs, altMeters)
    numLegs = numLegs or 4
    local waypoints = {}
    local R   = 3440.065
    local rad = math.pi / 180
    local lat1 = centerLat * rad
    local lon1 = centerLon * rad
    local d   = radiusNm / R

    for i = 0, numLegs - 1 do
        -- Distribute corners evenly around the circle
        -- Offset by 45° so the first leg goes NE for a square box
        local angle = (360 / numLegs) * i + (180 / numLegs)
        local b = angle * rad

        local lat2 = math.asin(math.sin(lat1) * math.cos(d)
                                + math.cos(lat1) * math.sin(d) * math.cos(b))
        local lon2 = lon1 + math.atan(
            math.sin(b) * math.sin(d) * math.cos(lat1),
            math.cos(d) - math.sin(lat1) * math.sin(lat2))

        waypoints[#waypoints + 1] = {
            latitude  = lat2 / rad,
            longitude = ((lon2 / rad + 540) % 360) - 180,
            altitude  = altMeters,
        }
    end

    -- Close the loop by returning to the first waypoint
    waypoints[#waypoints + 1] = waypoints[1]
    return Course.setCourse(unitGuid, waypoints)
end

--- Generate a racetrack patrol pattern between two endpoints.
--- The unit flies back and forth between the two points.
---
--- @param unitGuid  string
--- @param lat1      number   Endpoint 1 latitude
--- @param lon1      number   Endpoint 1 longitude
--- @param lat2      number   Endpoint 2 latitude
--- @param lon2      number   Endpoint 2 longitude
--- @param altMeters number|nil
--- @param loops     number|nil  How many complete laps to encode (default 3)
--- @return boolean
function Course.racetrack(unitGuid, lat1, lon1, lat2, lon2, altMeters, loops)
    loops = loops or 3
    local waypoints = {}
    local p1 = { latitude=lat1, longitude=lon1, altitude=altMeters }
    local p2 = { latitude=lat2, longitude=lon2, altitude=altMeters }

    for _ = 1, loops do
        waypoints[#waypoints + 1] = p2
        waypoints[#waypoints + 1] = p1
    end
    return Course.setCourse(unitGuid, waypoints)
end

--- Generate a figure-8 (lemniscate) patrol pattern around two anchor points.
---
--- @param unitGuid  string
--- @param lat1      number  First anchor latitude
--- @param lon1      number  First anchor longitude
--- @param lat2      number  Second anchor latitude
--- @param lon2      number  Second anchor longitude
--- @param radiusNm  number  Loop radius in nautical miles
--- @param altMeters number|nil
--- @return boolean
function Course.figure8(unitGuid, lat1, lon1, lat2, lon2, radiusNm, altMeters)
    -- Build a figure-8 by generating a semi-circle around each anchor
    local R   = 3440.065
    local rad = math.pi / 180
    local waypoints = {}

    local anchors = {
        { lat=lat1, lon=lon1 },
        { lat=lat2, lon=lon2 },
    }

    local directions = { 1, -1 }   -- clockwise, then counter-clockwise

    for i, anchor in ipairs(anchors) do
        local la1 = anchor.lat * rad
        local lo1 = anchor.lon * rad
        local d   = radiusNm / R
        local dir = directions[i]
        local steps = 8  -- semicircle points

        for s = 0, steps do
            local angle = dir * 180 * s / steps  -- 0..180 degrees arc
            local b     = angle * rad
            local lat2r = math.asin(math.sin(la1) * math.cos(d)
                                    + math.cos(la1) * math.sin(d) * math.cos(b))
            local lon2r = lo1 + math.atan(
                math.sin(b) * math.sin(d) * math.cos(la1),
                math.cos(d) - math.sin(la1) * math.sin(lat2r))

            waypoints[#waypoints + 1] = {
                latitude  = lat2r / rad,
                longitude = ((lon2r / rad + 540) % 360) - 180,
                altitude  = altMeters,
            }
        end
    end

    return Course.setCourse(unitGuid, waypoints)
end

-- ============================================================
-- SUBMARINE: SPRINT AND DRIFT
-- ============================================================

--- Configure a submarine for sprint-and-drift tactics.
--- Uses the unit's built-in sprintDrift flag plus optional
--- course/speed setup for a realistic drift period.
---
--- @param unitGuid     string
--- @param enable       boolean  true=enable, false=disable
--- @param sprintSpeedKt number|nil  Sprint speed in knots (default 20)
--- @param driftSpeedKt  number|nil  Drift speed in knots (default 5)
--- @return boolean
function Course.sprintAndDrift(unitGuid, enable, sprintSpeedKt, driftSpeedKt)
    local ok, err = pcall(ScenEdit_SetUnit, {
        guid         = unitGuid,
        sprintDrift  = (enable ~= false),
        desiredSpeed = enable and (sprintSpeedKt or 20) or (driftSpeedKt or 5),
    })
    if not ok then
        print('[Course] sprintAndDrift error: ' .. tostring(err))
        return false
    end
    return true
end

-- ============================================================
-- RTB (RETURN TO BASE)
-- ============================================================

--- Command a unit to return to base immediately.
--- Checks that the unit exists and is not already RTB or destroyed.
---
--- @param unitGuid   string
--- @param force      boolean  If true, call RTB even if already returning (default false)
--- @return boolean  true if RTB was issued
function Course.rtb(unitGuid, force)
    local unit = ScenEdit_GetUnit({ guid = unitGuid })
    if not unit then
        print('[Course] rtb: unit not found: ' .. tostring(unitGuid))
        return false
    end
    if unit.IsDestroyed then
        print('[Course] rtb: unit is destroyed')
        return false
    end
    -- unitstate may contain 'RTB' if already returning
    if not force and unit.unitstate and unit.unitstate:find('RTB') then
        return false   -- already RTB
    end

    local ok, err = pcall(function() unit:RTB() end)
    if not ok then
        print('[Course] rtb error: ' .. tostring(err))
        return false
    end
    return true
end

--- Command RTB for all units in a list that are below a fuel threshold.
---
--- @param unitGuids     table   Array of unit GUIDs
--- @param fuelThreshold number  Fuel % below which to RTB (default 20)
--- @return table  Array of GUIDs that were sent RTB
function Course.rtbBingo(unitGuids, fuelThreshold)
    fuelThreshold = fuelThreshold or 20
    local sent = {}
    for _, guid in ipairs(unitGuids or {}) do
        local unit = ScenEdit_GetUnit({ guid = guid })
        if unit and not unit.IsDestroyed then
            local fuel = unit.fuel
            local pct  = 100
            if fuel then
                pct = tonumber(fuel.percent) or
                      (fuel.current and fuel.max and fuel.max > 0 and
                       (fuel.current / fuel.max * 100)) or 100
            end
            if pct <= fuelThreshold then
                if Course.rtb(guid) then
                    sent[#sent + 1] = guid
                end
            end
        end
    end
    return sent
end

return Course
