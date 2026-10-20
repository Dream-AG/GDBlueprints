# 0.10.1-alpha validation

Validated October 20, 2026, on Windows x86_64 with Godot 4.7.2 stable (`ed1daf0bf`).

- 271 GDScript files load; all 172 registered node definitions validate.
- All 22 isolated regression, audit, catalog, and documentation scripts passed. This includes Milestones 1–6, typed values/events/functions, safe script interoperability, automatic node discovery, sampled graph traces, playable gameplay fixtures, native resource helpers, persistence, and compiler maintenance.
- The native resource suite passed 171 assertions across shared target resolution, UI actions, audio playback/control, animation, sprite animation, collision deferral, camera shake, and object-flash restoration.
- Generated-code audit: 938 configurations parsed with zero failures; 151 configurations require user properties or representative scene/runtime fixtures.
- The 1,021-node compiler fixture executed all 1,000 actions in order. Three warm/cold samples improved from 3,753/1,951/1,964 ms to 3,663/1,788/1,788 ms after edge indexing and generated-action reuse. These are fixture measurements, not general performance guarantees.
- Official Godot 4.7.2 editor and standard export templates were downloaded from Godot's GitHub release and verified against its SHA-512 manifest. Real Windows debug and release executables passed the headless export smoke fixture without script errors or ObjectDB leak warnings.
- Exported runtime checks cover both gameplay scenes, generated input/movement/events, pickup spawn/deletion, restart, typed save/load, all three audio-player families, animation playback, and camera-effect restoration. Release builds create no debugger overlay and disable its frame and F8 processing.
- The offline manual has 40 pages, 172 exact node sections, validated local links/anchors, and 12 passing light/dark/system-theme tests.
- Deterministic addon and source archives were built twice with identical checksums, every entry hash was verified, and both archive layouts clean-imported with the plugin enabled and all 172 definitions present. Packaging replaces project globals in memory and does not modify the developer's `global_vars.gd`.
- Per-node graph breakpoint buttons, cooperative pause/step hooks, saved breakpoint/debug-message fields, and their execution-node `await` boundary were removed. View Code now leads users to Godot's normal Script gutter breakpoints; sampled graph highlighting and watch snapshots remain.

## Scope and remaining human checks

This is a Windows/Godot 4.7.2 alpha candidate, not certification of every node, engine version, rendering backend, device, or platform. The repository workflow defines Windows and Linux checks but has not run on GitHub yet. Complex AnimationTree setups, split-screen rendering, hardware-dependent input/effects, multiplayer/network conditions, live editor highlighting, manual gutter-breakpoint behavior, and keyboard playthroughs remain explicit manual or platform acceptance checks. No repository release or Asset Library listing was published by this validation.
