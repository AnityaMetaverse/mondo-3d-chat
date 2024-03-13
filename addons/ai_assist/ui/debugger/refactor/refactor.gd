tool
extends Control


var starting_selection_line := 0
var selected_text := ""
var completions := []


func _ready():
	# Don't run if it's being edited instead of being in plugin mode.
	if get_tree().edited_scene_root in [self, get_parent()]:
		return

	$Button.show()


func _on_ChatGPTRequest_completions_request_completed(result):
	$"%Panel".show()
	$"%TargetCode".text = result.content.strip_edges()
	$"%SourceCode".text = selected_text


func _on_Refactor_pressed():
	var text_edit = get_parent().script_editor.get_base_editor()
	starting_selection_line = text_edit.get_selection_from_line()
	selected_text = text_edit.get_selection_text()
	completions.clear()

	add_completions("Optimize this GDScript function as much as possible. Just the code, no comments. Text format", "system")
	add_completions(selected_text, "user")
	$ChatGPTRequest.completions(completions)

	$PopupDialog.popup(get_parent().editor_interface.get_editor_viewport().get_global_rect())
	$"%Panel".hide()


func _on_Regenerate_pressed():
	add_completions($"%TargetCode".text, "assistant")
	add_completions("I don't like this suggestion. Generate a better one. Just the code, no comments. Text format", "user")
	$ChatGPTRequest.completions(completions)

	$"%Panel".hide()


func _on_Apply_pressed():
	var source_code = get_parent().script_editor.get_current_script().source_code
	var text_editor = get_parent().script_editor.get_base_editor()
	text_editor.text = source_code.replace(
		selected_text,
		$"%TargetCode".text
	)
	text_editor.cursor_set_line(starting_selection_line)

	# takes a sec to update the code text edit
	yield(get_tree().create_timer(2.0), "timeout")
	$PopupDialog.hide()


func add_completions(prompt: String, role: String):
	completions.push_back({
		"content": prompt,
		"role": role
	})
