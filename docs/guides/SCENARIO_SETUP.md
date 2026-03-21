# Setting Up a Lua Scenario

This guide covers the community-standard patterns for structuring a CMO scenario that uses Lua scripting. Following these patterns makes your scenario maintainable, debuggable, and safe against the common pitfalls of CMO's save/load cycle.

Based on the community patterns pioneered at [GrandStrategos/Command_Resources](https://github.com/GrandStrategos/Command_Resources).

> **Cross-references:** [EVENT_SYSTEM.md](./EVENT_SYSTEM.md) | [FUNCTIONS.md](../api-reference/FUNCTIONS.md) | [BEST_PRACTICES.md](./BEST_PRACTICES.md)

---

## The Two Core Events

Every well-structured CMO Lua scenario has exactly two special framework events:

| Event | Trigger | When | Purpose |
|-------|---------|------|---------|
| **LuaInit** | `ScenLoaded` | Every load/reload | Load libraries, define functions, restore state |
| **GameSetup** | `Time` (scenario start) | Once per play | Spawn units, set postures, initialize game state |

These aren't magic names — they're a convention. But it's a very good one.

---

## The LuaInit Pattern

`LuaInit` runs every time the scenario is opened or loaded from a save. It is your bootstrapper.

### What LuaInit does

1. Loads helper libraries from the filesystem
2. Defines global functions that other events will call
3. Keeps itself active (preventing CMO from deactivating it on save)

### Setting Up LuaInit

**Step 1:** Create the trigger and action in the console:

```lua
-- Create the ScenLoaded trigger
ScenEdit_SetTrigger({
    name = 'T_ScenLoaded',
    type = 'ScenLoaded'
})

-- Create the action that runs LuaInit.lua
ScenEdit_SetAction({
    name       = 'A_RunLuaInit',
    type       = 'LuaScript',
    scriptText = "ScenEdit_RunScript('/Development/MyScenario/LuaInit.lua')"
})

-- Create the event and link them
ScenEdit_SetEvent('LuaInit', {
    mode         = 'add',
    IsRepeatable = true,
    IsActive     = true,
    IsShown      = false   -- hide from event log, it fires every load
})
ScenEdit_SetEventTrigger('LuaInit', 'T_ScenLoaded', {mode='add'})
ScenEdit_SetEventAction('LuaInit', 'A_RunLuaInit', {mode='add'})

print('LuaInit event created.')
```

**Step 2:** Create `LuaInit.lua` in your Lua folder:

```lua
-- LuaInit.lua
-- Runs on every scenario load. Bootstrap file.

-- Keep this event active even if CMO tries to deactivate it on save.
-- This is the #1 defensive measure — CMO sometimes deactivates events on save.
ScenEdit_SetEvent('LuaInit', {isActive=true})

-- Load helper libraries (each file runs in the global scope)
ScenEdit_RunScript('/Development/MyScenario/lib/helpers.lua')
ScenEdit_RunScript('/Development/MyScenario/lib/csar.lua')

-- Define any global functions that event action scripts will call.
-- Event scripts can only call functions if they're in global scope —
-- loading them here on ScenLoaded ensures they're available.
function MYSCEN_CheckVictory()
    local score = ScenEdit_GetScore('Blue')
    if score >= 1000 then
        ScenEdit_SpecialMessage('Blue', 'Mission accomplished!')
        ScenEdit_EndScenario()
    end
end

function MYSCEN_LogError(context, err)
    local msg = '[ERROR] ' .. context .. ': ' .. tostring(err)
    ScenEdit_SetKeyValue('last_error', msg)
    -- Uncomment to show errors to player:
    -- ScenEdit_SpecialMessage('Blue', msg)
end

-- Confirm init ran (useful during development, remove for release)
-- ScenEdit_SpecialMessage('Blue', 'LuaInit loaded at ' .. ScenEdit_CurrentTime())
```

> **Why `ScenEdit_SetEvent('LuaInit', {isActive=true})`?**  
> CMO's save system can deactivate events as part of its serialization. Including this call at the top of LuaInit ensures the event reactivates itself every time the scenario loads, making it self-healing.

---

## The GameSetup Pattern

`GameSetup` runs once per gameplay at the scenario's start time (the first second). It handles everything that should happen once at the beginning: spawning units, setting initial postures, configuring starting state.

### What GameSetup does

1. Spawns reinforcement units not present in the base scenario
2. Sets side postures (hostile/friendly/neutral)
3. Activates or deactivates missions based on game parameters
4. Seeds the KeyStore with initial values
5. Runs once — then deactivates itself so it doesn't repeat

### Setting Up GameSetup

```lua
-- Get the exact scenario start time
local startTime = ScenEdit_CurrentTime()  -- run this BEFORE the scenario clock starts
-- or if already running:
local scen = VP_GetScenario()
local startTime = scen.StartTime

-- Create the Time trigger at scenario start time
ScenEdit_SetTrigger({
    name = 'T_GameSetupTime',
    type = 'Time',
    time = startTime   -- fires at the first second of scenario time
})

-- Create the action
ScenEdit_SetAction({
    name       = 'A_RunGameSetup',
    type       = 'LuaScript',
    scriptText = "ScenEdit_RunScript('/Development/MyScenario/GameSetup.lua')"
})

-- Create the event — NOT repeatable (runs once)
ScenEdit_SetEvent('GameSetup', {
    mode         = 'add',
    IsRepeatable = false,
    IsActive     = true,
    IsShown      = true   -- show in log so you can confirm it fired
})
ScenEdit_SetEventTrigger('GameSetup', 'T_GameSetupTime', {mode='add'})
ScenEdit_SetEventAction('GameSetup', 'A_RunGameSetup', {mode='add'})

print('GameSetup event created.')
```

**GameSetup.lua:**

```lua
-- GameSetup.lua
-- Runs once at scenario start. Initialize everything.

-- Self-deactivate immediately (redundant with IsRepeatable=false, but defensive)
ScenEdit_SetEvent('GameSetup', {isActive=false})

-- Initialize KeyStore state variables
ScenEdit_SetKeyValue('MYSCEN_phase',           '1')
ScenEdit_SetKeyValue('MYSCEN_blue_losses',     '0')
ScenEdit_SetKeyValue('MYSCEN_csar_active',     'false')
ScenEdit_SetKeyValue('MYSCEN_reinforcements',  'false')

-- Set postures
ScenEdit_SetSidePosture('Blue', 'Red',     'H')  -- Blue is Hostile to Red
ScenEdit_SetSidePosture('Red',  'Blue',    'H')  -- Red is Hostile to Blue
ScenEdit_SetSidePosture('Blue', 'Neutral', 'N')  -- Blue is Neutral to Neutral side

-- Spawn scenario-specific units
local carrier = ScenEdit_AddUnit({
    side        = 'Blue',
    type        = 'Ship',
    name        = 'USS Nimitz',
    dbid        = 316,
    latitude    = 36.5,
    longitude   = -10.5,
    heading     = 90,
    proficiency = 'Veteran'
})
ScenEdit_SetKeyValue('MYSCEN_nimitz_guid', carrier.guid)  -- Store for later use

-- Activate first-phase missions
ScenEdit_SetMission('Blue', 'Phase 1 CAP', {isactive=true})
ScenEdit_SetMission('Blue', 'Phase 2 Strike', {isactive=false})  -- not yet

ScenEdit_SpecialMessage('Blue', 'Battle Group Alpha has deployed. Good luck.')
```

---

## File Structure

Organize your Lua files alongside the scenario:

```
[CMO Install]/Lua/
└── Development/
    └── MyScenario/
        ├── LuaInit.lua          -- Bootstrap: runs on every scenario load
        ├── GameSetup.lua        -- Init: runs once at scenario start
        └── lib/
            ├── helpers.lua      -- Shared utility functions
            ├── csar.lua         -- Combat Search & Rescue logic
            ├── scoring.lua      -- Victory condition checks
            └── ai_behavior.lua  -- Red force AI logic
```

**Naming recommendations:**
- Prefix all global functions with your scenario abbreviation: `MYSCEN_`, `OP_ALPHA_`, etc. This prevents collisions when multiple libraries are loaded.
- Keep `lib/` files pure (no side effects on load — just function definitions).
- Keep GameSetup.lua and LuaInit.lua as entry points that call into `lib/`.

---

## Loading Libraries

`ScenEdit_RunScript` runs a file in the current Lua state's global scope. All functions and variables defined in the file become globally available.

```lua
-- In LuaInit.lua:
ScenEdit_RunScript('/Development/MyScenario/lib/helpers.lua')

-- helpers.lua defines:
function HELPERS_GetNearestBase(side, lat, lon) ... end
function HELPERS_IsNight() ... end

-- Now HELPERS_GetNearestBase is callable from any subsequent event script
-- because LuaInit ran on ScenLoaded before any other event fires.
```

**Load order matters.** If `csar.lua` calls functions from `helpers.lua`, load `helpers.lua` first.

---

## ScenEdit_UseAttachment — Distributing with Embedded Scripts

When distributing a scenario (`.scen` file), external Lua files won't travel with it unless you embed them as **attachments**.

```lua
-- In the scenario editor: embed a Lua file as an attachment
-- Then at runtime, extract it to the Lua folder:
ScenEdit_UseAttachment('MyScenario_helpers')

-- ScenEdit_UseAttachmentOnSide extracts and runs on a side context:
ScenEdit_UseAttachmentOnSide('MyScenario_helpers', 'Blue')
```

For distribution, either:
1. Include a `README` telling users to copy your `Lua/Development/MyScenario/` folder, or
2. Embed all scripts as attachments and use `ScenEdit_UseAttachment` in LuaInit

Standalone distribution (option 2) is more user-friendly but requires managing the attachment workflow in the scenario editor.

---

## VSCode Setup and IntelliSense

For a production-quality editing experience, use VSCode with CMO IntelliSense support.

**Recommended extension:** [blu3ser's CMO IntelliSense](https://github.com/blu3ser/CMO_Intellisense) — an updated fork of KnightHawk75's original extension that provides function signatures, parameter hints, and completions for all CMO Lua API functions.

**Setup:**

1. Install [VSCode](https://code.visualstudio.com/) and the [Lua language server extension](https://marketplace.visualstudio.com/items?itemName=sumneko.lua) (`sumneko.lua`)
2. Clone or download [blu3ser/CMO_Intellisense](https://github.com/blu3ser/CMO_Intellisense)
3. Add this to your workspace `.vscode/settings.json`:

```json
{
    "Lua.workspace.library": [
        "/path/to/CMO_Intellisense/library"
    ],
    "Lua.runtime.version": "Lua 5.3",
    "Lua.diagnostics.globals": [
        "ScenEdit_AddUnit",
        "ScenEdit_GetUnit",
        "ScenEdit_SetUnit",
        "VP_GetSide",
        "VP_GetUnit"
    ]
}
```

4. Or copy the type definitions from `types/cmo.lua` in this repository into your project — these provide LuaLS annotations for all wrappers.

With IntelliSense active, you'll get autocomplete and parameter documentation for the entire CMO API as you type.

---

## Complete Bootstrap Example

Here's the complete setup for a new scenario, runnable in the console:

```lua
-- ============================================================
-- Bootstrap script: paste into CMO console to set up framework
-- ============================================================

local SCENARIO_NAME = 'OpAlpha'
local LUA_BASE_PATH = '/Development/OpAlpha'

-- Create ScenLoaded trigger
ScenEdit_SetTrigger({
    name = 'T_ScenLoaded_' .. SCENARIO_NAME,
    type = 'ScenLoaded'
})

-- Create LuaInit action
ScenEdit_SetAction({
    name       = 'A_LuaInit_' .. SCENARIO_NAME,
    type       = 'LuaScript',
    scriptText = "ScenEdit_RunScript('" .. LUA_BASE_PATH .. "/LuaInit.lua')"
})

-- Create LuaInit event
ScenEdit_SetEvent('LuaInit_' .. SCENARIO_NAME, {
    mode         = 'add',
    IsRepeatable = true,
    IsActive     = true,
    IsShown      = false
})
ScenEdit_SetEventTrigger('LuaInit_' .. SCENARIO_NAME,
    'T_ScenLoaded_' .. SCENARIO_NAME, {mode='add'})
ScenEdit_SetEventAction('LuaInit_' .. SCENARIO_NAME,
    'A_LuaInit_' .. SCENARIO_NAME, {mode='add'})

-- Create GameSetup time trigger at scenario start
local scen = VP_GetScenario()
ScenEdit_SetTrigger({
    name = 'T_GameSetup_' .. SCENARIO_NAME,
    type = 'Time',
    time = scen.StartTime
})

-- Create GameSetup action
ScenEdit_SetAction({
    name       = 'A_GameSetup_' .. SCENARIO_NAME,
    type       = 'LuaScript',
    scriptText = "ScenEdit_RunScript('" .. LUA_BASE_PATH .. "/GameSetup.lua')"
})

-- Create GameSetup event (runs once)
ScenEdit_SetEvent('GameSetup_' .. SCENARIO_NAME, {
    mode         = 'add',
    IsRepeatable = false,
    IsActive     = true,
    IsShown      = true
})
ScenEdit_SetEventTrigger('GameSetup_' .. SCENARIO_NAME,
    'T_GameSetup_' .. SCENARIO_NAME, {mode='add'})
ScenEdit_SetEventAction('GameSetup_' .. SCENARIO_NAME,
    'A_GameSetup_' .. SCENARIO_NAME, {mode='add'})

print('Framework events created for ' .. SCENARIO_NAME)
print('  LuaInit:   fires on every ScenLoaded')
print('  GameSetup: fires once at t=' .. scen.StartTime)
```

---

## Troubleshooting

**LuaInit isn't firing after save/reload**  
CMO deactivated the event. Add `ScenEdit_SetEvent('LuaInit', {isActive=true})` as the first line of `LuaInit.lua`.

**GameSetup fired twice**  
`IsRepeatable` was accidentally set to `true`. Check the event settings. Also ensure GameSetup immediately deactivates itself via `ScenEdit_SetEvent('GameSetup', {isActive=false})`.

**File not found error in `ScenEdit_RunScript`**  
Check the path. Remember it's relative to `[CMO Install]/Lua/` and requires a leading `/`. Paths are case-sensitive on Linux.

**Functions defined in LuaInit aren't available in event scripts**  
`ScenEdit_RunScript` runs in a new Lua environment by default. To share state across scripts, use the global table. Functions defined in LuaInit's loaded files are global — confirm LuaInit is actually running (add a `ScenEdit_SpecialMessage` temporarily).

**Changes to external `.lua` files aren't reflected**  
CMO caches nothing — it reads from disk every time `ScenEdit_RunScript` is called. If changes aren't showing up, check you saved the file and that the path in the event is correct.
