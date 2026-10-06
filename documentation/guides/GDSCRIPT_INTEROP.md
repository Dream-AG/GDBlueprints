# Graphs and GDScript together

## Call a handwritten method

Write a synchronous method outside the generated markers, in Godot's Script tab or your external editor, and save it:

```gdscript
func calculate_damage(base: float, multiplier: float = 1.0) -> float:
    return base * multiplier
```

Add Call Function, set Target to Self or a scene-relative node path, and click Browse Methods. Search and double-click the method. The picker copies its parameter names, types, optional argument defaults, and return type into the node. Connect the argument pins and read Result on Then. Handle missing targets or invalid calls through Failed.

The picker can also resolve a connected Scene Tree reference or Get Node By Path output. It never evaluates arbitrary target expressions in the editor. For a runtime-only target, enter the signature manually. Save/reload script changes in Godot, then browse again to update a signature; compatible wires follow their names and incompatible edits are rejected. Variadic methods need a handwritten helper with a fixed signature. Call Function requires synchronous methods; use event graphs for waiting work.

Native methods appear alongside public script methods. Methods beginning with an underscore are omitted from the picker. Custom script-class arguments are displayed as Object when they cannot be represented by the built-in type registry; actual method dispatch still checks the receiver's declared script class. Native and script collection hints produce constrained collection pins when supported.

Call Object Method remains available for an argument Array. It validates the actual target signature, but has no captured Result pin. Call Custom Event supports Browse Methods for fire-and-forget calls, including delayed event work. Use Local Definition copies an applied function/event signature directly from the current graph, even before compiling it.

## Call a graph function from code

A Function Entry named `calculate_health` becomes a public typed GDScript method. Call `calculate_health(amount)` from the same script or `target.calculate_health(amount)` from another script. The owner must be in the scene tree. Function arguments, locals, Return, and failure semantics are described in [Functions and locals](functions.html).

## Receive a native or handwritten signal

1. Add Connect Signal To Custom Event on a startup path. Set Target to the emitting node.
2. Click Browse Signals and double-click a signal. This enables Forward Arguments and records its parameter signature.
3. Set Event Name to a unique callback name such as `on_health_changed`.
4. Click Create / Update Signal Event. It creates a matching Custom Event with typed output pins, or safely updates the matching event already in the graph.
5. Connect the event to its behavior and compile. Run the connection node once at startup.

The receiving method can also be handwritten on the graph owner's script. Forwarding checks argument count and compatible declared types. Duplicate connections are ignored. Set Disconnect on the same node configuration to remove that connection later. Keep the same Forward Arguments setting when disconnecting. Godot also removes connections when their objects are freed.

Older saved connection nodes keep Forward Arguments disabled and discard signal arguments for their original no-argument events. Enable it explicitly when upgrading them. A Variant signal cannot promise a specific receiver type; use Variant event parameters and validate in your graph/helper.

Emit Typed Signal provides named argument pins and Browse Signals. It emits an existing signal declared by Godot or a handwritten `signal` declaration. Emit Signal retains its Array-based interface. Invalid targets/counts/types are skipped; emitting nodes report a warning. Signal declarations themselves remain native GDScript declarations outside the generated region.

## Discover properties

Browse Properties shows native Inspector properties, script variables, and saved graph variables. Choosing a property sets the Get output or Set input type. Existing incompatible connections prevent applying the change. Set checks the live property's type and writability before assigning; Get returns null for a missing target/property. For a runtime-only target, use the manual name and Variant pins. Refresh the selection after changing a property's declaration.

## Preserve script edits

Save modified Script tabs before applying graph code. The plugin refuses writes while the built-in Script editor has unsaved text. Godot's public editor API does not reliably associate every text tab with a resource, so this check includes other modified script tabs. External editors must also save their edits before compilation.

Handwritten text outside the generated markers is preserved. The compiler reads the current disk contents, checks symbol collisions, validates the combined script, and rechecks the file before writing. It does not merge competing edits to the same region. Graph callbacks and handwritten callbacks cannot have duplicate names; move handwritten callback behavior into a named helper and invoke it from the graph.

Newly generated regions include a checksum. If code inside the region is edited later, compilation stops and preserves the file. Move the intended behavior into a helper or a custom node definition, then restore the generated region from your last saved version before compiling. Older generated regions acquire this protection on their first successful compile with this release; earlier edits cannot be distinguished from old generated code.

GlobalVars generation uses the same preservation principles for its own markers, preserves handwritten declarations outside them, and records typed variable metadata without executing the script to recover defaults. Never edit the global metadata comments by hand.

Rebuild from Script recovers the plugin's generated metadata. It does not translate arbitrary GDScript into a graph. To extend a node's reusable implementation in the Script tab or an external editor, add a project-local `.gd` definition as explained in [Create nodes](contributing.html).
