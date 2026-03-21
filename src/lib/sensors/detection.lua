--- CMO Lua Sensors Detection Library
--- LOS checks, contact filtering, area checks, bearing/range, sensor sweeps.
---
--- @module sensors.detection
---
--- USAGE EXAMPLE:
---   local Detection = dofile('path/to/lib/sensors/detection.lua')
---
---   -- Check line-of-sight between two units
---   local hasSight = Detection.los('unit-a-guid', 'unit-b-guid')
---
---   -- Get all hostile aircraft contacts for blue side
---   local contacts = Detection.getContacts('USA', 'Aircraft')
---
---   -- Is a contact inside a named area?
---   local inside = Detection.contactInArea('contact-guid', {'zone-rp1','zone-rp2','zone-rp3','zone-rp4'})
---
---   -- Find all contacts within 50nm of a point
---   local nearby = Detection.sweepRadius('USA', 36.0, -10.0, 50)

local Detection = {}

-- ============================================================
-- LINE-OF-SIGHT
-- ============================================================

--- Check line-of-sight between two units using Tool_LOS.
--- Returns false on any error (units not found, Tool_LOS unavailable, etc.)
---
--- @param unitGuidA string  First unit GUID
--- @param unitGuidB string  Second unit GUID
--- @return boolean  true if LOS exists between the two units
function Detection.los(unitGuidA, unitGuidB)
    local unitA = ScenEdit_GetUnit({ guid = unitGuidA })
    local unitB = ScenEdit_GetUnit({ guid = unitGuidB })
    if not unitA or not unitB then return false end

    local ok, result = pcall(Tool_LOS,
        { latitude=unitA.latitude, longitude=unitA.longitude, altitude=unitA.altitude or 0 },
        { latitude=unitB.latitude, longitude=unitB.longitude, altitude=unitB.altitude or 0 })

    return ok and result == true
end

--- Check LOS between two explicit geographic points.
---
--- @param lat1 number  Point 1 latitude
--- @param lon1 number  Point 1 longitude
--- @param alt1 number  Point 1 altitude in meters (0 = sea level)
--- @param lat2 number
--- @param lon2 number
--- @param alt2 number
--- @return boolean
function Detection.losPoints(lat1, lon1, alt1, lat2, lon2, alt2)
    local ok, result = pcall(Tool_LOS,
        { latitude=lat1, longitude=lon1, altitude=alt1 or 0 },
        { latitude=lat2, longitude=lon2, altitude=alt2 or 0 })
    return ok and result == true
end

-- ============================================================
-- CONTACT QUERIES
-- ============================================================

--- Get all contacts for a side, optionally filtered by unit type.
---
--- @param sideName string       Side name/GUID
--- @param unitType  string|nil  'Aircraft'|'Ship'|'Submarine'|'Facility'|nil=any
--- @param hostile   boolean|nil If true, only return contacts NOT from sideName (hostile)
--- @return table  Array of Contact wrappers
---
--- EXAMPLE:
---   local subs = Detection.getContacts('USA', 'Submarine', true)
function Detection.getContacts(sideName, unitType, hostile)
    local side = VP_GetSide({ Side = sideName })
    if not side then return {} end

    local result = {}
    for _, contact in ipairs(side.contacts or {}) do
        local typeMatch = (unitType == nil) or (contact.type == unitType)
        local sideMatch = (hostile == nil) or
                          (hostile == true  and contact.fromside ~= sideName) or
                          (hostile == false and contact.fromside == sideName)

        if typeMatch and sideMatch then
            result[#result + 1] = contact
        end
    end
    return result
end

--- Get a specific contact by GUID from a side's contact list.
---
--- @param sideName    string  Side name/GUID
--- @param contactGuid string  Contact GUID to find
--- @return Contact|nil
function Detection.getContact(sideName, contactGuid)
    local side = VP_GetSide({ Side = sideName })
    if not side then return nil end

    for _, contact in ipairs(side.contacts or {}) do
        if contact.guid == contactGuid then return contact end
    end
    return nil
end

--- Get the classification level of a contact.
--- Returns 'Unknown' if the contact is not found.
---
--- @param sideName    string
--- @param contactGuid string
--- @return string  'Unknown'|'Suspect'|'Identified'|'Recognized'
function Detection.getClassification(sideName, contactGuid)
    local contact = Detection.getContact(sideName, contactGuid)
    if not contact then return 'Unknown' end
    return contact.classificationlevel or 'Unknown'
end

--- Check whether a contact has been identified (classification = 'Identified' or 'Recognized').
---
--- @param sideName    string
--- @param contactGuid string
--- @return boolean
function Detection.isIdentified(sideName, contactGuid)
    local cl = Detection.getClassification(sideName, contactGuid)
    return cl == 'Identified' or cl == 'Recognized'
end

--- Get the age of a contact in seconds (time since last update).
---
--- @param sideName    string
--- @param contactGuid string
--- @return number  Age in seconds, or math.huge if not found
function Detection.getContactAge(sideName, contactGuid)
    local contact = Detection.getContact(sideName, contactGuid)
    if not contact then return math.huge end
    return contact.age or 0
end

-- ============================================================
-- AREA / POSITION CHECKS
-- ============================================================

--- Check if a contact is inside a named reference-point area.
--- Uses the contact's estimated position.
---
--- @param sideName    string        Side that owns both the contact and reference points
--- @param contactGuid string        Contact GUID
--- @param rpNames     table         Array of reference point name strings
--- @return boolean
---
--- EXAMPLE:
---   Detection.contactInArea('USA', 'contact-guid', {'ZN-1','ZN-2','ZN-3','ZN-4'})
function Detection.contactInArea(sideName, contactGuid, rpNames)
    if not rpNames or #rpNames < 3 then
        print('[Detection] contactInArea: need at least 3 reference points')
        return false
    end

    local contact = Detection.getContact(sideName, contactGuid)
    if not contact then return false end

    -- Use point-in-polygon with the reference point positions
    -- Fetch RP positions
    local polygon = {}
    for _, name in ipairs(rpNames) do
        local ok, rp = pcall(ScenEdit_GetReferencePoint, { side=sideName, name=name })
        if ok and rp then
            polygon[#polygon + 1] = { lat=rp.latitude, lon=rp.longitude }
        end
    end

    if #polygon < 3 then return false end

    -- Ray-casting algorithm for point-in-polygon
    local lat  = contact.latitude
    local lon  = contact.longitude
    local inside = false
    local j    = #polygon

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

--- Check if a lat/lon point is within a simple rectangular bounding box.
---
--- @param lat    number  Point latitude
--- @param lon    number  Point longitude
--- @param minLat number
--- @param maxLat number
--- @param minLon number
--- @param maxLon number
--- @return boolean
function Detection.inBoundingBox(lat, lon, minLat, maxLat, minLon, maxLon)
    return lat >= minLat and lat <= maxLat and lon >= minLon and lon <= maxLon
end

--- Check if a contact is within a given range (nm) of a reference point.
---
--- @param sideName    string
--- @param contactGuid string
--- @param refLat      number  Reference latitude
--- @param refLon      number  Reference longitude
--- @param radiusNm    number  Radius in nautical miles
--- @return boolean
function Detection.contactWithinRadius(sideName, contactGuid, refLat, refLon, radiusNm)
    local contact = Detection.getContact(sideName, contactGuid)
    if not contact then return false end

    local ok, dist = pcall(Tool_Range,
        { latitude=contact.latitude, longitude=contact.longitude },
        { latitude=refLat,           longitude=refLon           })

    if not ok or type(dist) ~= 'number' then
        -- Haversine fallback
        local R   = 3440.065
        local rad = math.pi / 180
        local dlat = (refLat - contact.latitude) * rad
        local dlon = (refLon - contact.longitude) * rad
        local a   = math.sin(dlat/2)^2 + math.cos(contact.latitude*rad) *
                    math.cos(refLat*rad) * math.sin(dlon/2)^2
        dist = R * 2 * math.atan(math.sqrt(a), math.sqrt(1-a))
    end

    return dist <= radiusNm
end

-- ============================================================
-- BEARING AND RANGE
-- ============================================================

--- Calculate the bearing and range from one unit to a contact.
---
--- @param fromUnitGuid string  GUID of the observing unit
--- @param contactGuid  string  GUID of the contact
--- @param sideName     string  Side that owns the contact record
--- @return number, number  bearing (degrees), range (nautical miles); or nil,nil on error
function Detection.bearingRange(fromUnitGuid, contactGuid, sideName)
    local unit    = ScenEdit_GetUnit({ guid = fromUnitGuid })
    local contact = Detection.getContact(sideName, contactGuid)
    if not unit or not contact then return nil, nil end

    -- Use unit method if available
    local ok, rng = pcall(function()
        return unit:rangetotarget(contactGuid)
    end)
    local range = (ok and type(rng) == 'number') and rng or nil

    if not range then
        -- Fallback: Tool_Range
        local ok2, r2 = pcall(Tool_Range,
            { latitude=unit.latitude,    longitude=unit.longitude    },
            { latitude=contact.latitude, longitude=contact.longitude })
        range = (ok2 and type(r2) == 'number') and r2 or 0
    end

    -- Bearing (forward azimuth)
    local rad  = math.pi / 180
    local dlon = (contact.longitude - unit.longitude) * rad
    local y    = math.sin(dlon) * math.cos(contact.latitude * rad)
    local x    = math.cos(unit.latitude * rad) * math.sin(contact.latitude * rad)
               - math.sin(unit.latitude * rad) * math.cos(contact.latitude * rad) * math.cos(dlon)
    local brg  = (math.atan(y, x) / rad + 360) % 360

    return brg, range
end

-- ============================================================
-- SENSOR SWEEP
-- ============================================================

--- Find all contacts for a side within a radius of a point.
--- Returns contacts sorted by range (nearest first).
---
--- @param sideName string       Side name/GUID
--- @param lat      number       Center latitude
--- @param lon      number       Center longitude
--- @param radiusNm number       Search radius in nautical miles
--- @param unitType string|nil   Filter by contact type (nil=all)
--- @return table  Array of {contact=Contact, range=number} sorted by range
---
--- EXAMPLE:
---   local threats = Detection.sweepRadius('USA', 36.0, -10.0, 100, 'Aircraft')
function Detection.sweepRadius(sideName, lat, lon, radiusNm, unitType)
    local contacts = Detection.getContacts(sideName, unitType, true)
    local results  = {}

    for _, contact in ipairs(contacts) do
        local ok, dist = pcall(Tool_Range,
            { latitude=contact.latitude, longitude=contact.longitude },
            { latitude=lat,              longitude=lon               })

        local range
        if ok and type(dist) == 'number' then
            range = dist
        else
            local R   = 3440.065
            local rad = math.pi / 180
            local dlat = (lat - contact.latitude) * rad
            local dlon = (lon - contact.longitude) * rad
            local a   = math.sin(dlat/2)^2 + math.cos(contact.latitude*rad) *
                        math.cos(lat*rad) * math.sin(dlon/2)^2
            range = R * 2 * math.atan(math.sqrt(a), math.sqrt(1-a))
        end

        if range <= radiusNm then
            results[#results + 1] = { contact=contact, range=range }
        end
    end

    -- Sort by range ascending
    table.sort(results, function(a, b) return a.range < b.range end)
    return results
end

--- Count how many hostile contacts a side currently has, optionally by type.
---
--- @param sideName string
--- @param unitType  string|nil
--- @return number
function Detection.countContacts(sideName, unitType)
    return #Detection.getContacts(sideName, unitType, true)
end

--- Get the closest hostile contact to a unit.
---
--- @param unitGuid string  Observer unit GUID
--- @param sideName string  Side of the observer
--- @param unitType  string|nil  Filter by type
--- @return Contact|nil, number|nil  Closest contact and range (nm)
function Detection.closestContact(unitGuid, sideName, unitType)
    local unit = ScenEdit_GetUnit({ guid = unitGuid })
    if not unit then return nil, nil end

    local contacts = Detection.getContacts(sideName, unitType, true)
    local best_contact = nil
    local best_range   = math.huge

    for _, contact in ipairs(contacts) do
        local ok, dist = pcall(Tool_Range,
            { latitude=unit.latitude,    longitude=unit.longitude    },
            { latitude=contact.latitude, longitude=contact.longitude })
        local range = (ok and type(dist) == 'number') and dist or math.huge
        if range < best_range then
            best_range   = range
            best_contact = contact
        end
    end

    return best_contact, (best_contact and best_range or nil)
end

return Detection
