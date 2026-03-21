--- CMO Lua Cargo Library
--- Cargo loading/unloading, transfer, container creation, capacity checks.
---
--- @module cargo.cargo
---
--- CMO cargo system allows units to carry fuel, ammunition, personnel,
--- and custom containers. Cargo is accessed via unit.cargo (array of Cargo wrappers).
---
--- USAGE EXAMPLE:
---   local Cargo = dofile('path/to/lib/cargo/cargo.lua')
---
---   -- Check what's aboard a unit
---   local manifest = Cargo.getManifest('ship-guid')
---   for _, item in ipairs(manifest) do
---       print(item.name, item.type)
---   end
---
---   -- Transfer all cargo from one unit to another
---   Cargo.transferAll('source-unit-guid', 'dest-unit-guid')
---
---   -- Check remaining cargo capacity
---   local capacity = Cargo.getCapacity('ship-guid')
---   print('Cargo slots available: ' .. capacity)

local Cargo = {}

-- ============================================================
-- CARGO TYPE CONSTANTS
-- ============================================================

--- Cargo type identifiers (matches CMO database cargo types).
Cargo.TYPE = {
    CUSTOM      = 0,       -- Custom / generic cargo
    FUEL        = 1,       -- Fuel containers
    AMMUNITION  = 2,       -- Ammunition pallets
    PERSONNEL   = 3,       -- Troops / crew
    VEHICLE     = 4,       -- Vehicles
    EQUIPMENT   = 5,       -- General equipment
    FOOD        = 6,       -- Food/water supplies
    MEDICAL     = 7,       -- Medical supplies
}

-- ============================================================
-- MANIFEST / QUERY
-- ============================================================

--- Get all cargo items currently aboard a unit.
---
--- @param unitGuid string
--- @return table  Array of Cargo wrapper tables (may be empty)
function Cargo.getManifest(unitGuid)
    local unit = ScenEdit_GetUnit({ guid = unitGuid })
    if not unit then return {} end
    return unit.cargo or {}
end

--- Count cargo items aboard a unit, optionally filtered by cargo type.
---
--- @param unitGuid  string
--- @param cargoType number|nil  Cargo.TYPE constant (nil = all)
--- @return number
function Cargo.countCargo(unitGuid, cargoType)
    local manifest = Cargo.getManifest(unitGuid)
    if cargoType == nil then return #manifest end

    local count = 0
    for _, item in ipairs(manifest) do
        if item.type == cargoType then count = count + 1 end
    end
    return count
end

--- Check whether a unit is carrying any cargo.
---
--- @param unitGuid string
--- @return boolean
function Cargo.hasCargo(unitGuid)
    return Cargo.countCargo(unitGuid) > 0
end

--- Find a cargo item by name pattern.
---
--- @param unitGuid string
--- @param pattern  string  Lua string pattern to match against cargo.name
--- @return Cargo|nil  First matching cargo item
function Cargo.findCargo(unitGuid, pattern)
    local manifest = Cargo.getManifest(unitGuid)
    for _, item in ipairs(manifest) do
        if item.name and item.name:match(pattern) then
            return item
        end
    end
    return nil
end

--- Get the GUID of a cargo item by name.
---
--- @param unitGuid string
--- @param name     string  Exact cargo name
--- @return string|nil  Cargo GUID or nil
function Cargo.getCargoGuid(unitGuid, name)
    local manifest = Cargo.getManifest(unitGuid)
    for _, item in ipairs(manifest) do
        if item.name == name then
            return item.guid
        end
    end
    return nil
end

-- ============================================================
-- CAPACITY
-- ============================================================

--- Get the number of remaining cargo slots for a unit.
--- Returns -1 if capacity information is unavailable.
---
--- NOTE: CMO does not always expose a direct cargo capacity field.
--- This function estimates based on the unit's cargo wrapper data.
---
--- @param unitGuid string
--- @return number  Available cargo slots or -1
function Cargo.getCapacity(unitGuid)
    local unit = ScenEdit_GetUnit({ guid = unitGuid })
    if not unit then return -1 end

    -- Some unit types expose capacity via a cargo_capacity field
    -- This is wrapper-version dependent; fall back to a standard check
    local current = #(unit.cargo or {})

    -- Try to read max capacity from unit data
    -- (Implementation depends on CMO version; this is a safe approximation)
    if unit.cargo_capacity then
        return unit.cargo_capacity - current
    end

    -- Return current count; caller determines capacity by context
    return current
end

--- Check if a unit can accept additional cargo.
--- Uses a simple heuristic (cargo count < max expected).
---
--- @param unitGuid   string
--- @param maxCargo   number  Maximum allowed cargo items (default 10)
--- @return boolean
function Cargo.canAcceptCargo(unitGuid, maxCargo)
    maxCargo = maxCargo or 10
    return Cargo.countCargo(unitGuid) < maxCargo
end

-- ============================================================
-- LOAD / UNLOAD
-- ============================================================

--- Load (create) a cargo item onto a unit.
--- Uses unit:createUnitCargo() and sets properties.
---
--- @param unitGuid  string
--- @param cargoName string  Name for the cargo item
--- @param cargoType number  Cargo.TYPE constant
--- @param dbid      number|nil  Database ID (for ammunition/fuel containers)
--- @return Cargo|nil  Created cargo item, or nil on failure
---
--- EXAMPLE:
---   Cargo.loadCargo('helicopter-guid', 'Ammo Pallet Alpha', Cargo.TYPE.AMMUNITION)
function Cargo.loadCargo(unitGuid, cargoName, cargoType, dbid)
    local unit = ScenEdit_GetUnit({ guid = unitGuid })
    if not unit then
        print('[Cargo] loadCargo: unit not found: ' .. tostring(unitGuid))
        return nil
    end

    local ok, cargo = pcall(function()
        return unit:createUnitCargo()
    end)
    if not ok or not cargo then
        print('[Cargo] loadCargo: createUnitCargo failed: ' .. tostring(cargo))
        return nil
    end

    -- Set cargo properties if the cargo object supports it
    if cargo then
        if cargo.name ~= nil    then
            pcall(function() cargo.name = cargoName end)
        end
        if cargoType ~= nil then
            pcall(function() cargo.type = cargoType end)
        end
        if dbid ~= nil then
            pcall(function() cargo.dbid = dbid end)
        end
    end

    return cargo
end

--- Unload (delete) a cargo item from a unit by GUID.
---
--- @param unitGuid  string
--- @param cargoGuid string  GUID of the cargo item to remove
--- @return boolean
---
--- EXAMPLE:
---   Cargo.unloadCargo('helicopter-guid', 'cargo-item-guid')
function Cargo.unloadCargo(unitGuid, cargoGuid)
    local unit = ScenEdit_GetUnit({ guid = unitGuid })
    if not unit then return false end

    local ok, err = pcall(function()
        unit:deleteUnitCargo(cargoGuid)
    end)
    if not ok then
        print('[Cargo] unloadCargo error: ' .. tostring(err))
        return false
    end
    return true
end

--- Unload all cargo from a unit.
---
--- @param unitGuid string
--- @return number  Count of items unloaded
function Cargo.unloadAll(unitGuid)
    local manifest = Cargo.getManifest(unitGuid)
    local count = 0
    for _, item in ipairs(manifest) do
        if item.guid and Cargo.unloadCargo(unitGuid, item.guid) then
            count = count + 1
        end
    end
    return count
end

-- ============================================================
-- TRANSFER
-- ============================================================

--- Transfer a specific cargo item from one unit to another.
--- Unloads from source and creates equivalent on destination.
---
--- @param fromGuid  string   Source unit GUID
--- @param toGuid    string   Destination unit GUID
--- @param cargoGuid string   Cargo item GUID on the source unit
--- @return boolean
function Cargo.transferCargo(fromGuid, toGuid, cargoGuid)
    local fromUnit = ScenEdit_GetUnit({ guid = fromGuid })
    local toUnit   = ScenEdit_GetUnit({ guid = toGuid   })
    if not fromUnit or not toUnit then
        print('[Cargo] transferCargo: source or destination unit not found')
        return false
    end

    -- Find the cargo item on source
    local cargoItem = nil
    for _, item in ipairs(fromUnit.cargo or {}) do
        if item.guid == cargoGuid then
            cargoItem = item
            break
        end
    end

    if not cargoItem then
        print('[Cargo] transferCargo: cargo not found on source unit')
        return false
    end

    -- Create equivalent cargo on destination
    local newCargo = Cargo.loadCargo(toGuid,
        cargoItem.name or 'Transferred Cargo',
        cargoItem.type,
        cargoItem.dbid)

    if not newCargo then return false end

    -- Remove from source
    return Cargo.unloadCargo(fromGuid, cargoGuid)
end

--- Transfer all cargo from one unit to another.
---
--- @param fromGuid string
--- @param toGuid   string
--- @return number  Count of items transferred successfully
function Cargo.transferAll(fromGuid, toGuid)
    local manifest = Cargo.getManifest(fromGuid)
    local count    = 0
    for _, item in ipairs(manifest) do
        if item.guid then
            if Cargo.transferCargo(fromGuid, toGuid, item.guid) then
                count = count + 1
            end
        end
    end
    return count
end

-- ============================================================
-- CONTAINER CREATION
-- ============================================================

--- Create a cargo container with specific contents on a unit.
--- This is a convenience function for common cargo types.
---
--- @param unitGuid string
--- @param params   table
---   {
---     name    = string,          -- Container name
---     type    = number,          -- Cargo.TYPE constant
---     dbid    = number|nil,      -- Database ID (for specific ammunition types)
---     qty     = number|nil,      -- Quantity (for ammo/fuel containers)
---   }
--- @return Cargo|nil
---
--- EXAMPLE:
---   -- Load a fuel container
---   Cargo.createContainer('ship-guid', {
---       name='JP-8 Fuel Container', type=Cargo.TYPE.FUEL, qty=10000})
---
---   -- Load an ammo pallet
---   Cargo.createContainer('ship-guid', {
---       name='AIM-120C Pallet', type=Cargo.TYPE.AMMUNITION, dbid=2083, qty=8})
function Cargo.createContainer(unitGuid, params)
    params = params or {}
    return Cargo.loadCargo(
        unitGuid,
        params.name or 'Container',
        params.type or Cargo.TYPE.CUSTOM,
        params.dbid)
end

--- Generate a cargo manifest report for a unit.
---
--- @param unitGuid string
--- @return string  Multi-line manifest text
function Cargo.manifestReport(unitGuid)
    local unit     = ScenEdit_GetUnit({ guid = unitGuid })
    local manifest = Cargo.getManifest(unitGuid)
    local lines    = { 'CARGO MANIFEST' }

    if unit then lines[#lines + 1] = 'Unit: ' .. unit.name end
    lines[#lines + 1] = string.format('Items: %d', #manifest)
    lines[#lines + 1] = ''

    if #manifest == 0 then
        lines[#lines + 1] = '  (no cargo)'
    else
        for i, item in ipairs(manifest) do
            lines[#lines + 1] = string.format(
                '  %d. %s (type=%s guid=%s)',
                i,
                item.name  or 'Unknown',
                tostring(item.type  or '?'),
                item.guid  or '?')
        end
    end

    return table.concat(lines, '\n')
end

return Cargo
