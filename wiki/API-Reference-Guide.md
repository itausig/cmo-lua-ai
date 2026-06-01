# API Reference Guide

Use these documents as the authoritative API surface for this project:

- `docs/api-reference/FUNCTIONS.md`
  - CMO function signatures and expected parameter tables
- `docs/api-reference/WRAPPERS.md`
  - Wrapper object fields and usage expectations
- `docs/api-reference/ENUMS.md`
  - Enumerations and known value sets

## Practical usage advice

- Prefer GUID-based targeting over name-based lookups
- Treat event scripts as fail-silent; wrap risky operations
- Keep side effects in `ScenEdit_*` paths and reads in `VP_*` paths
