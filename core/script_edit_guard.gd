@tool
extends RefCounted

## Godot exposes script editors and their TextEdit versions, but no public mapping
## from every open text editor to its resource. Require saved tabs before writing.
static func unsaved_error(editor_interface) -> String:
	if editor_interface == null: return ""
	var script_editor = editor_interface.get_script_editor()
	if script_editor == null: return ""
	for editor in script_editor.get_open_script_editors():
		var text = editor.get_base_editor()
		if text is TextEdit and text.get_version() != text.get_saved_version():
			return "Save the modified Script editor tabs before applying graph code. This prevents a later Script-tab save from replacing the newly generated code. No file was changed."
	return ""
