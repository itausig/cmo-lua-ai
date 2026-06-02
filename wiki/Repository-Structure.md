# Repository Structure

## Top-level layout

- `README.md` — project entry point
- `CONTEXT.md` / `.cursorrules` — AI context payloads
- `docs/` — API and scripting pattern documentation
- `src/` — reusable Lua modules, templates, and examples
- `types/` — LuaLS annotations for IDE support
- `prompts/` — prompt sources and AI assistant materials
- `tests/` — repository validation scripts
- `wiki/` — GitHub Wiki source pages
- `tests/` — repository validation scripts

## Documentation folders

- `docs/api-reference/`
  - `FUNCTIONS.md`
  - `WRAPPERS.md`
  - `ENUMS.md`
- `docs/patterns/`
  - `CSAR.md`
  - `DYNAMIC_SPAWNING.md`
  - `SIDE_SWITCHING.md`
  - `RANDOM_EVENTS.md`

## Source folders

- `src/core/` — foundations (`utils.lua`, `keystore.lua`)
- `src/lib/` — domain modules (combat, missions, doctrine, zones, etc.)
- `src/templates/` — starter scripts for scenario lifecycle
- `src/examples/` — full scenario-style implementations
