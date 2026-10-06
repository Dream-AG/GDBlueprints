# Collections and enums

## Typed collections

Use `Array[int]` for an ordered list of integers, or `Dictionary[String, int]` for a lookup such as item IDs to quantities. These are native Godot containers. You can use them in Script Variables, Global Variables, event parameters, function parameters, returns, and locals.

In a variable's expanded editor, enter the type in the advanced type field below the type picker and press Enter. The current initial value must fit the type; a rejected change leaves the original data intact. Start with an empty Array or Dictionary when changing an existing variable to a constrained collection. Enter defaults as data literals, for example `[1, 2, 3]` or `{"potion": 3}`. Connect compatible collection values through the normal variable getter/setter pins.

Signatures accept collections directly: `items: Array[int], counts: Dictionary[String, int]`. Click Apply Parameters or Apply Signature after editing. Collection commas are distinguished from parameter separators.

Typed containers retain their element/key/value constraints at runtime. Function and event dispatch validates collection contents; function locals and returns also check their declared types. Compatible untyped runtime collections are constructed with the required native constraints at a call boundary. Invalid data is rejected before calling a typed method. Such conversion can create a new container; do not depend on alias identity across a conversion. Already compatible references otherwise follow Godot's shared-data semantics.

A typed container can connect to an untyped container pin. Different element types do not implicitly connect: `Array[int]` cannot wire to `Array[float]`, since the receiving code could insert incompatible elements. Nested typed declarations such as `Array[Array[int]]` are unsupported by GDScript. Use `Array[Array]` or a Resource with explicit fields. Collections of custom script classes are not yet represented by these type declarations; use Object/Resource references and validate them in a helper. Packed arrays are distinct types.

Expose in Inspector is available when the container's element types support this workflow's exports. Resource and node references should be assigned at runtime or in the Inspector, rather than serialized inside graph default data.

## Explicit enum cases

An enum type describes named integers with explicit values:

```text
Enum[Idle=0, Running=10, Stunned=20]
```

Use this declaration in the advanced variable type field or a function/event signature. Each case name and integer must be unique. Use the same declaration wherever that enum is expected. Case names are labels; they do not add global GDScript constants. The generated variable or method parameter is an ordinary integer. Exported enum variables have an Inspector dropdown with the labels.

Add Enum Value, enter the enum declaration, and set Case Name to `Running`. Its Value pin carries `10` with the enum's type. Connect it to a matching enum input or to Switch on Int. An arbitrary Int pin does not implicitly become an enum pin. Unconnected argument fields can use the explicit integer; runtime function/event checks reject values outside the declaration.

Keep assigned integers stable when saving game state. Adding a case with a new integer is safer than changing the meaning of an existing value. Handwritten code can call an enum-parameter method with its integer value. Direct assignment to a generated integer member follows GDScript's integer semantics; enum membership checks apply at graph function/event boundaries, not to every handwritten member assignment.

## Evaluation

Pure Value outputs evaluate their expression when consumed. Call Function captures its Result once per execution. Function locals belong to that invocation; Script Variables belong to the scene-node instance. Arrays and Dictionaries use fresh empty defaults for each function invocation. See [Functions and locals](functions.html).
