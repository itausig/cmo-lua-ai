--- CMO Lua Event Triggers Library
--- Reusable trigger pattern builders for common scenario logic.
---
--- @module events.triggers
---
--- These helpers are meant to complement events/builder.lua with
--- higher-level, named patterns. They all return parameter tables that
--- can be passed directly to ScenEdit_AddTrigger or EB.addTrigger.
---
--- USAGE EXAMPLE:
---   local T   = dofile('path/to/lib/events/triggers.lua')
---   local EB  = dofile('path/to/lib/events/builder.lua')
---
---   -- Time-delay trigger 2 hours from now
---   local trigParams = T.timeDelay(7200)
---   EB.addTrigger('MyEvent', 'MyEvent_Trigger', trigParams)
---
---   -- Detection trigger for submarine contacts
---   local detParams = T.detectionByType('Submarine', 'OPFOR', 'USA')
---   EB.createEvent('SubDetected', {isActive=true, isRepeatable=true})
---   EB.addTrigger('SubDetected', 'SubDetected_Trigger', detParams)
---   EB.addLuaAction('SubDetected', 'SubDetected_Action', [[print('Sub detected!')]])

local T = {}

-- ============================================================
-- TIME TRIGGERS
-- ============================================================

--- Build a one-shot trigger that fires at a specific absolute Unix timestamp.
---
--- @param unixTime number  Absolute scenario time (Unix seconds)
--- @return table  Trigger params for ScenEdit_AddTrigger
function T.absoluteTime(unixTime)
    return {
        type = 'Time',
        time = unixTime,
    }
end

--- Build a time-delay trigger that fires N seconds after the current scenario time.
--- Captures the current time at call time; call during scenario setup.
---
--- @param delaySec number  Seconds from now to fire
--- @return table  Trigger params
---
--- EXAMPLE:
---   -- Fire 1 hour from scenario start
---   local trig = T.timeDelay(3600)
function T.timeDelay(delaySec)
    local ok, now = pcall(ScenEdit_CurrentTime)
    local t = (ok and now or os.time()) + (delaySec or 0)
    return {
        type = 'Time',
        time = t,
    }
end

--- Build a repeating (regular interval) trigger.
---
--- @param intervalSec number  Seconds between firings
--- @return table  Trigger params
---
--- EXAMPLE:
---   -- Check every 5 minutes
---   local trig = T.repeating(300)
function T.repeating(intervalSec)
    return {
        type     = 'RegularTime',
        interval = intervalSec or 60,
    }
end

--- Build a trigger with a random time window.
--- Fires once, at a random time between minDelay and maxDelay seconds from now.
---
--- @param minDelaySec number  Minimum delay in seconds
--- @param maxDelaySec number  Maximum delay in seconds
--- @return table  Trigger params
function T.randomTimeWindow(minDelaySec, maxDelaySec)
    local ok, now = pcall(ScenEdit_CurrentTime)
    local base  = ok and now or os.time()
    local range = (maxDelaySec or 600) - (minDelaySec or 0)
    local delay = (minDelaySec or 0) + math.floor(math.random() * range)
    return {
        type = 'Time',
        time = base + delay,
    }
end

-- ============================================================
-- AREA TRIGGERS
-- ============================================================

--- Build a trigger that fires when a unit from the given side enters the area.
---
--- @param unitSide  string        Side whose units trigger this
--- @param rpNames   table         Reference point names forming the polygon
--- @param unitType  string|nil    'Aircraft'|'Ship'|'Submarine'|nil=any
--- @return table  Trigger params
---
--- EXAMPLE:
---   local trig = T.unitEntersArea('OPFOR', {'Z1','Z2','Z3','Z4'}, 'Ship')
function T.unitEntersArea(unitSide, rpNames, unitType)
    return {
        type     = 'UnitEntersArea',
        unitSide = unitSide,
        unitType = unitType,
        area     = rpNames,
    }
end

--- Build a compound area trigger using a Lua condition to confirm
--- the unit has remained in the area for at least minDwellSec seconds.
---
--- This returns both trigger params AND a condition script string,
--- since CMO doesn't have a native "dwell" trigger type.
---
--- @param unitSide    string
--- @param rpNames     table
--- @param minDwellSec number  Minimum seconds the unit must be inside (approx)
--- @param side        string  Observer side that owns the reference points
--- @return table, string  triggerParams, conditionLuaScript
---
--- EXAMPLE:
---   local trig, cond = T.unitDwellArea('OPFOR', {'Z1','Z2','Z3'}, 120, 'USA')
function T.unitDwellArea(unitSide, rpNames, minDwellSec, side)
    local rp_list = table.concat(rpNames, "','")
    local trigger = T.unitEntersArea(unitSide, rpNames)
    local condition = string.format([[
        -- Dwell check: unit must have been in area for at least %d seconds
        local u = ScenEdit_UnitX()
        if not u then return false end
        local entryKey = 'dwell_entry_' .. u.guid
        local entryTime = tonumber(ScenEdit_GetKeyValue(entryKey)) or 0
        if entryTime == 0 then
            ScenEdit_SetKeyValue(entryKey, tostring(ScenEdit_CurrentTime()))
            return false
        end
        local age = ScenEdit_CurrentTime() - entryTime
        if age >= %d then
            ScenEdit_SetKeyValue(entryKey, '')  -- reset
            return true
        end
        return false
    ]], minDwellSec, minDwellSec)
    return trigger, condition
end

-- ============================================================
-- UNIT STATE TRIGGERS
-- ============================================================

--- Build a trigger for when a specific unit is destroyed.
---
--- @param unitGuid string  GUID of the unit to watch
--- @return table  Trigger params
function T.unitDestroyed(unitGuid)
    return {
        type = 'UnitDestroyed',
        unit = unitGuid,
    }
end

--- Build a trigger for when a unit is damaged.
---
--- @param unitGuid string
--- @return table  Trigger params
function T.unitDamaged(unitGuid)
    return {
        type = 'UnitDamaged',
        unit = unitGuid,
    }
end

--- Build a trigger for when a unit is detected.
---
--- @param detectedSide  string  Side of the unit being detected
--- @param detectorSide  string  Side doing the detecting
--- @param unitType      string|nil
--- @return table  Trigger params
function T.unitDetected(detectedSide, detectorSide, unitType)
    return {
        type          = 'UnitDetected',
        unitSide      = detectedSide,
        detectingSide = detectorSide,
        unitType      = unitType,
    }
end

-- ============================================================
-- DETECTION TRIGGERS BY CLASS
-- ============================================================

--- Build a detection trigger for a specific unit class/type.
--- Useful for alerting when a particular threat type is spotted.
---
--- @param unitType      string  'Aircraft'|'Ship'|'Submarine'|'Facility'
--- @param detectedSide  string  Side of the detected units
--- @param detectorSide  string  Side doing the detecting
--- @return table  Trigger params
---
--- EXAMPLE:
---   -- Alert USA when OPFOR aircraft are detected
---   local trig = T.detectionByType('Aircraft', 'OPFOR', 'USA')
function T.detectionByType(unitType, detectedSide, detectorSide)
    return {
        type          = 'UnitDetected',
        unitSide      = detectedSide,
        detectingSide = detectorSide,
        unitType      = unitType,
    }
end

-- ============================================================
-- SCORE TRIGGER
-- ============================================================

--- Build a condition script that evaluates whether a side's score
--- meets a threshold. Used with a repeating trigger.
---
--- @param sideName  string
--- @param threshold number
--- @param above     boolean  true = score >= threshold; false = score <= threshold
--- @return string  Lua condition script
function T.scoreThreshold(sideName, threshold, above)
    if above then
        return string.format([[
            return ScenEdit_GetScore('%s') >= %d
        ]], sideName, threshold)
    else
        return string.format([[
            return ScenEdit_GetScore('%s') <= %d
        ]], sideName, threshold)
    end
end

-- ============================================================
-- SPECIAL ACTION TRIGGER
-- ============================================================

--- Build a trigger that fires when a Special Action is executed by the player.
---
--- @param specialActionName string  Name of the special action
--- @return table  Trigger params
function T.specialAction(specialActionName)
    return {
        type   = 'SpecialAction',
        action = specialActionName,
    }
end

-- ============================================================
-- SCENARIO-STARTED TRIGGER
-- ============================================================

--- Build a trigger that fires once when the scenario starts (at t+0).
---
--- @return table  Trigger params
function T.scenarioStart()
    local ok, now = pcall(ScenEdit_CurrentTime)
    return {
        type = 'Time',
        time = (ok and now or os.time()) + 1,   -- 1 second after current time
    }
end

return T
