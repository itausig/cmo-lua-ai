--- CMO Lua Combat Damage Library
--- Damage assessment, tracking, and BDA (Battle Damage Assessment) reporting.
---
--- @module combat.damage
---
--- USAGE EXAMPLE:
---   local Damage = dofile('path/to/lib/combat/damage.lua')
---   local KS     = dofile('path/to/core/keystore.lua')
---
---   -- Get damage percentage for a unit
---   local dp = Damage.getDamagePercent('unit-guid')
---   print(string.format('Unit is %.0f%% damaged', dp))
---
---   -- Check if unit is still combat-effective (< 50% damage)
---   if Damage.isCombatEffective('unit-guid', 50) then
---       -- proceed with mission
---   end
---
---   -- Track a kill in the keystore
---   Damage.trackKill(KS, 'USA', 'F-15C Eagle')
---
---   -- Print a BDA report for the blue side
---   local report = Damage.bdaReport(KS, 'USA')
---   ScenEdit_SpecialMessage('USA', report)

local Damage = {}

-- ============================================================
-- DAMAGE QUERIES
-- ============================================================

--- Get the damage percentage of a unit (0 = undamaged, 100 = destroyed).
--- Uses unit.condition_v (0–100, 100 = fully intact) inverted to a 0–100 damage scale.
---
--- @param unitGuid string  GUID of the unit
--- @return number  Damage percentage (0–100), or -1 if unit not found
function Damage.getDamagePercent(unitGuid)
    local unit = ScenEdit_GetUnit({ guid = unitGuid })
    if not unit then return -1 end
    -- condition_v: 100 = undamaged, 0 = destroyed
    local cond = tonumber(unit.condition_v) or 100
    return 100 - cond
end

--- Get the condition value directly (0 = destroyed, 100 = intact).
---
--- @param unitGuid string
--- @return number  0–100, or -1 if unit not found
function Damage.getCondition(unitGuid)
    local unit = ScenEdit_GetUnit({ guid = unitGuid })
    if not unit then return -1 end
    return tonumber(unit.condition_v) or 100
end

--- Check whether a unit is destroyed.
---
--- @param unitGuid string
--- @return boolean  true if IsDestroyed == true or unit not found
function Damage.isDestroyed(unitGuid)
    local unit = ScenEdit_GetUnit({ guid = unitGuid })
    if not unit then return true end
    return unit.IsDestroyed == true
end

--- Check whether a unit is sinking (mortally damaged ship, not yet gone).
---
--- @param unitGuid string
--- @return boolean
function Damage.isSinking(unitGuid)
    local unit = ScenEdit_GetUnit({ guid = unitGuid })
    if not unit then return false end
    return unit.isSinking == true
end

--- Check whether a unit is still combat-effective.
--- A unit is effective when its damage percentage is below the threshold.
---
--- @param unitGuid  string   GUID of the unit
--- @param threshold number   Max damage % to still be effective (default 50)
--- @return boolean  true if damage < threshold and unit is not destroyed
function Damage.isCombatEffective(unitGuid, threshold)
    threshold = threshold or 50
    if Damage.isDestroyed(unitGuid) then return false end
    return Damage.getDamagePercent(unitGuid) < threshold
end

--- Get a human-readable damage state string.
---
--- @param unitGuid string
--- @return string  'Undamaged' | 'Light' | 'Moderate' | 'Heavy' | 'Critical' | 'Destroyed'
function Damage.getDamageState(unitGuid)
    local dp = Damage.getDamagePercent(unitGuid)
    if dp < 0   then return 'Unknown'   end
    if dp == 0  then return 'Undamaged' end
    if dp < 25  then return 'Light'     end
    if dp < 50  then return 'Moderate'  end
    if dp < 75  then return 'Heavy'     end
    if dp < 100 then return 'Critical'  end
    return 'Destroyed'
end

--- List damaged components on a unit.
--- Returns an array of {component, damage} tables from unit.damage.
---
--- @param unitGuid string
--- @return table  Array of component damage entries (may be empty)
function Damage.getDamagedComponents(unitGuid)
    local unit = ScenEdit_GetUnit({ guid = unitGuid })
    if not unit or not unit.damage then return {} end
    local result = {}
    local d = unit.damage
    if d.components then
        for _, comp in ipairs(d.components) do
            if comp.dp and comp.dp < 100 then
                result[#result + 1] = comp
            end
        end
    end
    return result
end

-- ============================================================
-- APPLY DAMAGE
-- ============================================================

--- Apply damage to a unit using ScenEdit_SetUnitDamage.
--- Only available in scenario editor context (not during gameplay events on some versions).
---
--- @param unitGuid  string  GUID of the unit
--- @param dp        number  Damage percentage to apply (0–100); this sets the damage level
--- @param killFirst boolean If true, also set specific components to killed state
--- @return boolean  true on success
---
--- EXAMPLE:
---   Damage.applyDamage('ship-guid', 40)   -- 40% structural damage
function Damage.applyDamage(unitGuid, dp, killFirst)
    if not unitGuid or dp == nil then
        print('[Damage] applyDamage: unitGuid and dp required')
        return false
    end

    dp = math.max(0, math.min(100, dp))

    local ok, err = pcall(ScenEdit_SetUnitDamage, {
        guid          = unitGuid,
        dp            = dp,
        fires         = (dp > 50),    -- fires at >50% damage
        flood         = false,
    })

    if not ok then
        print('[Damage] applyDamage failed: ' .. tostring(err))
        return false
    end
    return true
end

--- Destroy a unit directly by setting damage to 100%.
---
--- @param unitGuid string
--- @return boolean
function Damage.destroyUnit(unitGuid)
    return Damage.applyDamage(unitGuid, 100)
end

--- Repair a unit to full condition (0% damage).
---
--- @param unitGuid string
--- @return boolean
function Damage.repairUnit(unitGuid)
    local ok, err = pcall(ScenEdit_SetUnitDamage, { guid = unitGuid, dp = 0 })
    if not ok then
        print('[Damage] repairUnit failed: ' .. tostring(err))
        return false
    end
    return true
end

-- ============================================================
-- CUMULATIVE DAMAGE TRACKING (USES KEYSTORE)
-- ============================================================

--- Track cumulative damage across all units of a side.
--- Stores summary counters in the keystore.
---
--- Call periodically (e.g., in a timed event) to update the snapshot.
---
--- @param ks        table   Keystore module instance (KS)
--- @param sideName  string  Side name/GUID to survey
--- @return table  Summary: {total, destroyed, critical, heavy, moderate, light, ok}
function Damage.updateSideDamage(ks, sideName)
    local side = VP_GetSide({ Side = sideName })
    if not side then return {} end

    local summary = { total=0, destroyed=0, critical=0, heavy=0,
                      moderate=0, light=0, ok=0 }

    for _, unit in ipairs(side.units or {}) do
        summary.total = summary.total + 1
        local state = Damage.getDamageState(unit.guid)
        if     state == 'Destroyed' then summary.destroyed = summary.destroyed + 1
        elseif state == 'Critical'  then summary.critical  = summary.critical  + 1
        elseif state == 'Heavy'     then summary.heavy     = summary.heavy     + 1
        elseif state == 'Moderate'  then summary.moderate  = summary.moderate  + 1
        elseif state == 'Light'     then summary.light     = summary.light     + 1
        else                             summary.ok        = summary.ok        + 1
        end
    end

    -- Persist to keystore
    local pfx = 'bda.' .. sideName .. '.'
    for k, v in pairs(summary) do
        ks.setNumber(pfx .. k, v)
    end

    return summary
end

--- Retrieve the last stored damage summary from the keystore.
---
--- @param ks       table   Keystore module instance
--- @param sideName string
--- @return table  {total, destroyed, critical, heavy, moderate, light, ok}
function Damage.getSideDamage(ks, sideName)
    local pfx = 'bda.' .. sideName .. '.'
    return {
        total     = ks.getNumber(pfx .. 'total',     0),
        destroyed = ks.getNumber(pfx .. 'destroyed', 0),
        critical  = ks.getNumber(pfx .. 'critical',  0),
        heavy     = ks.getNumber(pfx .. 'heavy',     0),
        moderate  = ks.getNumber(pfx .. 'moderate',  0),
        light     = ks.getNumber(pfx .. 'light',     0),
        ok        = ks.getNumber(pfx .. 'ok',        0),
    }
end

-- ============================================================
-- KILL/LOSS TRACKING
-- ============================================================

--- Record a kill for a side in the keystore.
---
--- @param ks       table   Keystore module
--- @param sideName string  Side that scored the kill
--- @param unitType string  Type string of the killed unit (e.g. 'Aircraft')
function Damage.trackKill(ks, sideName, unitType)
    ks.increment('kills.' .. sideName .. '.total')
    if unitType then
        ks.increment('kills.' .. sideName .. '.' .. tostring(unitType))
    end
end

--- Record a loss for a side in the keystore.
---
--- @param ks       table
--- @param sideName string
--- @param unitType string
function Damage.trackLoss(ks, sideName, unitType)
    ks.increment('losses.' .. sideName .. '.total')
    if unitType then
        ks.increment('losses.' .. sideName .. '.' .. tostring(unitType))
    end
end

--- Get kill count for a side (optionally by unit type).
---
--- @param ks       table
--- @param sideName string
--- @param unitType string|nil  nil = total kills
--- @return number
function Damage.getKills(ks, sideName, unitType)
    local key = 'kills.' .. sideName .. '.' .. (unitType or 'total')
    return ks.getNumber(key, 0)
end

--- Get loss count for a side (optionally by unit type).
---
--- @param ks       table
--- @param sideName string
--- @param unitType string|nil
--- @return number
function Damage.getLosses(ks, sideName, unitType)
    local key = 'losses.' .. sideName .. '.' .. (unitType or 'total')
    return ks.getNumber(key, 0)
end

-- ============================================================
-- BDA REPORT GENERATOR
-- ============================================================

--- Generate a formatted Battle Damage Assessment (BDA) report for a side.
--- Performs a live survey of all units on the side.
---
--- @param sideName  string   Side name/GUID
--- @param ks        table|nil  Keystore instance (for kill/loss tallies); may be nil
--- @return string   Multi-line BDA report suitable for ScenEdit_SpecialMessage
---
--- EXAMPLE:
---   ScenEdit_SpecialMessage('USA', Damage.bdaReport('USA', KS))
function Damage.bdaReport(sideName, ks)
    local lines = {}
    local function add(s) lines[#lines + 1] = s end

    -- DTG header
    local ok_t, t = pcall(ScenEdit_CurrentTime)
    local dtg = string.upper(os.date('!%d%H%MZ %b %y', ok_t and t or os.time()))

    add('=== BDA REPORT ===')
    add(dtg)
    add('SIDE: ' .. tostring(sideName))
    add('')

    local side = VP_GetSide({ Side = sideName })
    if not side then
        add('ERROR: Side not found.')
        return table.concat(lines, '\n')
    end

    local counts = { total=0, ok=0, light=0, moderate=0, heavy=0, critical=0, destroyed=0 }
    local destroyed_names = {}

    for _, unit in ipairs(side.units or {}) do
        counts.total = counts.total + 1
        local state = Damage.getDamageState(unit.guid)
        local sk = state:lower()
        if counts[sk] then counts[sk] = counts[sk] + 1 end
        if state == 'Destroyed' then
            destroyed_names[#destroyed_names + 1] = unit.name
        end
    end

    add(string.format('UNITS TOTAL   : %d', counts.total))
    add(string.format('  Operational : %d', counts.ok))
    add(string.format('  Light Dmg   : %d', counts.light))
    add(string.format('  Moderate    : %d', counts.moderate))
    add(string.format('  Heavy       : %d', counts.heavy))
    add(string.format('  Critical    : %d', counts.critical))
    add(string.format('  DESTROYED   : %d', counts.destroyed))

    if #destroyed_names > 0 then
        add('')
        add('DESTROYED UNITS:')
        for _, name in ipairs(destroyed_names) do
            add('  - ' .. name)
        end
    end

    if ks then
        add('')
        add(string.format('KILLS : %d', Damage.getKills(ks, sideName)))
        add(string.format('LOSSES: %d', Damage.getLosses(ks, sideName)))
    end

    add('')
    add('=== END BDA ===')
    return table.concat(lines, '\n')
end

return Damage
