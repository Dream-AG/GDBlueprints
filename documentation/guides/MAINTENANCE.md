# Maintenance and runtime coverage

## What compatibility means

Some stable node IDs, old saved-graph adapters, metadata keys and small menu wrappers are retained so existing projects load correctly. They are active compatibility code, not abandoned copies of the plugin. A 2D/UI wrapper that inherits a shared implementation avoids duplication. The canonical installation is addons/GDBlueprints.

A generated-code audit checks syntax for particular configurations. A runtime fixture creates resources and executes the graph or generated node, checking observable results. Neither means every possible scene, resource, device and timing combination has been tested. An unconfigured audit case is not automatically a broken node or dead code.

## 0.10.1 cleanup

Seven UI actions share one definition helper and runtime target resolver. Existing data-pin order is preserved, with new Target pins appended. A connected Node reference takes precedence; otherwise a relative NodePath resolves directly. Scene-wide name lookup remains a compatibility fallback. Explicit paths that fail never fall back to unrelated names. Freed/queued references are rejected. No persistent name cache can go stale when a scene changes.

Audio 2D, UI Audio and 3D Audio now share one playback implementation. An optional Channel connects separate Play, Stop, Pause and Fade nodes on the same graph owner. With no Channel, Play uses its file as the channel key. Stop/Pause/Fade Out with no channel or file affect all channels of that owner and audio family; specifying a file narrows the selection. Different graph owners stay isolated. Recompile existing graphs to use this behavior.

Each channel prepares its stream once, without mutating the imported resource. At most 32 overlapping voices are retained per channel; oldest excess voices are removed. Looping uses one persistent player and suppresses repeated restarts. Spatial Pause requests survive deferred playback startup. New playback cancels an old fade-out. Pitch is clamped to a positive supported range, missing resources fail safely, and non-finite numeric values are rejected. Control operations continue through Then even when no channel exists; they do not introduce new execution outputs.

Animation uses one runtime helper with explicit player targeting or owner/descendant discovery. Reverse playback, blend time, dynamic speed and from-end are handled independently; stale speed multipliers are reset. Sprite Animation correctly includes the owner itself and restores the configured default speed. Camera Shake uses one replaceable bound tween regardless of duration, restores the original offset/rotation and rejects non-finite settings.

The execution compiler indexes outgoing edges once and generates each action once per compile pass. Traversal queues use a cursor instead of repeatedly shifting arrays. Ordering, cancellation, inactive branches and saved IDs retain their existing contracts. Dense node definitions were expanded into readable formatting. Only redundant implementations were removed; required compatibility entry points remain.

## Tested behavior and remaining work

resource_node_runtime.gd executes generated audio modes for all three player classes, native AnimationPlayer resources, AnimatedSprite2D, UI controls, collision shapes, camera effects, and all 2D/3D object-flash modes. It also checks dynamic value bindings, channel isolation/lifetime rules, voice cleanup, and pin ordering. Existing suites cover structured flow, events/functions, gameplay, persistence and script interoperability. The native export smoke test also exercises the new runtime helpers.

This is representative coverage, not a claim of perfection. Complex AnimationTree state machines, split-screen rendering, hardware rumble, platform-specific audio, networking, and every resource-dependent effect configuration still need targeted acceptance tests. Test the capabilities your game uses and report a minimal reproducer for failures. Keep new features small, document their failure behavior, and add a runtime fixture with real resources when syntax checks alone cannot establish correctness.
