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
	$"%Comment".text = result.content.strip_edges()


func _on_Comment_pressed():
	var text_edit = get_parent().script_editor.get_base_editor()
	starting_selection_line = text_edit.get_selection_from_line()
	selected_text = text_edit.get_selection_text()
	completions.clear()

	add_completions("Comment about this GDScript codeblock. Summarize it, no more than one sentence. Just the description", "system")
	add_completions(selected_text, "user")
	$ChatGPTRequest.completions(completions)

	$PopupDialog.popup(get_parent().editor_interface.get_editor_viewport().get_global_rect())
	$"%Panel".hide()


func _on_Regenerate_pressed():
	add_completions($"%Comment".text, "assistant")
	add_completions("I don't like this description. Generate a better one.", "user")
	$ChatGPTRequest.completions(completions)

	$"%Panel".hide()


func _on_AddComment_pressed():
	var editor_settings = get_parent().editor_interface.get_editor_settings()
	var max_characters = editor_settings.get_setting("text_editor/appearance/line_length_guideline_soft_column")
	get_parent().script_editor.get_base_editor().set_line(
		starting_selection_line - 1,
		String("\n" + format_to_comment($"%Comment".text, max_characters))
	)

	# takes a sec to update the code text edit
	yield(get_tree().create_timer(2.0), "timeout")
	$PopupDialog.hide()


func add_completions(prompt: String, role: String):
	completions.push_back({
		"content": prompt,
		"role": role
	})


func format_to_comment(text: String, padding: int) -> String:
	var words = text.split(" ")
	var lines: PoolStringArray = ["#"]
	var line_length = 0
	for w in words:
		if line_length + w.length() + 1 > padding:
			lines.append("#")
			line_length = 0
		lines[lines.size() - 1] += " " + w
		line_length += w.length() + 1

	return lines.join("\n")
