# GDBlueprints node API

Use `core/pin_type_registry.gd` for pin normalization, compatibility, and generated variable type names. Packed arrays are distinct from Array. Concrete built-in Object classes retain their class when promoted to a variable. Integer-vector split pins carry Int values; floating-vector components carry Float values. Keep pure output expressions free of side effects: they may evaluate more than once. Store a computed result with an execution node when later reads must share one captured value.

`BlueprintNode.get_blueprint_definition()` is the contributor-facing normalized contract. Existing nodes may continue to implement `get_brick_info()`, `get_property_definitions()`, `get_value_output_definitions()`, and the base class will adapt them into the normalized definition.

Use the methods below for new nodes. The normalized dictionary is an adapter; the editor still reads property and output methods directly. Put the file in `res://gdblueprints_nodes/` and give it a unique ID. A complete action looks like:

```gdscript
@tool
extends "res://addons/GDBlueprints/core/blueprint_node.gd"

func _init() -> void:
    super._init()
    brick_type = BrickType.ACTUATOR
    brick_name = "Example Action"

func _initialize_properties() -> void:
    properties = {
        "text": "Hello",
        "text_expression": "",
    }

func get_brick_info() -> Dictionary:
    return {
        "class": "ExampleActionActuator",
        "name": "Example Action",
        "type": "actuator",
        "category": "Examples",
        "description": "Prints a message to the Godot Output panel.",
        "aliases": ["Example"],
        "godot_term": "GDScript: print(text)",
    }

func get_property_definitions() -> Array:
    return [
        {
            "name": "text",
            "type": TYPE_STRING,
            "default": "Hello",
            "blueprint_pin": true,
            "pin_type": "String",
        }
    ]

func generate_ir(_node: Node, _chain_name: String) -> Dictionary:
    var expr := str(properties.get("text_expression", "")).strip_edges()
    if expr.is_empty():
        expr = '"%s"' % _gd_string(str(properties.get("text", "Hello")))
    return {"actuator": [{"op":"call", "method":"print", "args":[expr]}]}
```

## Runtime input binding

For a property named `text`, define a sibling `text_expression` property when the node needs direct control of a connected expression. The editor disables/grays the manual field while the pin is driven. String/Int/Float legacy nodes also have a compatibility rewrite layer, but new nodes should prefer explicit expression properties.

## Data outputs

Implement `get_value_output_definitions()`:

```gdscript
func get_value_output_definitions() -> Array:
    return [
        {"name":"Node", "type":"Node", "expression":"get_node_or_null(\"Button\")"},
        {"name":"Found", "type":"Bool", "expression":"is_instance_valid(get_node_or_null(\"Button\"))"},
    ]
```

Expressions should be side-effect free. Do not put a method call with gameplay side effects into a value output because it may be evaluated more than once.

## Execution outputs

Ordinary Actions/Flow nodes get `In → Then`; Events get `Then`; Values have no execution pins. Override `get_exec_output_definitions()` for named exits such as Branch `True/False` or Cast `Succeeded/Failed`. A custom exec layout does not automatically define compiler semantics; reusable unusual flow behavior belongs in the graph/compiler layer.

## Compiler IR

For an action that requires fixed-step processing, add `"requires_physics": true` to its metadata. The manager schedules automatic update chains in `_physics_process` without a hardcoded node ID. Explicit Custom Events still execute in their caller's context. Configurable pure-value nodes support ordinary property controls and typed data inputs; output expressions must read current properties and prefer wired `name_expression` values.

New ordinary nodes should prefer `generate_ir()`. Supported operations currently include `statement`, `assign`, `declare`, `call`, `if`, `return`, and `await`. Returning `{}` falls back to `generate_code()`.

## Execution operations

Ordinary action nodes need no new code: the default `get_execution_spec()` returns `{"kind":"action"}` and the backend calls their generated action code before Then. They may still provide member variables, setup code, and inactive updates.

Supported flow kinds are `branch`, `delay`, `once`, `sequence`, `switch`, `for`, `foreach`, `break`, `continue`, `function_call`, `function_return`, and `set_local`. Follow the built-in definition for the required fields; pins alone do not implement a new operation. The compiler rejects unsupported operation kinds. Keep input/output IDs and ordering stable across releases. `core/function_compiler.gd` validates function scope/return paths and emits public wrappers; `core/function_runtime.gd` handles checked dispatch, local assignment, and returns. Ordinary action definitions remain usable inside synchronous functions unless their generated execution code waits with `await`.

Each activation has an internal `_flow` context. Loop Index/Item expressions are valid only along the corresponding Body path; do not use this private context as a general plugin API. Contributors adding a new operation must add runtime and editor/save-reload tests. See [Execution and loops](execution-model.html).
