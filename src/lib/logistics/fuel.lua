--- CMO Lua Logistics Fuel Library
--- Fuel state queries, bingo detection, level setting, tanker search.
---
--- @module logistics.fuel
---
--- USAGE EXAMPLE:
---   local Fuel = dofile('path/to/lib/logistics/fuel.lua')
---
---   -- Check fuel percentage
---   local pct = Fuel.getFuelPercent('unit-guid')
---   print(string.format('Fuel: %.0f%%', pct))
---
---   -- Is the unit at bingo fuel?
---   if Fuel.isBingo('unit-guid') then
---       unit:RTB()
---   end
---
---   -- Set fuel to 75%
---   Fuel.setFuelPercent('unit-guid', 75)
---
---   -- Find nearest tanker for a unit
---   local tanker = Fuel.findNearestTanker('fighter-guid', 'USA')

local Fuel = {}

-- ============================================================
-- FUEL TYPE CODES
-- Reference: CMO database fuel type IDs
-- ============================================================

--- Fuel type numeric codes used in magazine/loadout fuel entries.
Fuel.TYPE = {
    AviationGasoline = 3001,  -- Piston-engine aircraft
    JetFuel          = 3002,  -- Turbine aircraft (JP-4, JP-8, Jet-A)
    AvGasJetFuel     = 3003,  -- Mixed gas/jet (some turboprops)
    DieselFuel       = 4001,  -- Ships, submarines, ground vehicles
    MDO              = 4002,  -- Marine diesel oil
    HFO              = 4003,  -- Heavy fuel oil (large ships)
    NuclearFuel      = 5001,  -- Nuclear reactors
    RocketFuel       = 6001,  -- Solid or liquid rocket propellant
    Battery          = 7001,  -- Electric (mini-UAS, torpedoes)
    Hydrogen         = 8001,  -- Fuel cell aircraft
}

-- Bingo fuel thresholds by unit type (percent). Adjust per scenario.
Fuel.BINGO_PERCENT = {
    Aircraft   = 20,
    Ship       = 15,
    Submarine  = 25,
    default    = 20,
}

-- ============================================================
-- FUEL QUERIES
-- ============================================================

--- Get the current fuel percentage for a unit (0–100).
--- Returns -1 if the unit is not found or has no fuel data.
---
--- @param unitGuid string
--- @return number  Fuel percentage (0–100) or -1
function Fuel.getFuelPercent(unitGuid)
    local unit = ScenEdit_GetUnit({ guid = unitGuid })
    if not unit then return -1 end

    local fuel = unit.fuel
    if not fuel then return -1 end

    -- CMO fuel table has percent, current, max fields
    if fuel.percent then return tonumber(fuel.percent) or -1 end

    -- Fallback: compute from current/max
    local current = tonumber(fuel.current)
    local max     = tonumber(fuel.max)
    if current and max and max > 0 then
        return (current / max) * 100
    end

    -- Some versions expose fuel state string
    if unit.fuelstate == 'OK'       then return 75 end  -- approximate
    if unit.fuelstate == 'Bingo'    then return 15 end
    if unit.fuelstate == 'Winchester' then return 0 end

    return -1
end

--- Get the CMO fuel state string for a unit.
---
--- @param unitGuid string
--- @return string  'OK' | 'Bingo' | 'Winchester' | 'Unknown'
function Fuel.getFuelState(unitGuid)
    local unit = ScenEdit_GetUnit({ guid = unitGuid })
    if not unit then return 'Unknown' end
    return unit.fuelstate or 'Unknown'
end

--- Get raw fuel current and max values.
---
--- @param unitGuid string
--- @return number, number  current fuel, max fuel (both 0 if unavailable)
function Fuel.getFuelRaw(unitGuid)
    local unit = ScenEdit_GetUnit({ guid = unitGuid })
    if not unit or not unit.fuel then return 0, 0 end
    local fuel = unit.fuel
    return tonumber(fuel.current) or 0,
           tonumber(fuel.max)     or 0
end

-- ============================================================
-- BINGO FUEL DETECTION
-- ============================================================

--- Check whether a unit is at or below bingo fuel.
--- Uses the type-specific threshold from Fuel.BINGO_PERCENT.
---
--- @param unitGuid  string
--- @param threshold number|nil  Override threshold percentage (default: type-based)
--- @return boolean
function Fuel.isBingo(unitGuid, threshold)
    local unit = ScenEdit_GetUnit({ guid = unitGuid })
    if not unit then return false end

    -- CMO native bingo check
    if unit.fuelstate == 'Bingo' or unit.fuelstate == 'Winchester' then
        return true
    end

    local pct  = Fuel.getFuelPercent(unitGuid)
    if pct < 0 then return false end

    local limit = threshold
    if not limit then
        limit = Fuel.BINGO_PERCENT[unit.type] or Fuel.BINGO_PERCENT.default
    end
    return pct <= limit
end

--- Check whether a unit is Winchester (out of fuel).
---
--- @param unitGuid string
--- @return boolean
function Fuel.isWinchester(unitGuid)
    local unit = ScenEdit_GetUnit({ guid = unitGuid })
    if not unit then return true end
    if unit.fuelstate == 'Winchester' then return true end
    local pct = Fuel.getFuelPercent(unitGuid)
    return pct >= 0 and pct < 1
end

--- Scan a list of unit GUIDs and return those at bingo fuel.
---
--- @param unitGuids table
--- @param threshold number|nil
--- @return table  Array of GUIDs at bingo
function Fuel.bingoUnits(unitGuids, threshold)
    local bingo = {}
    for _, guid in ipairs(unitGuids or {}) do
        if Fuel.isBingo(guid, threshold) then
            bingo[#bingo + 1] = guid
        end
    end
    return bingo
end

-- ============================================================
-- SET FUEL LEVEL
-- ============================================================

--- Set the absolute fuel amount for a unit using ScenEdit_SetUnit.
--- Finds the first fuel entry and sets its current value.
---
--- @param unitGuid   string
--- @param currentFuel number  Absolute fuel quantity
--- @return boolean
---
--- NOTE: Not all CMO versions support direct fuel editing via script.
--- Use with caution; test in scenario editor first.
function Fuel.setFuelAmount(unitGuid, currentFuel)
    local ok, err = pcall(ScenEdit_SetUnit, {
        guid = unitGuid,
        fuel = { { current = currentFuel } },
    })
    if not ok then
        print('[Fuel] setFuelAmount error: ' .. tostring(err))
        return false
    end
    return true
end

--- Set fuel to a percentage of the unit's maximum fuel load.
---
--- @param unitGuid string
--- @param percent  number  0–100
--- @return boolean
function Fuel.setFuelPercent(unitGuid, percent)
    percent = math.max(0, math.min(100, percent))
    local current, max = Fuel.getFuelRaw(unitGuid)
    if max <= 0 then
        print('[Fuel] setFuelPercent: no max fuel data for unit ' .. tostring(unitGuid))
        return false
    end
    local target = math.floor(max * percent / 100)
    return Fuel.setFuelAmount(unitGuid, target)
end

--- Top off a unit to 100% fuel.
---
--- @param unitGuid string
--- @return boolean
function Fuel.topOff(unitGuid)
    local unit = ScenEdit_GetUnit({ guid = unitGuid })
    if not unit then return false end
    -- ReplenishUnit fully restores fuel and ammo
    local ok, err = pcall(function() unit:ReplenishUnit() end)
    if not ok then
        print('[Fuel] topOff error: ' .. tostring(err))
        return false
    end
    return true
end

-- ============================================================
-- TANKER / UNREP SEARCH
-- ============================================================

--- Find the nearest airborne tanker unit for a given aircraft.
--- Searches all units on the same side for tanker support missions.
---
--- @param unitGuid string   GUID of the aircraft needing fuel
--- @param sideName string   Side name/GUID
--- @return Unit|nil, number|nil  Nearest tanker unit and range (nm)
---
--- EXAMPLE:
---   local tanker, distNm = Fuel.findNearestTanker('f18-guid', 'USA')
function Fuel.findNearestTanker(unitGuid, sideName)
    local unit = ScenEdit_GetUnit({ guid = unitGuid })
    if not unit then return nil, nil end

    local side = VP_GetSide({ Side = sideName })
    if not side then return nil, nil end

    local best_tanker = nil
    local best_range  = math.huge

    for _, u in ipairs(side.units or {}) do
        if u.guid ~= unitGuid and u.type == 'Aircraft' and not u.IsDestroyed then
            -- Identify tankers by subtype or name pattern
            local isTanker = (u.subtype and u.subtype:lower():find('tanker')) or
                             (u.name and u.name:lower():find('tanker')) or
                             (u.name and (
                                 u.name:lower():find('kc%-') or
                                 u.name:lower():find('kc ') or
                                 u.name:lower():find('il%-78') or
                                 u.name:lower():find('victor'))
                             )

            if isTanker then
                local ok, dist = pcall(Tool_Range,
                    { latitude=unit.latitude, longitude=unit.longitude },
                    { latitude=u.latitude,    longitude=u.longitude    })
                local range = (ok and type(dist) == 'number') and dist or math.huge

                if range < best_range then
                    best_range  = range
                    best_tanker = u
                end
            end
        end
    end

    return best_tanker, (best_tanker and best_range or nil)
end

--- Find the nearest UNREP (underway replenishment) ship for a surface unit.
---
--- @param unitGuid string  GUID of the ship needing fuel
--- @param sideName string
--- @return Unit|nil, number|nil  Nearest UNREP ship and range (nm)
function Fuel.findNearestUnrep(unitGuid, sideName)
    local unit = ScenEdit_GetUnit({ guid = unitGuid })
    if not unit then return nil, nil end

    local side = VP_GetSide({ Side = sideName })
    if not side then return nil, nil end

    local best   = nil
    local bestR  = math.huge

    for _, u in ipairs(side.units or {}) do
        if u.guid ~= unitGuid and u.type == 'Ship' and not u.IsDestroyed then
            local isUnrep = (u.subtype and u.subtype:lower():find('replenish')) or
                            (u.name and (
                                u.name:lower():find('aoe') or
                                u.name:lower():find('afs') or
                                u.name:lower():find('aor') or
                                u.name:lower():find('supply') or
                                u.name:lower():find('replenish'))
                            )
            if isUnrep then
                local ok, dist = pcall(Tool_Range,
                    { latitude=unit.latitude, longitude=unit.longitude },
                    { latitude=u.latitude,    longitude=u.longitude    })
                local range = (ok and type(dist) == 'number') and dist or math.huge
                if range < bestR then
                    bestR = range
                    best  = u
                end
            end
        end
    end

    return best, (best and bestR or nil)
end

return Fuel
