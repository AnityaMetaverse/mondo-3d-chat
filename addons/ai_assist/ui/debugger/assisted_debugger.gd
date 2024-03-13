tool
extends Control


var editor_interface: EditorInterface
var script_editor: ScriptEditor


func _ready():
	# Don't run if it's being edited instead of being in plugin mode.
	if get_tree().edited_scene_root == self:
		return

	if has_meta("editor_interface"):
		editor_interface = get_meta("editor_interface")

	if has_meta("script_editor"):
		script_editor = get_meta("script_editor")
