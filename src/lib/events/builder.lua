--- CMO Lua Event Builder Library
--- Programmatic creation of Events, Triggers, Conditions, and Actions (TCA system).
---
--- @module events.builder
---
--- The CMO event system uses Trigger → Condition → Action (TCA) chains.
--- Each event has: one or more triggers, optional conditions, one or more actions.
---
--- KEY FUNCTIONS:
---   ScenEdit_AddEvent(name, options)
---   ScenEdit_AddTrigger(params)
---   ScenEdit_AddCondition(params)
---   ScenEdit_AddAction(params)
---   ScenEdit_SetTriggerParamAction(...)   -- link trigger to action
---   ScenEdit_AddTCAtoEvent(eventname, tcatype, tcaname) -- wire TCA to event
---
--- USAGE EXAMPLE:
---   local EB = dofile('path/to/lib/events/builder.lua')
---
---   -- Fire a Lua script 60 seconds from now
---   EB.createTimedEvent('Phase2Start', ScenEdit_CurrentTime() + 60,
---       [[ScenEdit_SpecialMessage('USA', 'Phase 2 begins!')]])
---
---   -- Fire a repeating event every 300 seconds
---   EB.createRepeatingEvent('Reinforcement', 300,
---       [[-- spawn units here]])
---
---   -- Fire when a unit enters an area
---   EB.createUnitEntersAreaEvent('EnemyDetected', 'OPFOR', {'Z1','Z2','Z3','Z4'},
---       [[ScenEdit_SpecialMessage('USA', 'Enemy crossed the line!')]])

local EB = {}

-- ============================================================
-- INTERNAL: WIRE TCA TO EVENT
-- ============================================================

--- Attach a trigger, condition, or action to an event.
--- tcaType: 'trigger' | 'condition' | 'action'
---
--- @param eventName string
--- @param tcaType   string  'trigger'|'condition'|'action'
--- @param tcaName   string
--- @return boolean
local function addTCA(eventName, tcaType, tcaName)
    local ok, err = pcall(ScenEdit_AddTCAtoEvent, eventName, tcaType, tcaName)
    if not ok then
        print('[EventBuilder] addTCA error (' .. tcaType .. '=' .. tcaName .. '): ' .. tostring(err))
        return false
    end
    return true
end

-- ============================================================
-- LOW-LEVEL PRIMITIVES
-- ============================================================

--- Create an event with the given name and options.
---
--- @param name    string
--- @param options table|nil  {isActive=bool, isRepeatable=bool, probability=number}
--- @return boolean, Event|nil
function EB.createEvent(name, options)
    options = options or {}
    local ok, ev = pcall(ScenEdit_AddEvent, name, {
        isActive     = options.isActive     ~= false,
        isRepeatable = options.isRepeatable ~= false,
        probability  = options.probability  or 100,
    })
    if not ok or not ev then
        print('[EventBuilder] createEvent failed: ' .. tostring(ev))
        return false, nil
    end
    return true, ev
end

--- Create a trigger and attach it to an event.
---
--- @param eventName   string
--- @param triggerName string
--- @param params      table   Trigger-type-specific parameters
--- @return boolean
---
--- Common param structures:
---   Time trigger: {type='Time', time=unixTimestamp}
---   RegularTime: {type='RegularTime', interval=seconds}
---   UnitEntersArea: {type='UnitEntersArea', unittype='...', area={rp names}}
---   UnitDestroyed: {type='UnitDestroyed', unit='guid'}
function EB.addTrigger(eventName, triggerName, params)
    local p = { name=triggerName }
    for k, v in pairs(params) do p[k] = v end

    local ok, err = pcall(ScenEdit_AddTrigger, p)
    if not ok then
        print('[EventBuilder] addTrigger error: ' .. tostring(err))
        return false
    end
    return addTCA(eventName, 'trigger', triggerName)
end

--- Create a condition and attach it to an event.
---
--- @param eventName     string
--- @param conditionName string
--- @param params        table   Condition parameters
--- @return boolean
function EB.addCondition(eventName, conditionName, params)
    local p = { name=conditionName }
    for k, v in pairs(params) do p[k] = v end

    local ok, err = pcall(ScenEdit_AddCondition, p)
    if not ok then
        print('[EventBuilder] addCondition error: ' .. tostring(err))
        return false
    end
    return addTCA(eventName, 'condition', conditionName)
end

--- Create a Lua script action and attach it to an event.
---
--- @param eventName  string
--- @param actionName string
--- @param luaScript  string  Lua code to execute when the event fires
--- @return boolean
function EB.addLuaAction(eventName, actionName, luaScript)
    local ok, err = pcall(ScenEdit_AddAction, {
        name       = actionName,
        type       = 'LuaScript',
        ScriptText = luaScript,
    })
    if not ok then
        print('[EventBuilder] addLuaAction error: ' .. tostring(err))
        return false
    end
    return addTCA(eventName, 'action', actionName)
end

--- Create a message action and attach it to an event.
---
--- @param eventName  string
--- @param actionName string
--- @param message    string  Message text
--- @param side       string  Side name/GUID to receive the message
--- @return boolean
function EB.addMessageAction(eventName, actionName, message, side)
    local ok, err = pcall(ScenEdit_AddAction, {
        name    = actionName,
        type    = 'Message',
        message = message,
        side    = side,
    })
    if not ok then
        print('[EventBuilder] addMessageAction error: ' .. tostring(err))
        return false
    end
    return addTCA(eventName, 'action', actionName)
end

--- Create a score change action and attach it to an event.
---
--- @param eventName  string
--- @param actionName string
--- @param side       string  Side name/GUID
--- @param delta      number  Score change (positive=add, negative=subtract)
--- @return boolean
function EB.addScoreAction(eventName, actionName, side, delta)
    local ok, err = pcall(ScenEdit_AddAction, {
        name   = actionName,
        type   = 'Points',
        side   = side,
        points = delta,
    })
    if not ok then
        print('[EventBuilder] addScoreAction error: ' .. tostring(err))
        return false
    end
    return addTCA(eventName, 'action', actionName)
end

-- ============================================================
-- HIGH-LEVEL: TIMED EVENT
-- ============================================================

--- Create a complete timed event that fires at a specific scenario time.
---
--- @param name       string  Event name (must be unique)
--- @param triggerTime number  Unix timestamp when the event fires
--- @param luaScript  string  Lua code to execute
--- @param isRepeatable boolean (default false)
--- @return boolean
---
--- EXAMPLE:
---   EB.createTimedEvent('Phase2', ScenEdit_CurrentTime() + 3600,
---       [[ScenEdit_SpecialMessage('USA', 'Phase 2 begins')]])
function EB.createTimedEvent(name, triggerTime, luaScript, isRepeatable)
    local ok, _ = EB.createEvent(name, {
        isActive     = true,
        isRepeatable = isRepeatable or false,
    })
    if not ok then return false end

    local trigName  = name .. '_TimeTrigger'
    local actName   = name .. '_LuaAction'

    EB.addTrigger(name, trigName, {
        type = 'Time',
        time = triggerTime,
    })
    EB.addLuaAction(name, actName, luaScript)
    return true
end

-- ============================================================
-- HIGH-LEVEL: REPEATING EVENT
-- ============================================================

--- Create a repeating event that fires every N seconds.
---
--- @param name       string
--- @param intervalSec number  Seconds between firings
--- @param luaScript  string
--- @return boolean
---
--- EXAMPLE:
---   EB.createRepeatingEvent('ForceMorale', 600, [[-- morale logic]])
function EB.createRepeatingEvent(name, intervalSec, luaScript)
    local ok, _ = EB.createEvent(name, {
        isActive     = true,
        isRepeatable = true,
    })
    if not ok then return false end

    local trigName = name .. '_RegularTrigger'
    local actName  = name .. '_LuaAction'

    EB.addTrigger(name, trigName, {
        type     = 'RegularTime',
        interval = intervalSec,
    })
    EB.addLuaAction(name, actName, luaScript)
    return true
end

-- ============================================================
-- HIGH-LEVEL: UNIT-ENTERS-AREA EVENT
-- ============================================================

--- Create an event that fires when any unit of a given side enters an area.
---
--- @param name      string
--- @param unitSide  string     Side whose units trigger this (e.g., 'OPFOR')
--- @param rpNames   table      Array of reference point names defining the area polygon
--- @param luaScript string
--- @param unitType  string|nil 'Aircraft'|'Ship'|'Submarine'|nil=any
--- @return boolean
---
--- EXAMPLE:
---   EB.createUnitEntersAreaEvent('EnemyInZone','OPFOR',{'Z1','Z2','Z3','Z4'},
---       [[ScenEdit_SpecialMessage('USA','Contact!')]])
function EB.createUnitEntersAreaEvent(name, unitSide, rpNames, luaScript, unitType)
    local ok, _ = EB.createEvent(name, { isActive=true, isRepeatable=true })
    if not ok then return false end

    local trigName = name .. '_AreaTrigger'
    local actName  = name .. '_LuaAction'

    EB.addTrigger(name, trigName, {
        type     = 'UnitEntersArea',
        unitSide = unitSide,
        unitType = unitType,
        area     = rpNames,
    })
    EB.addLuaAction(name, actName, luaScript)
    return true
end

-- ============================================================
-- HIGH-LEVEL: UNIT-DESTROYED EVENT
-- ============================================================

--- Create an event that fires when a specific unit is destroyed.
---
--- @param name      string
--- @param unitGuid  string   GUID of the unit to watch
--- @param luaScript string
--- @return boolean
---
--- EXAMPLE:
---   EB.createUnitDestroyedEvent('CarrierLost', 'carrier-guid',
---       [[ScenEdit_EndScenario()]])
function EB.createUnitDestroyedEvent(name, unitGuid, luaScript)
    local ok, _ = EB.createEvent(name, { isActive=true, isRepeatable=false })
    if not ok then return false end

    local trigName = name .. '_DestroyedTrigger'
    local actName  = name .. '_LuaAction'

    EB.addTrigger(name, trigName, {
        type = 'UnitDestroyed',
        unit = unitGuid,
    })
    EB.addLuaAction(name, actName, luaScript)
    return true
end

-- ============================================================
-- HIGH-LEVEL: LUA CONDITION EVENT
-- ============================================================

--- Create an event with a Lua condition gate.
--- The event fires when its trigger activates AND the Lua condition returns true.
---
--- @param name           string
--- @param triggerParams  table     Trigger parameters (passed to addTrigger)
--- @param conditionScript string   Lua code returning true/false
--- @param actionScript   string    Lua code executed when condition passes
--- @return boolean
---
--- EXAMPLE:
---   EB.createLuaConditionEvent('NightAttack',
---       {type='RegularTime', interval=60},
---       [[return ScenEdit_GetTimeOfDay() == 'Night']],
---       [[-- do night attack]])
function EB.createLuaConditionEvent(name, triggerParams, conditionScript, actionScript)
    local ok, _ = EB.createEvent(name, { isActive=true, isRepeatable=true })
    if not ok then return false end

    local trigName = name .. '_Trigger'
    local condName = name .. '_Condition'
    local actName  = name .. '_Action'

    EB.addTrigger(name, trigName, triggerParams)
    EB.addCondition(name, condName, {
        type       = 'LuaScript',
        ScriptText = conditionScript,
    })
    EB.addLuaAction(name, actName, actionScript)
    return true
end

-- ============================================================
-- HIGH-LEVEL: SCORE-THRESHOLD EVENT
-- ============================================================

--- Create an event that fires when a side's score crosses a threshold.
---
--- @param name      string
--- @param side      string
--- @param threshold number   Score value that triggers the event
--- @param above     boolean  true=fires when score >= threshold, false=when <=
--- @param luaScript string
--- @return boolean
function EB.createScoreThresholdEvent(name, side, threshold, above, luaScript)
    return EB.createLuaConditionEvent(
        name,
        { type='RegularTime', interval=60 },
        string.format([[
            local score = ScenEdit_GetScore('%s')
            return %s
        ]], side,
            above and ('score >= ' .. tostring(threshold))
                   or ('score <= ' .. tostring(threshold))),
        luaScript
    )
end

return EB
