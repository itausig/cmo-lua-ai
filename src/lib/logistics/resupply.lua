--- CMO Lua Logistics Resupply Library
--- Magazine management, weapon reloading, loadout filling, inventory checks.
---
--- @module logistics.resupply
---
--- USAGE EXAMPLE:
---   local Resupply = dofile('path/to/lib/logistics/resupply.lua')
---
---   -- Add AIM-120C to an aircraft's magazine
---   Resupply.addWeaponToMagazine('aircraft-guid', 2083, 4)
---
---   -- Fill all magazines for the current loadout
---   Resupply.fillMagsForLoadout('aircraft-guid')
---
---   -- Reload a specific weapon across an entire side
---   Resupply.reloadSideWeapon('USA', 2083, 10)
---
---   -- Check how many of a weapon a unit has left
---   local count = Resupply.countWeapon('ship-guid', 762)

local Resupply = {}

-- ============================================================
-- ADD WEAPONS TO MAGAZINE
-- ============================================================

--- Add weapons to a specific unit's magazine.
--- Wraps ScenEdit_AddWeaponToUnitMagazine.
---
--- @param unitGuid   string  GUID of the unit (ship, aircraft, facility)
--- @param weaponDbid number  Database ID of the weapon to add
--- @param qty        number  Quantity to add
--- @param loadoutDbid number|nil  Loadout DB ID (optional, for aircraft)
--- @return boolean  true on success
---
--- EXAMPLE:
---   -- Add 4 AIM-120C (DBID 2083) to a fighter
---   Resupply.addWeaponToMagazine('f15-guid', 2083, 4)
function Resupply.addWeaponToMagazine(unitGuid, weaponDbid, qty, loadoutDbid)
    if not unitGuid or not weaponDbid or not qty then
        print('[Resupply] addWeaponToMagazine: unitGuid, weaponDbid, qty required')
        return false
    end

    local params = {
        unitname = unitGuid,   -- accepts GUID or name
        dbid     = weaponDbid,
        qty      = qty,
    }
    if loadoutDbid then params.loadout_dbid = loadoutDbid end

    local ok, err = pcall(ScenEdit_AddWeaponToUnitMagazine, params)
    if not ok then
        print('[Resupply] addWeaponToMagazine error: ' .. tostring(err))
        return false
    end
    return true
end

--- Add weapons to a unit's magazine using its name (convenience wrapper).
---
--- @param unitName   string  Unit name (GUID preferred — use only when GUID unavailable)
--- @param sideName   string  Side name/GUID
--- @param weaponDbid number
--- @param qty        number
--- @return boolean
function Resupply.addWeaponByName(unitName, sideName, weaponDbid, qty)
    local unit = ScenEdit_GetUnit({ name=unitName, side=sideName })
    if not unit then
        print('[Resupply] addWeaponByName: unit not found: ' .. tostring(unitName))
        return false
    end
    return Resupply.addWeaponToMagazine(unit.guid, weaponDbid, qty)
end

-- ============================================================
-- FILL MAGAZINES
-- ============================================================

--- Fill all magazines for a unit's current loadout to maximum capacity.
--- Wraps ScenEdit_FillMagsForLoadout.
---
--- @param unitGuid string  GUID of the unit
--- @return boolean
---
--- EXAMPLE:
---   Resupply.fillMagsForLoadout('aircraft-guid')
function Resupply.fillMagsForLoadout(unitGuid)
    if not unitGuid then return false end

    local ok, err = pcall(ScenEdit_FillMagsForLoadout, {
        unitname = unitGuid,
        quantity = 99999,   -- max
    })
    if not ok then
        print('[Resupply] fillMagsForLoadout error: ' .. tostring(err))
        return false
    end
    return true
end

--- Fill magazines for a list of units.
---
--- @param unitGuids table  Array of unit GUIDs
--- @return number  Count of units successfully filled
function Resupply.fillMagsForUnits(unitGuids)
    local count = 0
    for _, guid in ipairs(unitGuids or {}) do
        if Resupply.fillMagsForLoadout(guid) then
            count = count + 1
        end
    end
    return count
end

-- ============================================================
-- ADD RELOADS TO MOUNTS
-- ============================================================

--- Add reloads to a unit's weapon mounts.
--- Wraps ScenEdit_AddReloadsToUnit.
---
--- @param unitGuid   string
--- @param weaponDbid number   Weapon DB ID to reload
--- @param qty        number   Number of reloads to add
--- @return boolean
---
--- EXAMPLE:
---   Resupply.addReloadsToUnit('destroyer-guid', 12345, 20)
function Resupply.addReloadsToUnit(unitGuid, weaponDbid, qty)
    if not unitGuid or not weaponDbid then
        print('[Resupply] addReloadsToUnit: unitGuid and weaponDbid required')
        return false
    end

    local ok, err = pcall(ScenEdit_AddReloadsToUnit, {
        unitname = unitGuid,
        dbid     = weaponDbid,
        qty      = qty or 1,
    })
    if not ok then
        print('[Resupply] addReloadsToUnit error: ' .. tostring(err))
        return false
    end
    return true
end

-- ============================================================
-- SIDE-WIDE RELOAD
-- ============================================================

--- Add a specific weapon type to all units of a side (aircraft only, or all types).
--- Useful for reinforcing a side's offensive capability at a scenario checkpoint.
---
--- @param sideName   string       Side name/GUID
--- @param weaponDbid number       Weapon DB ID to add
--- @param qty        number       Quantity per unit
--- @param unitType   string|nil   'Aircraft'|'Ship'|'Submarine'|nil=all
--- @return number  Number of units reloaded
---
--- EXAMPLE:
---   -- Reload 2 Harpoons on every US ship
---   Resupply.reloadSideWeapon('USA', 398, 2, 'Ship')
function Resupply.reloadSideWeapon(sideName, weaponDbid, qty, unitType)
    local side = VP_GetSide({ Side = sideName })
    if not side then
        print('[Resupply] reloadSideWeapon: side not found: ' .. tostring(sideName))
        return 0
    end

    local count = 0
    for _, unit in ipairs(side.units or {}) do
        if not unit.IsDestroyed then
            local typeMatch = (unitType == nil) or (unit.type == unitType)
            if typeMatch then
                local ok = Resupply.addWeaponToMagazine(unit.guid, weaponDbid, qty)
                if ok then count = count + 1 end
            end
        end
    end
    return count
end

--- Replenish all units on a side (full fuel + full magazines).
---
--- @param sideName string
--- @param unitType  string|nil  Filter by type (nil=all)
--- @return number  Count of units replenished
function Resupply.replenishSide(sideName, unitType)
    local side = VP_GetSide({ Side = sideName })
    if not side then return 0 end

    local count = 0
    for _, unit in ipairs(side.units or {}) do
        if not unit.IsDestroyed then
            local typeMatch = (unitType == nil) or (unit.type == unitType)
            if typeMatch then
                local ok, err = pcall(function()
                    local u = ScenEdit_GetUnit({ guid = unit.guid })
                    if u then u:ReplenishUnit() end
                end)
                if ok then count = count + 1 end
            end
        end
    end
    return count
end

-- ============================================================
-- INVENTORY / WEAPON COUNT
-- ============================================================

--- Count how many weapons of a given DB ID a unit currently has.
--- Searches all magazines on the unit.
---
--- @param unitGuid   string
--- @param weaponDbid number  Weapon DB ID to search for
--- @return number  Total quantity found (0 if not found or unit missing)
---
--- EXAMPLE:
---   local tomahawks = Resupply.countWeapon('destroyer-guid', 1215)
function Resupply.countWeapon(unitGuid, weaponDbid)
    local unit = ScenEdit_GetUnit({ guid = unitGuid })
    if not unit or not unit.magazines then return 0 end

    local total = 0
    for _, mag in ipairs(unit.magazines) do
        if mag.weapons then
            for _, wpn in ipairs(mag.weapons) do
                if wpn.dbid == weaponDbid then
                    total = total + (wpn.current or 0)
                end
            end
        end
    end
    return total
end

--- Check weapon inventory across an entire side.
--- Returns a table mapping weapon DB ID -> total count.
---
--- @param sideName   string
--- @param unitType   string|nil  Filter by unit type
--- @return table  { [dbid] = count, ... }
---
--- EXAMPLE:
---   local inv = Resupply.sideInventory('USA', 'Aircraft')
---   print('AIM-120C remaining: ' .. (inv[2083] or 0))
function Resupply.sideInventory(sideName, unitType)
    local side = VP_GetSide({ Side = sideName })
    if not side then return {} end

    local inventory = {}

    for _, unit in ipairs(side.units or {}) do
        if not unit.IsDestroyed then
            local typeMatch = (unitType == nil) or (unit.type == unitType)
            if typeMatch then
                local u = ScenEdit_GetUnit({ guid = unit.guid })
                if u and u.magazines then
                    for _, mag in ipairs(u.magazines) do
                        if mag.weapons then
                            for _, wpn in ipairs(mag.weapons) do
                                local dbid = wpn.dbid
                                if dbid then
                                    inventory[dbid] = (inventory[dbid] or 0) + (wpn.current or 0)
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    return inventory
end

--- Check if a side has at least minQty of a weapon available.
---
--- @param sideName   string
--- @param weaponDbid number
--- @param minQty     number  (default 1)
--- @param unitType   string|nil
--- @return boolean
function Resupply.sideHasWeapon(sideName, weaponDbid, minQty, unitType)
    minQty = minQty or 1
    local inv = Resupply.sideInventory(sideName, unitType)
    return (inv[weaponDbid] or 0) >= minQty
end

--- Generate a readable inventory report for a side.
---
--- @param sideName string
--- @return string  Multi-line report text
function Resupply.inventoryReport(sideName)
    local lines  = { 'WEAPON INVENTORY — ' .. tostring(sideName) }
    local inv    = Resupply.sideInventory(sideName)
    local sorted = {}
    for dbid, count in pairs(inv) do
        sorted[#sorted + 1] = { dbid=dbid, count=count }
    end
    table.sort(sorted, function(a, b) return a.dbid < b.dbid end)
    for _, entry in ipairs(sorted) do
        lines[#lines + 1] = string.format('  DBID %d: %d rounds', entry.dbid, entry.count)
    end
    if #sorted == 0 then lines[#lines + 1] = '  (no data)' end
    return table.concat(lines, '\n')
end

return Resupply
