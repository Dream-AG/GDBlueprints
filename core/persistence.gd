extends RefCounted
const Codec = preload("res://addons/GDBlueprints/core/data_codec.gd")
const Collections = preload("res://addons/GDBlueprints/core/collection_types.gd")
const MAGIC := "GDBSAVE1"

static func valid_path(path: String) -> bool:
	return path.begins_with("user://") and not path.ends_with("/") and not path.contains("\\") and not path.trim_prefix("user://").contains(":") and not ".." in path.split("/") and path.length() > 7

static func save_game(path: String, data: Dictionary, version: int = 1) -> Dictionary:
	if not valid_path(path): return Codec.error("Save path must be a file under user:// without parent traversal.")
	if version < 1: return Codec.error("Save schema version must be positive.")
	var encoded := Codec.encode({"schema_version":version, "data":data})
	if not encoded.ok: return encoded
	var previous := _read_file(path) if FileAccess.file_exists(path) else {"ok":false}
	if previous.ok and int(previous.version) > version: return Codec.error("Existing save schema is newer; refusing to overwrite it with an older schema.")
	var directory_error := DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if directory_error != OK: return Codec.error("Cannot create save directory: " + error_string(directory_error))
	var temporary := path + ".tmp-" + str(Time.get_ticks_usec())
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null: return Codec.error("Cannot open temporary save: " + error_string(FileAccess.get_open_error()))
	file.store_line(MAGIC)
	file.store_line(Codec.checksum(encoded.bytes))
	file.store_buffer(encoded.bytes)
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		DirAccess.remove_absolute(temporary)
		return Codec.error("Cannot write save: " + error_string(write_error))
	# Retain the previous valid primary as .bak. A corrupt primary must not replace
	# an existing good backup when the user saves after recovery.
	if previous.ok:
		var backup_error := DirAccess.copy_absolute(path, path + ".bak")
		if backup_error != OK:
			DirAccess.remove_absolute(temporary)
			return Codec.error("Cannot preserve previous save: " + error_string(backup_error))
	var replace_error := DirAccess.rename_absolute(temporary, path)
	if replace_error != OK:
		DirAccess.remove_absolute(temporary)
		return Codec.error("Cannot replace save: " + error_string(replace_error))
	return {"ok":true, "error":"", "recovered":false}

static func _read_file(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return Codec.error("Cannot read save: " + error_string(FileAccess.get_open_error()))
	if file.get_length() > Codec.MAX_BYTES + 128: return Codec.error("Save file exceeds 16 MiB.")
	if file.get_line() != MAGIC: return Codec.error("Unsupported save format.")
	var checksum := file.get_line()
	var bytes := file.get_buffer(file.get_length() - file.get_position())
	if checksum != Codec.checksum(bytes): return Codec.error("Save checksum mismatch.")
	var decoded := Codec.decode(bytes)
	if not decoded.ok: return decoded
	var envelope: Dictionary = decoded.data
	if not envelope.get("schema_version") is int or int(envelope.schema_version) < 1 or not envelope.get("data") is Dictionary: return Codec.error("Invalid save envelope.")
	return {"ok":true, "error":"", "version":envelope.schema_version, "data":envelope.data, "recovered":false}

static func load_game(path: String, version: int = 1, migrations: Dictionary = {}, recover_backup: bool = true) -> Dictionary:
	if not valid_path(path): return Codec.error("Load path must be a file under user:// without parent traversal.")
	if version < 1: return Codec.error("Save schema version must be positive.")
	var result := _read_file(path)
	if not result.ok and recover_backup:
		var backup := _read_file(path + ".bak")
		if backup.ok:
			result = backup
			result.recovered = true
	if not result.ok: return result
	if int(result.version) > version: return Codec.error("Save schema is newer than this game; refusing to downgrade.")
	var data: Dictionary = result.data.duplicate(true)
	var current := int(result.version)
	if version - current > 100: return Codec.error("Migration chain exceeds 100 steps.")
	while current < version:
		var migration = migrations.get(current)
		if not migration is Callable or not migration.is_valid(): return Codec.error("Missing migration from schema " + str(current))
		var migrated = migration.call(data.duplicate(true))
		if not migrated is Dictionary: return Codec.error("Migration must return a Dictionary.")
		var issue := Codec.validate(migrated)
		if not issue.is_empty(): return Codec.error(issue)
		data = migrated
		current += 1
	result.data = data
	result.version = current
	return result # Loading/migrating never rewrites the file or mutates live objects.

static func capture_state(target: Variant, names: PackedStringArray) -> Dictionary:
	if typeof(target) != TYPE_OBJECT or not is_instance_valid(target): return Codec.error("Capture target is not a live Object.")
	var available := {}
	for property in target.get_property_list(): available[str(property.name)] = property
	var data := {}
	for name in names:
		if name.is_empty() or not available.has(name): return Codec.error("Unknown property: " + name)
		data[name] = target.get(name)
	var issue := Codec.validate(data)
	if not issue.is_empty(): return Codec.error(issue)
	return {"ok":true, "error":"", "data":data.duplicate(true)}

static func restore_state(target: Variant, data: Dictionary) -> Dictionary:
	if typeof(target) != TYPE_OBJECT or not is_instance_valid(target): return Codec.error("Restore target is not a live Object.")
	var issue := Codec.validate(data)
	if not issue.is_empty(): return Codec.error(issue)
	var available := {}
	for property in target.get_property_list(): available[str(property.name)] = property
	var assignments := {}
	# Preflight every field before changing anything. User-defined setters are
	# still ordinary code: this cannot roll back their external side effects.
	for key in data:
		if not key is String and not key is StringName: return Codec.error("State keys must be property names.")
		if not available.has(str(key)): return Codec.error("Unknown property: " + str(key))
		var property: Dictionary = available[str(key)]
		if int(property.usage) & PROPERTY_USAGE_READ_ONLY or str(key) == "script": return Codec.error("Read-only property: " + str(key))
		var kind := int(property.type)
		var value = data[key]
		if kind != TYPE_NIL and typeof(value) != kind and not (kind == TYPE_FLOAT and value is int): return Codec.error("Property type mismatch: " + str(key))
		var existing = target.get(key)
		if existing is Array and existing.is_typed():
			var element_type := type_string(existing.get_typed_builtin())
			if not Collections.accepts(value, "Array[%s]" % element_type): return Codec.error("Array element mismatch: " + str(key))
			value = Array(value, existing.get_typed_builtin(), existing.get_typed_class_name(), existing.get_typed_script())
		elif existing is Dictionary and existing.is_typed():
			var key_type := "Variant" if existing.get_typed_key_builtin() == TYPE_NIL else type_string(existing.get_typed_key_builtin())
			var value_type := "Variant" if existing.get_typed_value_builtin() == TYPE_NIL else type_string(existing.get_typed_value_builtin())
			var schema := "Dictionary[%s, %s]" % [key_type, value_type]
			if not Collections.accepts(value, schema): return Codec.error("Dictionary element mismatch: " + str(key))
			value = Dictionary(value, existing.get_typed_key_builtin(), existing.get_typed_key_class_name(), existing.get_typed_key_script(), existing.get_typed_value_builtin(), existing.get_typed_value_class_name(), existing.get_typed_value_script())
		assignments[key] = value.duplicate(true) if value is Array or value is Dictionary else value
	for key in assignments: target.set(key, assignments[key])
	return {"ok":true, "error":""}
