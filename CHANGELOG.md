# GDBlueprints 0.10.1-alpha

- Consolidate UI targeting, audio playback and animation into shared helpers while retaining saved node IDs and pin order.
- Fix cross-node audio controls, deferred spatial pause, fade interruption, sprite self targeting and reverse-animation speed.
- Bound overlapping audio voices and replace duration-proportional camera-shake allocation with one bound tween.
- Index compiler edges, reuse generated actions, expand dense node formatting and add native resource runtime fixtures.
- Remove per-node graph breakpoint buttons, their saved metadata and cooperative pause/step awaits; use View Code with Godot's Script debugger while keeping sampled graph highlights and watches.
- Recompile existing graphs to obtain the new runtime behavior; see the maintenance guide for audio channel semantics.

# GDBlueprints 0.10.0-alpha

- Disable debugger overlays, frame scans and F8 handling in release exports.
- Add genuine native debug/release export smoke fixtures for both gameplay examples and typed saves.
- Add reproducible addon/source archives, content hashes, clean globals and repository/CI release tools.
- Document the Windows 4.7.2 validation scope, alpha limitations and publishing/manual acceptance checklist.

# GDBlueprints 0.9.0-alpha

- Completed Milestone 6 with Capture State, Restore State, Save Game Data and Load Game Data (172 registered definitions), typed data preservation, checksums, temporary replacement, previous-good backup recovery and explicit schema migration Callables.
- Restore preflights all property names and values before assignment. Live references, object-typed containers, callable/signal/RID values and cyclic/oversized data are rejected. Legacy Save/Load JSON behavior remains compatible.
- Added validated, checksummed `.gdbtemplate` files with data-only legacy `.lbtemplate` migration. Selected graph reuse now preserves pure values/references/reroutes and refreshes result IDs; incompatible existing variable types reject import.
- Indexed graph connections and replaced recursive execution cycle/scope walks with iterative traversal. A 1,021-node fixture compiles and executes 1,000 actions in order without increasing runtime budgets.
- Added persistence, template and large-graph tests and a practical persistence/reuse guide. Milestone 7 is export/platform and Asset Library release hardening.

# GDBlueprints 0.8.0-alpha

- Completed Milestone 5 with playable 2D/3D Collect & Escape scenes, saved editable graphs, typed handwritten helpers, and real-physics integration fixtures.
- Added Input Vector, Move Character 2D/3D, Spawn Scene, Destroy Node, and Get Overlapping Bodies: direct references, documented failure behavior, and no scene-wide name lookup.
- Added `requires_physics` metadata for discovered actions and editable properties/data inputs on configurable pure-value nodes, including persistent value configuration and dependency-ordered binding refresh.
- Sampled ordinary debugger traces, kept editor panning limited to pauses, matched scene paths before highlighting, preserved preexisting pause state, honored breakpoints during stepping, and skipped cancelled actions after a debugger wait.
- Updated the offline manual and 168-node inventory. Persistence/project scale is next; legacy effects, multiplayer, and platform exports remain outside this milestone's verification.

# GDBlueprints 0.7.0-alpha

- Completed Milestone 4 with graph breakpoints, cooperative pause/continue, Step Into/Over/Out, stable-ID editor highlighting, and bounded activation snapshots.
- Added inspection for event arguments, function arguments/locals, loop frames, captured values, and explicitly watched variables without evaluating arbitrary graph expressions.
- Added editor debugger message capture and runtime overlay controls. Synchronous graph functions remain trace-only so their public GDScript methods do not acquire an `await` requirement.
- Added debugger architecture, workflow, limitations, automated regressions, and updated the roadmap toward Milestone 5 gameplay coverage.

# GDBlueprints 0.6.0-alpha

- Completed Milestones 2 and 3: Function Entry, Call Function, Return, Set Local, Enum Value, and Emit Typed Signal (162 registered definitions).
- Added typed synchronous GDScript wrappers, independent per-call locals, stored results, early returns, and shared budgets across recursive/cross-node calls.
- Added scope, return-path, signature, and waiting-operation validation; function graphs use execution format 4.
- Added Use Local Definition to function/event calls, safe signature application, and function runtime/editor/scene-persistence tests.
- Added native typed arrays/dictionaries, explicit stable integer enum cases, typed defaults/exports, and runtime schema checks.
- Added method/signal pickers, reflected argument defaults and return pins, typed signal events, idempotent connection/disconnection, and checked property/method/signal dispatch.
- Preserved handwritten globals, added generated-region edit detection and unsaved Script-tab checks, and avoided script instantiation when reading global declarations.
- Added collection, enum, interoperability, and roadmap guides plus runtime/editor/external-file regression fixtures. Graph-native debugging is next.

# GDBlueprints 0.5.2-alpha

- Added typed Custom Event parameters, graph call inputs, and ordinary typed GDScript entry points.
- Added explicit signature application with named wire remapping, incompatible-change rejection, and undo snapshots.
- Event arguments remain local to each invocation through delayed and legacy asynchronous paths; calls validate argument count and basic runtime types before dispatch.
- Added runtime/editor/save-reload regressions and documented event authoring, reference semantics, and remaining Milestone 2 work.

# GDBlueprints 0.5.1-alpha

- Started Milestone 2 with expanded variable types, concrete reference promotion, integer-vector pins, and compatible Inspector exports.
- Fixed nested collection and escaped-string reloads and packed-array code generation; added compiled-value and editor regressions.
- Graph functions, event parameters, enum authoring, and typed collection constraints remain pending.

# GDBlueprints 0.5.0-alpha — Milestone 1

- Unified native graph and chain-only save compilation through one execution backend.
- Added Sequence, Switch on Int/String, For Loop, For Each, Break, and Continue (156 built-in definitions total).
- Defined ordered awaited paths, inclusive loop bounds, nested control scope, Array snapshots, and activation-local loop values.
- Added Delay Cancel, owner-lifetime/state cancellation, 10,000-step and 128-call-depth budgets, including synchronous recursive custom events.
- Preserved condition adapters, per-chain legacy namespaces, stable IDs, and existing port positions; versioned execution migration and failed-compile rollback are covered by tests.
- Added runtime fixtures and headless editor save/reload tests; rebuilt the manual and node catalog.

# GDBlueprints 0.4.7.2-alpha

- Rebuilt the offline manual around the current graph workflow and live registry.
- Added a searchable reference for all 149 registered node definitions, with settings, outputs, target requirements, and explicit audit coverage.
- View Documentation resolves registered stable IDs and compatibility aliases directly to node sections.
- Renamed product/UI branding to GDBlueprints. The installation folder is now addons/GDBlueprints; resource paths must migrate. Saved graph identifiers remain compatible. Generated markers migrate on compilation; owned older debugger Autoload entries migrate when enabling the plugin.
- Added `res://gdblueprints_nodes/` discovery and a copy-one-file contributor workflow, with optional Python generation and inherited extensions.
- Replaced misleading message/signal and condition-combination labels; separated legacy Timer Event and One Shot Event from the new execution actions.
- Added missing node descriptions and native Godot teaching labels.
- Fixed Tab Next/Previous code generation, Get Transforms group lookup compilation, quoted message literals, empty Progress Bar operations, and collision events with no enabled detection types.
- Added Music dependency validation and exposed Print String's warning option.
- Added mode/configuration auditing and targeted runtime regressions. Passing syntax tests do not establish full gameplay coverage for every node/property combination.

Upstream attribution remains in LICENSE and THIRD_PARTY_NOTICES.md.

- Added execution-edge compilation, latent Delay, resettable Do Once, and runtime flow regressions. Unsupported cycles/legacy inactive-update behavior fail before script writes.
- Added a persistent dark/light documentation theme.
