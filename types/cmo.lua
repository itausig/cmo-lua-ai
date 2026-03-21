--- ============================================================
--- CMO Lua Type Definitions (LuaLS / EmmyLua)
--- Command: Modern Operations — IntelliSense Annotations
---
--- Based on KnightHawk75's CMO IntelliSense work,
--- updated and extended by blu3ser:
--- https://github.com/blu3ser/CMO_Intellisense
---
--- Usage:
---   Add this file to your LuaLS workspace library path.
---   In .luarc.json:
---     {
---       "workspace.library": ["path/to/cmo-lua-ai/types"]
---     }
---
--- Covers the most-used 50+ functions and all wrapper classes.
--- ============================================================

-- ============================================================
-- ENUM TYPES
-- ============================================================

--- @alias UnitType
--- | 'Aircraft'
--- | 'Ship'
--- | 'Submarine'
--- | 'Facility'
--- | 'Satellite'

--- @alias Proficiency
--- | 'Novice'
--- | 'Cadet'
--- | 'Regular'
--- | 'Veteran'
--- | 'Ace'

--- @alias MissionType
--- | 'strike'
--- | 'patrol'
--- | 'support'
--- | 'ferry'
--- | 'mining'
--- | 'mineclearing'
--- | 'escort'
--- | 'cargo'

--- @alias MissionSubtype
--- | 'air'
--- | 'naval'
--- | 'sub'
--- | 'land'

--- @alias PostureCode
--- | 'H'    # Hostile
--- | 'F'    # Friendly
--- | 'N'    # Neutral
--- | 'U'    # Unfriendly
--- | 'A'    # Affiliated

--- @alias WeaponControlStatus
--- | 0   # Free
--- | 1   # Tight
--- | 2   # Hold

--- @alias ClassificationLevel
--- | 'Unknown'
--- | 'Identified'
--- | 'Recognized'
--- | 'Tracked'

--- @alias EMCONState
--- | 'Active'
--- | 'Passive'
--- | 'Enabled'
--- | 'Disabled'

--- @alias TriggerType
--- | 'Time'
--- | 'RegularTime'
--- | 'ScenLoaded'
--- | 'UnitDestroyed'
--- | 'UnitEntersArea'
--- | 'DetectedContact'
--- | 'UnitBaseStatus'

--- @alias ActionType
--- | 'LuaScript'
--- | 'Message'
--- | 'Points'
--- | 'EndScenario'

--- @alias ConditionType
--- | 'LuaScript'
--- | 'TotalScore'
--- | 'SideScore'

-- ============================================================
-- WRAPPER CLASSES
-- ============================================================

--- @class Weapon
--- @field id       number    Weapon DB ID
--- @field name     string    Weapon name
--- @field current  number    Current count
--- @field maxcap   number    Maximum capacity
--- @field guid     string    Weapon slot GUID

--- @class Magazine
--- @field guid    string      Magazine GUID
--- @field dbid    number      Magazine DB ID
--- @field name    string      Magazine name
--- @field weapons Weapon[]    Weapons in this magazine

--- @class Mount
--- @field guid    string      Mount GUID
--- @field dbid    number      Mount DB ID
--- @field name    string      Mount name
--- @field weapons Weapon[]    Weapons on this mount

--- @class Sensor
--- @field guid    string    Sensor GUID
--- @field dbid    number    Sensor DB ID
--- @field name    string    Sensor name
--- @field type    string    Sensor type (radar, sonar, ESM, etc.)

--- @class Waypoint
--- @field latitude  number
--- @field longitude number
--- @field altitude  number|nil
--- @field speed     number|nil

--- @class UnitDoctrine
--- @field weapon_control_status_air        WeaponControlStatus
--- @field weapon_control_status_surface    WeaponControlStatus
--- @field weapon_control_status_subsurface WeaponControlStatus
--- @field weapon_control_status_land       WeaponControlStatus
--- @field ignore_plotted_course            'yes'|'no'
--- @field use_nuclear_weapons              'yes'|'no'
--- @field engage_non_hostile_targets       'yes'|'no'
--- @field fuel_state_planned               string
--- @field fuel_state_rtb                   string

--- @class Unit
--- @field guid        string          Unique identifier (never changes)
--- @field name        string          Display name (can change)
--- @field side        string          Owning side name
--- @field type        UnitType        Unit type
--- @field dbid        number          Database ID
--- @field latitude    number          Current latitude (decimal degrees)
--- @field longitude   number          Current longitude (decimal degrees)
--- @field altitude    number          Altitude in meters (negative = depth)
--- @field heading     number          True heading in degrees (0-360)
--- @field speed       number          Speed in knots
--- @field fuel        number          Fuel level percentage (0-100)
--- @field damage      number          Damage percentage (0-100)
--- @field proficiency Proficiency     Crew proficiency level
--- @field mission     string          Current mission name ('' if none)
--- @field base        string          Home base name ('' if none)
--- @field group       string|nil      Group name if part of a group
--- @field course      Waypoint[]      Current plotted course
--- @field magazines   Magazine[]      All magazines
--- @field mounts      Mount[]         All weapon mounts
--- @field sensors     Sensor[]        All sensors
--- @field doctrine    UnitDoctrine    Unit doctrine (overrides side if set)
--- @field isalive     boolean         Whether unit is still in the scenario

--- @class ReferencePoint
--- @field guid        string
--- @field name        string
--- @field side        string
--- @field latitude    number
--- @field longitude   number
--- @field highlighted boolean

--- @class Contact
--- @field guid               string            Contact GUID (NOT same as unit GUID)
--- @field name               string            Estimated name/designation
--- @field side               string            Side that holds this contact
--- @field latitude           number
--- @field longitude          number
--- @field altitude           number|nil
--- @field heading            number|nil        Estimated heading
--- @field speed              number|nil        Estimated speed
--- @field type               UnitType|'Unknown' Contact type
--- @field classificationlevel ClassificationLevel
--- @field actualunitid       string|nil        Real unit GUID (nil if not confirmed)
--- @field detectionBy        string[]          Side names that can see this contact
--- @field BDA                string            Battle damage assessment

--- @class SideDoctrine
--- @field weapon_control_status_air        WeaponControlStatus
--- @field weapon_control_status_surface    WeaponControlStatus
--- @field weapon_control_status_subsurface WeaponControlStatus

--- @class Side
--- @field guid         string            Side GUID
--- @field name         string            Side name
--- @field units        Unit[]            All units belonging to this side
--- @field contacts     Contact[]         All known contacts
--- @field missions     Mission[]         All missions
--- @field rps          ReferencePoint[]  All reference points
--- @field doctrine     SideDoctrine      Side-level doctrine
--- @field losses       table             Loss tracking data
--- @field expenditures table             Expenditure tracking data

--- @class Mission
--- @field guid       string        Mission GUID
--- @field name       string        Mission name
--- @field side       string        Owning side
--- @field type       MissionType   Mission type
--- @field isactive   boolean       Whether mission is currently active
--- @field unitlist   string[]      GUIDs of assigned units
--- @field targetlist string[]      GUIDs of strike targets
--- @field doctrine   UnitDoctrine  Mission-specific doctrine

--- @class Event
--- @field guid         string
--- @field name         string
--- @field isActive     boolean
--- @field isRepeatable boolean

--- @class Trigger
--- @field guid string
--- @field name string
--- @field type TriggerType

--- @class Action
--- @field guid       string
--- @field name       string
--- @field type       ActionType
--- @field ScriptText string|nil

--- @class Condition
--- @field guid       string
--- @field name       string
--- @field type       ConditionType

-- ============================================================
-- UNIT FUNCTIONS (ScenEdit_*)
-- ============================================================

--- Add a new unit to the scenario.
--- @param params table  {side, type, name, dbid, latitude, longitude, [heading], [speed], [altitude], [proficiency], [loadoutid], [Base]}
--- @return Unit
function ScenEdit_AddUnit(params) end

--- Get a unit wrapper by GUID or name+side.
--- Returns nil if unit is dead or not found.
--- @param params table  {guid=string} or {side=string, name=string}
--- @return Unit|nil
function ScenEdit_GetUnit(params) end

--- Modify unit properties.
--- @param params table  {guid=string, [heading], [speed], [altitude], [course], [mission], [magazines], ...}
--- @return Unit|nil
function ScenEdit_SetUnit(params) end

--- Delete a unit from the scenario.
--- @param params table  {guid=string}
--- @return boolean
function ScenEdit_DeleteUnit(params) end

--- Update unit sensors or loadout (use mode field).
--- Common modes: 'add_sensor', 'remove_sensor', 'addload', 'updateload'
--- @param params table  {guid=string, mode=string, dbid=number, [arc_detect], [arc_track]}
function ScenEdit_UpdateUnit(params) end

--- Transfer a unit to a different side.
--- @param params table  {guid=string, side=string}
function ScenEdit_SetUnitSide(params) end

--- Assign a unit to a mission.
--- @param unitGuid   string  Unit GUID
--- @param missionRef string  Mission name or GUID
function ScenEdit_AssignUnitToMission(unitGuid, missionRef) end

--- Get the unit that triggered the current event (ScenEdit_UnitX).
--- Available inside event script actions only.
--- @return Unit|nil
function ScenEdit_UnitX() end

--- Get the "other" unit in a detection or interaction event.
--- @return Unit|nil
function ScenEdit_UnitY() end

--- Get the contact wrapper in a detection event.
--- @return Contact|nil
function ScenEdit_UnitC() end

-- ============================================================
-- MISSION FUNCTIONS (ScenEdit_*)
-- ============================================================

--- Create a new mission.
--- @param side        string       Side name
--- @param name        string       Mission name (must be unique per side)
--- @param missionType MissionType
--- @param options     table        {type=MissionSubtype, [isactive=bool]}
--- @return Mission
function ScenEdit_AddMission(side, name, missionType, options) end

--- Configure or update a mission.
--- @param side    string
--- @param name    string
--- @param params  table   {[patrolzone], [isactive], [flightsize], [onethirdrule], [strikeTarget], ...}
--- @return nil
function ScenEdit_SetMission(side, name, params) end

--- Delete a mission.
--- @param side string
--- @param name string
function ScenEdit_DeleteMission(side, name) end

-- ============================================================
-- EVENT SYSTEM (ScenEdit_*)
-- ============================================================

--- Create or update an event.
--- @param name   string
--- @param params table  {mode='add'|'update'|'remove', [IsActive], [IsRepeatable], [probability]}
--- @return Event
function ScenEdit_SetEvent(name, params) end

--- Create or update a trigger.
--- @param params table  {mode='add'|'update'|'remove', type=TriggerType, name=string, ...}
--- @return Trigger
function ScenEdit_SetTrigger(params) end

--- Link a trigger to an event.
--- @param eventGuid  string
--- @param params     table  {mode='add'|'remove', name=string}
function ScenEdit_SetEventTrigger(eventGuid, params) end

--- Create or update a condition.
--- @param params table  {mode='add'|'update'|'remove', type=ConditionType, name=string, ...}
--- @return Condition
function ScenEdit_SetCondition(params) end

--- Link a condition to an event.
--- @param eventGuid string
--- @param params    table  {mode='add'|'remove', name=string}
function ScenEdit_SetEventCondition(eventGuid, params) end

--- Create or update an action.
--- @param params table  {mode='add'|'update'|'remove', type=ActionType, name=string, [ScriptText], [message], [points], [side]}
--- @return Action
function ScenEdit_SetAction(params) end

--- Link an action to an event.
--- @param eventGuid string
--- @param params    table  {mode='add'|'remove', name=string}
function ScenEdit_SetEventAction(eventGuid, params) end

--- Register a player-accessible special action.
--- @param params table  {mode='add'|'update'|'remove', name=string, IsActive=bool, ScriptText=string}
function ScenEdit_SetSpecialAction(params) end

-- ============================================================
-- SIDE & DOCTRINE FUNCTIONS (ScenEdit_*)
-- ============================================================

--- Set posture between two sides.
--- @param side1   string  Side that is setting the posture
--- @param side2   string  Target side
--- @param posture PostureCode
function ScenEdit_SetSidePosture(side1, side2, posture) end

--- Set doctrine for a side, mission, or unit.
--- @param target table   {side=string} or {guid=string} or {name=string, side=string}
--- @param params table   Doctrine fields (weapon_control_status_*, etc.)
function ScenEdit_SetDoctrine(target, params) end

--- Set EMCON (Electronic Mission Control) for a side or unit.
--- @param level    'Side'|'Unit'|'Mission'
--- @param refStr   string  Side name, unit GUID, or mission name
--- @param emconStr string  Format: 'Radar=Active;Sonar=Passive;OECM=Active'
function ScenEdit_SetEMCON(level, refStr, emconStr) end

-- ============================================================
-- REFERENCE POINT FUNCTIONS (ScenEdit_*)
-- ============================================================

--- Add a reference point.
--- @param params table  {side=string, name=string, latitude=number, longitude=number, [highlighted=bool]}
--- @return ReferencePoint
function ScenEdit_AddReferencePoint(params) end

--- Delete a reference point.
--- @param params table  {side=string, name=string}
function ScenEdit_DeleteReferencePoint(params) end

-- ============================================================
-- KEYSTORE FUNCTIONS (ScenEdit_*)
-- ============================================================

--- Store a string value in persistent KeyStore.
--- @param key   string  Key name (unique per scenario)
--- @param value string  Must be a string — use tostring() for numbers
function ScenEdit_SetKeyValue(key, value) end

--- Retrieve a string value from KeyStore.
--- Returns '' (empty string) if key not set.
--- @param key string
--- @return string
function ScenEdit_GetKeyValue(key) end

-- ============================================================
-- SCORING & MESSAGING (ScenEdit_*)
-- ============================================================

--- Get current score for a side.
--- @param side string  Side name
--- @return number
function ScenEdit_GetScore(side) end

--- Set score for a side (absolute value).
--- @param side   string
--- @param score  number
--- @param reason string
function ScenEdit_SetScore(side, score, reason) end

--- Send a special message (in-game notification) to a side.
--- @param side    string  Side name or GUID
--- @param message string
function ScenEdit_SpecialMessage(side, message) end

--- End the scenario.
function ScenEdit_EndScenario() end

-- ============================================================
-- TIME FUNCTIONS (ScenEdit_*)
-- ============================================================

--- Get current scenario time as a Unix timestamp.
--- @return number  Seconds since epoch
function ScenEdit_CurrentTime() end

--- Set weather conditions.
--- @param params table  {WindDir=number, WindSpeed=number, Rainfall=number, SeaState=number}
function ScenEdit_SetWeather(params) end

-- ============================================================
-- VIEW-POINT READ FUNCTIONS (VP_*)
-- ============================================================

--- Get a side wrapper by name or GUID.
--- @param params table  {Side=string}
--- @return Side|nil
function VP_GetSide(params) end

--- Get a unit wrapper (read-only snapshot).
--- @param params table  {guid=string} or {side=string, name=string}
--- @return Unit|nil
function VP_GetUnit(params) end

--- Get a contact wrapper.
--- @param params table  {guid=string}
--- @return Contact|nil
function VP_GetContact(params) end

-- ============================================================
-- TOOL FUNCTIONS (Tool_*)
-- ============================================================

--- Calculate distance in nautical miles between two points.
--- @param from table  {latitude=number, longitude=number}
--- @param to   table  {latitude=number, longitude=number}
--- @return number  Distance in nautical miles
function Tool_Range(from, to) end

--- Calculate initial bearing in degrees from one point to another.
--- @param from table  {latitude=number, longitude=number}
--- @param to   table  {latitude=number, longitude=number}
--- @return number  Bearing in degrees (0-360, true north)
function Tool_Bearing(from, to) end

--- Check line of sight between two points.
--- @param from table  {latitude=number, longitude=number, altitude=number}
--- @param to   table  {latitude=number, longitude=number, altitude=number}
--- @return boolean  true if LOS exists
function Tool_LOS(from, to) end

--- Emulate no-console mode for testing event scripts from console.
--- Call with true at the top of console scripts that test event behavior.
--- @param enabled boolean
function Tool_EmulateNoConsole(enabled) end

-- ============================================================
-- WORLD FUNCTIONS (World_*)
-- ============================================================

--- Get terrain elevation at a geographic point.
--- @param params table  {latitude=number, longitude=number}
--- @return number  Elevation in meters (negative = below sea level)
function World_GetElevation(params) end

-- ============================================================
-- UI FUNCTIONS (UI_*)
-- ============================================================

--- Move the camera to a specific location.
--- @param params table  {latitude=number, longitude=number, [altitude=number]}
function UI_SetCameraView(params) end

-- ============================================================
-- ADDITIONAL SCENEEDIT FUNCTIONS
-- ============================================================

--- Get the current time of day as a string.
--- @return 'Day'|'Night'|'Dawn'|'Dusk'
function ScenEdit_GetTimeOfDay() end

--- Set EMCON for a group.
--- @param groupGuid string
--- @param emconStr  string
function ScenEdit_SetGroupEMCON(groupGuid, emconStr) end

--- Transfer a unit between bases.
--- @param params table  {guid=string, base=string}
function ScenEdit_TransferUnit(params) end

--- Get all units matching criteria.
--- @param params table  {side=string, [type=UnitType], [mission=string]}
--- @return Unit[]
function ScenEdit_GetUnits(params) end

--- Get a mission wrapper.
--- @param params table  {name=string, side=string} or {guid=string}
--- @return Mission|nil
function ScenEdit_GetMission(params) end

--- Add a contact to a side's contact list (manual contact injection).
--- @param params table  {side=string, latitude=number, longitude=number, [type=UnitType], [name=string]}
function ScenEdit_AddContact(params) end

--- Remove a contact from a side's contact list.
--- @param params table  {guid=string}
function ScenEdit_RemoveContact(params) end

--- Get scenario information.
--- @return table  {name=string, starttime=number, currenttime=number, duration=number}
function ScenEdit_GetScenarioInfo() end

--- Set scenario description or briefing text.
--- @param params table  {Description=string}
function ScenEdit_SetScenarioInfo(params) end
