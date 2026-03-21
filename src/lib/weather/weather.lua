--- CMO Lua Weather Library
--- Weather queries, setting, random generation, deterioration, flight ops checks.
---
--- @module weather.weather
---
--- CMO weather fields:
---   temperature : number   Celsius (-30 to 50)
---   rainfall    : number   0.0 (none) to 1.0 (torrential)
---   clouds      : number   0.0 (clear) to 1.0 (overcast)
---   seastate    : number   Beaufort scale 0–9
---
--- USAGE EXAMPLE:
---   local Weather = dofile('path/to/lib/weather/weather.lua')
---
---   -- Get current conditions
---   local wx = Weather.get()
---   print(Weather.describe(wx))
---
---   -- Set storm conditions
---   Weather.setStorm()
---
---   -- Check if flight ops are safe
---   if Weather.flightOpsSafe(wx) then
---       -- launch sorties
---   end
---
---   -- Deteriorate weather gradually over 10 minutes
---   Weather.deteriorate(600)

local Weather = {}

-- ============================================================
-- BEAUFORT SCALE DESCRIPTIONS
-- ============================================================

--- Beaufort scale descriptions (0–12).
Weather.BEAUFORT = {
    [0]  = 'Calm',
    [1]  = 'Light Air',
    [2]  = 'Light Breeze',
    [3]  = 'Gentle Breeze',
    [4]  = 'Moderate Breeze',
    [5]  = 'Fresh Breeze',
    [6]  = 'Strong Breeze',
    [7]  = 'Near Gale',
    [8]  = 'Gale',
    [9]  = 'Strong Gale',
    [10] = 'Storm',
    [11] = 'Violent Storm',
    [12] = 'Hurricane',
}

--- Wave height approximations by Beaufort number (meters).
Weather.WAVE_HEIGHT = {
    [0]=0, [1]=0.1, [2]=0.2, [3]=0.6, [4]=1.0,
    [5]=2.0, [6]=3.0, [7]=4.0, [8]=5.5, [9]=7.0,
}

-- ============================================================
-- GET / SET WEATHER
-- ============================================================

--- Get current global weather settings.
---
--- @return table  {temperature, rainfall, clouds, seastate} or defaults on error
function Weather.get()
    local ok, wx = pcall(ScenEdit_GetWeather)
    if ok and wx then return wx end
    -- Safe defaults if unavailable
    return { temperature=15, rainfall=0, clouds=0.2, seastate=2 }
end

--- Set global weather.
---
--- @param params table
---   {
---     temperature = number,   -- Celsius
---     rainfall    = number,   -- 0.0–1.0
---     clouds      = number,   -- 0.0–1.0
---     seastate    = number,   -- Beaufort 0–9
---   }
--- @return boolean
function Weather.set(params)
    if type(params) ~= 'table' then return false end

    -- Clamp values to valid ranges
    local wx = {
        temperature = math.max(-30, math.min(50,  tonumber(params.temperature) or 15)),
        rainfall    = math.max(0,   math.min(1.0, tonumber(params.rainfall)    or 0)),
        clouds      = math.max(0,   math.min(1.0, tonumber(params.clouds)      or 0.2)),
        seastate    = math.max(0,   math.min(9,   math.floor(tonumber(params.seastate) or 2))),
    }

    local ok, err = pcall(ScenEdit_SetWeather, wx)
    if not ok then
        print('[Weather] set error: ' .. tostring(err))
        return false
    end
    return true
end

-- ============================================================
-- PRESET CONDITIONS
-- ============================================================

--- Set clear/calm weather.
--- @return boolean
function Weather.setClear()
    return Weather.set({ temperature=22, rainfall=0, clouds=0.05, seastate=1 })
end

--- Set moderate weather (typical operating conditions).
--- @return boolean
function Weather.setModerate()
    return Weather.set({ temperature=16, rainfall=0.1, clouds=0.4, seastate=3 })
end

--- Set storm conditions (heavy weather, restricted operations).
--- @return boolean
function Weather.setStorm()
    return Weather.set({ temperature=10, rainfall=0.7, clouds=0.95, seastate=7 })
end

--- Set fog/low-visibility conditions.
--- @return boolean
function Weather.setFog()
    return Weather.set({ temperature=12, rainfall=0.2, clouds=0.9, seastate=1 })
end

--- Set tropical storm conditions.
--- @return boolean
function Weather.setTropicalStorm()
    return Weather.set({ temperature=28, rainfall=0.9, clouds=1.0, seastate=9 })
end

--- Set Arctic winter conditions.
--- @return boolean
function Weather.setArctic()
    return Weather.set({ temperature=-20, rainfall=0.3, clouds=0.7, seastate=5 })
end

-- ============================================================
-- RANDOM WEATHER
-- ============================================================

--- Generate a random weather state within realistic bounds.
---
--- @param severity string|nil  'calm'|'moderate'|'rough'|'storm' (default 'moderate')
--- @return table  Weather params table (also applied to scenario)
---
--- EXAMPLE:
---   local wx = Weather.randomize('rough')
---   print(Weather.describe(wx))
function Weather.randomize(severity)
    severity = severity or 'moderate'

    local presets = {
        calm     = { tempMin=-5,  tempMax=30, rainMax=0.1, cloudMax=0.3, ssMax=2 },
        moderate = { tempMin=5,   tempMax=28, rainMax=0.4, cloudMax=0.6, ssMax=4 },
        rough    = { tempMin=5,   tempMax=20, rainMax=0.6, cloudMax=0.8, ssMax=6 },
        storm    = { tempMin=0,   tempMax=18, rainMax=0.9, cloudMax=1.0, ssMax=9 },
    }
    local p = presets[severity] or presets.moderate

    local wx = {
        temperature = p.tempMin  + math.random() * (p.tempMax  - p.tempMin),
        rainfall    = math.random() * p.rainMax,
        clouds      = math.random() * p.cloudMax,
        seastate    = math.random(0, p.ssMax),
    }
    wx.temperature = math.floor(wx.temperature + 0.5)
    wx.rainfall    = math.floor(wx.rainfall    * 100 + 0.5) / 100
    wx.clouds      = math.floor(wx.clouds      * 100 + 0.5) / 100

    Weather.set(wx)
    return wx
end

-- ============================================================
-- GRADUAL CHANGE
-- ============================================================

--- Schedule a gradual weather deterioration over time using a timed event.
--- This function sets progressively worse weather at each call.
--- Call from a repeating event to simulate a moving weather system.
---
--- @param targetSeastate number   Target Beaufort sea state (max 9)
--- @param durationSteps  number   Number of incremental steps
--- @return boolean
---
--- EXAMPLE:
---   -- Called from a repeating event every 300 seconds:
---   Weather.deteriorate(8, 6)   -- Move to SS8 over 6 steps
function Weather.deteriorate(targetSeastate, durationSteps)
    local wx      = Weather.get()
    local current = wx.seastate
    local target  = math.min(9, math.max(0, targetSeastate or 7))
    local steps   = durationSteps or 5

    if current >= target then return true end   -- Already at target

    local step    = math.ceil((target - current) / steps)
    local newSS   = math.min(target, current + step)

    -- Also increase clouds and rainfall proportionally
    local ratio   = (target > 0) and (newSS / target) or 0
    local newRain = math.min(1.0, wx.rainfall  + 0.1 * ratio)
    local newCloud = math.min(1.0, wx.clouds   + 0.1 * ratio)
    local newTemp  = wx.temperature - (step * 0.5)  -- slight cooling

    return Weather.set({
        temperature = newTemp,
        rainfall    = newRain,
        clouds      = newCloud,
        seastate    = newSS,
    })
end

--- Schedule a gradual weather improvement.
---
--- @param targetSeastate number  Target sea state to improve toward
--- @param durationSteps  number
--- @return boolean
function Weather.improve(targetSeastate, durationSteps)
    local wx      = Weather.get()
    local current = wx.seastate
    local target  = math.max(0, math.min(9, targetSeastate or 2))
    local steps   = durationSteps or 5

    if current <= target then return true end

    local step     = math.ceil((current - target) / steps)
    local newSS    = math.max(target, current - step)
    local ratio    = (current > 0) and (newSS / current) or 0
    local newRain  = math.max(0, wx.rainfall  - 0.1)
    local newCloud = math.max(0, wx.clouds    - 0.1)
    local newTemp  = math.min(30, wx.temperature + 0.5)

    return Weather.set({
        temperature = newTemp,
        rainfall    = newRain,
        clouds      = newCloud,
        seastate    = newSS,
    })
end

-- ============================================================
-- DESCRIPTION & FLIGHT OPS
-- ============================================================

--- Get a human-readable weather description string.
---
--- @param wx table|nil  Weather table; if nil, reads current weather
--- @return string
function Weather.describe(wx)
    wx = wx or Weather.get()
    local ss      = math.floor(wx.seastate or 0)
    local ssDesc  = Weather.BEAUFORT[ss] or ('Sea State ' .. ss)
    local rainStr = wx.rainfall >= 0.7 and 'Heavy Rain'
                 or wx.rainfall >= 0.3 and 'Moderate Rain'
                 or wx.rainfall >= 0.1 and 'Light Rain'
                 or 'Dry'
    local skyStr  = wx.clouds >= 0.8 and 'Overcast'
                 or wx.clouds >= 0.5 and 'Cloudy'
                 or wx.clouds >= 0.2 and 'Partly Cloudy'
                 or 'Clear'
    return string.format(
        'Temp: %d°C | Sky: %s | %s | Sea: %s (SS %d)',
        math.floor(wx.temperature or 15),
        skyStr, rainStr, ssDesc, ss)
end

--- Check whether weather conditions allow routine flight operations.
--- Considers sea state (for carrier ops), ceiling, and precipitation.
---
--- @param wx           table|nil   Weather table (nil = current)
--- @param strictMode   boolean     true = carrier/deck ops thresholds (stricter)
--- @return boolean  true = flight ops safe
--- @return string   Reason string (empty if safe)
---
--- EXAMPLE:
---   local safe, reason = Weather.flightOpsSafe(nil, true)
---   if not safe then Msg.send('USA', 'Flight ops suspended: ' .. reason) end
function Weather.flightOpsSafe(wx, strictMode)
    wx = wx or Weather.get()
    local ss      = wx.seastate or 0
    local rain    = wx.rainfall or 0
    local clouds  = wx.clouds   or 0

    local maxSS   = strictMode and 4 or 6     -- Carrier SS4 limit, land-base SS6
    local maxRain = strictMode and 0.5 or 0.8
    local maxCloud = 0.95                      -- Near-zero visibility = no ops

    if ss >= maxSS then
        return false, string.format('Sea state %d exceeds limit (%d)', ss, maxSS)
    end
    if rain >= maxRain then
        return false, string.format('Rainfall %.0f%% exceeds limit', rain * 100)
    end
    if clouds >= maxCloud then
        return false, string.format('Overcast %.0f%% (zero-ceiling)', clouds * 100)
    end
    return true, ''
end

--- Get the forecast label: 'CAVOK'|'VFR'|'MVFR'|'IFR'|'LIFR'
--- Based on cloud coverage and precipitation.
---
--- @param wx table|nil
--- @return string  Visibility category
function Weather.visibility(wx)
    wx = wx or Weather.get()
    local clouds = wx.clouds   or 0
    local rain   = wx.rainfall or 0

    if clouds < 0.1 and rain < 0.05 then return 'CAVOK'  end
    if clouds < 0.3 and rain < 0.2  then return 'VFR'    end
    if clouds < 0.6 and rain < 0.5  then return 'MVFR'   end
    if clouds < 0.9                  then return 'IFR'    end
    return 'LIFR'
end

return Weather
