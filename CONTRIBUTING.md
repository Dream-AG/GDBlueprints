# Contributing to GDBlueprints

Start with `documentation/guides/CONTRIBUTING.md` and `documentation/guides/NODE_DEFINITION_API.md`.

Quick validation:

```bash
godot --headless --path /path/to/project --script res://addons/GDBlueprints/tests/validate_addon.gd
```

Project-local node packs belong in `res://gdblueprints_nodes/` so addon upgrades do not overwrite them.
