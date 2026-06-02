# CMO Lua AI — The Command: Modern Operations Lua Reference & Script Library

> **Plug-and-play with AI coding assistants.** This repository is the definitive Lua scripting reference for [Command: Modern Operations](https://www.matrixgames.com/game/command-modern-operations) (CMO), structured so AI tools (Cursor, Copilot, Claude, ChatGPT, etc.) can generate correct CMO Lua code on the first try.

---

## Why This Exists

CMO exposes a powerful but sprawling Lua API. The official docs are scattered across wikis, forum posts, and changelogs. AI assistants hallucinate function names and invent parameters that don't exist. This repo solves both problems:

1. **Single source of truth** — Every function, wrapper, enum, and data type in one place.
2. **AI-optimized context** — Drop `CONTEXT.md` or `.cursorrules` into your project and the AI *knows* CMO Lua.
3. **Battle-tested scripts** — Reusable modules for combat, CSAR, missions, doctrine, events, and more.

## Quick Start

### For AI-Assisted Coding (Cursor / Copilot / Claude)

1. Copy `.cursorrules` into your CMO Lua project root.
2. Or paste the contents of `CONTEXT.md` into your AI system prompt.
3. Start writing CMO Lua — the AI will use correct function signatures.

### For Manual Scripting

1. Browse `docs/api-reference/` for the complete API.
2. Copy modules from `src/lib/` into your scenario's Lua folder.
3. Follow `docs/guides/` for setup and patterns.

### For Scenario Development

```
YourCMOFolder/
└── Lua/
    └── Development/
        └── MyScenario/
            ├── LuaInit.lua          -- Loaded on every scenario start
            ├── GameSetup.lua        -- Runs once at scenario start time
            └── lib/                 -- Copy modules from src/lib/ here
                ├── utils.lua
                ├── csar.lua
                └── ...
```

## Repository Structure

```
cmo-lua-ai/
├── .cursorrules              # Drop into project for Cursor/Copilot context
├── CONTEXT.md                # Full AI context file (paste into system prompts)
├── README.md                 # This file
│
├── docs/
│   ├── api-reference/
│   │   ├── FUNCTIONS.md      # All ScenEdit_*, VP_*, Tool_* functions
│   │   ├── WRAPPERS.md       # Unit, Side, Mission, Contact, etc. wrappers
│   │   ├── ENUMS.md          # All enumerated types and codes
│   │   └── DATA_TYPES.md     # Altitude, GUID, DateTime, KeyStore, etc.
│   ├── guides/
│   │   ├── QUICKSTART.md     # First script in 5 minutes
│   │   ├── EVENT_SYSTEM.md   # Triggers, Conditions, Actions (TCA)
│   │   ├── SCENARIO_SETUP.md # LuaInit / GameSetup pattern
│   │   └── BEST_PRACTICES.md # Error handling, GUID usage, performance
│   └── patterns/
│       ├── CSAR.md           # Combat Search & Rescue implementation
│       ├── DYNAMIC_SPAWNING.md
│       ├── SIDE_SWITCHING.md
│       └── RANDOM_EVENTS.md
│
├── src/
│   ├── core/
│   │   ├── utils.lua         # Foundation utilities (logging, validation, etc.)
│   │   └── keystore.lua      # Persistent state management wrapper
│   ├── lib/
│   │   ├── combat/
│   │   │   ├── attack.lua    # Engagement and weapon allocation
│   │   │   └── damage.lua    # Damage assessment and tracking
│   │   ├── movement/
│   │   │   ├── course.lua    # Waypoint and course management
│   │   │   └── formation.lua # Formation control
│   │   ├── sensors/
│   │   │   └── detection.lua # Sensor and LOS utilities
│   │   ├── logistics/
│   │   │   ├── fuel.lua      # Fuel management
│   │   │   └── resupply.lua  # Magazine and weapon reloading
│   │   ├── events/
│   │   │   ├── builder.lua   # Programmatic event creation (TCA)
│   │   │   └── triggers.lua  # Common trigger patterns
│   │   ├── missions/
│   │   │   ├── builder.lua   # Mission creation helpers
│   │   │   └── management.lua # Assignment and lifecycle
│   │   ├── zones/
│   │   │   └── areas.lua     # Reference points and zone management
│   │   ├── emcon/
│   │   │   └── emcon.lua     # Emission control management
│   │   ├── doctrine/
│   │   │   ├── doctrine.lua  # Doctrine configuration
│   │   │   └── wra.lua       # Weapon Release Authority
│   │   ├── scoring/
│   │   │   └── scoring.lua   # Score and side management
│   │   ├── ui/
│   │   │   └── messages.lua  # Player messaging and dialogs
│   │   ├── cargo/
│   │   │   └── cargo.lua     # Cargo and transport operations
│   │   └── weather/
│   │       └── weather.lua   # Weather control
│   ├── templates/
│   │   ├── scenario_init.lua # Boilerplate LuaInit template
│   │   ├── game_setup.lua    # Boilerplate GameSetup template
│   │   └── special_action.lua # Special Action template
│   └── examples/
│       ├── carrier_ops.lua   # Full carrier battle group scenario
│       ├── asw_patrol.lua    # ASW patrol with dynamic contacts
│       ├── csar_system.lua   # Complete CSAR implementation
│       ├── dynamic_campaign.lua # Multi-phase campaign scripting
│       └── red_ai.lua        # Advanced AI opponent behavior
│
├── types/
│   └── cmo.lua               # LuaLS type annotations for IDE support
│
├── prompts/
│   ├── system_prompt.md      # Full system prompt for AI assistants
│   ├── cursor_rules.md       # Source for .cursorrules generation
│   └── examples.md           # Example prompt/response pairs
│
└── tests/
    └── validate.lua          # Syntax validation for all library files
```

## Wiki

- Local wiki source pages: [`wiki/Home.md`](wiki/Home.md)
- Recommended first page: [`wiki/Home.md`](wiki/Home.md)

## Official Documentation Sources

- [Command Lua Docs (Current)](https://commandlua.github.io) — Primary API reference
- [Command Lua Docs (Legacy)](https://commandlua.github.io/oldsite/index.html) — Detailed function docs
- [Matrix Games Forums](https://forums.matrixgames.com/) — Community scripts and examples
- [CMO Game Manual (PDF)](https://www.matrixgames.com/amazon/PDF/CMO/CMO_manual_EBOOK.pdf)
- [Command PE User Manual (PDF)](https://www.usmcu.edu/Portals/218/Krulak/Wargaming%20Directorate/Command%20PE%20User%20Manual.pdf)

## Key Concepts

### CMO Lua runs in two contexts:

| Context | When | Error Behavior |
|---------|------|----------------|
| **Lua Console** | Manual entry during play | Shows error messages in-game |
| **Event Scripts** | Triggered by TCA events | Errors are silent — script stops, no message shown |

### Always use GUIDs over names:

```lua
-- BAD: Name can change or be ambiguous across sides
local unit = ScenEdit_GetUnit({name = 'F-15C Eagle'})

-- GOOD: GUID is unique and permanent
local unit = ScenEdit_GetUnit({guid = 'a1a52edf-3541-4b55-bea4-58d4e1ab11dc'})
```

### Error handling in event scripts:

```lua
Tool_EmulateNoConsole(true)  -- Required at top of console scripts that test event code
local success, result = pcall(ScenEdit_AddUnit, {
    side = 'Blue', type = 'Ship', name = 'USS Test', dbid = 960,
    latitude = 'N38.50.00', longitude = 'E6.50.00'
})
if not success then
    -- Handle error: result contains error message
end
```

## Contributing

PRs welcome. If you discover undocumented functions, updated wrapper fields, or useful patterns, please contribute.

## License

MIT — Use freely in your CMO scenarios and tools.
