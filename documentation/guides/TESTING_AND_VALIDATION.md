# Testing and current limits

## Automated checks

Run in a disposable Godot project containing the addon. Replace `godot` with your Godot executable and run from the project root.

```bash
godot --headless --path . --script res://addons/GDBlueprints/tests/validate_sources.gd
godot --headless --path . --script res://addons/GDBlueprints/tests/validate_addon.gd
godot --headless --path . --script res://addons/GDBlueprints/tests/regression_0472.gd
godot --headless --path . --script res://addons/GDBlueprints/tests/script_interop.gd
godot --headless --path . --script res://addons/GDBlueprints/tests/node_extension.gd
godot --headless --path . --script res://addons/GDBlueprints/tests/node_behavior_regressions.gd
godot --headless --path . --script res://addons/GDBlueprints/tests/audit_node_modes.gd
godot --headless --path . --script res://addons/GDBlueprints/tests/execution_flow.gd
godot --headless --path . --script res://addons/GDBlueprints/tests/milestone1_execution.gd
godot --headless --path . --script res://addons/GDBlueprints/tests/milestone1_editor.gd
godot --headless --path . --script res://addons/GDBlueprints/tests/typed_data.gd
godot --headless --path . --script res://addons/GDBlueprints/tests/event_parameters.gd
godot --headless --path . --script res://addons/GDBlueprints/tests/graph_functions.gd
godot --headless --path . --script res://addons/GDBlueprints/tests/milestone2_types.gd
godot --headless --path . --script res://addons/GDBlueprints/tests/milestone3_interop.gd
godot --headless --path . --script res://addons/GDBlueprints/tests/milestone4_debugger.gd
godot --headless --path . --script res://addons/GDBlueprints/tests/milestone5_gameplay.gd
godot --headless --path . --script res://addons/GDBlueprints/tests/milestone6_persistence.gd
godot --headless --path . --script res://addons/GDBlueprints/tests/export_node_catalog.gd
python addons/GDBlueprints/documentation/tools/build_site.py
python addons/GDBlueprints/documentation/tools/validate_site.py
godot --headless --path . --script res://addons/GDBlueprints/tests/documentation_links.gd
```

Source validation loads addon scripts. Definition validation checks discovery, stable-ID round trips, and pin contracts. Regression tests cover child-node availability, reflected properties, reference connections, and generated getter/setter behavior. Interoperability tests check handwritten code preservation, marker migration, and collision rejection. Extension tests check inherited defaults, pins, identity, and generated behavior.

The mode audit generates scripts for defaults, configured fixtures, string and integer enum choices, and individual boolean toggles. All 172 registered definitions have at least one passing generated-code case. It records configuration-dependent cases explicitly in `node_audit.json`; it does not count skipped cases as passes. It does not test every combination of properties or prove all scene-dependent runtime effects. Each node's reference shows its coverage. Runtime regressions also test tab wrapping, nearest-group transform lookup in 2D/3D, and message text with quotes and newlines.

## Manual scene tests

1. Enable the plugin and create a root and child graph in 2D, 3D, and UI scenes.
2. Add nodes, connect execution and values, save, close, reopen, and confirm restoration.
3. Compile and run representative physics, animation, audio, UI, and scene-loading graphs with real resources.
4. Exercise Branch outputs, Cast success/failure, custom events, and native signal arguments.
5. Confirm direct references, exported references, missing targets, and duplicate-name behavior.
6. Test state changes and repeated activation of timers, tweens, audio, pooled objects, and effects.
7. Edit handwritten code in an external editor, save, recompile, and check the diff.
8. Open View Documentation on nodes and confirm the corresponding reference section.

## Execution flow checks

`execution_flow.gd` tests Delay/Do Once, Reset, re-entry, pause/resume, instance isolation, owner deletion, branches, and Reset UI slots. `milestone1_execution.gd` runs structured and nested loops, Break/Continue, delayed bodies, integer/string switches, ordered Sequence outputs, cancellation, state round trips, chain-only migration, condition-style Branch compatibility, inactive updates, execution budgets, recursive custom events, scope validation, and a scene-file round trip. `milestone1_editor.gd` creates real editor nodes and checks ports, graph saving, and reloading.

## Current limits

`typed_data.gd` compiles every supported variable default and supported Inspector export, checks concrete reference promotion and packed-array compatibility, runs nested collection/string reload cases, and exercises the actual variable editor and manager-generated declarations. `event_parameters.gd` checks typed event calls, argument isolation across delayed invocations, single argument evaluation, invalid calls/signatures/scopes, editor pin updates, wire preservation and rejection, and scene-file persistence. `graph_functions.gd` tests direct typed GDScript calls without await, nested/recursive locals, independent mutable local defaults, cross-node calls with shared budgets, Return inside loops, calls after Delay, scope/return/latent validation, signature copying, and editor/scene-file persistence.

This release remains alpha. Milestone 1 supplies unified execution, structured loops, ordering, cancellation, and compatibility adapters. Back-wire cycles are deliberately rejected. Activations have a 10,000-step budget and a 128-active-node-call depth limit, including nested execution. Invalid loop scope, duplicate switch cases, and constant zero steps are compile errors. Dynamic zero steps, invalid Array inputs, non-finite delays, and budget exhaustion report runtime errors and cancel execution without Completed.

Functions are synchronous instance methods on scene-tree owners. Their body cannot wait; handwritten methods called through Call Function must also be synchronous. Typed collections, enums, reflected methods/signals, sampled graph traces, and Godot Script breakpoints are implemented. Nested typed containers, custom script-class container schemas, variadic picker signatures, and automatic GDScript-to-graph conversion are unsupported. Some older actions still use scene-wide name searches; prefer direct references and Object property/method nodes. Legacy Save/Load retains its original JSON/scalar coverage; new Capture/Restore State and Save/Load Game Data supply typed, versioned data persistence. Milestone 5 covers representative gameplay physics; audio, animation and object-flash now have representative native-resource fixtures; complex AnimationTree, split-screen, hardware-dependent effects and other configurations still need targeted fixtures. A passing generated-code audit does not establish full gameplay coverage.

`milestone2_types.gd` checks native typed exports, collection invariance, invalid defaults, enum signatures, typed dispatch/locals/returns, invalid enum rejection, and variable-editor persistence. `milestone3_interop.gd` checks reflected signatures/defaults, editor-created signal events, typed signal emission and disconnection, generated callbacks calling handwritten helpers, graph reload, actual external-file preservation, and generated-region checksums.

`milestone4_debugger.gd` checks bounded activation snapshots, watched values, stable trace instrumentation, removal of graph-controlled pause hooks, and generated-script parsing. Manual release testing verifies Godot gutter breakpoints, overlay watches, and editor highlighting through the live debugger connection.

`milestone5_gameplay.gd` exercises the shipped 2D/3D scenes through real physics frames, graph reload/recompile, direct-reference failure paths, input, movement/collision, 3D jumping/landing, spawning, Area signals, overlap pickups, damage/respawn, HUD win/loss, and button restart. It checks trace instrumentation, removal of graph-controlled pause hooks, and value-node menu authoring. These fixtures cover their named gameplay paths; they do not establish coverage for every audio format, effect configuration or platform. See [Playable examples](gameplay-examples.html).

## Release verification

Milestone 7 adds an export-template-only runtime fixture and isolated Python runners in the source release repository. See [Release and publishing](release.html) for the supported target, archive validation and remaining human acceptance checks. CI configuration for another platform does not certify that platform before a successful run.

## Code maintenance and resource fixtures

See [Maintenance and coverage](maintenance.html) for the 0.10.1 cleanup, new audio/animation/UI/effect runtime checks, and the distinction between required compatibility code and untested scene configurations.
