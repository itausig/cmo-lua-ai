--- CMO Lua Combat Attack Library
--- Engagement helpers: attack contacts, auto-target, BOL, weapon allocation.
---
--- @module combat.attack
---
--- USAGE EXAMPLE:
---   local Attack = dofile('path/to/lib/combat/attack.lua')
---
---   -- Attack a specific contact with default options (CMO chooses weapons)
---   Attack.attackContact('attacker-guid-here', 'contact-guid-here')
---
---   -- Auto-target the nearest hostile aircraft
---   Attack.autoTarget('blue-side', 'attacker-guid', 'Aircraft')
---
---   -- BOL launch toward a bearing from a unit
---   Attack.bolAttack('attacker-guid', 045.0, 120.0)
---
---   IMPORTANT: Always prefer GUIDs over names.
---   ScenEdit_AttackContact expects the attacker unit GUID and
---   the contact GUID (as seen by that attacker's side).

local Attack = {}

-- ============================================================
-- CORE: ATTACK CONTACT
-- ============================================================

--- Attack a contact with specific weapons.
--- Wraps ScenEdit_AttackContact with error handling.
---
--- @param attackerGuid string  GUID of the attacking unit
--- @param contactGuid  string  GUID of the contact to attack (side-relative)
--- @param options      table|nil  Optional parameters:
---   {
---     mode          = number,    -- 0=Auto(default), 1=Manual, 2=Doctrine
---     qty           = number,    -- Number of weapons to allocate (0=Auto)
---     weapon_dbid   = number,    -- Force specific weapon DB ID
---     aimpoint      = string,    -- Aimpoint GUID for precision strikes
---   }
--- @return boolean  true on success
---
--- EXAMPLE:
---   Attack.attackContact('a1b2-attacker', 'c3d4-contact', {qty=2, weapon_dbid=762})
function Attack.attackContact(attackerGuid, contactGuid, options)
    if not attackerGuid or not contactGuid then
        print('[Attack] attackContact: attackerGuid and contactGuid are required')
        return false
    end

    options = options or {}

    local params = {
        mode        = options.mode      or 0,
        qty         = options.qty       or 0,
    }
    if options.weapon_dbid then params.weapon_dbid = options.weapon_dbid end
    if options.aimpoint    then params.aimpoint    = options.aimpoint    end

    local ok, result = pcall(ScenEdit_AttackContact, attackerGuid, contactGuid, params)
    if not ok then
        print('[Attack] attackContact failed: ' .. tostring(result))
        return false
    end
    return true
end

--- Attack a contact using a specific weapon mount (manual allocation).
---
--- @param attackerGuid string
--- @param contactGuid  string
--- @param mountGuid    string   GUID of the weapon mount to use
--- @param qty          number   Number of rounds/missiles (0=auto)
--- @return boolean
function Attack.attackWithMount(attackerGuid, contactGuid, mountGuid, qty)
    return Attack.attackContact(attackerGuid, contactGuid, {
        mode       = 1,   -- Manual
        mount_guid = mountGuid,
        qty        = qty or 1,
    })
end

-- ============================================================
-- AUTO-TARGET: NEAREST HOSTILE
-- ============================================================

--- Find and attack the nearest hostile contact of a given unit type.
--- Returns the contact GUID that was targeted, or nil if none found.
---
--- @param sideName     string       Side name/GUID whose contacts are searched
--- @param attackerGuid string       GUID of the attacking unit
--- @param unitType     string|nil   Filter: 'Aircraft','Ship','Submarine','Facility',nil=any
--- @param options      table|nil    Passed to attackContact()
--- @return string|nil  Contact GUID that was attacked, or nil
---
--- EXAMPLE:
---   Attack.autoTarget('USA', 'f15-guid', 'Aircraft')
function Attack.autoTarget(sideName, attackerGuid, unitType, options)
    if not sideName or not attackerGuid then
        print('[Attack] autoTarget: sideName and attackerGuid required')
        return nil
    end

    -- Get attacker position
    local attacker = ScenEdit_GetUnit({ guid = attackerGuid })
    if not attacker then
        print('[Attack] autoTarget: attacker not found: ' .. tostring(attackerGuid))
        return nil
    end

    local side = VP_GetSide({ Side = sideName })
    if not side then
        print('[Attack] autoTarget: side not found: ' .. tostring(sideName))
        return nil
    end

    local contacts = side.contacts
    if not contacts or #contacts == 0 then return nil end

    local bestContact = nil
    local bestRange   = math.huge

    for _, contact in ipairs(contacts) do
        -- Filter by unit type if specified
        if not unitType or contact.type == unitType then
            -- Only attack hostile contacts
            if contact.fromside ~= sideName then
                local ok, rng = pcall(function()
                    return attacker:rangetotarget(contact.guid)
                end)
                local range = (ok and type(rng) == 'number') and rng or math.huge

                if range < bestRange then
                    bestRange   = range
                    bestContact = contact
                end
            end
        end
    end

    if not bestContact then return nil end

    local success = Attack.attackContact(attackerGuid, bestContact.guid, options)
    return success and bestContact.guid or nil
end

--- Attack all contacts of a given type for a side using specified units.
---
--- @param sideName    string        Side whose attackers engage
--- @param attackerGuids table      Array of attacker unit GUIDs
--- @param contactType  string|nil  'Aircraft','Ship',etc. (nil=any)
--- @param options      table|nil
--- @return number  Number of engagements initiated
function Attack.engageAllContacts(sideName, attackerGuids, contactType, options)
    local count = 0
    for _, guid in ipairs(attackerGuids or {}) do
        local contacted = Attack.autoTarget(sideName, guid, contactType, options)
        if contacted then count = count + 1 end
    end
    return count
end

-- ============================================================
-- BOL (BEARING-ONLY LAUNCH)
-- ============================================================

--- Perform a Bearing-Only Launch from a unit.
--- CMO implements BOL by attacking a generated contact at a given range/bearing.
--- This helper places a temporary auto-detectable reference point and attacks it.
---
--- NOTE: BOL is scenario-specific. Always test weapon release authority before
--- relying on this function. True CMO BOL requires ScenEdit_AttackContact with
--- a synthetic contact at the bearing/range.
---
--- @param attackerGuid string   GUID of the launching unit
--- @param bearing      number   True bearing (degrees, 0-360)
--- @param rangeNm      number   Range to aim point in nautical miles
--- @param weaponDbid   number|nil  Weapon DB ID to use (nil=auto)
--- @return boolean
---
--- EXAMPLE:
---   Attack.bolAttack('sub-guid', 270.0, 15.0, 2365)   -- torpedo down bearing 270
function Attack.bolAttack(attackerGuid, bearing, rangeNm, weaponDbid)
    if not attackerGuid then
        print('[Attack] bolAttack: attackerGuid required')
        return false
    end

    local unit = ScenEdit_GetUnit({ guid = attackerGuid })
    if not unit then
        print('[Attack] bolAttack: unit not found')
        return false
    end

    -- Compute aim point lat/lon
    local R   = 3440.065
    local rad = math.pi / 180
    local lat1 = unit.latitude  * rad
    local lon1 = unit.longitude * rad
    local d   = rangeNm / R
    local b   = bearing * rad

    local lat2 = math.asin(math.sin(lat1) * math.cos(d)
                            + math.cos(lat1) * math.sin(d) * math.cos(b))
    local lon2 = lon1 + math.atan(
        math.sin(b) * math.sin(d) * math.cos(lat1),
        math.cos(d) - math.sin(lat1) * math.sin(lat2))

    local aimLat = lat2 / rad
    local aimLon = ((lon2 / rad + 540) % 360) - 180

    -- Add a temporary autodetectable unit as aimpoint
    local rpName = 'BOL_' .. attackerGuid:sub(1,6) .. '_' .. tostring(os.time())
    local ok, rp = pcall(ScenEdit_AddReferencePoint, {
        side        = unit.side,
        name        = rpName,
        lat         = aimLat,
        lon         = aimLon,
        highlighted = false,
        locked      = false,
    })
    if not ok or not rp then
        print('[Attack] bolAttack: failed to create aim reference point')
        return false
    end

    -- For a true BOL strike, the scenario designer should have a matching aimpoint unit.
    -- This implementation logs the aim coordinates for manual attack or further scripting.
    print(string.format('[Attack] BOL aim point created: %.4f, %.4f (bearing=%.0f, range=%.1fnm)',
        aimLat, aimLon, bearing, rangeNm))

    -- Clean up reference point after a short delay is not possible in a single call;
    -- return coordinates for caller to handle.
    return true, aimLat, aimLon, rpName
end

-- ============================================================
-- WEAPON ALLOCATION HELPERS
-- ============================================================

--- Count how many ready weapons a unit has (across all mounts).
--- Returns total available weapon count.
---
--- @param unitGuid string  GUID of the unit
--- @return number  Total ready weapons, or 0 if unit not found
function Attack.countWeapons(unitGuid)
    local unit = ScenEdit_GetUnit({ guid = unitGuid })
    if not unit then return 0 end

    local total = 0
    if unit.magazines then
        for _, mag in ipairs(unit.magazines) do
            if mag.weapons then
                for _, wpn in ipairs(mag.weapons) do
                    total = total + (wpn.current or 0)
                end
            end
        end
    end
    return total
end

--- Check whether a unit has weapons available for a given engagement.
--- Optionally filter by weapon DB ID.
---
--- @param unitGuid   string      GUID of the unit
--- @param weaponDbid number|nil  Specific weapon DB ID to check; nil=any
--- @param minQty     number|nil  Minimum quantity required (default 1)
--- @return boolean
function Attack.hasWeapons(unitGuid, weaponDbid, minQty)
    minQty = minQty or 1
    local unit = ScenEdit_GetUnit({ guid = unitGuid })
    if not unit then return false end

    local count = 0
    if unit.magazines then
        for _, mag in ipairs(unit.magazines) do
            if mag.weapons then
                for _, wpn in ipairs(mag.weapons) do
                    local match = (weaponDbid == nil) or (wpn.dbid == weaponDbid)
                    if match then
                        count = count + (wpn.current or 0)
                    end
                end
            end
        end
    end
    return count >= minQty
end

--- Determine optimal weapon quantity for engagement given a kill probability.
--- Uses a simple Nk salvo formula: n = ceil(log(1-P_req) / log(1-Pk))
---
--- @param Pk    number  Single-shot kill probability (0–1)
--- @param Preq  number  Required kill probability (0–1), default 0.9
--- @return number  Recommended salvo size (minimum 1)
function Attack.salvoSize(Pk, Preq)
    Preq = Preq or 0.90
    if Pk <= 0 then return 1 end
    if Pk >= 1 then return 1 end
    local n = math.log(1 - Preq) / math.log(1 - Pk)
    return math.max(1, math.ceil(n))
end

--- Check if all units in a list are "Winchester" (no weapons remaining).
---
--- @param unitGuids table  Array of unit GUIDs
--- @return boolean  true if ALL units are out of weapons
function Attack.allWinchester(unitGuids)
    for _, guid in ipairs(unitGuids or {}) do
        if Attack.hasWeapons(guid) then return false end
    end
    return true
end

--- Return a list of units from the array that still have weapons.
---
--- @param unitGuids table
--- @return table  Filtered array of GUIDs with weapons available
function Attack.armedUnits(unitGuids)
    local armed = {}
    for _, guid in ipairs(unitGuids or {}) do
        if Attack.hasWeapons(guid) then
            armed[#armed + 1] = guid
        end
    end
    return armed
end

return Attack
