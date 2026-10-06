@tool
extends RefCounted

## Serialized visual-graph schema and migration entry point.
## Never change saved pin/node IDs without adding a migration here.

const CURRENT_VERSION := 2


static func migrate(graph_data: Variant) -> Dictionary:
	if not (graph_data is Dictionary):
		return {"schema_version": CURRENT_VERSION, "nodes": [], "connections": [], "next_id": 0}
	var data: Dictionary = graph_data.duplicate(true)
	var version := int(data.get("schema_version", 1))
	if version > CURRENT_VERSION or version < 1:
		return data # Never relabel an unknown schema as one we can safely save.
	while version < CURRENT_VERSION:
		match version:
			1:
				data = _migrate_v1_to_v2(data)
				version = 2
			_:
				push_warning("GDBlueprints: Unknown graph schema version %d; leaving data unchanged." % version)
				break
	data["schema_version"] = CURRENT_VERSION
	if not data.has("nodes"): data["nodes"] = []
	if not data.has("connections"): data["connections"] = []
	if not data.has("next_id"): data["next_id"] = 0
	return data


static func _migrate_v1_to_v2(data: Dictionary) -> Dictionary:
	# v2 formalizes schema versioning. No structural rewrite is necessary; older
	# graphs already use nodes/connections/next_id and remain byte-compatible.
	data["schema_version"] = 2
	return data
