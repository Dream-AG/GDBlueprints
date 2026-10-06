# From Unreal to Godot

## Familiar names, native behavior

- An Unreal Actor usually maps to a scene instance composed of Godot Nodes. There is no universal Godot Actor class.
- A component-like responsibility often belongs on a child Node or a Resource, depending on whether it needs scene-tree lifetime.
- Event Tick maps to `_process(delta)`; physics updates use `_physics_process(delta)`.
- Event BeginPlay in this release fires on the first process pass after `_ready()`, not inside `_ready()` itself.
- Spawn Actor maps to loading a PackedScene and calling `instantiate()`, then parenting the instance.
- Event Dispatchers map to Godot signals. Use Connect Signal To Custom Event and Emit Signal.
- Actor tags often map to groups. Query groups when objects share a role.
- Editable instance variables map to `@export` properties configured in the Inspector.
- Persistent services often use Autoloads. Keep per-object state on the object.

## Differences to learn early

Delay is now a latent execution action with Completed and Cancel. Do Once has a Reset input. Timer Event and One Shot Event retain the older event behavior. Sequence and loop bodies await their connected paths; in particular, a delayed Sequence branch finishes before the next output starts. This is an intentional Godot-oriented ordering contract, not a promise of identical Unreal latent-flow behavior. See [Execution and loops](execution-model.html). Save/Load nodes store selected data; they do not serialize an entire running game. Cast To Script checks script inheritance on an existing reference.

The menu contains domain-specific versions and some compatibility definitions. Read each node's reference for exact target requirements. A familiar label is a learning aid, not an assertion of complete Unreal feature parity.

## Before adding Unreal-equivalent nodes

Define the Godot use case first. Prefer Nodes, Resources, signals, groups, and explicit references. Reuse a generic compiler capability for branching, loops, and latent execution. Do not implement editor/compiler special cases for every new node.
