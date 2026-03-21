--- CMO Lua Zone / Area Library
--- Reference point management, zone creation, in-area checks, transforms.
---
--- @module zones.areas
---
--- USAGE EXAMPLE:
---   local Areas = dofile('path/to/lib/zones/areas.lua')
---
---   -- Create a rectangular patrol zone from corners
---   Areas.createRect('USA', 'PatrolZone', 36.0, -10.0, 38.0, -8.0)
---
---   -- Create a circular area around a center point (8 reference points)
---   Areas.createCircle('USA', 'ThreatCircle', 36.5, -10.0, 50.0, 8)
---
---   -- Check if a unit is within a named reference-point polygon
---   if Areas.unitInArea('unit-guid', {'Z1','Z2','Z3','Z4'}) then print('inside') end
---
---   -- Create an exclusion zone
---   Areas.createExclusionZone('USA', 'NoFlyNorth', {'EX1','EX2','EX3','EX4'}, 'aircraft')

local Areas = {}

-- ============================================================
-- REFERENCE POINT CREATION
-- ============================================================

--- Add a single reference point to a side.
---
--- @param sideName string
--- @param name     string
--- @param lat      number
--- @param lon      number
--- @param options  table|nil  {highlighted=bool, locked=bool, bearingtype=string}
--- @return ReferencePoint|nil
function Areas.addPoint(sideName, name, lat, lon, options)
    options = options or {}
    local params = {
        side        = sideName,
        name        = name,
        lat         = lat,
        lon         = lon,
        highlighted = options.highlighted or false,
        locked      = options.locked      or false,
    }
    if options.bearingtype then params.bearingtype = options.bearingtype end
    if options.relativeto  then params.relativeto  = options.relativeto  end

    local ok, rp = pcall(ScenEdit_AddReferencePoint, params)
    if not ok or not rp then
        print('[Areas] addPoint error: ' .. tostring(rp))
        return nil
    end
    return rp
end

--- Add multiple reference points from an array of {name, lat, lon} tables.
---
--- @param sideName string
--- @param points   table   Array of {name=string, lat=number, lon=number}
--- @return table  Array of created ReferencePoint wrappers
function Areas.addPoints(sideName, points)
    local created = {}
    local ok, result = pcall(ScenEdit_AddReferencePoint, {
        side = sideName,
        area = points,
    })
    if ok and result then
        if type(result) == 'table' then
            for _, rp in ipairs(result) do created[#created + 1] = rp end
        else
            created[1] = result
        end
    else
        print('[Areas] addPoints error: ' .. tostring(result))
    end
    return created
end

--- Create a rectangular zone from SW and NE corners.
--- Adds 4 reference points: name_SW, name_NW, name_NE, name_SE
---
--- @param sideName  string
--- @param prefix    string  Name prefix for the 4 points
--- @param swLat     number  South-West latitude
--- @param swLon     number  South-West longitude
--- @param neLat     number  North-East latitude
--- @param neLon     number  North-East longitude
--- @return table  {SW, NW, NE, SE} name strings
---
--- EXAMPLE:
---   local names = Areas.createRect('USA', 'PatrolZone', 36.0,-10.0, 38.0,-8.0)
---   -- Use names as zone in ScenEdit_AddMission or Areas.unitInArea
function Areas.createRect(sideName, prefix, swLat, swLon, neLat, neLon)
    local names = {
        prefix .. '_SW',
        prefix .. '_NW',
        prefix .. '_NE',
        prefix .. '_SE',
    }
    local points = {
        { name=names[1], lat=swLat, lon=swLon },
        { name=names[2], lat=neLat, lon=swLon },
        { name=names[3], lat=neLat, lon=neLon },
        { name=names[4], lat=swLat, lon=neLon },
    }
    Areas.addPoints(sideName, points)
    return names
end

--- Create a circular zone approximated by N reference points.
--- Points are evenly distributed around a center.
---
--- @param sideName  string
--- @param prefix    string  Name prefix (points named prefix_1 .. prefix_N)
--- @param centerLat number
--- @param centerLon number
--- @param radiusNm  number  Radius in nautical miles
--- @param numPoints number  Number of polygon vertices (default 8)
--- @return table  Array of reference point name strings
function Areas.createCircle(sideName, prefix, centerLat, centerLon, radiusNm, numPoints)
    numPoints = numPoints or 8
    local R   = 3440.065
    local rad = math.pi / 180
    local lat1 = centerLat * rad
    local lon1 = centerLon * rad
    local d    = radiusNm / R

    local points = {}
    local names  = {}

    for i = 1, numPoints do
        local angle = ((360 / numPoints) * (i - 1)) * rad
        local lat2  = math.asin(math.sin(lat1) * math.cos(d)
                                + math.cos(lat1) * math.sin(d) * math.cos(angle))
        local lon2  = lon1 + math.atan(
            math.sin(angle) * math.sin(d) * math.cos(lat1),
            math.cos(d) - math.sin(lat1) * math.sin(lat2))

        local name = prefix .. '_' .. i
        names[i]   = name
        points[i]  = {
            name = name,
            lat  = lat2 / rad,
            lon  = ((lon2 / rad + 540) % 360) - 180,
        }
    end

    Areas.addPoints(sideName, points)
    return names
end

-- ============================================================
-- ZONE CREATION
-- ============================================================

--- Create an exclusion zone from a set of reference points.
--- Units of affected types will not enter the zone.
---
--- @param sideName string
--- @param zoneName string
--- @param rpNames  table   Reference point names
--- @param affects  string  'aircraft'|'ships'|'submarines'|'all' (default 'aircraft')
--- @param isActive boolean (default true)
--- @return Zone|nil
---
--- EXAMPLE:
---   Areas.createExclusionZone('USA', 'NoFlyZone', {'Z1','Z2','Z3','Z4'}, 'aircraft')
function Areas.createExclusionZone(sideName, zoneName, rpNames, affects, isActive)
    local ok, zone = pcall(ScenEdit_AddZone, sideName, 'exclusion', {
        name     = zoneName,
        isactive = isActive ~= false,
        affects  = affects or 'aircraft',
        area     = rpNames,
    })
    if not ok or not zone then
        print('[Areas] createExclusionZone error: ' .. tostring(zone))
        return nil
    end
    return zone
end

--- Create a no-navigation zone (ships/submarines won't enter).
---
--- @param sideName string
--- @param zoneName string
--- @param rpNames  table
--- @param isActive boolean
--- @return Zone|nil
function Areas.createNoNavZone(sideName, zoneName, rpNames, isActive)
    local ok, zone = pcall(ScenEdit_AddZone, sideName, 'nonavigation', {
        name     = zoneName,
        isactive = isActive ~= false,
        area     = rpNames,
    })
    if not ok or not zone then
        print('[Areas] createNoNavZone error: ' .. tostring(zone))
        return nil
    end
    return zone
end

--- Activate or deactivate an existing zone by name.
---
--- @param sideName string
--- @param zoneName string
--- @param active   boolean
--- @return boolean
function Areas.setZoneActive(sideName, zoneName, active)
    local ok, err = pcall(ScenEdit_SetZone, sideName, zoneName, {
        isactive = active ~= false
    })
    if not ok then
        print('[Areas] setZoneActive error: ' .. tostring(err))
        return false
    end
    return true
end

-- ============================================================
-- IN-AREA CHECKS
-- ============================================================

--- Check if a unit is within a reference-point polygon.
--- Uses the unit's native :inArea() method when available.
---
--- @param unitGuid string
--- @param rpNames  table   Array of reference point name strings (3+)
--- @return boolean
---
--- EXAMPLE:
---   if Areas.unitInArea('unit-guid', {'P1','P2','P3','P4'}) then ... end
function Areas.unitInArea(unitGuid, rpNames)
    if not rpNames or #rpNames < 3 then return false end

    local unit = ScenEdit_GetUnit({ guid = unitGuid })
    if not unit then return false end

    local ok, result = pcall(function()
        return unit:inArea({ area = rpNames })
    end)
    return ok and result == true
end

--- Get all units on a side that are inside a reference-point area.
---
--- @param sideName string
--- @param rpNames  table   Reference point names
--- @param unitType string|nil  Filter by type (nil=all)
--- @return table  Array of Unit wrappers inside the area
function Areas.unitsInArea(sideName, rpNames, unitType)
    local side = VP_GetSide({ Side = sideName })
    if not side then return {} end

    local inside = {}
    for _, unit in ipairs(side.units or {}) do
        local typeMatch = (unitType == nil) or (unit.type == unitType)
        if typeMatch and not unit.IsDestroyed then
            if Areas.unitInArea(unit.guid, rpNames) then
                inside[#inside + 1] = unit
            end
        end
    end
    return inside
end

--- Check if a lat/lon point is inside a reference-point polygon.
--- Uses ray-casting algorithm.
---
--- @param lat      number
--- @param lon      number
--- @param sideName string   Side that owns the reference points
--- @param rpNames  table    Reference point name strings
--- @return boolean
function Areas.pointInArea(lat, lon, sideName, rpNames)
    local polygon = {}
    for _, name in ipairs(rpNames or {}) do
        local ok, rp = pcall(ScenEdit_GetReferencePoint, { side=sideName, name=name })
        if ok and rp then
            polygon[#polygon + 1] = { lat=rp.latitude, lon=rp.longitude }
        end
    end

    if #polygon < 3 then return false end

    local inside = false
    local j = #polygon
    for i = 1, #polygon do
        local xi = polygon[i].lon
        local yi = polygon[i].lat
        local xj = polygon[j].lon
        local yj = polygon[j].lat
        local intersect = ((yi > lat) ~= (yj > lat)) and
                          (lon < (xj - xi) * (lat - yi) / (yj - yi) + xi)
        if intersect then inside = not inside end
        j = i
    end
    return inside
end

-- ============================================================
-- REFERENCE POINT UTILITIES
-- ============================================================

--- Color a set of reference points (cosmetic highlight).
--- Colors: 'red'|'green'|'blue'|'yellow'|'white'|'black'
---
--- @param sideName string
--- @param rpNames  table    Array of reference point names
--- @param color    string
function Areas.colorPoints(sideName, rpNames, color)
    for _, name in ipairs(rpNames or {}) do
        pcall(ScenEdit_SetReferencePoint, {
            side  = sideName,
            name  = name,
            color = color or 'yellow',
        })
    end
end

--- Move a reference point to a new position.
---
--- @param sideName string
--- @param rpName   string
--- @param lat      number
--- @param lon      number
--- @return boolean
function Areas.movePoint(sideName, rpName, lat, lon)
    local ok, err = pcall(ScenEdit_SetReferencePoint, {
        side = sideName,
        name = rpName,
        lat  = lat,
        lon  = lon,
    })
    if not ok then
        print('[Areas] movePoint error: ' .. tostring(err))
        return false
    end
    return true
end

--- Delete a reference point by name.
---
--- @param sideName string
--- @param rpName   string
--- @return boolean
function Areas.deletePoint(sideName, rpName)
    local ok, err = pcall(ScenEdit_DeleteReferencePoint, {
        side = sideName,
        name = rpName,
    })
    if not ok then
        print('[Areas] deletePoint error: ' .. tostring(err))
        return false
    end
    return true
end

--- Translate (shift) all points in a zone by a delta lat/lon.
--- Useful for moving patrol areas without recreating them.
---
--- @param sideName string
--- @param rpNames  table   Array of reference point names to move
--- @param deltaLat number
--- @param deltaLon number
function Areas.translateZone(sideName, rpNames, deltaLat, deltaLon)
    for _, name in ipairs(rpNames or {}) do
        local ok, rp = pcall(ScenEdit_GetReferencePoint, { side=sideName, name=name })
        if ok and rp then
            pcall(ScenEdit_SetReferencePoint, {
                side = sideName,
                name = name,
                lat  = rp.latitude  + deltaLat,
                lon  = rp.longitude + deltaLon,
            })
        end
    end
end

return Areas
