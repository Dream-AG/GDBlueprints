# Architecture

## Authoring and execution

The editor graph stores versioned scene metadata. The manager evaluates native events and legacy condition trees, while one execution backend translates connected actions and typed values into GDScript. The game executes the generated script using Godot APIs. No separate graph interpreter is required at runtime.

The installation folder is `addons/GDBlueprints/`. Saved metadata keys and stable node IDs are retained so existing graphs keep their identity. Resource paths must be migrated when upgrading from the previous folder; see Compatibility.

## Main modules

- `core/blueprint_node.gd`: node contract, serialization, execution pins, code-generation helpers.
- `core/brick_registry.gd`: deterministic discovery, stable IDs, aliases, duplicate detection, and menu metadata.
- `core/gdblueprints_manager.gd`: chain compilation, code-region replacement, and validation before file writes.
- `core/compiler_ir.gd`: structured operations lowered to GDScript.
- `core/pin_type_registry.gd`: data pin types and connection compatibility.
- `core/object_property_catalog.gd`: reflected property information for known objects.
- `core/documentation_helper.gd`: documentation URLs derived from registered stable IDs.
- `ui/gdblueprints_panel.gd` and UI helpers: graph interaction and editing.
- `bricks/`: node implementations. Folder names are internal compatibility vocabulary.

## Extension boundaries

Ordinary nodes live in one `.gd` file. Project-local scripts go in `res://gdblueprints_nodes/` and are discovered recursively. Helpers that do not inherit BlueprintNode are ignored. Duplicate stable IDs are errors, not silent overrides. File-system changes invalidate discovery.

The normalized definition adapter exposes existing methods. The editor still reads property and output methods directly; overriding only a definition dictionary is not sufficient for all UI behavior. Follow the working single-file template.

Control-flow nodes declare a tested execution operation through get_execution_spec(). Ordinary actions remain one-file extensions. New execution operations and graph functions need compiler semantics as well as pins. The editor panel still has room for further modularization.

## Documentation source

Markdown guides in `documentation/guides/` are the prose source. `tests/export_node_catalog.gd` writes live node metadata. `tests/audit_node_modes.gd` writes reproducible coverage data. `documentation/tools/build_site.py` builds the offline manual, exact node anchors, and Markdown index with no Python package dependencies.

## Unified execution backend

`ui/execution_graph_builder.gd` extracts execution edges with stable input/output IDs. It validates cycles, loop-control scope, loop-value scope, and reachable flow-node configuration. Disconnected drafts remain in raw graph metadata without executing.

`core/execution_graph_compiler.gd` lowers both native graphs and old chain-only saves into one representation and emits node methods. `core/execution_runtime.gd` provides per-activation context, loop scope, lifetime validation, and execution budgets; it is a small generated-code dependency, not a graph interpreter. Generated projects must retain this addon runtime file.

The manager retains event polling, physics scheduling, legacy condition evaluation, and generated-region ownership. Combine Conditions and old condition-style Branch/Cast definitions remain condition adapters. Script Controller retains its legacy terminal script-call behavior. Ordinary actions, Branch/Cast paths, inactive updates, and new flow nodes use the same node-method backend. The old flat actuator emitter and graph flattener have been removed.

Raw editor graph schema remains version 2. Its execution version is 2 for ordinary graphs, 3 for parameterized events, and 4 when function nodes are present. An upgrade marks legacy Branch/Cast input semantics or version-1 asynchronous fan-out per node. Chain-only metadata is normalized on a copy during compilation, keeping its original per-chain instance namespaces. Unknown future execution formats are rejected before script writes. Failed editor compilation preserves the last compiled-chain metadata as well as the script file.

`core/function_compiler.gd` validates function declarations, scope, result availability, and return paths. It marks function-owned execution paths as synchronous and emits typed public GDScript wrappers. `core/function_runtime.gd` checks local assignments, return values, and calls; function contexts share the execution budget while keeping arguments and locals separate. `ui/event_signature_editor.gd` applies event/function signatures using named wire remapping and undo snapshots. Retain these runtime dependencies when exporting games.

See [Execution and loops](execution-model.html) for the runtime contract and intentional limits.

## Types, reflection, and file preservation

`collection_types.gd` parses collection/enum schemas and builds native typed containers. `member_catalog.gd` reads method/signal declarations without calling user code. `member_editor.gd` and `member_browser.gd` apply reflected signatures through the shared signature editor. `signal_dispatch.gd`, `event_dispatch.gd`, and `property_access.gd` validate live targets and arguments.

`generated_region.gd` seals generated bodies with a checksum and detects external changes inside them. `script_edit_guard.gd` checks unsaved built-in Script tabs. Writers validate combined source and recheck the disk before writing. Global declarations include serialized metadata comments for lossless type/default recovery without instantiating scripts.

## Graph debugger

`execution_graph_compiler.gd` instruments stable execution-node IDs. The runtime Autoload pauses asynchronous paths cooperatively, owns step state, and sends bounded snapshots through `EngineDebugger`. `graph_debugger_plugin.gd` receives those messages in the editor; the panel matches scene owner paths and highlights the corresponding saved graph node. `debug_snapshot.gd` serializes activation state without evaluating expressions or getters. Synchronous graph functions emit trace messages without awaiting.

## Shared resource operations

UI target lowering lives in ui_action.gd and runtime node/path resolution in node_targets.gd. Audio definitions share audio_codegen.gd while games load only audio_runtime.gd. Animation and camera effects use animation_runtime.gd and camera_effects.gd. These helpers have native-resource runtime fixtures. See [Maintenance and coverage](maintenance.html).
