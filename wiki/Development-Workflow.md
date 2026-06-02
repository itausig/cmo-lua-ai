# Development Workflow

## Suggested loop

1. Start from `src/templates/` for new scenario logic
2. Reuse `src/lib/` modules instead of one-off scripts
3. Validate script syntax before publishing

## Validation

The repository includes a syntax validation script:

```bash
lua tests/validate.lua
```

If Lua is unavailable in your environment, install a Lua interpreter first.

## Documentation-first maintenance

When adding capabilities:

- Update `docs/api-reference/` for API changes
- Add or update `docs/patterns/` for scenario techniques
- Keep wiki pages aligned with canonical docs
