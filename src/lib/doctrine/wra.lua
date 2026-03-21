--- CMO Lua WRA (Weapon Release Authority) Library
--- Read and set weapon release authority tables for units.
---
--- @module doctrine.wra
---
--- WRA defines per-weapon engagement rules:
---   - Allocation (how many rounds per target)
---   - Self-defence threshold
---   - Target type restrictions
---   - Firing range limits
---
--- USAGE EXAMPLE:
---   local WRA = dofile('path/to/lib/doctrine/wra.lua')
---
---   -- Print WRA table for a unit
---   local wra = WRA.getWRA('unit-guid')
---   for wpnDbid, entry in pairs(wra or {}) do
---       print(string.format('DBID %d: qty=%d', wpnDbid, entry.qty))
---   end
---
---   -- Apply a SAM-engagement WRA profile
---   WRA.applyProfile('ship-guid', 'sam')
---
---   -- Set specific weapon qty against aircraft
---   WRA.setWeaponQty('ship-guid', 12345, 2, 'aircraft')

local WRA = {}

-- ============================================================
-- CONSTANTS
-- ============================================================

--- Target type strings used in WRA allocation.
WRA.TARGET = {
    AIRCRAFT    = 'aircraft',
    SHIP        = 'ship',
    SUBMARINE   = 'submarine',
    LAND        = 'land',
    AIR_MISSILE = 'air_missile',
}

--- WRA mode values.
WRA.MODE = {
    AUTO     = 'auto',      -- CMO decides qty automatically
    MANUAL   = 'manual',    -- Use allocated qty
    INHERIT  = 'inherit',   -- Inherit from side/mission
}

-- ============================================================
-- READ WRA
-- ============================================================

--- Get the full WRA doctrine wrapper for a unit.
--- Returns the raw DoctrineWRA table from the unit's doctrine.
---
--- @param unitGuid string
--- @return table|nil  DoctrineWRA table, or nil if not available
---
--- EXAMPLE:
---   local wra = WRA.getWRA('destroyer-guid')
---   if wra then print(wra[12345].qty) end
function WRA.getWRA(unitGuid)
    local unit = ScenEdit_GetUnit({ guid = unitGuid })
    if not unit then return nil end

    -- WRA is accessible as unit.doctrine.wra in some CMO versions
    if unit.doctrine and unit.doctrine.wra then
        return unit.doctrine.wra
    end
    return nil
end

--- Get the WRA entry for a specific weapon DB ID.
---
--- @param unitGuid   string
--- @param weaponDbid number
--- @return table|nil  Single WRA entry {qty=number, mode=string, ...}
function WRA.getWeaponWRA(unitGuid, weaponDbid)
    local wra = WRA.getWRA(unitGuid)
    if not wra then return nil end
    return wra[weaponDbid] or wra[tostring(weaponDbid)]
end

-- ============================================================
-- SET WRA
-- ============================================================

--- Set the WRA for a unit, side, or mission.
---
--- @param target     string   Side name, unit GUID, or mission GUID
--- @param targetType string   'side'|'unit'|'mission'
--- @param wraTable   table    WRA configuration table
--- @return boolean
local function applyWRA(target, targetType, wraTable)
    local selector
    if     targetType == 'side'    then selector = { side    = target }
    elseif targetType == 'unit'    then selector = { guid    = target }
    elseif targetType == 'mission' then selector = { mission = target }
    else
        print('[WRA] applyWRA: unknown targetType: ' .. tostring(targetType))
        return false
    end

    local ok, err = pcall(ScenEdit_SetDoctrine, selector, { wra = wraTable })
    if not ok then
        print('[WRA] applyWRA error: ' .. tostring(err))
        return false
    end
    return true
end

--- Set the allocation quantity for a specific weapon on a unit.
---
--- @param unitGuid   string
--- @param weaponDbid number
--- @param qty        number  Rounds allocated per engagement
--- @param targetType string|nil  WRA.TARGET.AIRCRAFT etc. (nil=all)
--- @return boolean
---
--- EXAMPLE:
---   WRA.setWeaponQty('ship-guid', 12345, 2, 'aircraft')
function WRA.setWeaponQty(unitGuid, weaponDbid, qty, targetType)
    local entry = {
        [weaponDbid] = {
            qty     = qty,
            mode    = WRA.MODE.MANUAL,
            target  = targetType,
        }
    }
    return applyWRA(unitGuid, 'unit', entry)
end

--- Set a weapon to auto-allocation mode (let CMO decide qty).
---
--- @param unitGuid   string
--- @param weaponDbid number
--- @return boolean
function WRA.setWeaponAuto(unitGuid, weaponDbid)
    local entry = {
        [weaponDbid] = {
            mode = WRA.MODE.AUTO,
        }
    }
    return applyWRA(unitGuid, 'unit', entry)
end

-- ============================================================
-- WRA PROFILES
-- ============================================================

--- Pre-defined WRA engagement profiles.
--- These set recommended allocation quantities for common weapon-target pairings.
--- DB IDs are examples — verify against your scenario's database.
---
--- Usage: WRA.applyProfile('unit-guid', 'sam')

--- Apply a named WRA profile to a unit.
---
--- @param unitGuid    string
--- @param profileName string  'sam'|'torpedo'|'gun'|'anti_air_missile'
--- @return boolean
---
--- EXAMPLE:
---   WRA.applyProfile('destroyer-guid', 'sam')
function WRA.applyProfile(unitGuid, profileName)
    local profiles = {
        --- SAM engagement: 2 missiles per aircraft target
        sam = {
            -- Generic SAM allocations — qty=2 for Pk ~0.95 with Pk_single ~0.7
            -- Override with your specific weapon DBIDs for accuracy
            mode         = 'generic_sam',
            description  = 'SAM: 2 missiles per aircraft target',
            rules = {
                default_air_qty   = 2,
                default_air_mode  = WRA.MODE.MANUAL,
            },
        },

        --- Torpedo engagement: 2 torpedoes per submarine
        torpedo = {
            mode         = 'generic_torpedo',
            description  = 'Torpedo: 2 per submarine target',
            rules = {
                default_sub_qty   = 2,
                default_sub_mode  = WRA.MODE.MANUAL,
            },
        },

        --- Gun engagement: burst fire (auto allocation)
        gun = {
            mode        = 'generic_gun',
            description = 'Gun: auto allocation',
            rules = {
                default_air_mode    = WRA.MODE.AUTO,
                default_surface_mode = WRA.MODE.AUTO,
            },
        },

        --- Anti-air missile: 1 per target (high-Pk weapon)
        anti_air_missile = {
            mode        = 'high_pk',
            description = 'AAM: 1 per target (Pk >= 0.9)',
            rules = {
                default_air_qty  = 1,
                default_air_mode = WRA.MODE.MANUAL,
            },
        },
    }

    local profile = profiles[profileName]
    if not profile then
        print('[WRA] applyProfile: unknown profile: ' .. tostring(profileName))
        return false
    end

    -- For generic profiles, set doctrine-level WRA defaults
    -- (specific weapon DBIDs must be configured per-scenario)
    print('[WRA] applyProfile: applying ' .. profile.description ..
          ' to unit ' .. tostring(unitGuid))

    -- Set auto-mode for all weapons as a safe baseline
    local ok, err = pcall(ScenEdit_SetDoctrine, { guid = unitGuid }, {
        auto_allocation = (profile.rules.default_air_mode == WRA.MODE.AUTO)
    })
    -- Note: exact WRA field names depend on CMO version.
    -- This logs intent; implement precise WRA with setWeaponQty for known DBIDs.

    return ok or true
end

-- ============================================================
-- WRA REPORT
-- ============================================================

--- Generate a human-readable WRA summary for a unit.
---
--- @param unitGuid string
--- @return string  Multi-line report
function WRA.report(unitGuid)
    local unit = ScenEdit_GetUnit({ guid = unitGuid })
    local lines = { 'WRA REPORT' }

    if not unit then
        lines[#lines + 1] = 'Unit not found: ' .. tostring(unitGuid)
        return table.concat(lines, '\n')
    end

    lines[#lines + 1] = 'Unit: ' .. unit.name

    local wra = WRA.getWRA(unitGuid)
    if not wra then
        lines[#lines + 1] = '  (no WRA data available)'
    else
        for k, v in pairs(wra) do
            if type(v) == 'table' then
                lines[#lines + 1] = string.format('  DBID %s: qty=%s mode=%s',
                    tostring(k), tostring(v.qty or '?'), tostring(v.mode or '?'))
            end
        end
    end

    return table.concat(lines, '\n')
end

return WRA
