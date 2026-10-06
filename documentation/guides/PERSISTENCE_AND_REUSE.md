# Persistence and reusable graphs

Milestone 6 adds explicit, versioned game-state persistence and improves template reuse and larger-graph processing. Use data snapshots for saves, native scenes for reusable game objects, and graph functions for shared behavior.

## Save a checkpoint from a graph

1. Add a Custom Event named `save_checkpoint`.
2. Connect **Capture State** with Target `self` and Names `PackedStringArray(["health", "inventory"])`. Choose actual properties on your script. Capture reads only those named properties.
3. Branch on Capture State's **Success**. On True, run **Save Game Data**. Wire Capture's **Data** into its Data input, use `user://saves/checkpoint.gdbsave`, and start with Version 1.
4. Branch on Save's **Success** before showing a success message. Its Error output explains a failure.
5. For loading, run **Load Game Data**, branch on Success, pass Data to **Restore State**, then branch on Restore's Success before refreshing the HUD or continuing gameplay.

Every operation continues through Then, including failures. Its Success/Error outputs describe that activation. Keep result wires downstream of their producing action. Do not save an empty fallback Dictionary after a failed capture or apply load data without checking Success.

Capture/Restore accept direct Object references. They do not search the scene tree. Restore checks every property name and type before assigning any field; typed Array/Dictionary members validate their contents. Unknown, read-only, incompatible, or unsupported fields reject the complete snapshot before assignment. Explicit getters and setters remain ordinary GDScript code: a setter can have external side effects, so Restore cannot promise transaction rollback for arbitrary user code.

## What can be saved

The data-only codec preserves null, booleans, 64-bit integers, floats, strings, StringName, NodePath, integer/floating vectors, rectangles, transforms, Basis, Quaternion, Plane, AABB, Projection, Color, arrays, dictionaries, supported native typed containers, and packed arrays. Integer keys and integers beyond JSON's exact numeric range retain their types and values. Limits are 16 MiB of encoded data, 100,000 entries, and 32 nested levels. Cyclic containers are rejected.

Live Nodes, Objects, Resources, Callables, Signals, RIDs and Object-typed containers are rejected. Store a stable game ID or resource path instead, then resolve it deliberately after loading. A NodePath is saved as a value; loading it does not look up or create a node. Resource loading and whole-scene reconstruction are not implicit save operations.

For a complete world checkpoint, build a Dictionary with explicit player state, stable entity IDs, scene/resource IDs and local transforms. Recreate entities from known PackedScenes, then restore their state. Avoid storing absolute runtime node names as long-term identities. Keep transient references, timers, debugger state, cached results and execution contexts out of save data.

## File behavior and recovery

Save paths must be files under `user://`; parent traversal and `res://` writes are rejected. The runtime creates nested directories, writes and flushes a temporary sibling, and replaces the primary file after a successful write. The previous valid primary becomes `.bak`. A corrupt primary does not overwrite an existing valid backup.

Load validates the format and SHA-256 checksum before decoding its data. Recover Backup defaults to true. If the primary is missing or damaged and the backup is valid, Success is true and **Recovered** is true; tell the player that the previous save was used when appropriate. Set Recover Backup false to require the primary. A checksum detects corruption; it is not encryption or proof that a save has not been edited.

Loading and migration never modify a file or a live game object. A save with a newer application schema is rejected even when an older backup exists, preventing silent downgrade. Saving also refuses to overwrite a valid newer-schema primary with an older schema. The implementation uses Godot's data-only `var_to_bytes()` / `bytes_to_var()` functions; it does not deserialize objects. See [Godot's Variant API](https://docs.godotengine.org/en/4.4/classes/class_%40globalscope.html#class-globalscope-method-bytes-to-var).

Temporary replacement and backup recovery are tested on Windows with Godot 4.7.2. Platform/export testing, cross-engine compatibility and power-loss testing belong to release hardening; this is not a durability guarantee for every filesystem.

## Evolve your save schema

The save container format and your game's schema version are separate. Increase Version when changing the meaning or shape of game data. Supply a Dictionary of trusted migration Callables keyed by the old version:

```gdscript
const Saves = preload("res://addons/GDBlueprints/core/persistence.gd")

func migrate_v1(data: Dictionary) -> Dictionary:
    data["coins"] = data.get("score", 0)
    data.erase("score")
    return data

func read_checkpoint() -> Dictionary:
    return Saves.load_game(
        "user://saves/checkpoint.gdbsave", 2,
        {1: Callable(self, "migrate_v1")}
    )
```

In a Load Game Data node, enter `{1: Callable(self, "migrate_v1")}` in Migrations and set Version to 2. Each callback receives a copied Dictionary and must return a Dictionary for the next version. A migration can be a synchronous graph function with a Dictionary argument and Dictionary return. Missing steps and invalid results fail the load. The chain is limited to 100 steps. Save again explicitly after a successful upgrade if you want the new version written to disk.

Older **Save / Load** and **Save / Load 2D** nodes retain their original JSON format and limited scalar-variable behavior for compatibility. New nodes do not reinterpret those files automatically. To migrate an old game, read its JSON, map its known fields into your new data schema, and use Save Game Data with a new filename. Keep the old file until you verify the conversion. Generic automatic conversion cannot infer the intended meaning of old scene paths or values.

## Reuse scenes, functions and templates

- Put reusable gameplay components in ordinary Godot scenes. Their saved graph metadata and generated script travel with the scene. Export per-instance configuration and use explicit references or signals to communicate.
- Keep reusable behavior in typed graph functions or handwritten script methods. Call Function works across both. Local function variables belong to each activation; instance members belong to their scene node. Use GlobalVars only for intentionally shared state.
- Use **Add → Options → Save Template** for an entire graph, or select a subgraph first to save just that selection. **Load Template** appends it to the selected owner's graph. Templates copy definitions; they are not linked assets that automatically update every use.

New templates use `.gdbtemplate`, format version 2, with checksummed data-only payloads. Data-only version-1 `.lbtemplate` files remain readable and migrate on import. Future formats, duplicate IDs, missing node definitions and invalid connections are rejected before editing the graph. Templates containing live resource/object data must be rebuilt from data-only properties in their source project.

Selected templates now include pure value/reference nodes and reroutes. Pasting remaps node IDs and refreshes wired expressions so captured results point to the new producing nodes. Included frames follow the pasted nodes. Local variables merge by name without overwriting existing defaults; a same-name/different-type conflict rejects template import before any graph change. Rename duplicated Custom Event/function definitions and apply their signatures before compiling.

Templates include graph metadata, included frames and local variable definitions. They do not bundle scripts, assets, autoloads, Input Map settings or other scene nodes. Keep extensions in `res://gdblueprints_nodes/`, shared templates in a project folder such as `res://blueprint_templates/`, and reusable scenes/helpers in feature folders. Review owner-relative references and required variables when moving a graph to another scene.

## Larger graphs and verification

Connection lookup, execution reachability/cycle checks and value-binding refresh now index edges instead of repeatedly scanning every wire for each node. The regression fixture builds and compiles 1,021 graph nodes and executes 1,000 actions across 20 event paths, verifying all results and their ordering. This is a repeatable integration fixture, not a guarantee of editor frame rate for arbitrary graphs.

The normal 10,000-step and 128-active-call-depth runtime limits still apply per activation. Organize large projects around smaller scenes, typed functions, events and descriptive frames. A thousand-node project does not require a thousand-node execution chain, and adding nodes does not increase an activation's budget.

Run `tests/milestone6_persistence.gd` in a disposable project to check data types, large integer preservation, disk replacement, backup recovery, schema migrations, invalid state preflight, generated persistence nodes, template migration/paste, and the large-graph fixture. It creates a uniquely named directory under that project's `user://` and removes its test files. Existing tests cover instance/function isolation and handwritten-source preservation. Milestone 7 is export/platform and Asset Library release hardening.
