# Playable gameplay examples

Milestone 5 adds two small **Collect & Escape** games using the same graph design: a top-down 2D arena and a 3D arena with gravity and jumping. They are representative integration fixtures, not a claim that every existing node or every game genre is production-tested.

## Run a game

1. Enable GDBlueprints and open `res://addons/GDBlueprints/examples/gameplay/game_2d.tscn` or `game_3d.tscn`.
2. Run the current scene with F6. Generated scripts are included, so an initial compile is unnecessary.
3. Move with the arrow keys. In 3D, Space or Enter jumps. Collect the three gold pickups, avoid red hazards, and enter the green exit. The button restarts the round after a win or loss.
4. Select the scene root and open GDBlueprints to inspect or edit its graph. Compile and save after edits.

The scenes use the project's existing `ui_left`, `ui_right`, `ui_up`, `ui_down`, and `ui_accept` Input Map actions. They do not add or overwrite project settings. If you have changed those actions, use your assigned controls or edit the Input Vector node. In 3D, input follows world X/Z axes, not camera-relative axes.

## Follow the graph

- Physics Tick reads Input Vector, calls a typed velocity helper, runs Move Character, queries overlaps, then updates the HUD. Velocity is in units per second; `move_and_slide()` handles the timestep.
- Start Round iterates three local transforms and uses Spawn Scene to create pickups under the explicit Pickups parent.
- Pickup checks that a body is a live, uncollected pickup, adds to the score, then uses Destroy Node. Queued bodies are ignored to prevent double scoring.
- Native Area signals call typed Damage and Reach Goal Custom Events. The exit branch checks all three pickups and positive health before declaring a win.
- The Restart button calls a handwritten helper that resets health, score and position, removes the old pickups, and calls Start Round again.

Player collision mask 1 blocks the arena's solid geometry. Pickups occupy layer 2, which the player's Detector Area monitors without physically blocking the player. Hazard and goal Areas monitor the player on layer 1. Overlap snapshots update on physics steps; teleporting an Area or body does not synchronously refresh them.

## Graph and GDScript work together

The two `game_2d.gd` / `game_3d.gd` files contain sealed generated regions. Their shared parent script, `game_base.gd`, supplies typed velocity, score, health, HUD and restart helpers. This deliberately demonstrates the supported hybrid workflow: edit graph routing in the graph and edit handwritten helpers in Godot's Script tab or an external editor. Do not edit the sealed generated region.

The helpers use native CharacterBody, Area, PackedScene, Label and Button APIs. For example, 3D gravity is added to vertical velocity using delta, and a jump is allowed only while `is_on_floor()` is true. Use the Call Function method picker to replace a helper with your own typed script method, or a graph function with the same signature.

## New reusable nodes

- **Input Vector**: four named input actions produce a length-limited Vector2. Missing actions produce zero. Deadzone -1 uses the actions' average deadzone; other values are clamped to the supported range.
- **Move Character 2D / Move Character 3D**: an explicit CharacterBody reference and velocity call `move_and_slide()` once. Invalid, freed, detached or queued targets do nothing. Run once per physics step and do not combine with the older Character Physics node on the same body.
- **Spawn Scene**: a PackedScene, live parent and optional local Transform2D/Transform3D produce an Instance output. The transform is applied before entering the tree. Invalid inputs or a dimensional mismatch return null, and Then still runs; use a Branch to check Instance before dereferencing it. Results belong to that execution activation and are available downstream, not across unrelated events. Runtime spawning does not set an editor scene owner. Spawn outside physics-query signal callbacks, or defer the calling event using Godot's `call_deferred()`.
- **Destroy Node**: queues a direct Node reference for deletion. Invalid/freed/already queued targets do nothing. Destroying Self cancels its remaining graph path.
- **Get Overlapping Bodies**: a direct Area2D/Area3D reference returns the latest `Array[Node]` overlap snapshot. Invalid targets return an empty array. Monitoring and collision masks must be configured.

These definitions live in the normal discovered node folders. No special registration is required. Physics actions can declare `"requires_physics": true` in `get_brick_info()` or `get_blueprint_definition()` to put automatic update chains in `_physics_process`. A Custom Event still runs when its caller invokes it; this metadata does not reschedule explicit calls.

## Verification and boundaries

`tests/milestone5_gameplay.gd` runs the shipped scenes through real physics frames: normalized input, movement against obstacles, 3D grounded jumping and landing, spawning, overlaps, damage/respawn, cooldown, pickup deletion, win/loss HUD state, button restart, invalid references, transformed parents, and graph save/reload/recompile. It also checks configurable value-node authoring and debugger pause/cancellation regressions.

Maintainers can deliberately regenerate the examples using `tests/build_gameplay_examples.gd` in a disposable project. This overwrites the shipped example scenes and their generated scripts; do not use it to compile your own edited example.

The examples cover local single-player gameplay. They do not validate multiplayer, navigation, animation trees, audio, persistence, every legacy scene effect, or exported builds. Persistence/project scale is Milestone 6; platform/export and Asset Library release validation is Milestone 7.
