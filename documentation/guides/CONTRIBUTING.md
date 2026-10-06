# Create Blueprint nodes

## Project nodes

The simplest extension is **one `.gd` file** in `res://gdblueprints_nodes/`. No central registry edit, editor panel edit, or Python installation is required. Copy the working template from `addons/GDBlueprints/templates/modern_action_node_template.gd`, rename it, and edit its unique ID, display name, properties, and behavior. Save the file; the editor's file-system rescan refreshes node discovery. Reopen the editor if a changed script remains cached.

Core contributors place files under `bricks/sensors`, `bricks/controllers`, `bricks/actuators`, or `bricks/values`. Keep game-specific extensions outside the addon so upgrades preserve them.

## Optional generator

Run from your Godot project root with Python 3.10 or newer:

```bash
python addons/GDBlueprints/tools/create_node.py --name "Print Score" --kind action --category Game --godot-term "GDScript: print(score)"
```

This creates `gdblueprints_nodes/print_score.gd` and refuses to overwrite an existing file. Implement its behavior, then validate and compile a sample graph. The generator supports event, action, and value nodes. Flow nodes require an existing compiler semantic or a tested compiler addition.

## The single-file contract

1. Extend `core/blueprint_node.gd` and keep `@tool` so the editor can inspect the node.
2. Set its kind and name in `_init()` after calling `super._init()`.
3. Provide a permanent unique `class` ID, display name, type, description, category, and native Godot teaching term in `get_brick_info()`.
4. Initialize defaults in `_initialize_properties()` and describe editable controls in `get_property_definitions()`.
5. Generate behavior with `generate_ir()` or `generate_code()`. Pure values implement `get_value_output_definitions()`.
6. Add meaningful validation and test actual runtime behavior in a small scene.

See the [Node API](node-api.html) for a complete action example and typed-input rules. Supply clear tooltips; use Godot APIs and explicit references. IDs must remain stable after users save graphs with your node.

Pure-value nodes with properties use the same editable controls and typed data-input declarations as actions, with no execution pins. Implement `get_value_output_definitions()` using the current properties; a wired `property_name_expression` takes precedence over the unconnected field. Configurations and data wires survive save/reload. Outputs are evaluated when consumed, so pure nodes must not cause gameplay side effects.

Actions that must update with physics can add `"requires_physics": true` to their metadata. Automatic update chains then use `_physics_process` without a compiler ID list change. Explicit Custom Event calls still run in their caller's context. See `bricks/actuators/2d/move_character_2d.gd` and the [playable examples](gameplay-examples.html) for working definitions and integration fixtures.

## Extend a built-in node

Copy `templates/extend_existing_node_template.gd` into your project extension folder. It inherits Print String and adds a prefix setting. Or generate an inherited skeleton:

```bash
python addons/GDBlueprints/tools/create_node.py --name "Game Print" --kind action --extends-node res://addons/GDBlueprints/bricks/actuators/common/print_string_actuator.gd
```

Use the same kind as the base node. Give the extension its own ID. Call `super` to keep base defaults and pins, then add yours. Override the generation method used by the base and compose its result. Edit these files in Godot's Script workspace or an external editor.

The extension appears as a separate node; existing graphs keep the original type. Replace and reconnect nodes where desired. Changing an addon file directly is possible but a plugin upgrade may overwrite it.

## Document and verify

Describe use cases, target requirements, Godot equivalents, and failure behavior in the node metadata and tooltips. Built-in documentation is generated from that metadata; no help-link table needs updating. Run the catalog export and site build after adding a built-in node. Project extension help currently opens this workflow; publish additional documentation with your custom node as needed.

Run definition validation, compile connected inputs and outputs, then test runtime behavior, save/reopen, and the View Documentation destination. See [Testing](testing-validation.html). A successful parse alone is insufficient for physics, async work, or scene/resource effects.
