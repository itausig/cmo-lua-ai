# CMO Lua API — Enumerated Types Reference

All enumerated constants, code values, and option strings used across the CMO Lua API.

> **Cross-references:** [FUNCTIONS.md](./FUNCTIONS.md) | [WRAPPERS.md](./WRAPPERS.md) | [DATA_TYPES.md](./DATA_TYPES.md)

---

## Table of Contents

1. [UnitType](#1-unittype)
2. [MissionClass](#2-missionclass)
3. [Weapon Control Status (WCS)](#3-weapon-control-status-wcs)
4. [Side Posture Codes](#4-side-posture-codes)
5. [LoadoutRole](#5-loadoutrole)
6. [LoadoutTimeOfDay](#6-loadouttimeofday)
7. [LoadoutWeather](#7-loadoutweather)
8. [Contact Classification Levels](#8-contact-classification-levels)
9. [Throttle Presets](#9-throttle-presets)
10. [Altitude Presets](#10-altitude-presets)
11. [Depth Presets (Submarines)](#11-depth-presets-submarines)
12. [Trigger Types](#12-trigger-types)
13. [Action Types](#13-action-types)
14. [Condition Types](#14-condition-types)
15. [Target Types](#15-target-types)
16. [Doctrine Option Values](#16-doctrine-option-values)
17. [Proficiency Levels](#17-proficiency-levels)
18. [Awareness Levels](#18-awareness-levels)
19. [EMCON States](#19-emcon-states)
20. [Sensor Types](#20-sensor-types)
21. [Weapon Guidance Types](#21-weapon-guidance-types)
22. [Time of Day Values](#22-time-of-day-values)
23. [Waypoint Types](#23-waypoint-types)
24. [Zone Types](#24-zone-types)
25. [BVR Logic Values](#25-bvr-logic-values)

---

## 1. UnitType

Numeric IDs used in `unit.typed`, `ScenEdit_AddUnit({type=...})` (string form), and trigger target filters.

| Name | Numeric ID | String Form | Description |
|------|-----------|-------------|-------------|
| `Aircraft` | `1` | `'Aircraft'` | Fixed-wing and rotary aircraft |
| `Ship` | `2` | `'Ship'` | Surface vessels |
| `Submarine` | `3` | `'Submarine'` | Submerged vessels |
| `Facility` | `4` | `'Facility'` | Ground installations, bases |
| `Aimpoint` | `5` | `'Aimpoint'` | Precision aim point (subset of facility) |
| `Weapon` | `6` | `'Weapon'` | In-flight weapons (missiles, torpedoes) |
| `Satellite` | `7` | `'Satellite'` | Orbital assets |

**Usage:**
```lua
-- Add a facility
ScenEdit_AddUnit({side='OPFOR', type='Facility', name='Command Bunker', dbid=1000, lat=36.5, lon=-10.0})

-- Filter units by numeric type
local side = VP_GetSide({Side='USA'})
for _, u in ipairs(side.units) do
    if u.typed == 1 then  -- Aircraft
        print('Aircraft: ' .. u.name)
    end
end
```

---

## 2. MissionClass

Used in `Mission.type` (numeric) and `Mission.typeS` (string).

| Name | Numeric | String | Description |
|------|---------|--------|-------------|
| `None` | `0` | `'none'` | No specific mission type |
| `Strike` | `1` | `'strike'` | Strike against specific targets |
| `Patrol` | `2` | `'patrol'` | Area patrol / search |
| `Support` | `3` | `'support'` | AAR, AEW, jamming support |
| `Ferry` | `4` | `'ferry'` | Transit flight |
| `Mining` | `5` | `'mining'` | Mine laying |
| `MineClearing` | `6` | `'mineclearing'` | Mine sweeping |
| `Escort` | `7` | `'escort'` | Escorting another mission |
| `Cargo` | `8` | `'cargo'` | Cargo transport |

**Patrol sub-types** (used in `ScenEdit_AddMission` options `{type=...}`):

| Value | Description |
|-------|-------------|
| `'air'` | Anti-air / CAP patrol |
| `'sub'` | Anti-submarine patrol (ASW) |
| `'naval'` | Anti-surface patrol |
| `'land'` | Land attack patrol |

**Strike sub-types:**

| Value | Description |
|-------|-------------|
| `'land'` | Strike against land targets |
| `'sub'` | Strike against submarines |
| `'air'` | Strike against airborne targets |

**Support sub-types:**

| Value | Description |
|-------|-------------|
| `'aew'` | Airborne early warning |
| `'tand'` | Tanker (AAR) |
| `'aar'` | Air-to-air refueling (receiver) |
| `'jammer'` | Electronic warfare / jamming |
| `'lofar'` | Low-frequency acoustic ranging |

**Usage:**
```lua
local m = ScenEdit_GetMission('USA', 'Alpha Strike')
if m.type == 1 then  -- Strike
    print('Strike targets: ' .. #m.targetlist)
end
-- or using typeS
if m.typeS == 'patrol' then
    print('Patrol mission')
end
```

---

## 3. Weapon Control Status (WCS)

Used in `Doctrine.weapon_control_status_*` fields and `ScenEdit_SetDoctrine()`.

| Name | Value | Description |
|------|-------|-------------|
| `Free` | `0` | Weapons free — engage any valid target |
| `Tight` | `1` | Weapons tight — engage only designated targets |
| `Hold` | `2` | Weapons hold — do not engage |

**Usage:**
```lua
-- Set weapons free for all categories
ScenEdit_SetDoctrine({side='USA'}, {
    weapon_control_status_air        = 0,  -- Free
    weapon_control_status_surface    = 0,
    weapon_control_status_subsurface = 1,  -- Tight
    weapon_control_status_land       = 2   -- Hold
})
```

---

## 4. Side Posture Codes

Used in `ScenEdit_SetSidePosture(sideA, sideB, code)` and returned by `ScenEdit_GetSidePosture()`.

| Code | Full Name | Description |
|------|-----------|-------------|
| `'H'` | `Hostile` | Will engage on detection |
| `'N'` | `Neutral` | Will not engage unless fired upon |
| `'F'` | `Friendly` | Treated as friendly, will cooperate |
| `'U'` | `Unfriendly` | Distrusted but not actively hostile |

**Note:** Postures are **asymmetric** — sideA can be Hostile to sideB while sideB is Neutral to sideA. Set both directions explicitly.

**Usage:**
```lua
-- Trigger a war between Russia and USA
ScenEdit_SetSidePosture('Russia', 'USA', 'H')
ScenEdit_SetSidePosture('USA', 'Russia', 'H')

-- Make Iran unfriendly (not yet hostile)
ScenEdit_SetSidePosture('Iran', 'USA', 'U')
ScenEdit_SetSidePosture('USA', 'Iran', 'U')
```

---

## 5. LoadoutRole

Role codes used in `Loadout.roles` array. Determine when a loadout is selected automatically.

### Primary Mission Roles

| Name | Code | Description |
|------|------|-------------|
| `None` | `1001` | No role (catch-all) |
| `Intercept_BVR` | `2001` | Beyond Visual Range intercept |
| `Intercept_WVR` | `2002` | Within Visual Range intercept |
| `Intercept_BVR_WVR` | `2003` | BVR + WVR combined |
| `CAS` | `3001` | Close Air Support |
| `DAS` | `3002` | Deep Air Support |
| `Strike_Land` | `4001` | Strike vs land targets |
| `Strike_Ship` | `4002` | Strike vs surface ships |
| `Strike_Sub` | `4003` | Strike vs submarines |
| `SEAD` | `4004` | Suppression of Enemy Air Defenses |
| `EW_Jamming` | `5001` | Electronic warfare / jamming |
| `AEW` | `5002` | Airborne Early Warning |
| `Tanker` | `5003` | Air-to-air refueling tanker |
| `Recon` | `6001` | Reconnaissance |
| `ASW_Patrol` | `7001` | Anti-submarine patrol |
| `ASW_Attack` | `7002` | Anti-submarine attack |
| `Mining` | `8001` | Mine laying |
| `Ferry` | `9001` | Ferry / transit |

**Usage:**
```lua
local loadout = ScenEdit_GetLoadout({UnitNameOrID='VFA-105 Alpha'})
for _, role in ipairs(loadout.roles) do
    if role == 4002 then
        print('This loadout is configured for anti-ship strike')
    end
end
```

---

## 6. LoadoutTimeOfDay

Restricts loadout availability to specific lighting conditions.

| Name | Code | Description |
|------|------|-------------|
| `None` | `1001` | No restriction (any time) |
| `DayNight` | `2001` | Available day and night |
| `NightOnly` | `2002` | Night operations only |
| `DayOnly` | `2003` | Day operations only |

---

## 7. LoadoutWeather

Restricts loadout availability by weather conditions.

| Name | Code | Description |
|------|------|-------------|
| `None` | `1001` | No restriction |
| `AllWeather` | `2001` | Usable in all weather |
| `LimitedAllWeather` | `2002` | Some weather restriction |
| `ClearWeather` | `2003` | Clear conditions required |

---

## 8. Contact Classification Levels

Used in `Contact.classificationlevel`. Reflects how well a contact is identified.

| Value | Description |
|-------|-------------|
| `'Unknown'` | Contact detected but not yet classified |
| `'Suspect'` | Probable type inferred from emissions/signature |
| `'Identified'` | Type confirmed by sensors |
| `'Recognized'` | Fully classified including specific platform |

**Note:** `Contact.actualunitid` is only populated when classification is `'Identified'` or `'Recognized'`.

**Usage:**
```lua
local side = VP_GetSide({Side='USA'})
for _, c in ipairs(side.contacts) do
    if c.classificationlevel == 'Identified' and c.typed == 2 then  -- Identified ship
        print('Identified ship: ' .. c.name .. ' at ' .. c.latitude .. ',' .. c.longitude)
    end
end
```

---

## 9. Throttle Presets

String values for `Waypoint.presetThrottle` and unit speed instructions.

| Value | Description |
|-------|-------------|
| `'Loiter'` | Minimum fuel-efficient speed |
| `'Cruise'` | Standard cruise speed |
| `'Full'` | Full military power (no afterburner) |
| `'Flank'` | Maximum speed (afterburner for aircraft, emergency speed for ships) |
| `'Optimal'` | AI selects best speed for the mission |
| `'Sprint'` | High-speed dash (submarine tactic) |
| `'Drift'` | Minimal speed / near-silent (submarine tactic) |

---

## 10. Altitude Presets

String values for `Waypoint.presetAltitude` and aircraft altitude instructions.

| Value | Description |
|-------|-------------|
| `'Low'` | Low altitude (terrain-following) |
| `'Medium'` | Medium altitude |
| `'High'` | High altitude |
| `'VeryHigh'` | Very high altitude |
| `'Optimal'` | AI selects optimal altitude |
| `'GroundLevel'` | On the ground / sea level |
| `'Periscope'` | Periscope depth (submarine, see Depth Presets) |

---

## 11. Depth Presets (Submarines)

String values for `Waypoint.presetDepth` on submarine waypoints.

| Value | Description |
|-------|-------------|
| `'Periscope'` | Periscope depth (~18m) |
| `'Shallow'` | Shallow depth |
| `'Deep'` | Deep depth |
| `'VeryDeep'` | Very deep (near thermal layer) |
| `'Optimal'` | AI selects optimal depth |
| `'Snort'` | Snorkel depth (diesel submarines) |

---

## 12. Trigger Types

Used in `ScenEdit_SetTrigger({type=...})`. Defines what event triggers a TCA chain.

| Type String | Description | Key Parameters |
|-------------|-------------|----------------|
| `'Points'` | Side score reaches a value | `side`, `score`, `direction` (`'above'`/`'below'`) |
| `'RandomTime'` | Fires randomly within a time window | `starttime`, `endtime`, `probability` |
| `'RegularTime'` | Fires at regular intervals | `interval` (seconds) |
| `'ScenEnded'` | Fires when scenario ends | — |
| `'ScenLoaded'` | Fires when scenario is loaded/started | — |
| `'Time'` | Fires at a specific time | `time` (DateTime) |
| `'UnitDamaged'` | Unit takes damage | `unitId`, `sideId`, `damagetype`, `thresholdPercent` |
| `'UnitDestroyed'` | Unit is destroyed | `unitId`, `sideId`, `includesubunits` |
| `'UnitDetected'` | Unit is detected by side | `unitId`, `detectingSideId`, `byType` |
| `'UnitEmissions'` | Unit emits in specified state | `unitId`, `emissionState` |
| `'UnitEntersArea'` | Unit enters a defined area | `unitId`, `sideId`, `area`, `targetSide` |
| `'UnitRemainsInArea'` | Unit stays in area | `unitId`, `sideId`, `area`, `duration` |
| `'UnitBaseStatus'` | Unit base/carrier assignment changes | `unitId` |
| `'UnitCargoMoved'` | Cargo unit moved | `unitId` |

**Usage:**
```lua
-- Create a time trigger at 0200 local
ScenEdit_SetTrigger({
    name = 'DawnTrigger',
    type = 'Time',
    time = '2027-06-09 02:00:00!yyyy-MM-dd HH:mm:ss'
})

-- Create a unit-enters-area trigger
ScenEdit_SetTrigger({
    name       = 'EnemyInZone',
    type       = 'UnitEntersArea',
    targetSide = 'OPFOR',
    area       = {'Zone-NW','Zone-NE','Zone-SE','Zone-SW'}
})
```

---

## 13. Action Types

Used in `ScenEdit_SetAction({type=...})`. Defines what happens when an event fires.

| Type String | Description | Key Parameters |
|-------------|-------------|----------------|
| `'ChangeMissionStatus'` | Activate/deactivate a mission | `mission`, `isActive` |
| `'EndScenario'` | Ends the scenario | — |
| `'LuaScript'` | Executes arbitrary Lua code | `scriptText` |
| `'Message'` | Sends a message to a side | `side`, `message` |
| `'Points'` | Awards/deducts points | `side`, `points` |
| `'TeleportInArea'` | Teleports unit to random position in area | `unitId`, `area` |

**Usage:**
```lua
-- Create a Lua script action
ScenEdit_SetAction({
    name       = 'SpawnReinforcements',
    type       = 'LuaScript',
    scriptText = [[
        ScenEdit_AddUnit({
            side='OPFOR', type='Ship',
            name='Reinforcement Frigate',
            dbid=1150, latitude=35.0, longitude=-12.0
        })
    ]]
})

-- Create a points action
ScenEdit_SetAction({
    name   = 'AwardStrikePoints',
    type   = 'Points',
    side   = 'USA',
    points = 100
})
```

---

## 14. Condition Types

Used in `ScenEdit_SetCondition({type=...})`. Conditions gate event execution — the event only fires if all conditions pass.

| Type String | Description | Key Parameters |
|-------------|-------------|----------------|
| `'LuaScript'` | Lua expression that returns true/false | `scriptText` (must `return true/false`) |
| `'ScenHasStarted'` | True after scenario clock starts | — |
| `'SidePosture'` | True when sides have specified posture | `sideA`, `sideB`, `posture` |

**Usage:**
```lua
-- Lua condition: only fire if a key is set
ScenEdit_SetCondition({
    name       = 'PhaseTwo',
    type       = 'LuaScript',
    scriptText = 'return ScenEdit_GetKeyValue("phase") == "2"'
})

-- Posture condition
ScenEdit_SetCondition({
    name    = 'WarStarted',
    type    = 'SidePosture',
    sideA   = 'Russia',
    sideB   = 'USA',
    posture = 'Hostile'
})
```

**Important:** Lua condition scripts must explicitly `return true` or `return false`. A script that returns `nil` (no return statement) is treated as `false`.

---

## 15. Target Types

Target type strings used in `DoctrineWRA`, trigger `TargetFilter`, and doctrine settings.

### Air Targets

| Value | Description |
|-------|-------------|
| `'Air_Contact_Unknown_Type'` | Unknown air contact |
| `'Air_Fighter'` | Fighter aircraft |
| `'Air_Bomber'` | Bomber aircraft |
| `'Air_AEW'` | Airborne early warning |
| `'Air_Tanker'` | Tanker aircraft |
| `'Air_Recon'` | Reconnaissance |
| `'Air_Helicopter'` | Helicopters |
| `'Air_UAV'` | Unmanned aerial vehicles |
| `'Air_UCAv'` | Unmanned combat air vehicles |
| `'Air_Missile'` | Missiles in flight |
| `'Air_Decoy'` | Air decoys |

### Surface Targets

| Value | Description |
|-------|-------------|
| `'Surface_Contact_Unknown_Type'` | Unknown surface contact |
| `'Surface_Ship_Warship'` | Warships (combatants) |
| `'Surface_Ship_Carrier'` | Aircraft carriers |
| `'Surface_Ship_Amphibious'` | Amphibious ships |
| `'Surface_Ship_Support'` | Support/auxiliary vessels |
| `'Surface_Ship_Submarine_Snorkeling'` | Snorkeling submarine |

### Subsurface Targets

| Value | Description |
|-------|-------------|
| `'Sub_Contact_Unknown_Type'` | Unknown sub contact |
| `'Sub_Nuclear'` | Nuclear-powered submarine |
| `'Sub_Conventional'` | Conventional submarine |

### Land Targets

| Value | Description |
|-------|-------------|
| `'Land_Structure_Military_Heavy'` | Hardened military structures |
| `'Land_Structure_Military_Soft'` | Soft military structures |
| `'Land_Structure_Civilian'` | Civilian structures |
| `'Land_Mobile_Military'` | Mobile military units |

### TargetFilter Table

Used in triggers and mission options:
```lua
{
    TargetSide      = string,   -- Side name to filter on
    TargetType      = string,   -- Unit type (see UnitType)
    TargetSubType   = string,   -- Unit subtype string
    SpecificUnitClass = string, -- Specific class name
    SpecificUnitID  = string    -- Specific unit GUID
}
```

---

## 16. Doctrine Option Values

Boolean string options used in `ScenEdit_SetDoctrine()`. All accept `'yes'` or `'no'` unless noted.

### Engagement Doctrine

| Field | Values | Description |
|-------|--------|-------------|
| `engage_opportunity_targets` | `'yes'`, `'no'` | Engage targets of opportunity |
| `ignore_emcon_while_under_attack` | `'yes'`, `'no'` | Break EMCON if attacked |
| `auto_evade` | `'yes'`, `'no'` | Automatically evade incoming weapons |
| `use_refueling` | `'yes'`, `'no'` | Accept air-to-air refueling |
| `refuel_unrep_allied` | `'yes'`, `'no'` | Accept AAR from allied (not own side) tankers |

### Withdrawal Doctrine

| Field | Values | Description |
|-------|--------|-------------|
| `withdraw_on_fuel_state_auto` | `'yes'`, `'no'` | Auto-RTB when fuel hits bingo |
| `withdraw_on_attack` | `'yes'`, `'no'` | RTB when attacked |
| `withdraw_on_weapon_state` | `'yes'`, `'no'` | RTB when winchester |
| `rtb_when_winchester` | `'yes'`, `'no'` | RTB when out of all weapons |

### Aircraft Doctrine

| Field | Values | Description |
|-------|--------|-------------|
| `gun_strafing` | `'yes'`, `'no'` | Use guns for strafing |
| `buzz_fuse` | `'yes'`, `'no'` | Use proximity fuze |
| `taxi_unassigned` | `'yes'`, `'no'` | Move aircraft to aprons when unassigned |
| `maintain_standoff` | `'yes'`, `'no'` | Maintain standoff distance |

### Submarine Doctrine

| Field | Values | Description |
|-------|--------|-------------|
| `dive_on_threat` | `'yes'`, `'no'` | Submerge when threat detected |
| `snort_necessary` | `'yes'`, `'no'` | Only snort when battery is low |
| `avoid_cavitation_auto` | `'yes'`, `'no'` | Auto-adjust speed to avoid cavitation |
| `sprint_drift` | `'yes'`, `'no'` | Use sprint-and-drift tactics |
| `attack_periscope_depth` | `'yes'`, `'no'` | Attack subs at periscope depth |

### ASW Doctrine

| Field | Values | Description |
|-------|--------|-------------|
| `drop_active_sono` | `'yes'`, `'no'` | Deploy active sonobuoys |
| `use_dipping_sonar` | `'yes'`, `'no'` | Use helicopter dipping sonar |

### BVR Logic (see next section)

| Field | Values |
|-------|--------|
| `bvr_logic` | See [BVR Logic Values](#25-bvr-logic-values) |

---

## 17. Proficiency Levels

Used in `ScenEdit_AddUnit({proficiency=...})`, `ScenEdit_SetUnit()`, `ScenEdit_SetSideOptions()`.

| Value | Description |
|-------|-------------|
| `'Novice'` | Lowest skill, poor accuracy and decision-making |
| `'Cadet'` | Below average |
| `'Regular'` | Average proficiency (default) |
| `'Veteran'` | Above average |
| `'Ace'` | Elite: best accuracy, most aggressive tactics |

**Usage:**
```lua
-- Spawn elite fighter pilots
ScenEdit_AddUnit({
    side='USA', type='Aircraft', name='Top Gun Alpha',
    dbid=300, latitude=36.0, longitude=-10.0,
    proficiency='Ace'
})

-- Downgrade all OPFOR units
local opfor = VP_GetSide({Side='OPFOR'})
for _, u in ipairs(opfor.units) do
    ScenEdit_SetUnit({guid=u.guid, proficiency='Novice'})
end
```

---

## 18. Awareness Levels

Used in `ScenEdit_SetSideOptions({awareness=...})`.

| Value | Description |
|-------|-------------|
| `'Blind'` | Cannot detect own units beyond direct sensor range |
| `'Blissful'` | Normal AI awareness |
| `'Withit'` | Heightened awareness |
| `'Omniscient'` | Knows exact location of all own units and contacts |

---

## 19. EMCON States

Used in `ScenEdit_SetEMCON()` settings string values.

| Value | Description |
|-------|-------------|
| `'Active'` | Emit actively (radar transmitting, active sonar pinging) |
| `'Passive'` | Listen only (no emissions) |
| `'Nominal'` | Use the doctrine/default setting |

**Sensor type keys for EMCON string:**

| Key | Description |
|-----|-------------|
| `'Radar'` | All radar emitters |
| `'Sonar'` | All sonar emitters |
| `'ECM'` | Electronic countermeasures |
| `'TACAN'` | TACAN navigation beacons |
| `'IFF'` | Identification Friend or Foe |
| `'Link'` | Data link transmitters |

**Example:**
```lua
-- Full emissions blackout
ScenEdit_SetEMCON('Unit', 'USS Nimitz', 'Radar=Passive;Sonar=Passive;ECM=Passive;TACAN=Passive;IFF=Passive')

-- Active operations
ScenEdit_SetEMCON('Side', 'USA', 'Radar=Active;Sonar=Active;ECM=Nominal')
```

---

## 20. Sensor Types

Used in `Sensor.type` and `ScenEdit_UpdateUnit({mode='add_sensor'})`.

| Value | Description |
|-------|-------------|
| `'Radar'` | Radio frequency radar |
| `'Sonar'` | Active or passive sonar |
| `'ESM'` | Electronic Support Measures (passive RF listening) |
| `'Visual'` | Optical/visual sensor |
| `'IR'` | Infrared sensor |
| `'MAD'` | Magnetic Anomaly Detector |
| `'Laser'` | Laser rangefinder/designator |
| `'IRST'` | Infrared Search and Track |
| `'HullSonar'` | Hull-mounted sonar |
| `'TowedArray'` | Towed sonar array |
| `'Dipping'` | Dipping sonar (helicopter) |
| `'Sonobuoy'` | Sonobuoy (active or passive) |

---

## 21. Weapon Guidance Types

Used in `Weapon.guidance`.

| Value | Description |
|-------|-------------|
| `'ARH'` | Active Radar Homing (fire and forget) |
| `'SARH'` | Semi-Active Radar Homing (requires illumination) |
| `'IR'` | Infrared homing |
| `'TV'` | Television/optical guidance |
| `'Laser'` | Laser guided |
| `'GPS'` | GPS/satellite guidance |
| `'INS'` | Inertial navigation |
| `'INS/GPS'` | INS with GPS correction |
| `'MIL'` | Millimeter-wave radar |
| `'Wire'` | Wire-guided (torpedoes) |
| `'Unguided'` | No guidance (dumb bombs, ballistic) |
| `'Command'` | Command/datalink guided |
| `'TASM'` | Terrain-following cruise missile guidance |
| `'Anti-Radiation'` | Anti-radiation (homes on radar emissions) |

---

## 22. Time of Day Values

Returned by `ScenEdit_GetTimeOfDay()`.

| Value | Description |
|-------|-------------|
| `'Day'` | Daylight hours |
| `'Dusk'` | Transition from day to night |
| `'Night'` | Nighttime |
| `'Dawn'` | Transition from night to day |

**Usage:**
```lua
local tod = ScenEdit_GetTimeOfDay()
if tod == 'Night' or tod == 'Dawn' then
    -- Use night loadouts
    ScenEdit_SetLoadout({
        UnitNameOrID = 'Strike Package Alpha',
        LoadoutID    = 99201,   -- Night strike loadout
        TimeToReady_Minutes = 30
    })
end
```

---

## 23. Waypoint Types

Used in `Waypoint.type`.

| Value | Description |
|-------|-------------|
| `'Normal'` | Standard waypoint |
| `'Turn'` | Turn point (changes course without lingering) |
| `'Hold'` | Loiter at this point until ordered |
| `'Strike'` | Strike waypoint (initiates weapon release) |
| `'Refuel'` | Air-to-air refueling rendezvous |
| `'Land'` | Landing waypoint |
| `'Takeoff'` | Takeoff waypoint |

---

## 24. Zone Types

Used in `ScenEdit_AddZone()`, `ScenEdit_SetZone()`, `ScenEdit_RemoveZone()`.

| Type String | Description |
|-------------|-------------|
| `'exclusion'` | Units must not enter; trespassers treated per `markas` |
| `'nonavigation'` | Navigation restriction (units avoid or are stopped) |
| `'standard'` | General purpose zone (for triggers, display, custom logic) |
| `'customenvironment'` | Overrides weather/environment within zone boundary |

---

## 25. BVR Logic Values

Used in `Doctrine.bvr_logic` and `ScenEdit_SetDoctrine()`.

| Value | Description |
|-------|-------------|
| `'Pilot'` | Pilot decides optimal BVR engagement |
| `'WCS'` | Follow weapon control status strictly |
| `'Standoff'` | Maximize standoff range |
| `'Engage'` | Engage at first opportunity |
| `'Disengage'` | Avoid BVR engagement; prefer WVR or RTB |

---

## Quick Reference: String vs. Number

Many CMO functions accept either a **name** (string) or **GUID** (string). A few accept numeric IDs for database items. This table summarizes common patterns:

| Parameter type | Best practice | Example |
|----------------|--------------|---------|
| Unit identifier | Prefer GUID | `{guid='a1b2c3...'}` |
| Side identifier | Name is stable | `'USA'` |
| Mission identifier | Either; GUID preferred | `mission.guid` |
| DB item (unit class, weapon, sensor) | Numeric `dbid` | `dbid=278` |
| Event identifier | GUID preferred | `ScenEdit_EventX().guid` |
| Reference point | Name or GUID | `name='Alpha'` |

---

*End of ENUMS.md*

> **See also:** [FUNCTIONS.md](./FUNCTIONS.md) | [WRAPPERS.md](./WRAPPERS.md) | [DATA_TYPES.md](./DATA_TYPES.md)
