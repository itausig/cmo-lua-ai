--- CMO Lua Doctrine Library
--- Doctrine profile management: ROE, WCS, fuel/weapon thresholds, evasion.
---
--- @module doctrine.doctrine
---
--- Doctrine controls how units behave autonomously: when they engage,
--- when they retreat, how aggressive they are, etc.
---
--- WEAPON CONTROL STATUS (WCS):
---   0 = Weapons Free  (engage any valid target)
---   1 = Weapons Tight (engage only designated targets)
---   2 = Weapons Hold  (do not engage)
---
--- USAGE EXAMPLE:
---   local Doc = dofile('path/to/lib/doctrine/doctrine.lua')
---
---   -- Apply a defensive doctrine profile to a ship
---   Doc.applyProfile('ship-guid', 'unit', Doc.PROFILES.defensive)
---
---   -- Set weapons free for all domains on a side
---   Doc.setWCS('USA', 'side', {air=0, surface=0, subsurface=1, land=2})
---
---   -- Copy doctrine from one unit to another
---   Doc.copyDoctrine('template-unit-guid', 'new-unit-guid')

local Doc = {}

-- ============================================================
-- WCS CONSTANTS
-- ============================================================

Doc.WCS = {
    FREE  = 0,    -- Weapons Free
    TIGHT = 1,    -- Weapons Tight
    HOLD  = 2,    -- Weapons Hold
}

-- ============================================================
-- DOCTRINE PROFILES
-- ============================================================

--- Pre-defined doctrine profile tables.
--- Each profile is a table of doctrine fields compatible with ScenEdit_SetDoctrine.
Doc.PROFILES = {
    --- Defensive: hold fire except when targeted, evade threats
    defensive = {
        weapon_control_status_air        = 1,   -- Tight
        weapon_control_status_surface    = 1,
        weapon_control_status_subsurface = 1,
        weapon_control_status_land       = 2,   -- Hold
        use_ammunition                   = 'yes',
        fuel_state_rtb                   = 'bingo',
        weapon_state_rtb                 = 'winchester',
        ignore_plotted_course            = 'no',
        engage_non_hostile_targets       = 'no',
        guns_strafe_air                  = 'no',
        guns_strafe_surface              = 'no',
        air_intercept                    = 'yes',
        anti_surface_warfare             = 'no',
        anti_submarine_warfare           = 'no',
    },

    --- Offensive: weapons free, engage all valid targets
    offensive = {
        weapon_control_status_air        = 0,   -- Free
        weapon_control_status_surface    = 0,
        weapon_control_status_subsurface = 0,
        weapon_control_status_land       = 0,
        use_ammunition                   = 'yes',
        fuel_state_rtb                   = 'bingo',
        weapon_state_rtb                 = 'winchester',
        engage_non_hostile_targets       = 'no',
        air_intercept                    = 'yes',
        anti_surface_warfare             = 'yes',
        anti_submarine_warfare           = 'yes',
    },

    --- Ambush: weapons tight, do not engage until ordered
    ambush = {
        weapon_control_status_air        = 1,   -- Tight
        weapon_control_status_surface    = 1,
        weapon_control_status_subsurface = 1,
        weapon_control_status_land       = 2,   -- Hold land
        use_ammunition                   = 'yes',
        fuel_state_rtb                   = 'bingo',
        weapon_state_rtb                 = 'winchester',
        engage_non_hostile_targets       = 'no',
        ignore_plotted_course            = 'no',
    },

    --- Evasive: hold all fire, avoid contact, RTB early
    evasive = {
        weapon_control_status_air        = 2,   -- Hold
        weapon_control_status_surface    = 2,
        weapon_control_status_subsurface = 2,
        weapon_control_status_land       = 2,
        use_ammunition                   = 'no',
        fuel_state_rtb                   = 'bingo',
        weapon_state_rtb                 = 'winchester',
        engage_non_hostile_targets       = 'no',
        ignore_plotted_course            = 'yes',
    },

    --- ASW hunter: sub-tight, all others hold
    asw_hunter = {
        weapon_control_status_air        = 2,   -- Hold
        weapon_control_status_surface    = 2,
        weapon_control_status_subsurface = 0,   -- Free
        weapon_control_status_land       = 2,
        anti_submarine_warfare           = 'yes',
        use_ammunition                   = 'yes',
    },
}

-- ============================================================
-- APPLY DOCTRINE
-- ============================================================

--- Apply a doctrine table to a side, unit, or mission.
---
--- @param target     string  Side name, unit GUID, or mission GUID
--- @param targetType string  'side'|'unit'|'mission'|'group'
--- @param doctrine   table   Doctrine fields table
--- @return boolean
---
--- EXAMPLE:
---   Doc.applyDoctrine('ship-guid', 'unit', {weapon_control_status_air=0})
function Doc.applyDoctrine(target, targetType, doctrine)
    if not target or not doctrine then return false end

    local selector
    if     targetType == 'side'    then selector = { side    = target }
    elseif targetType == 'unit'    then selector = { guid    = target }
    elseif targetType == 'mission' then selector = { mission = target }
    elseif targetType == 'group'   then selector = { group   = target }
    else
        print('[Doctrine] applyDoctrine: unknown targetType: ' .. tostring(targetType))
        return false
    end

    local ok, err = pcall(ScenEdit_SetDoctrine, selector, doctrine)
    if not ok then
        print('[Doctrine] applyDoctrine error: ' .. tostring(err))
        return false
    end
    return true
end

--- Apply a named profile (from Doc.PROFILES) to a target.
---
--- @param target     string
--- @param targetType string
--- @param profileName string  Key in Doc.PROFILES (or custom table)
--- @return boolean
---
--- EXAMPLE:
---   Doc.applyProfile('USA', 'side', 'offensive')
function Doc.applyProfile(target, targetType, profileName)
    local profile = type(profileName) == 'table' and profileName
                 or Doc.PROFILES[profileName]
    if not profile then
        print('[Doctrine] applyProfile: unknown profile: ' .. tostring(profileName))
        return false
    end
    return Doc.applyDoctrine(target, targetType, profile)
end

-- ============================================================
-- WCS HELPERS
-- ============================================================

--- Set Weapon Control Status for one or more domains.
---
--- @param target     string
--- @param targetType string
--- @param wcs        table   {air=0, surface=1, subsurface=2, land=0}
---                            Values: 0=Free, 1=Tight, 2=Hold
--- @return boolean
---
--- EXAMPLE:
---   Doc.setWCS('USA', 'side', {air=0, surface=0, subsurface=2, land=2})
function Doc.setWCS(target, targetType, wcs)
    local doctrine = {}
    if wcs.air        ~= nil then doctrine.weapon_control_status_air        = wcs.air        end
    if wcs.surface    ~= nil then doctrine.weapon_control_status_surface    = wcs.surface    end
    if wcs.subsurface ~= nil then doctrine.weapon_control_status_subsurface = wcs.subsurface end
    if wcs.land       ~= nil then doctrine.weapon_control_status_land       = wcs.land       end
    return Doc.applyDoctrine(target, targetType, doctrine)
end

--- Set weapons free for all domains.
---
--- @param target     string
--- @param targetType string
--- @return boolean
function Doc.weaponsFree(target, targetType)
    return Doc.setWCS(target, targetType,
        { air=Doc.WCS.FREE, surface=Doc.WCS.FREE,
          subsurface=Doc.WCS.FREE, land=Doc.WCS.FREE })
end

--- Set weapons hold for all domains (cease fire).
---
--- @param target     string
--- @param targetType string
--- @return boolean
function Doc.weaponsHold(target, targetType)
    return Doc.setWCS(target, targetType,
        { air=Doc.WCS.HOLD, surface=Doc.WCS.HOLD,
          subsurface=Doc.WCS.HOLD, land=Doc.WCS.HOLD })
end

-- ============================================================
-- FUEL / WEAPON RTB THRESHOLDS
-- ============================================================

--- Set when a unit returns to base based on fuel/weapon state.
---
--- @param target        string
--- @param targetType    string
--- @param fuelRtb       string  'bingo'|'winchester'|'custom'
--- @param weaponRtb     string  'winchester'|'custom'
--- @param fuelCustomPct number|nil  Custom fuel % threshold (when fuelRtb='custom')
--- @param wpnCustomPct  number|nil  Custom weapon % threshold
--- @return boolean
function Doc.setRtbThresholds(target, targetType, fuelRtb, weaponRtb, fuelCustomPct, wpnCustomPct)
    local doctrine = {
        fuel_state_rtb   = fuelRtb   or 'bingo',
        weapon_state_rtb = weaponRtb or 'winchester',
    }
    if fuelCustomPct then
        doctrine.fuel_state_rtb_custom   = fuelCustomPct
    end
    if wpnCustomPct then
        doctrine.weapon_state_rtb_custom = wpnCustomPct
    end
    return Doc.applyDoctrine(target, targetType, doctrine)
end

-- ============================================================
-- COPY DOCTRINE
-- ============================================================

--- Read the doctrine from a template unit and apply it to another unit.
---
--- @param templateGuid string  Source unit GUID
--- @param targetGuid   string  Destination unit GUID
--- @return boolean
---
--- EXAMPLE:
---   Doc.copyDoctrine('veteran-ship-guid', 'new-ship-guid')
function Doc.copyDoctrine(templateGuid, targetGuid)
    local unit = ScenEdit_GetUnit({ guid = templateGuid })
    if not unit then
        print('[Doctrine] copyDoctrine: template unit not found: ' .. tostring(templateGuid))
        return false
    end

    local doctrine = unit.doctrine
    if not doctrine then
        print('[Doctrine] copyDoctrine: no doctrine on template unit')
        return false
    end

    -- Extract writeable doctrine fields
    local copy = {
        weapon_control_status_air        = doctrine.weapon_control_status_air,
        weapon_control_status_surface    = doctrine.weapon_control_status_surface,
        weapon_control_status_subsurface = doctrine.weapon_control_status_subsurface,
        weapon_control_status_land       = doctrine.weapon_control_status_land,
        fuel_state_rtb                   = doctrine.fuel_state_rtb,
        weapon_state_rtb                 = doctrine.weapon_state_rtb,
        use_ammunition                   = doctrine.use_ammunition,
        engage_non_hostile_targets       = doctrine.engage_non_hostile_targets,
        air_intercept                    = doctrine.air_intercept,
        anti_surface_warfare             = doctrine.anti_surface_warfare,
        anti_submarine_warfare           = doctrine.anti_submarine_warfare,
    }

    return Doc.applyDoctrine(targetGuid, 'unit', copy)
end

--- Get the current doctrine table for a unit (read-only).
---
--- @param unitGuid string
--- @return table|nil  Doctrine fields or nil if unit not found
function Doc.getDoctrine(unitGuid)
    local unit = ScenEdit_GetUnit({ guid = unitGuid })
    if not unit then return nil end
    return unit.doctrine
end

return Doc
