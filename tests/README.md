# Testing and Validation

## Automated contributor validator

Run:

```bash
godot --headless --path /path/to/project \
  --script res://addons/GDBlueprints/tests/validate_addon.gd
```

The validator scans the registry, instantiates node scripts, checks stable IDs, duplicate IDs, definition shape, pin declarations, exec IDs, and teaching metadata. A non-zero exit code indicates validation errors.

To verify that handwritten GDScript remains isolated from generated code:

```bash
godot --headless --path /path/to/project \
  --script res://addons/GDBlueprints/tests/script_interop.gd
```

To verify that project-local node subclasses inherit properties, pins, and generated behavior:

```bash
godot --headless --path /path/to/project \
  --script res://addons/GDBlueprints/tests/node_extension.gd
```

## Manual smoke test before a release

### 0.4.7.2 regression suite

```bash
godot --headless --path /path/to/project \
  --script res://addons/GDBlueprints/tests/regression_0472.gd
```

Run in a disposable project containing the addon. This covers common actions in
UI/2D/3D menus, property discovery, child-relative references, browser-created
connections, saved graph restoration, and generated getter/setter runtime behavior.
For desktop smoke testing, use a Node3D → Control → Label scene, open the Control
graph, search Print String and Call Custom Event, drag Label into the graph, browse
`text`, add Set Property, connect execution, compile, and run. Reopen the scene and
confirm the reference browser and chosen property remain available.

### General smoke test

1. Clean-replace the addon folder and enable it.
2. Open a 3D, 2D, and UI scene.
3. Confirm graph load/frame behavior and node search.
4. Create Event → Action and Event → Branch → Action chains.
5. Test typed value connections, rejected mismatches, Promote to Variable, Split Struct, and disconnect/reconnect.
6. Compile and ensure the editor does not minimize/flicker.
7. Confirm the generated script parses and the scene runs.
8. Save, close, reopen, and verify graph/variables/frames restore.
9. Test a child-node reference, Group lookup, Custom Event, Signal connection, and Cast To Script.
10. Test hand-written code outside the generated region survives another compile.

## CI direction

The headless validator is designed to be the first stage of CI. A repository CI job should also open a fixture project in the supported Godot versions, import the project, run the validator, compile representative generated scripts, and execute a small runtime scene. Keep the workflow version matrix explicit so an engine upgrade cannot silently become the only tested version.

## Milestones 2 and 3

Run `graph_functions.gd`, `milestone2_types.gd`, and `milestone3_interop.gd` in a disposable project. They exercise generated synchronous methods, typed collection/enum boundaries, reflected defaults, editor signature updates, typed signal callbacks, external file preservation, and global-variable metadata recovery without executing handwritten initializers. See `documentation/testing-validation.html` for the complete test list.

## Milestone 4

Run `milestone4_debugger.gd` to check stable trace instrumentation, bounded activation snapshots, and the absence of graph-controlled pause hooks. Complete the manual game/editor test in `documentation/debugging.html` before release because the headless suite cannot prove a live Godot gutter breakpoint or the editor debugger connection's visual highlight.

## Milestone 5

Run `milestone5_gameplay.gd` in a disposable project to test the shipped 2D/3D scenes through real physics frames and graph reload/recompile, including input, obstacle collision, grounded jumping, spawning, overlap collection, native hazard/goal signals, health, HUD, restart, invalid references, and debugger cancellation. Run `build_gameplay_examples.gd` only to intentionally overwrite/regenerate the example assets through the production editor/compiler. See `documentation/gameplay-examples.html` for controls, collision layers, graph structure, failure behavior, and coverage boundaries.

## Milestone 6

Run `milestone6_persistence.gd` in a disposable project with writable user data. It creates and removes a unique `user://gdb_milestone6_*` directory, tests typed data/binary roundtrips, file replacement, checksum failure, backup recovery, version migrations, state preflight, generated persistence actions, template migration/value-node/result-ID reuse, and a 1,021-node compile/runtime fixture. See `documentation/persistence-and-reuse.html` for supported data and organization practices.
