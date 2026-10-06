# Objects, scenes, and signals

## Choose a reference

- Drag a known node from Godot's SceneTree into the graph for a scene-relative reference.
- Use Get Node By Path for an explicit path relative to the graph owner. A child's path is relative to that child, not automatically to the scene root.
- Expose a Node variable in the Inspector when each instance should assign its own dependency.
- Use Get Nodes In Group for a runtime collection of nodes sharing a role.
- Use an Autoload for a project-wide service with a deliberate global lifetime.

An instantiated scene is a subtree of live nodes. A PackedScene resource on disk is a recipe, not an actor reference. Instantiate it before reading runtime properties or casting its nodes.

## Browse properties

After adding a known scene reference, use the reference property browser to inspect available properties and create Get/Set Object Property nodes. Exported script variables and native Inspector properties can be discovered when the editor can resolve the target. This avoids guessing property names.

Runtime-only references, unknown object types, and dynamic properties may not be discoverable in the editor. Use the exact native property name in those cases. A setter requires a writable property of the expected type; a visible property is not necessarily writable. Target Valid helps distinguish a missing object from a legitimate null property value.

## Call methods

Call Function offers Browse Methods, named typed inputs, captured Result, and Then/Failed paths. Call Object Method also invokes a native or handwritten method on the target; supply arguments as an Array in method order. Custom Event creates a generated method, and Call Custom Event invokes it on Self or another node. Keep names and argument counts consistent.

Cast To Script checks whether a live object uses or inherits a chosen GDScript. Success returns the same reference. It does not locate, instantiate, or convert an object.

## Native signals

Use Connect Signal To Custom Event, Browse Signals, and Create / Update Signal Event to build a callback with typed arguments. Normally connect once during startup. Enable Forward Arguments for typed callbacks; older connections discard arguments by default. Disconnect removes a matching connection. Emit Typed Signal exposes named typed inputs; Emit Signal retains Array arguments. See the [interoperability tutorial](gdscript-interop.html).

**Send Message** and **Message Received** are a separate subject/body messaging mechanism implemented through a listener group and generated handler methods. They are retained for existing graphs. They do not create Godot signal declarations. Prefer native signals for normal Godot object communication.

## Name-based nodes

Some older action nodes search the scene for a node name. Their tooltips identify this. Duplicate names can make such searches ambiguous. Prefer direct references, NodePaths, or exported dependencies in new systems and contributor nodes.
