--- CMO Lua Utility Library
--- Foundation utilities for Command: Modern Operations scripting.
---
--- @module utils
---
--- USAGE EXAMPLE:
---   -- In your scenario init or event script:
---   local Utils = dofile('path/to/utils.lua')
---
---   Utils.log(Utils.LOG_INFO, "Scenario started")
---
---   local unit = Utils.getUnit({guid = 'abc-123'})
---   if not unit then
---       Utils.log(Utils.LOG_WARN, "Unit not found")
---       return
---   end
---
---   local dist = Utils.distance(unit.latitude, unit.longitude, 36.0, -10.0)
---   Utils.log(Utils.LOG_INFO, string.format("Unit is %.1f nm from point", dist))
---
---   local t = Utils.table_copy({a=1, b={c=2}})
---   Utils.log(Utils.LOG_DEBUG, Utils.table_print(t))

local Utils = {}

-- ============================================================
-- LOG LEVELS
-- ============================================================

--- @enum LogLevel
Utils.LOG_DEBUG   = 0
Utils.LOG_INFO    = 1
Utils.LOG_WARN    = 2
Utils.LOG_ERROR   = 3

--- Current log level. Messages below this level are suppressed.
--- Default: LOG_INFO (suppress debug messages in production).
Utils._logLevel = Utils.LOG_INFO

--- Side to send log messages to via ScenEdit_SpecialMessage.
--- Set to nil to suppress in-game messages (use print only).
Utils._logSide = nil

local _levelNames = { [0]='DEBUG', [1]='INFO', [2]='WARN', [3]='ERROR' }

--- Set the minimum log level.
--- @param level number  One of Utils.LOG_DEBUG .. Utils.LOG_ERROR
function Utils.setLogLevel(level)
    Utils._logLevel = level
end

--- Set the side to receive special-message log output.
--- @param side string|nil  Side name/GUID, or nil to disable
function Utils.setLogSide(side)
    Utils._logSide = side
end

--- Log a message at the given level.
--- Messages at or above Utils._logLevel are printed and optionally
--- sent as a special message to Utils._logSide.
---
--- @param level  number  Log level constant
--- @param msg    string  Message text
--- @param ...    any     Additional values appended via tostring()
function Utils.log(level, msg, ...)
    if level < Utils._logLevel then return end
    local parts = { tostring(msg) }
    for _, v in ipairs({...}) do
        parts[#parts + 1] = tostring(v)
    end
    local text = '[' .. (os.date('!%H:%M:%S') or '?') .. '] ['
                 .. (_levelNames[level] or '?') .. '] '
                 .. table.concat(parts, ' ')
    print(text)
    if Utils._logSide then
        pcall(ScenEdit_SpecialMessage, Utils._logSide, text)
    end
end

-- ============================================================
-- UNIT ACCESS
-- ============================================================

--- Safely retrieve a unit wrapper. Returns nil instead of raising an error.
---
--- Prefer GUIDs over names to avoid ambiguity.
---
--- @param params table  {guid=string} or {name=string, side=string}
--- @return Unit|nil     CMO Unit wrapper, or nil if not found
function Utils.getUnit(params)
    if type(params) ~= 'table' then
        Utils.log(Utils.LOG_WARN, 'getUnit: params must be a table')
        return nil
    end
    local ok, result = pcall(ScenEdit_GetUnit, params)
    if ok and result then return result end
    return nil
end

--- Safely retrieve a side wrapper. Returns nil on failure.
---
--- @param sideName string  Side name or GUID
--- @return Side|nil
function Utils.getSide(sideName)
    local ok, result = pcall(VP_GetSide, { Side = sideName })
    if ok and result then return result end
    return nil
end

--- Safely retrieve a contact wrapper. Returns nil on failure.
---
--- @param contactGuid string  Contact GUID
--- @return Contact|nil
function Utils.getContact(contactGuid)
    local ok, result = pcall(VP_GetContact, { guid = contactGuid })
    if ok and result then return result end
    return nil
end

-- ============================================================
-- SAFE PCALL WRAPPER
-- ============================================================

--- Wrap a ScenEdit function call in pcall, logging any error.
--- Returns (true, result) on success or (false, errorMessage) on failure.
---
--- @param fn     function  The CMO function to call
--- @param ...    any       Arguments forwarded to fn
--- @return boolean, any
---
--- EXAMPLE:
---   local ok, mission = Utils.safeCall(ScenEdit_AddMission, 'USA', 'CAP Alpha', 'patrol', {type='air'})
---   if not ok then Utils.log(Utils.LOG_ERROR, 'Failed to create mission:', mission) end
function Utils.safeCall(fn, ...)
    if type(fn) ~= 'function' then
        Utils.log(Utils.LOG_ERROR, 'safeCall: first argument must be a function')
        return false, 'not a function'
    end
    local args = {...}
    local ok, result = pcall(fn, table.unpack(args))
    if not ok then
        Utils.log(Utils.LOG_ERROR, 'safeCall error:', tostring(result))
    end
    return ok, result
end

-- ============================================================
-- DISTANCE & NAVIGATION
-- ============================================================

--- Calculate distance in nautical miles between two lat/lon points.
--- Delegates to Tool_Range when available (CMO native, uses WGS-84),
--- falling back to the Haversine formula for offline/test use.
---
--- @param lat1 number  Latitude of point 1 (decimal degrees)
--- @param lon1 number  Longitude of point 1 (decimal degrees)
--- @param lat2 number  Latitude of point 2 (decimal degrees)
--- @param lon2 number  Longitude of point 2 (decimal degrees)
--- @return number      Distance in nautical miles
function Utils.distance(lat1, lon1, lat2, lon2)
    -- Prefer CMO native function for accuracy
    local ok, result = pcall(Tool_Range,
        { latitude = lat1, longitude = lon1 },
        { latitude = lat2, longitude = lon2 })
    if ok and type(result) == 'number' then return result end

    -- Fallback: Haversine formula
    local R = 3440.065   -- Earth radius in nautical miles
    local rad = math.pi / 180
    local dlat = (lat2 - lat1) * rad
    local dlon = (lon2 - lon1) * rad
    local a = math.sin(dlat / 2) ^ 2
              + math.cos(lat1 * rad) * math.cos(lat2 * rad)
              * math.sin(dlon / 2) ^ 2
    local c = 2 * math.atan(math.sqrt(a), math.sqrt(1 - a))
    return R * c
end

--- Calculate the initial bearing (degrees, 0–360) from point 1 to point 2.
---
--- @param lat1 number
--- @param lon1 number
--- @param lat2 number
--- @param lon2 number
--- @return number  Bearing in degrees
function Utils.bearing(lat1, lon1, lat2, lon2)
    local rad = math.pi / 180
    local dlon = (lon2 - lon1) * rad
    local y = math.sin(dlon) * math.cos(lat2 * rad)
    local x = math.cos(lat1 * rad) * math.sin(lat2 * rad)
              - math.sin(lat1 * rad) * math.cos(lat2 * rad) * math.cos(dlon)
    local brg = math.atan(y, x) / rad
    return (brg + 360) % 360
end

--- Compute the destination point given an origin, bearing and distance.
---
--- @param lat   number  Origin latitude (decimal degrees)
--- @param lon   number  Origin longitude (decimal degrees)
--- @param brg   number  Bearing in degrees (true north)
--- @param distNm number Distance in nautical miles
--- @return number, number  destination latitude, longitude
function Utils.destinationPoint(lat, lon, brg, distNm)
    local R   = 3440.065      -- Earth radius nm
    local rad = math.pi / 180
    local d   = distNm / R    -- angular distance
    local b   = brg * rad
    local lat1 = lat * rad
    local lon1 = lon * rad

    local lat2 = math.asin(
        math.sin(lat1) * math.cos(d)
        + math.cos(lat1) * math.sin(d) * math.cos(b))

    local lon2 = lon1 + math.atan(
        math.sin(b) * math.sin(d) * math.cos(lat1),
        math.cos(d) - math.sin(lat1) * math.sin(lat2))

    return lat2 / rad, ((lon2 / rad + 540) % 360) - 180
end

--- Generate a random lat/lon point within a bounding box defined by
--- a list of reference points (table of {lat,lon} or {latitude,longitude}).
---
--- @param refPoints table  Array of point tables with lat/lon fields
--- @return number, number  Random latitude, longitude within bounding box
function Utils.randomPointInArea(refPoints)
    if type(refPoints) ~= 'table' or #refPoints == 0 then
        Utils.log(Utils.LOG_WARN, 'randomPointInArea: empty or invalid refPoints')
        return 0, 0
    end

    local minLat, maxLat =  90, -90
    local minLon, maxLon = 180, -180

    for _, p in ipairs(refPoints) do
        local la = p.latitude  or p.lat
        local lo = p.longitude or p.lon
        if la and lo then
            if la < minLat then minLat = la end
            if la > maxLat then maxLat = la end
            if lo < minLon then minLon = lo end
            if lo > maxLon then maxLon = lo end
        end
    end

    local lat = minLat + math.random() * (maxLat - minLat)
    local lon = minLon + math.random() * (maxLon - minLon)
    return lat, lon
end

-- ============================================================
-- TABLE UTILITIES
-- ============================================================

--- Pretty-print a table for debugging. Returns a formatted string.
--- Nested tables are indented. Non-table values are tostring'd.
---
--- @param t     any     Value to print
--- @param indent number  Current indent level (default 0)
--- @return string
function Utils.table_print(t, indent)
    indent = indent or 0
    local pad = string.rep('  ', indent)
    if type(t) ~= 'table' then
        return tostring(t)
    end
    local lines = { '{' }
    -- Sort keys for deterministic output
    local keys = {}
    for k in pairs(t) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    for _, k in ipairs(keys) do
        local v = t[k]
        local key = type(k) == 'string' and (k .. ' = ') or ('[' .. tostring(k) .. '] = ')
        if type(v) == 'table' then
            lines[#lines + 1] = pad .. '  ' .. key .. Utils.table_print(v, indent + 1) .. ','
        else
            lines[#lines + 1] = pad .. '  ' .. key .. tostring(v) .. ','
        end
    end
    lines[#lines + 1] = pad .. '}'
    return table.concat(lines, '\n')
end

--- Deep-copy a table (handles nested tables; does not copy metatables).
---
--- @param orig any  Value to copy
--- @return any      Deep copy
function Utils.table_copy(orig)
    if type(orig) ~= 'table' then return orig end
    local copy = {}
    for k, v in pairs(orig) do
        copy[Utils.table_copy(k)] = Utils.table_copy(v)
    end
    return copy
end

--- Merge src table into dst in-place (shallow). Returns dst.
---
--- @param dst table
--- @param src table
--- @return table  dst with src keys merged in
function Utils.table_merge(dst, src)
    if type(src) ~= 'table' then return dst end
    for k, v in pairs(src) do
        dst[k] = v
    end
    return dst
end

--- Check if a value is in a table (linear scan).
---
--- @param t     table
--- @param value any
--- @return boolean
function Utils.table_contains(t, value)
    for _, v in ipairs(t) do
        if v == value then return true end
    end
    return false
end

-- ============================================================
-- STRING UTILITIES
-- ============================================================

--- Split a string by a separator pattern. Returns an array of parts.
---
--- @param str string   Input string
--- @param sep string   Separator pattern (default '%s+')
--- @return table       Array of string parts
function Utils.split(str, sep)
    sep = sep or '%s+'
    local parts = {}
    local pattern = '(.-)' .. sep
    local last = 1
    for part, pos in str:gmatch('()' .. pattern .. '()') do
        parts[#parts + 1] = part
        last = pos
    end
    parts[#parts + 1] = str:sub(last)
    return parts
end

--- Trim leading and trailing whitespace from a string.
---
--- @param s string
--- @return string
function Utils.trim(s)
    return (s:gsub('^%s+', ''):gsub('%s+$', ''))
end

--- Check if a string starts with a given prefix.
---
--- @param s      string
--- @param prefix string
--- @return boolean
function Utils.startsWith(s, prefix)
    return s:sub(1, #prefix) == prefix
end

--- Check if a string ends with a given suffix.
---
--- @param s      string
--- @param suffix string
--- @return boolean
function Utils.endsWith(s, suffix)
    return suffix == '' or s:sub(-#suffix) == suffix
end

-- ============================================================
-- TIME UTILITIES
-- ============================================================

--- Format a scenario timestamp using os.date.
--- Uses UTC by default (prefix '!').
---
--- @param fmt     string          os.date format string (default '%Y-%m-%d %H:%M:%S')
--- @param timeVar number|nil      Unix timestamp; defaults to ScenEdit_CurrentTime()
--- @return string
function Utils.formatTime(fmt, timeVar)
    fmt = fmt or '!%Y-%m-%d %H:%M:%S'
    if timeVar == nil then
        local ok, t = pcall(ScenEdit_CurrentTime)
        timeVar = ok and t or os.time()
    end
    return os.date(fmt, timeVar)
end

--- Format a Unix timestamp as a DTG (Date-Time Group) string.
--- Format: "DDHHMMZ MON YY"  e.g. "211430Z MAR 26"
---
--- @param timeVar number|nil  Unix timestamp; defaults to ScenEdit_CurrentTime()
--- @return string
function Utils.DTG(timeVar)
    if timeVar == nil then
        local ok, t = pcall(ScenEdit_CurrentTime)
        timeVar = ok and t or os.time()
    end
    return string.upper(os.date('!%d%H%MZ %b %y', timeVar))
end

--- Return elapsed seconds since a reference timestamp.
---
--- @param refTime number  Unix timestamp baseline
--- @return number  Seconds elapsed
function Utils.elapsed(refTime)
    local ok, now = pcall(ScenEdit_CurrentTime)
    if not ok then now = os.time() end
    return now - (refTime or now)
end

-- ============================================================
-- MATH / MISC UTILITIES
-- ============================================================

--- Clamp a value between min and max.
---
--- @param v   number
--- @param min number
--- @param max number
--- @return number
function Utils.clamp(v, min, max)
    if v < min then return min end
    if v > max then return max end
    return v
end

--- Linear interpolation between a and b by factor t (0..1).
---
--- @param a number
--- @param b number
--- @param t number  0=a, 1=b
--- @return number
function Utils.lerp(a, b, t)
    return a + (b - a) * Utils.clamp(t, 0, 1)
end

--- Round a number to a given number of decimal places (default 0).
---
--- @param n      number
--- @param places number  (default 0)
--- @return number
function Utils.round(n, places)
    places = places or 0
    local m = 10 ^ places
    return math.floor(n * m + 0.5) / m
end

--- Generate a random float in [min, max].
---
--- @param min number
--- @param max number
--- @return number
function Utils.randomFloat(min, max)
    return min + math.random() * (max - min)
end

return Utils
