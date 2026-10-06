# 0.10.0-alpha validation

Validated September 25, 2026, on Windows x86_64 with Godot 4.7.2 stable (`ed1daf0bf`).

- 263 GDScript files load; 172 node definitions validate.
- All 20 regression/audit/catalog scripts passed, including Milestones 1–6, typed values/events/functions, safe script interoperability, node discovery, graph debugging and documentation links.
- Generated-code audit: 912 parsed cases, zero failures; 174 cases still require configuration or representative runtime fixtures.
- The 1,021-node fixture executed all 1,000 actions. Its measured build/compile time was 3.65 seconds during this run; this is a fixture measurement, not a general performance guarantee.
- Official standard Godot 4.7.2 export templates were downloaded and verified against the release SHA512 checksum. Real native Windows debug and release executables passed the export smoke fixture headlessly and with OpenGL Compatibility rendering on an NVIDIA RTX 3090.
- Exported runtime checks cover both gameplay scenes, generated input/movement/events, pickup spawn/deletion, restart, and typed save/load. Release builds create no debugger overlay and disable its processing and F8 input handler.
- Real release-export screenshots of both demos were captured and visually inspected. They are included in the source archive's media folder, together with a 256×256 icon.
- Documentation has 39 pages, 172 node sections and validated local links/anchors. Twelve theme tests passed.
- Exact source and addon ZIPs are checksum/content validated and clean-imported with the plugin enabled and all 172 registry definitions present. Packaging uses empty globals and omits engine binaries, caches, test output and credentials.

Release hardening found and fixed release-build debugger activity. The gameplay debugger fixture now reuses the existing autoload so it controls the same instance as generated code when a sample project enables the plugin.

## Scope and remaining human checks

This is a Windows/Godot 4.7.2 alpha candidate, not a certification of every node, engine version or platform. The new GitHub workflow configures Windows and Linux checks but has not run on GitHub yet. Other platforms, live editor highlighting/session behavior, manual keyboard playthroughs and resource-dependent legacy effects remain explicit acceptance checks in RELEASING.md. No repository or store listing was published.

The sandbox reported a root-certificate-store access error during local icon/UID generation; escalated isolated tests and native exports did not. It did not affect script validation or rendering.
