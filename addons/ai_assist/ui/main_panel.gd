tool
extends Control


func _ready() -> void:
	# Don't run if it's being edited instead of being in plugin mode.
	if get_tree().edited_scene_root == self:
		return

	$MarginContainer/TabContainer.add_stylebox_override(
			"tab_fg", get_stylebox("tab_selected_odd", "TabContainer"))
	$MarginContainer/TabContainer.add_stylebox_override(
			"panel", get_stylebox("panel_odd", "TabContainer"))


func switch_to_generate_picture() -> void:
	$"MarginContainer/TabContainer".current_tab = 1


func get_generate_picture() -> Control:
	return $"MarginContainer/TabContainer/Generate Picture" as Control
