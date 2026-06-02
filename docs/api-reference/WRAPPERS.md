# CMO Lua API — Wrapper Objects Reference

All CMO Lua functions return **wrapper objects** — Lua tables with fields (properties) and methods. Fields marked **RW** are read-write; fields marked **RO** are read-only.

> **Cross-references:** [FUNCTIONS.md](./FUNCTIONS.md) | [ENUMS.md](./ENUMS.md)

---

## Table of Contents

1. [Unit](#1-unit)
2. [Contact](#2-contact)
3. [Side](#3-side)
4. [Mission](#4-mission)
5. [Doctrine](#5-doctrine)
6. [DoctrineWRA](#6-doctrinewra)
7. [Magazine](#7-magazine)
8. [Loadout](#8-loadout)
9. [Event](#9-event)
10. [Scenario](#10-scenario)
11. [ReferencePoint](#11-referencepoint)
12. [Zone](#12-zone)
13. [Group](#13-group)
14. [Cargo](#14-cargo)
15. [Sensor](#15-sensor)
16. [Waypoint](#16-waypoint)
17. [Weapon](#17-weapon)
18. [SpecialAction](#18-specialaction)

---

## 1. Unit

Returned by `ScenEdit_GetUnit()`, `ScenEdit_AddUnit()`, `VP_GetUnit()`, `ScenEdit_UnitX()`, and unit lists on `Side`.

### Identity Fields

| Field | Type | R/W | Description |
|-------|------|-----|-------------|
| `guid` | `string` | RO | Unique identifier. **Always store and use this** — names can change. |
| `name` | `string` | RW | Display name. |
| `side` | `string` | RO | Side name this unit belongs to. |
| `type` | `string` | RO | Unit type: `'Aircraft'`, `'Ship'`, `'Submarine'`, `'Facility'`, `'Satellite'` |
| `subtype` | `string` | RO | Subtype string (e.g., `'Fighter'`, `'Destroyer'`, `'SSN'`) |
| `dbid` | `number` | RO | Database ID of the unit class |

### Position & Movement

| Field | Type | R/W | Description |
|-------|------|-----|-------------|
| `latitude` | `number` | RW | Decimal degrees (-90 to 90) |
| `longitude` | `number` | RW | Decimal degrees (-180 to 180) |
| `altitude` | `number` | RW | Altitude in meters (negative = depth for submarines) |
| `heading` | `number` | RW | 0–360 degrees |
| `speed` | `number` | RW | Current speed in knots |
| `course` | `table` | RW | Array of waypoints `{latitude, longitude, altitude}` |
| `groundSpeed` | `number` | RO | Ground speed in knots |
| `pitch` | `number` | RO | Pitch angle in degrees |
| `desiredAltitude` | `number` | RW | Target altitude the unit is attempting to reach |
| `desiredSpeed` | `number` | RW | Target speed |
| `desiredHeading` | `number` | RW | Target heading |
| `manualAltitude` | `boolean` | RW | If true, altitude is manually overridden |
| `manualSpeed` | `boolean` | RW | If true, speed is manually overridden |

### Status Fields

| Field | Type | R/W | Description |
|-------|------|-----|-------------|
| `fuel` | `table` | RO | Fuel state table `{current, max, percent}` |
| `fuelstate` | `string` | RO | Fuel state code: `'OK'`, `'Bingo'`, `'Winchester'` |
| `weaponstate` | `string` | RO | Weapon state code |
| `unitstate` | `string` | RO | Overall unit state string |
| `condition` | `string` | RO | Readable condition string |
| `condition_v` | `number` | RO | Numeric condition value (0–100, 100=undamaged) |
| `damage` | `table` | RO | Damage state `{structural=number, components={...}}` |
| `IsDestroyed` | `boolean` | RO | `true` if unit has been destroyed |
| `isSinking` | `boolean` | RO | `true` if ship is sinking (mortally damaged but not yet gone) |
| `isOperating` | `boolean` | RO | `true` if unit is actively operating |
| `noiseLevel` | `number` | RO | Acoustic signature level |
| `signature` | `table` | RO | Signature values by type (radar, IR, etc.) |
| `jammed` | `boolean` | RO | `true` if unit is currently being jammed |
| `jammer` | `boolean` | RW | Whether the unit's jammer is active |
| `outOfComms` | `boolean` | RO | `true` if unit is out of communication range |

### Control Fields

| Field | Type | R/W | Description |
|-------|------|-----|-------------|
| `holdfire` | `boolean` | RW | Unit will not fire weapons if `true` |
| `holdposition` | `boolean` | RW | Unit will not move if `true` |
| `autodetectable` | `boolean` | RW | Visible to all sides regardless of sensor coverage |
| `obeyEMCON` | `boolean` | RW | Whether unit follows EMCON orders |
| `proficiency` | `string` | RW | `'Novice'`, `'Cadet'`, `'Regular'`, `'Veteran'`, `'Ace'` |
| `AllowMultiMission` | `boolean` | RW | Allow unit to be assigned to multiple missions |
| `SAR_enabled` | `boolean` | RW | Enable Search and Rescue behavior |
| `avoidCavitation` | `boolean` | RW | Submarine: avoid cavitation when true |
| `sprintDrift` | `boolean` | RW | Submarine: use sprint-and-drift tactic |

### Assignment & Relationships

| Field | Type | R/W | Description |
|-------|------|-----|-------------|
| `mission` | `string` | RO | GUID of assigned mission (or `nil`) |
| `base` | `string` | RO | GUID of home base |
| `group` | `string` | RO | GUID of group this unit belongs to |
| `loadoutdbid` | `number` | RO | Current loadout DB ID |
| `doctrine` | `Doctrine` | RO | Unit's doctrine settings |
| `magazines` | `table<Magazine>` | RO | Array of magazine wrappers |
| `mounts` | `table` | RO | Array of weapon mount data |
| `sensors` | `table<Sensor>` | RO | Array of sensor wrappers |

### Combat State

| Field | Type | R/W | Description |
|-------|------|-----|-------------|
| `firedOn` | `boolean` | RO | `true` if unit is being fired upon |
| `firingAt` | `table` | RO | Array of contact GUIDs this unit is firing at |
| `targetedBy` | `table` | RO | Array of contact GUIDs targeting this unit |

### Cargo & Embarked

| Field | Type | R/W | Description |
|-------|------|-----|-------------|
| `cargo` | `table<Cargo>` | RO | Array of cargo items aboard |
| `assignedUnits` | `table` | RO | Units assigned to this unit (e.g., aircraft to carrier) |
| `embarkedUnits` | `table` | RO | Units currently embarked |

### Timing Fields

| Field | Type | R/W | Description |
|-------|------|-----|-------------|
| `airbornetime_v` | `number` | RO | Seconds since unit became airborne |
| `readytime_v` | `number` | RW | Time (seconds) until unit is ready |

### Environmental

| Field | Type | R/W | Description |
|-------|------|-----|-------------|
| `weather` | `table` | RO | Local weather at unit position |
| `OODA` | `table` | RO | OODA loop state (Observe/Orient/Decide/Act) |
| `crew` | `table` | RO | Crew state information |

### Methods

#### `unit:delete()`
```lua
unit:delete() -> nil
```
Removes the unit from the scenario (equivalent to `ScenEdit_DeleteUnit`).

#### `unit:filterOnComponent(type)`
```lua
unit:filterOnComponent(type: string) -> table
```
Returns components matching the specified type string (e.g., `'sensor'`, `'weapon'`).

#### `unit:inArea(params)`
```lua
unit:inArea({area = {string, ...}}) -> boolean
```
Returns `true` if the unit is inside the polygon defined by the named reference points.

**Example:**
```lua
local unit = ScenEdit_GetUnit({name='Frigate Alpha', side='OPFOR'})
if unit:inArea({area={'PA-1','PA-2','PA-3','PA-4'}}) then
    ScenEdit_SpecialMessage('USA', 'Enemy in patrol area!')
end
```

#### `unit:Launch(bool)`
```lua
unit:Launch(bool: boolean) -> nil
```
Launches the unit (launches aircraft from carrier if `true`).

#### `unit:RTB()`
```lua
unit:RTB() -> nil
```
Commands the unit to return to base immediately.

#### `unit:rangetotarget(contactId)`
```lua
unit:rangetotarget(contactId: string) -> number
```
Returns the range in nautical miles to a specific contact.

#### `unit:getwaypoint(guid)`
```lua
unit:getwaypoint(guid: string) -> Waypoint
```
Returns a specific waypoint in the unit's current course.

#### `unit:getUnitMagazine(guid)`
```lua
unit:getUnitMagazine(guid: string) -> Magazine
```
Returns a specific magazine by GUID.

#### `unit:getUnitMountMagazine(guid)`
```lua
unit:getUnitMountMagazine(guid: string) -> Magazine
```
Returns the magazine associated with a specific weapon mount.

#### `unit:ReplenishUnit()`
```lua
unit:ReplenishUnit() -> nil
```
Fully restores unit to full fuel and ammunition.

#### `unit:dropSonobuoy(active, shallow)`
```lua
unit:dropSonobuoy(active: boolean, shallow: boolean) -> boolean
```
Commands an ASW aircraft to drop a sonobuoy at current position. `active=true` for active sonobuoy, `shallow=true` for shallow water pattern.

#### `unit:deployDippingSonar(deploy)`
```lua
unit:deployDippingSonar(deploy: boolean) -> boolean
```
Deploys (`true`) or retracts (`false`) helicopter dipping sonar.

#### `unit:createUnitCargo()`
```lua
unit:createUnitCargo() -> Cargo
```
Creates a cargo manifest entry for this unit.

#### `unit:deleteUnitCargo(cargoGuid)`
```lua
unit:deleteUnitCargo(cargoGuid: string) -> boolean
```
Removes a cargo item from this unit.

#### `unit:getUnitCargo(cargoGuid)`
```lua
unit:getUnitCargo(cargoGuid: string) -> Cargo
```
Returns a specific cargo item by GUID.

**Common Usage Pattern:**
```lua
local unit = ScenEdit_GetUnit({name='USS Nimitz', side='USA'})
if not unit then return end  -- Always nil-guard

-- Check fuel state
if unit.fuelstate == 'Bingo' then
    unit:RTB()
end

-- Check if in a zone
if unit:inArea({area={'Zone-NW','Zone-NE','Zone-SE','Zone-SW'}}) then
    ScenEdit_SetUnit({guid=unit.guid, holdfire=false})
end

-- Iterate magazines
for _, mag in ipairs(unit.magazines) do
    print(mag.name, 'capacity:', mag.capacity)
end
```

---

## 2. Contact

Returned by `VP_GetContact()`, `ScenEdit_UnitC()`, and contact lists on `Side`.

### Fields

| Field | Type | R/W | Description |
|-------|------|-----|-------------|
| `guid` | `string` | RO | Contact GUID (unique per side, not same as unit GUID) |
| `name` | `string` | RO | Contact display name |
| `latitude` | `number` | RO | Estimated latitude |
| `longitude` | `number` | RO | Estimated longitude |
| `altitude` | `number` | RO | Estimated altitude in meters |
| `heading` | `number` | RO | Estimated heading (0–360) |
| `speed` | `number` | RO | Estimated speed in knots |
| `type` | `string` | RO | Contact type code (e.g., `'Aircraft'`, `'Ship'`) |
| `typed` | `number` | RO | Numeric type ID (see [ENUMS.md — UnitType](./ENUMS.md#unittype)) |
| `type_description` | `string` | RO | Human-readable type description |
| `classificationlevel` | `string` | RO | Classification: `'Unknown'`, `'Suspect'`, `'Identified'`, `'Recognized'` |
| `actualunitid` | `string` | RO | GUID of the actual unit (only available if contact is fully identified) |
| `actualunitdbid` | `number` | RO | DB ID of actual unit class (if identified) |
| `age` | `number` | RO | Age of contact in seconds since last detection |
| `detectionBy` | `table` | RO | Array: which sensor types detected this contact |
| `emissions` | `table` | RO | Detected emissions (radar freq, IR signature, etc.) |
| `potentialmatches` | `table` | RO | Array of possible unit classes matching the contact |
| `BDA` | `table` | RO | Battle Damage Assessment data |
| `firedOn` | `boolean` | RO | `true` if contact is being fired upon |
| `firingAt` | `table` | RO | GUIDs of units this contact is firing at |
| `targetedBy` | `table` | RO | GUIDs of units targeting this contact |
| `side` | `string` | RO | Side that owns this contact record |
| `fromside` | `string` | RO | Side of the actual unit |
| `areaofuncertainty` | `table` | RO | Polygon defining location uncertainty |
| `FilterOut` | `boolean` | RW | Mark contact as filtered out from display |
| `markedAsDecoy` | `boolean` | RW | Mark contact as a decoy |
| `weather` | `table` | RO | Weather at contact location |
| `lastDetections` | `table` | RO | Array of recent detection events |

### Methods

#### `contact:DropContact()`
```lua
contact:DropContact() -> nil
```
Removes this contact from the side's contact picture.

#### `contact:inArea(params)`
```lua
contact:inArea({area = {string, ...}}) -> boolean
```
Returns `true` if the contact's estimated position is within the defined area.

**Usage Pattern:**
```lua
local side = VP_GetSide({Side='USA'})
for _, c in ipairs(side.contacts) do
    if c.type == 'Ship' and c.classificationlevel == 'Identified' then
        local rangeNM = Tool_Range(
            {latitude=c.latitude, longitude=c.longitude},
            {latitude=38.0, longitude=-10.0}
        )
        if rangeNM < 50 then
            ScenEdit_SpecialMessage('USA', 'Identified ship within 50NM: ' .. c.name)
        end
    end
end
```

---

## 3. Side

Returned by `VP_GetSide()` and `VP_GetSides()`.

### Fields

| Field | Type | R/W | Description |
|-------|------|-----|-------------|
| `guid` | `string` | RO | Side GUID |
| `name` | `string` | RO | Side name |
| `units` | `table<Unit>` | RO | All units belonging to this side |
| `contacts` | `table<Contact>` | RO | All contacts known to this side |
| `missions` | `table<Mission>` | RO | All missions for this side |
| `doctrine` | `Doctrine` | RO | Side-level doctrine |
| `awareness` | `string` | RO | `'Blind'`, `'Blissful'`, `'Withit'`, `'Omniscient'` |
| `proficiency` | `string` | RO | Side-level proficiency default |
| `rps` | `table` | RO | Reference points for this side |
| `losses` | `table` | RO | Loss/expenditure records |
| `expenditures` | `table` | RO | Weapon expenditure records |
| `exclusionzones` | `table<Zone>` | RO | Exclusion zones |
| `nonavzones` | `table<Zone>` | RO | No-navigation zones |
| `standardzones` | `table<Zone>` | RO | Standard zones |
| `customenvironmentzones` | `table<Zone>` | RO | Custom environment zones |
| `Chalks` | `table` | RO | Chalk (helicopter transport) assignments |
| `Operation` | `string` | RO | Current operation name |
| `enablers` | `table` | RO | Enabler units (logistics, support) |
| `hasmines` | `boolean` | RO | `true` if side has deployed mines |

### Methods

#### `side:unitsBy(type)`
```lua
side:unitsBy(type: string) -> table<Unit>
```
Filters side units by type string (`'Aircraft'`, `'Ship'`, `'Submarine'`, `'Facility'`, `'Satellite'`).

**Example:**
```lua
local side = VP_GetSide({Side='USA'})
local ships = side:unitsBy('Ship')
print('Ships: ' .. #ships)
```

#### `side:unitsInArea(params)`
```lua
side:unitsInArea({area = {string, ...}}) -> table<Unit>
```
Returns all side units within the defined polygon area.

**Example:**
```lua
local side = VP_GetSide({Side='USA'})
local inZone = side:unitsInArea({area={'Z1','Z2','Z3','Z4'}})
for _, u in ipairs(inZone) do
    ScenEdit_SetUnit({guid=u.guid, holdfire=false})
end
```

#### `side:contactsBy(type)`
```lua
side:contactsBy(type: string) -> table<Contact>
```
Filters contacts by type.

#### `side:getexclusionzone(name)`
```lua
side:getexclusionzone(name: string) -> Zone
```
Returns a specific exclusion zone by name.

#### `side:getnonavzone(name)`
```lua
side:getnonavzone(name: string) -> Zone
```
Returns a specific no-navigation zone by name.

#### `side:getstandardzone(name)`
```lua
side:getstandardzone(name: string) -> Zone
```
Returns a specific standard zone by name.

#### `side:getcustomenvironmentzone(name)`
```lua
side:getcustomenvironmentzone(name: string) -> Zone
```
Returns a specific custom environment zone by name.

---

## 4. Mission

Returned by `ScenEdit_GetMission()`, `ScenEdit_AddMission()`, and `side.missions`.

### Core Fields

| Field | Type | R/W | Description |
|-------|------|-----|-------------|
| `guid` | `string` | RO | Mission GUID |
| `name` | `string` | RW | Mission name |
| `side` | `string` | RO | Side this mission belongs to |
| `type` | `number` | RO | Mission class number (see [ENUMS.md — MissionClass](./ENUMS.md#missionclass)) |
| `typeS` | `string` | RO | Mission class string (e.g., `'strike'`, `'patrol'`) |
| `isactive` | `boolean` | RW | Whether mission is active |
| `starttime` | `string` | RW | Mission start time (DateTime format) |
| `endtime` | `string` | RW | Mission end time |
| `unitlist` | `table<Unit>` | RO | Units assigned to this mission |
| `targetlist` | `table` | RO | Target list (strike missions) |
| `doctrine` | `Doctrine` | RO | Mission-level doctrine |
| `packagelist` | `table` | RO | Package groupings |
| `parentTaskPool` | `string` | RO | GUID of parent task pool (if any) |

### Deactivation Behavior

| Field | Type | R/W | Description |
|-------|------|-----|-------------|
| `OnDeactivateUassign` | `boolean` | RW | Unassign units when deactivated |
| `OnDeactivateRTB` | `boolean` | RW | Send units to RTB when deactivated |
| `OnDeactivateDelete` | `boolean` | RW | Delete units when deactivated |

### Scheduling

| Field | Type | R/W | Description |
|-------|------|-----|-------------|
| `TakeOffTime` | `string` | RW | Scheduled take-off time |
| `TimeOnTargetStation` | `string` | RW | Time on target/station |
| `SISH` | `boolean` | RW | Strike: sink/if/sunk/here — if target already sunk, don't strike |

### Type-Specific Sub-Objects

| Field | Type | Notes |
|-------|------|-------|
| `strikemission` | `table` | Available for `typeS='strike'` |
| `patrolmission` | `table` | Available for `typeS='patrol'` |
| `supportmission` | `table` | Available for `typeS='support'` |
| `ferrymission` | `table` | Available for `typeS='ferry'` |
| `minemission` | `table` | Available for `typeS='mining'` |
| `mineclearmission` | `table` | Available for `typeS='mineclearing'` |
| `cargomission` | `table` | Available for `typeS='cargo'` |
| `aar` | `table` | Air-to-air refueling settings |

### Priority & Operations

| Field | Type | R/W | Description |
|-------|------|-----|-------------|
| `PriorityWeight` | `number` | RW | Mission priority (higher = higher priority) |
| `OperationName` | `string` | RW | Associated operation name |
| `Phase` | `string` | RW | Current mission phase |

### Cargo Mission Fields

| Field | Type | R/W | Description |
|-------|------|-----|-------------|
| `assignedCargo` | `table<Cargo>` | RO | Cargo assigned to this mission |

### Trigger Fields

Mission start and completion trigger configuration:

| Field | Type | R/W |
|-------|------|-----|
| `MissionStartTrigger_Score` | `number` | RW |
| `MissionStartTrigger_Time` | `string` | RW |
| `MissionStartTrigger_Zone` | `string` | RW |
| `MissionCompletedTrigger_Score` | `number` | RW |
| `MissionCompletedTrigger_Time` | `string` | RW |
| `MissionCompletedTrigger_AllTargetsDestroyed` | `boolean` | RW |

### Methods

#### `mission:addAssignedCargo(cargoGuid)`
```lua
mission:addAssignedCargo(cargoGuid: string) -> boolean
```
Adds cargo to a cargo mission's manifest.

#### `mission:removeAssignedCargo(cargoGuid)`
```lua
mission:removeAssignedCargo(cargoGuid: string) -> boolean
```
Removes cargo from a cargo mission.

#### `mission:createFlightPlans()`
```lua
mission:createFlightPlans() -> boolean
```
Generates flight plans for all assigned aircraft.

#### `mission:updateWPtimes()`
```lua
mission:updateWPtimes() -> boolean
```
Recalculates waypoint times based on current unit speeds and positions.

**Usage Pattern:**
```lua
local mission = ScenEdit_GetMission('USA', 'Alpha Strike')
if not mission then return end

print('Type:', mission.typeS)
print('Active:', mission.isactive)
print('Units:', #mission.unitlist)

-- Activate at a specific time
if ScenEdit_CurrentTime() >= 1749430800 then
    ScenEdit_SetMission('USA', mission.guid, {isactive=true})
end
```

---

## 5. Doctrine

Returned by `ScenEdit_GetDoctrine()`. Applied at side, mission, or unit level.

### Weapon Control Status (WCS)

| Field | Type | R/W | Values | Description |
|-------|------|-----|--------|-------------|
| `weapon_control_status_air` | `number` | RW | 0=Free, 1=Tight, 2=Hold | WCS vs air targets |
| `weapon_control_status_surface` | `number` | RW | 0=Free, 1=Tight, 2=Hold | WCS vs surface targets |
| `weapon_control_status_subsurface` | `number` | RW | 0=Free, 1=Tight, 2=Hold | WCS vs sub targets |
| `weapon_control_status_land` | `number` | RW | 0=Free, 1=Tight, 2=Hold | WCS vs land targets |

### Engagement Policy

| Field | Type | R/W | Values | Description |
|-------|------|-----|--------|-------------|
| `engage_opportunity_targets` | `string` | RW | `'yes'`, `'no'` | Engage non-assigned targets |
| `ignore_emcon_while_under_attack` | `string` | RW | `'yes'`, `'no'` | Break EMCON if attacked |
| `bvr_logic` | `string` | RW | See ENUMS | BVR engagement logic |
| `auto_evade` | `string` | RW | `'yes'`, `'no'` | Auto-evade incoming weapons |

### Fuel & Weapon State Thresholds

| Field | Type | R/W | Description |
|-------|------|-----|-------------|
| `fuel_state_planned` | `number` | RW | Fuel % to RTB for planned RTB |
| `fuel_state_dead` | `number` | RW | Fuel % for emergency RTB |
| `weapon_state_planned` | `number` | RW | Weapon % to RTB (planned) |
| `weapon_state_dead` | `number` | RW | Weapon % for emergency RTB |

### Withdrawal Rules

| Field | Type | R/W | Values | Description |
|-------|------|-----|--------|-------------|
| `withdraw_on_fuel_state_auto` | `string` | RW | `'yes'`, `'no'` | Auto-withdraw at bingo fuel |
| `withdraw_on_attack` | `string` | RW | `'yes'`, `'no'` | Withdraw when attacked |
| `withdraw_on_weapon_state` | `string` | RW | `'yes'`, `'no'` | Withdraw at minimum weapons |

### Deployment Rules

| Field | Type | R/W | Description |
|-------|------|-----|-------------|
| `deploy_on_attack` | `string` | RW | Deploy reserve units when attacked |
| `deploy_on_detection` | `string` | RW | Deploy on enemy detection |

### Aircraft-Specific Doctrine

| Field | Type | R/W | Description |
|-------|------|-----|-------------|
| `rtb_when_winchester` | `string` | RW | RTB when out of weapons |
| `gun_strafing` | `string` | RW | Use guns for strafing |
| `buzz_fuse` | `string` | RW | Use proximity fuze |
| `refuel_unrep_allied` | `string` | RW | Accept AAR from allied tankers |

### Submarine-Specific Doctrine

| Field | Type | R/W | Description |
|-------|------|-----|-------------|
| `dive_on_threat` | `string` | RW | Dive when threatened on surface |
| `snort_necessary` | `string` | RW | Only snort when battery low |
| `avoid_cavitation_auto` | `string` | RW | Auto-avoid cavitation |
| `sprint_drift` | `string` | RW | Use sprint-and-drift tactics |

### Anti-Sub Warfare Doctrine

| Field | Type | R/W | Description |
|-------|------|-----|-------------|
| `drop_active_sono` | `string` | RW | Drop active sonobuoys |
| `use_dipping_sonar` | `string` | RW | Use dipping sonar |
| `attack_periscope_depth` | `string` | RW | Attack subs at periscope depth |

**Example:**
```lua
-- Make a mission aggressive (weapons free, engage opportunities)
ScenEdit_SetDoctrine({mission='Alpha Strike'}, {
    weapon_control_status_air        = 0,   -- Free
    weapon_control_status_surface    = 0,
    weapon_control_status_subsurface = 0,
    weapon_control_status_land       = 0,
    engage_opportunity_targets       = 'yes',
    auto_evade                       = 'yes',
    withdraw_on_fuel_state_auto      = 'yes'
})
```

---

## 6. DoctrineWRA

Returned by `ScenEdit_GetDoctrineWRA()`. Controls Weapon Release Authority per target type.

### Fields

| Field | Type | R/W | Description |
|-------|------|-----|-------------|
| `level` | `string` | RO | Scope: `'side'`, `'mission'`, `'unit'` |
| `target_type` | `string` | RO | Target type this WRA applies to |
| `wra_qty_1` | `number` | RW | Primary weapon salvo size |
| `wra_qty_2` | `number` | RW | Secondary weapon salvo size |
| `wra_shooter_1` | `number` | RW | Shooters for primary weapon |
| `wra_shooter_2` | `number` | RW | Shooters for secondary weapon |
| `wra_range_max` | `number` | RW | Maximum engagement range (NM) |
| `wra_range_min` | `number` | RW | Minimum engagement range (NM) |

**Example:**
```lua
-- Check WRA for anti-surface
local wra = ScenEdit_GetDoctrineWRA({side='USA', target_type='Surface_Ship'})
print('Salvo size:', wra.wra_qty_1)
```

---

## 7. Magazine

Accessible via `unit.magazines` array or `unit:getUnitMagazine(guid)`.

### Fields

| Field | Type | R/W | Description |
|-------|------|-----|-------------|
| `guid` | `string` | RO | Magazine GUID |
| `name` | `string` | RO | Magazine name |
| `dbid` | `number` | RO | Magazine DB ID |
| `capacity` | `number` | RO | Maximum storage volume |
| `weapons` | `table` | RO | Array of `{guid, dbid, name, count, maxcount}` |
| `isaviationmagazine` | `boolean` | RO | `true` if aviation magazine |
| `armor` | `number` | RO | Magazine armor rating |
| `rof` | `number` | RO | Rate of fire for associated mount |
| `parentunitguid` | `string` | RO | GUID of the parent unit |

### Methods

#### `magazine:setExactWeaponQuantity(weaponGuid, quantity)`
```lua
magazine:setExactWeaponQuantity(
    weaponGuid : string,
    quantity   : number
) -> boolean
```
Sets the exact quantity of a specific weapon in the magazine. Useful for resupply without over-filling.

**Example:**
```lua
local unit = ScenEdit_GetUnit({name='USS Bunker Hill', side='USA'})
for _, mag in ipairs(unit.magazines) do
    for _, wpn in ipairs(mag.weapons) do
        if wpn.name:find('SM%-2') then
            mag:setExactWeaponQuantity(wpn.guid, wpn.maxcount)
            print('Restocked ' .. wpn.name)
        end
    end
end
```

---

## 8. Loadout

Returned by `ScenEdit_GetLoadout()`.

### Fields

| Field | Type | R/W | Description |
|-------|------|-----|-------------|
| `dbid` | `number` | RO | Loadout DB ID |
| `name` | `string` | RO | Loadout name |
| `roles` | `table` | RO | Array of role codes (see [ENUMS.md — LoadoutRole](./ENUMS.md#loadoutrole)) |
| `weapons` | `table` | RO | Array of `{dbid, name, count, maxcount, mountguid}` |

### Methods

#### `loadout:setExactWeaponQuantity(weaponGuid, quantity)`
```lua
loadout:setExactWeaponQuantity(
    weaponGuid : string,
    quantity   : number
) -> boolean
```
Sets a weapon count on the loadout.

---

## 9. Event

Returned by `ScenEdit_GetEvent()`, `ScenEdit_GetEvents()`, and `ScenEdit_EventX()`.

### Fields

| Field | Type | R/W | Description |
|-------|------|-----|-------------|
| `guid` | `string` | RO | Event GUID |
| `name` | `string` | RW | Event name |
| `description` | `string` | RW | Event description |
| `isActive` | `boolean` | RW | Whether event can fire |
| `isRepeatable` | `boolean` | RW | Whether event can fire multiple times |
| `isShown` | `boolean` | RW | Whether event is shown in log when fired |
| `probability` | `number` | RW | Probability of event firing (0–100) |
| `triggers` | `table` | RO | Array of trigger definitions |
| `conditions` | `table` | RO | Array of condition definitions |
| `actions` | `table` | RO | Array of action definitions |
| `details` | `table` | RO | Additional event metadata |

**Usage Pattern:**
```lua
-- In an event script: self-deactivate after first fire
local ev = ScenEdit_EventX()
if ev then
    ScenEdit_SetEvent(ev.guid, {
        isActive     = false,
        isRepeatable = false
    })
end
```

---

## 10. Scenario

Returned by `VP_GetScenario()`.

### Fields

| Field | Type | R/W | Description |
|-------|------|-----|-------------|
| `Title` | `string` | RO | Scenario title |
| `CurrentTime` | `number` | RO | Current time (Unix timestamp) |
| `StartTime` | `number` | RO | Scenario start time (Unix timestamp) |
| `Duration` | `string` | RO | Scenario duration string |
| `DurationNum` | `number` | RO | Scenario duration in seconds |
| `HasStarted` | `boolean` | RO | `true` if scenario clock is running |
| `PlayerSide` | `string` | RO | Human player side name |
| `Sides` | `table<Side>` | RO | All sides in scenario |
| `DBUsed` | `string` | RO | Database version string |
| `FileName` | `string` | RO | Scenario file name |
| `guid` | `string` | RO | Scenario GUID |
| `TimeCompression` | `number` | RW | Current time compression factor |
| `ScenDate` | `string` | RO | Scenario date string |
| `ScenSetting` | `string` | RO | Setting description |

### Methods

#### `scenario:ResetLossExp()`
```lua
scenario:ResetLossExp() -> nil
```
Resets all sides' loss and expenditure records.

#### `scenario:ResetScore()`
```lua
scenario:ResetScore() -> nil
```
Resets scores for all sides to zero.

**Example:**
```lua
local scen = VP_GetScenario()
print('Scenario: ' .. scen.Title)
print('Time: ' .. scen.CurrentTime)
print('Player: ' .. scen.PlayerSide)
print('DB: ' .. scen.DBUsed)
```

---

## 11. ReferencePoint

Returned by `ScenEdit_GetReferencePoint()` and `ScenEdit_AddReferencePoint()`.

### Fields

| Field | Type | R/W | Description |
|-------|------|-----|-------------|
| `guid` | `string` | RO | Reference point GUID |
| `name` | `string` | RW | Display name |
| `latitude` | `number` | RW | Decimal degrees |
| `longitude` | `number` | RW | Decimal degrees |
| `side` | `string` | RO | Owning side |
| `highlighted` | `boolean` | RW | Show as highlighted on map |
| `locked` | `boolean` | RW | Prevent user editing |
| `bearingtype` | `string` | RW | `'fixed'` or `'rotating'` |
| `relativeto` | `string` | RW | GUID of unit for rotating bearing |
| `relativeDistance` | `number` | RW | Distance from parent unit (NM) |
| `relativeBearing` | `number` | RW | Bearing from parent unit (degrees) |
| `color` | `string` | RW | Display color (hex or name) |

**Usage Pattern:**
```lua
-- Create a rotating reference point that follows a ship
local ship = ScenEdit_GetUnit({name='USS Nimitz', side='USA'})
ScenEdit_AddReferencePoint({
    side        = 'USA',
    name        = 'Nimitz-500NM',
    lat         = ship.latitude,
    lon         = ship.longitude,
    bearingtype = 'rotating',
    relativeto  = ship.guid,
    relativeDistance = 500,
    relativeBearing  = 0
})
```

---

## 12. Zone

Returned by zone-related functions and `side.exclusionzones`, etc.

### Core Fields

| Field | Type | R/W | Description |
|-------|------|-----|-------------|
| `guid` | `string` | RO | Zone GUID |
| `name` | `string` | RW | Zone name |
| `description` | `string` | RW | Description |
| `type` | `string` | RO | Zone type: `'exclusion'`, `'nonavigation'`, `'standard'`, `'customenvironment'` |
| `isactive` | `boolean` | RW | Whether zone is active |
| `locked` | `boolean` | RW | Prevent user editing |
| `area` | `table` | RW | Array of reference point names/GUIDs defining boundary |
| `affects` | `string` | RW | What is affected: `'aircraft'`, `'ships'`, `'submarines'`, `'all'` |
| `markas` | `string` | RW | How trespassers are treated: `'hostile'`, `'friendly'`, `'neutral'` |
| `noFire` | `boolean` | RW | No-fire zone — do not engage within |
| `areacolor` | `string` | RW | Display color |
| `enablers` | `table` | RW | Enabler overrides |

### Custom Environment Zone Fields

| Field | Type | R/W | Description |
|-------|------|-----|-------------|
| `temperature` | `number` | RW | Override temperature (Celsius) |
| `rainfall` | `number` | RW | Override rainfall (0–1) |
| `clouds` | `number` | RW | Override cloud cover (0–1) |
| `seastate` | `number` | RW | Override sea state (Beaufort) |

### Thermal Layer Fields (for Submarine Ops)

| Field | Type | R/W | Description |
|-------|------|-----|-------------|
| `thermalLayerDepth` | `number` | RW | Thermal layer depth (meters) |
| `thermalLayerStrength` | `number` | RW | Layer strength modifier |

---

## 13. Group

Groups of units that move and operate together.

### Fields

| Field | Type | R/W | Description |
|-------|------|-----|-------------|
| `guid` | `string` | RO | Group GUID |
| `name` | `string` | RW | Group name |
| `side` | `string` | RO | Owning side |
| `type` | `string` | RO | Group type |
| `lead` | `string` | RO | GUID of lead unit |
| `unitlist` | `table<Unit>` | RO | All units in the group |
| `doctrine` | `Doctrine` | RO | Group doctrine |

---

## 14. Cargo

Cargo objects that can be transported between units via cargo missions.

### Fields

| Field | Type | R/W | Description |
|-------|------|-----|-------------|
| `guid` | `string` | RO | Cargo GUID |
| `type` | `string` | RO | Cargo type: `'custom'`, `'fuel'`, `'ammunition'`, `'unit'` |
| `storageType` | `string` | RO | How stored: `'internal'`, `'external'`, `'container'` |
| `dbid` | `number` | RO | DB ID if applicable |
| `name` | `string` | RW | Cargo name |
| `requiredSize` | `number` | RO | Size units required |
| `requiredMass` | `number` | RO | Mass in tons |
| `requiredArea` | `number` | RO | Deck/floor area required |
| `requiredPAX` | `number` | RO | Personnel capacity |
| `unit` | `Unit` | RO | Unit cargo (if type=`'unit'`) |
| `containerCargo` | `table<Cargo>` | RO | Contents of container cargo |

### Methods

#### `cargo:createContainerContentCustom(params)`
Creates custom cargo content within a container.

#### `cargo:createContainerContentFuel(params)`
Creates a fuel item within a container.

#### `cargo:createContainerContentAmmunition(params)`
Creates an ammunition item within a container.

#### `cargo:deleteContainerContents(guid)`
Removes content from a container cargo.

---

## 15. Sensor

Accessible via `unit.sensors` array or `unit:filterOnComponent('sensor')`.

### Fields

| Field | Type | R/W | Description |
|-------|------|-----|-------------|
| `guid` | `string` | RO | Sensor GUID |
| `name` | `string` | RO | Sensor name |
| `dbid` | `number` | RO | Sensor DB ID |
| `type` | `string` | RO | Sensor type: `'Radar'`, `'Sonar'`, `'ESM'`, `'Visual'`, `'IR'`, `'MAD'` |
| `role` | `string` | RO | Sensor role description |
| `ranges` | `table` | RO | Detection ranges `{max_air, max_surface, max_sub, min_range}` |
| `altitudes` | `table` | RO | Operating altitude envelope |
| `scaninterval` | `number` | RO | Scan cycle in seconds |

### Methods

#### `sensor:IsPreciseCheck()`
```lua
sensor:IsPreciseCheck() -> boolean
```
Returns `true` if this sensor provides precise (fire-control quality) tracks.

#### `sensor:RangeAgainstTarget(targetType)`
```lua
sensor:RangeAgainstTarget(targetType: string) -> number
```
Returns the effective detection range (NM) against a specific target type.

---

## 16. Waypoint

Accessible via `unit:getwaypoint(guid)` or `unit.course` array.

### Fields

| Field | Type | R/W | Description |
|-------|------|-----|-------------|
| `guid` | `string` | RO | Waypoint GUID |
| `name` | `string` | RW | Waypoint name |
| `latitude` | `number` | RW | Waypoint latitude |
| `longitude` | `number` | RW | Waypoint longitude |
| `altitude` | `number` | RO | Assigned altitude |
| `description` | `string` | RW | Waypoint description |
| `desiredAltitude` | `number` | RW | Desired altitude at waypoint |
| `desiredSpeed` | `number` | RW | Desired speed at waypoint |
| `presetAltitude` | `string` | RW | Preset altitude code (`'Low'`, `'Medium'`, `'High'`, `'Optimal'`) |
| `presetDepth` | `string` | RW | Submarine preset depth (`'Periscope'`, `'Shallow'`, `'Deep'`, `'Optimal'`) |
| `presetThrottle` | `string` | RW | Speed preset (`'Loiter'`, `'Cruise'`, `'Full'`, `'Flank'`) |
| `TF` | `boolean` | RW | Terrain-following enabled at this waypoint |
| `type` | `string` | RO | Waypoint type (`'Normal'`, `'Turn'`, `'Hold'`) |

---

## 17. Weapon

Accessible via database queries or weapon lists on mounts/magazines.

### Fields

| Field | Type | R/W | Description |
|-------|------|-----|-------------|
| `guid` | `string` | RO | Weapon GUID (in-scenario instance) |
| `name` | `string` | RO | Weapon name |
| `dbid` | `number` | RO | Weapon DB ID |
| `classname` | `string` | RO | Class name |
| `type` | `string` | RO | Weapon type |
| `subtype` | `string` | RO | Weapon subtype |
| `guidance` | `string` | RO | Guidance type: `'ARH'`, `'SARH'`, `'IR'`, `'GPS'`, `'INS'`, `'TV'`, etc. |
| `ranges` | `table` | RO | Range envelope `{min, max}` in NM |
| `sensors` | `table` | RO | Onboard sensors (for semi-active/active weapons) |
| `warheads` | `table` | RO | Warhead data `{dbid, name, weight}` |
| `directors` | `table` | RO | Fire control directors |
| `launchLimits` | `table` | RO | Launch envelope (altitude, speed, aspect) |
| `targetLimits` | `table` | RO | Valid target altitude/speed envelope |
| `validTargetList` | `table` | RO | Types this weapon can engage |
| `OODA` | `table` | RO | Weapon OODA timings |

---

## 18. SpecialAction

Returned by `ScenEdit_AddSpecialAction()`, `ScenEdit_GetSpecialAction()`.

### Fields

| Field | Type | R/W | Description |
|-------|------|-----|-------------|
| `guid` | `string` | RO | Special action GUID |
| `name` | `string` | RW | Display name |
| `description` | `string` | RW | Description text |
| `side` | `string` | RO | Owning side |
| `isActive` | `boolean` | RW | Whether action is available to player |
| `isRepeatable` | `boolean` | RW | Can be triggered multiple times |
| `ScriptText` | `string` | RW | Lua script to execute when triggered |

**Usage Pattern:**
```lua
-- Add a special action for manual reinforcements
local sa = ScenEdit_AddSpecialAction({
    name       = 'Call Reinforcements',
    side       = 'USA',
    isActive   = true,
    isRepeatable = false,
    ScriptText = [[
        -- Spawn reinforcement group
        local carrier = ScenEdit_GetUnit({name='USS Nimitz', side='USA'})
        if not carrier then return end
        ScenEdit_AddUnit({
            side='USA', type='Aircraft', name='VFA-105 Charlie',
            dbid=278, latitude=carrier.latitude,
            longitude=carrier.longitude, Base=carrier.name
        })
        -- Deactivate after use
        local thisSA = ScenEdit_GetSpecialAction({side='USA', name='Call Reinforcements'})
        if thisSA then
            ScenEdit_SetSpecialAction({
                side='USA', guid=thisSA.guid, isActive=false
            })
        end
        ScenEdit_SpecialMessage('USA', 'Reinforcements have been dispatched!')
    ]]
})
```

---

*End of WRAPPERS.md*

> **See also:** [FUNCTIONS.md](./FUNCTIONS.md) | [ENUMS.md](./ENUMS.md)
