#!/usr/bin/env python3
"""Create a single-file Blueprint event, action, or value node (Python 3.10+)."""
from __future__ import annotations
import argparse
import json
import re
from pathlib import Path

KINDS = {"event": ("SENSOR", "sensor", "Sensor"), "action": ("ACTUATOR", "actuator", "Actuator"), "value": ("VALUE", "value", "Value")}

def snake(text: str) -> str:
    text = re.sub(r"([a-z0-9])([A-Z])", r"\1_\2", text)
    return re.sub(r"[^A-Za-z0-9]+", "_", text).strip("_").lower() or "custom_node"

def script_text(name: str, kind: str, category: str, godot_term: str) -> str:
    enum, legacy, suffix = KINDS[kind]
    stable_id = "".join(word.capitalize() for word in snake(name).split("_")) + suffix
    if stable_id[0].isdigit():
        stable_id = "Custom" + stable_id
    quote = lambda value: json.dumps(value, ensure_ascii=False)
    if kind == "value":
        implementation = '\nfunc get_value_output_definitions() -> Array:\n\treturn [{"name":"Value", "type":"Float", "expression":"0.0"}]\n'
    elif kind == "event":
        implementation = '\nfunc generate_ir(_node: Node, _chain_name: String) -> Dictionary:\n\t# This condition is evaluated each frame. Replace true with your trigger.\n\treturn {"sensor":[{"op":"statement", "code":"var sensor_active = true"}]}\n'
    else:
        implementation = '\nfunc generate_ir(_node: Node, _chain_name: String) -> Dictionary:\n\treturn {"actuator":[{"op":"statement", "code":"pass # Implement this action"}]}\n'
    return f'''@tool
extends "res://addons/GDBlueprints/core/blueprint_node.gd"

func _init() -> void:
\tsuper._init()
\tbrick_type = BrickType.{enum}
\tbrick_name = {quote(name)}

func _initialize_properties() -> void:
\tproperties = {{}}

func get_brick_info() -> Dictionary:
\treturn {{
\t\t"class":{quote(stable_id)}, "name":{quote(name)}, "type":{quote(legacy)},
\t\t"category":{quote(category)}, "domain":"common",
\t\t"description":"Replace with a description of the native Godot behavior.",
\t\t"aliases":[], "godot_term":{quote(godot_term)}
\t}}

func get_property_definitions() -> Array:
\treturn []
{implementation}'''

def extension_script_text(name: str, kind: str, category: str, godot_term: str, base_path: str) -> str:
    _enum, legacy, suffix = KINDS[kind]
    stable_id = "".join(word.capitalize() for word in snake(name).split("_")) + suffix
    if stable_id[0].isdigit():
        stable_id = "Custom" + stable_id
    quote = lambda value: json.dumps(value, ensure_ascii=False)
    return f'''@tool
extends {quote(base_path)}

## Project-local extension of {base_path}.
## Keep a unique class ID so saved graphs can distinguish it from the built-in node.

func _initialize_properties() -> void:
\tsuper._initialize_properties()
\tproperties["extra_option"] = false

func get_brick_info() -> Dictionary:
\tvar info: Dictionary = super.get_brick_info().duplicate(true)
\tinfo.merge({{
\t\t"class": {quote(stable_id)},
\t\t"name": {quote(name)},
\t\t"type": {quote(legacy)},
\t\t"category": {quote(category)},
\t\t"description": "A project-local extension of an existing Blueprint node.",
\t\t"godot_term": {quote(godot_term)}
\t}}, true)
\treturn info

func get_property_definitions() -> Array:
\tvar definitions: Array = super.get_property_definitions().duplicate(true)
\tdefinitions.append({{"name": "extra_option", "type": TYPE_BOOL, "default": false}})
\treturn definitions

# Override the same generate_ir(), generate_code(), or value method used by the
# base node, call super, and adjust its result to add behavior without copying it.
'''

def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--name", required=True)
    parser.add_argument("--kind", choices=KINDS, default="action")
    parser.add_argument("--category", default="Community")
    parser.add_argument("--godot-term", default="GDScript: replace with the native API")
    parser.add_argument("--output", help="Filesystem path; run from project root for automatic discovery")
    parser.add_argument("--extends-node", help="res:// path of an existing node script to inherit and extend")
    args = parser.parse_args()
    if args.output and args.output.startswith("res://"):
        parser.error("Use a filesystem path, such as gdblueprints_nodes/my_node.gd (not res://).")
    output = Path(args.output) if args.output else Path("gdblueprints_nodes") / f"{snake(args.name)}.gd"
    if output.suffix != ".gd":
        parser.error("Output must end in .gd")
    if output.exists():
        parser.error(f"Refusing to overwrite {output}")
    if args.extends_node and (not args.extends_node.startswith("res://") or not args.extends_node.endswith(".gd") or "\n" in args.extends_node or "\r" in args.extends_node):
        parser.error("--extends-node must be a res:// path ending in .gd")
    output.parent.mkdir(parents=True, exist_ok=True)
    content = extension_script_text(args.name, args.kind, args.category, args.godot_term, args.extends_node) if args.extends_node else script_text(args.name, args.kind, args.category, args.godot_term)
    output.write_text(content, encoding="utf-8")
    print(f"Created {output}. Implement behavior, then run tests/validate_addon.gd and compile a sample graph.")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
