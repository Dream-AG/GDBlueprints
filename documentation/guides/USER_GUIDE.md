# Use the graph

## Graph ownership

A graph belongs to the selected scene node. Select a Node3D, Node2D, or Control with a saved GDScript to author its behavior. General-purpose nodes are available on children as well as scene roots. Physics-specific nodes may require a CharacterBody or RigidBody. The scene stores graph metadata; its script stores compiled behavior. Save both together.

## Events, Flow, Actions, and Values

- **Events** start or test an execution chain. Event Tick updates every rendered frame; Event Physics Tick updates at a fixed physics step; input and condition events activate according to their settings.
- **Flow** decides which execution path runs. Branch has True/False exits. Combine Conditions supports boolean combinations of event conditions.
- **Actions** change state or call behavior. An action executes when its incoming path is active.
- **Values** expose expressions through typed data pins. Data wires carry values, not execution order. An expression can be evaluated more than once; do not hide gameplay side effects in a value output.

Some reference getters are still Action definitions with data outputs. The reference lists their actual execution pins. The compiler retains a chain-based implementation internally; custom pin layouts alone do not add new flow semantics.

## Editing

Right-click to search by node name, search alias, or Godot term. Drag between execution pins to establish order; connect data pins to provide inputs. Type labels show the expected data type. Compatible widening such as Int to Float is supported; incompatible connections are rejected.

Drag a pin into empty space to search for a compatible node. Data pins also offer Promote to Variable. Frame All fits the graph. Right-drag pans; Alt + left-click removes a nearby wire. View Code shows generated behavior. View Documentation opens that exact node's reference section.

## Variables and states

The variable picker supports Dictionary, Resource, PackedScene, Basis, Quaternion, integer vectors, rectangles, AABB, packed arrays, Callable, and Signal alongside the original types. Promoting a concrete reference such as Button or Texture2D preserves that type. Resource and node references start as null; assign them through Set Variable or expose a script variable and assign it in Godot's Inspector. Callable and Signal start empty and must be assigned at runtime. Object, Variant, Callable, and Signal cannot use this workflow's Inspector export option.

Use Dictionary for named data, for example `{"coins": 12, "health": 100}`. Enter data literals in its value field. Array uses an item editor with a type selector per item; nested Array and Dictionary items accept literal text. Packed arrays use Godot's serialized value notation, for example `PackedInt32Array(1, 2, 3)`. These defaults are data, not arbitrary executable expressions. The compiler decodes serialized collections when the script instance initializes. Metadata remains the authoritative editable representation. Object/resource references inside collection defaults are not a supported persistence mechanism; assign them at runtime instead.

Packed arrays retain distinct pin types and do not implicitly convert to Array. For Each currently accepts Array only. Script Variables are instance members. Function Entry declares separate per-call locals; see [Functions and locals](functions.html). Use the advanced type field for `Array[int]`, `Dictionary[String, int]`, and explicit enums; see [Collections and enums](types-and-enums.html).

## Custom Events with parameters

1. Add Custom Event and name it `take_damage`.
2. Set Parameters to `amount: Float, source: Node`, then click Apply Parameters. The event gains typed amount and source output pins.
3. Connect those values to actions on this event's execution path. Each invocation keeps its arguments through Delay and nested execution. Parameter outputs cannot be used on unrelated event paths.
4. Add Call Custom Event, set Event Name to `take_damage`, and enter the same Parameters signature. Click Apply Parameters to create its typed input pins. Connect a value or enter a GDScript expression; use quotes for text literals.
5. Apply Code. Handwritten GDScript can call `target.take_damage(10.0, attacker)` directly.

Reordering parameters preserves connected wires by name. Removing a connected parameter or making a directly connected pin incompatible is rejected; adjust those wires first. After editing a signature, update its call nodes to match. Compilation rejects unapplied signatures, conflicting declarations, and mismatched calls to graph events on Self. External calls check the actual target method's argument count and basic types at runtime; invalid calls warn and are skipped. No argument is optional; an empty Parameters field retains the old zero-argument behavior.

Call Custom Event dispatches work and then continues. It does not await the event's delayed paths and does not return a value. Scalar arguments are independent per invocation. Arrays, Dictionaries, Resources, and Objects retain Godot reference semantics: changing their contents affects shared references. Delay's existing busy/re-entry behavior still applies. Use [Call Function](functions.html) for synchronous work with a return value.

Script Variables are ordinary members on the attached script. Expose in Inspector lets each scene instance configure its own value. Prefer local variables and exported references for object-specific state. Global Variables use the GlobalVars Autoload and should hold truly project-wide data.

Graph states enable state-specific chains. Use State to change the active state; use an all-states setting for behavior that must run regardless of state. State entry can reset generated node state. Keep reusable systems separate when they must persist independently of graph states.

## Compile and run

Compile Blueprint → GDScript validates and writes the graph-owned region of the attached script. Yellow indicates graph changes; green indicates a successful current compile. Read configuration warnings, assign any generated exported references in Godot's Inspector, then run the scene. Review generated code when behavior is unclear.

Use Event Physics Tick for physics updates. Use one-shot events for spawning, impulses, signal connections, and file writes unless repeated execution is deliberate. Frame events repeat their connected actions.

## Combine graphs with handwritten GDScript

Edit the same script in Godot's Script workspace or an external editor. Save external edits before compiling. Write helper functions, properties, and signals outside this region:

```gdscript
# === GDBLUEPRINTS START ===
# Graph-owned declarations and methods
# === GDBLUEPRINTS END ===
```

Compilation replaces the region and preserves surrounding text. Newly generated regions have a checksum; edits inside them stop compilation instead of being overwritten. Save Script-tab edits before compiling. See [GDScript interoperability](gdscript-interop.html) for the complete preservation workflow and older-file adoption behavior. Names must be unique: if handwritten and generated declarations collide, compilation stops without writing. Incomplete, duplicate, or reversed markers and combined-source parse errors also stop the write.

For example, write `func calculate_damage(amount):` outside the region, then call it through Call Object Method with Target set to Self. Read and write properties through Get/Set Object Property; use native signals to communicate across objects.

Rebuild from Script recovers graph information from generated metadata/code. It does not translate arbitrary handwritten GDScript into visual nodes. To extend a reusable node type itself, follow [Create nodes](contributing.html).

## Debugging

Use graph breakpoints, stepping, active-node highlights, activation snapshots, node View Code, and Godot's normal debugger. The runtime overlay uses F8 to show or hide watched values and graph traces. See [Debug graphs](debugging.html). A successful compile proves syntax, not that scene paths, resource assignments, or gameplay assumptions are correct.

## Delay and Do Once

Connect an event or action to Delay's In pin. Completed runs after Duration seconds of game time; the timer pauses with the SceneTree. Negative durations become zero and still resume asynchronously. Re-entry while waiting is ignored. Other execution paths can continue. Cancel stops the waiting activation without Completed. Removing the owner from the tree or changing a Blueprint state cancels pending work even if the owner/state is restored before the timer finishes; freeing the owner ends its pending execution.

Do Once runs Then on its first In activation. Later activations do nothing until Reset is triggered. Reset reopens the node without running Then. Start Closed requires Reset before the first activation. State belongs to each graph node on each scene instance and is shared by all paths entering that node.

Timer Event is the older repeating/duration event; One Shot Event (Compatibility) is the older event without an incoming execution path. Existing saved graphs retain these IDs and behaviors. All graphs use the same execution backend. Structured loops replace back-wires; legacy condition and inactive-update behavior is retained through compatibility adapters. See [Execution and loops](execution-model.html).

## Documentation appearance

Use the Dark mode / Light mode button at the top of each manual page. The initial theme follows your system preference; your choice is remembered when the browser allows local storage. The toggle still works when storage is blocked.
