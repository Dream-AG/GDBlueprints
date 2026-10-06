# Roadmap

## Completed foundations

Milestone 1: unified execution, structured control flow, cancellation, shared budgets, and compatibility tests.

Milestone 2: typed Custom Events, synchronous graph functions, parameters and returns, independent locals, native typed collections, explicit enum authoring, and documented value evaluation.

Milestone 3: reflected method/property/signal authoring, typed signal callbacks, graph-to-script and script-to-graph calls, safe signature updates, handwritten-source preservation, generated-edit detection, and runtime/editor interoperability fixtures.

These foundations are available in 0.7.0-alpha. They do not imply full-game runtime coverage for every existing action.

## Milestone 4: graph debugging

Completed in 0.7.0-alpha: stable-ID source mapping, active-node highlights, graph breakpoints on asynchronous execution nodes, Continue/Step Into/Step Over/Step Out controls, and bounded inspection of arguments, loop values, locals, captured results, and watched members. Synchronous function nodes remain trace-only to preserve ordinary non-awaiting GDScript calls.

## Milestone 5: core gameplay coverage

Completed in 0.8.0-alpha: two playable 2D/3D Collect & Escape scenes, editable saved graphs, direct-reference movement/spawn/deletion/overlap nodes, configurable input values, automatic physics scheduling metadata, and automated real-physics integration fixtures. The examples exercise collision, 3D jump/landing, pickup collection, native signals, damage/respawn, HUD win/loss state, and restart. See [Playable examples](gameplay-examples.html).

This is representative local single-player coverage, not full validation of every legacy node or every genre. The examples intentionally demonstrate graph/GDScript interoperability using typed handwritten helpers.

## Persistence and release

- Milestone 6 is completed in 0.9.0-alpha: data-only typed snapshots, versioned saves, explicit schema migration callbacks, corruption/backup handling, validated template migration and value-node reuse, indexed graph processing, and a 1,021-node integration fixture. See [Persistence and reuse](persistence-and-reuse.html).
- Milestone 7 is implemented in 0.10.0-alpha for the Windows 4.7.2 alpha target: native debug/release export tests, inactive release debugger, reproducible packaging, clean-install checks, isolated regression tools, publication guidance and Windows/Linux CI configuration. Human acceptance and untested platforms remain explicit release requirements. See [Release and publishing](release.html).

Multiplayer deserves a separate design and testing milestone. Arbitrary GDScript-to-graph conversion and complete Unreal API parity are outside the current contract.
