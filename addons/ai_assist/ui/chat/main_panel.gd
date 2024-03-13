tool
extends Control


const CHAT_CONTEXT_DIRECTORY = "chat_context_data"
const CHAT_EMBEDDINGS_DIRECTORY = "chat_embeddings"

enum ResourceType {
	SCRIPT,
	SCENE,
}

export (NodePath) var root

onready var chat_text = $HSplitContainer/VSplitContainer/VSplitContainer/Chat
onready var prompt_text = $HSplitContainer/VSplitContainer/HSplitContainer/Prompt
onready var error_label = $HSplitContainer/VSplitContainer/VSplitContainer/Error
onready var send_button = $HSplitContainer/VSplitContainer/HSplitContainer/Send
onready var context_list = $HSplitContainer/ContextList
onready var code_options = $HSplitContainer/VSplitContainer/VSplitContainer/Chat/CodeOptions
onready var save_resource = $HSplitContainer/VSplitContainer/VSplitContainer/Chat/SaveResource

var editor_interface

var context_sent = ""


func _ready() -> void:
	# Don't run if it's being edited instead of being in plugin mode.
	if get_tree().edited_scene_root == self:
		return

	# Prevent error message on start.
	if root and get_node(root).has_meta("editor_interface"):
		editor_interface = get_node(root).get_meta("editor_interface")

	context_list.save_path = get_node("/root/AIPluginManager").get_save_path().plus_file(CHAT_CONTEXT_DIRECTORY)
	context_list.load_contexts()

	var effect = preload("res://addons/ai_assist/ui/chat/rte_accent_color.gd").new()
	effect.control = self
	chat_text.install_effect(effect)


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and is_visible_in_tree():
		if context_list.context_selected.empty():
			context_list.give_focus()
		else:
			prompt_text.grab_focus()


func _identify_resource_type(code):
	if code.begins_with("[gd_scene"):
		return ResourceType.SCENE

	return ResourceType.SCRIPT


func _add_chat_text(text):
	# Format codeblocks.
	while true:
		var i = text.find("`")
		if i == -1:
			break

		chat_text.add_text(text.substr(0, i))
		text.erase(0, i)

		if not text.begins_with("```"):
			text.erase(0, 1)
			i = text.find("`")
			if i == -1:
				break

			chat_text.append_bbcode("[accent_color weight=0.5]%s[/accent_color]" %
					text.substr(0, i))
			text.erase(0, i + 1)

			continue

		text.erase(0, 3)
		i = text.find("```")
		if i == -1:
			break

		var code = text.substr(0, i).strip_edges()
		chat_text.push_meta({"code": code, "type": _identify_resource_type(code)})
		chat_text.append_bbcode("[accent_color]%s[/accent_color]" % code)
		chat_text.pop()

		text.erase(0, code.length() + 3)

	if not text.empty():
		chat_text.add_text(text)


func _on_Send_pressed():
	error_label.hide()
	prompt_text.editable = false
	send_button.disabled = true

	var prompt = prompt_text.text.strip_edges()
	prompt_text.clear()
	prompt_text.placeholder_text = "Requesting...."

	chat_text.push_align(RichTextLabel.ALIGN_RIGHT)
	_add_chat_text(prompt)
	chat_text.pop()
	chat_text.newline()
	chat_text.newline()

	context_sent = context_list.context_selected

	context_list.append_context_data(
			context_list.context_selected, "chat", {"role": "user", "content": prompt})
	var context = context_list.get_context_data(context_list.context_selected, "chat")

	var embeddings = get_all_embeddings()
	if not embeddings.empty():
		# embed the prompt
		$ChatGPTRequest.embeddings(prompt)
		var prompt_embedding = yield($ChatGPTRequest, "embeddings_completed")
		yield(get_tree(), "idle_frame")

		# compare prompt embedding with the stored embeddings
		var embedding_values: Dictionary
		for i in range(embeddings.size()):
			var embedding_value = JSON.parse(embeddings.values()[i]).result
			embedding_values[embeddings.keys()[i]] = $ChatGPTRequest.cosine_distance(
					prompt_embedding, embedding_value)

		# order descending
		var relatedness_ranking = embedding_values.values()
		relatedness_ranking.sort()
		relatedness_ranking.invert()

		# add this context to the last context before requesting
		var message = "Answer questions about the following Godot Engine project. Use the below codebases and script descriptions to generate your answer"
		for i in range(5): # use top 5 references
			message += '\n\n"""\n%s\n"""' % embedding_values.keys().find(relatedness_ranking[i])
		context.push_back({
			"content": message,
			"role": "system",
		})

	$ChatGPTRequest.completions(context)


func get_all_embeddings() -> Dictionary:
	var embeddings: Dictionary
	var d = Directory.new()
	if d.open(get_node("/root/AIPluginManager").get_save_path().plus_file(CHAT_EMBEDDINGS_DIRECTORY)) == OK:
		d.list_dir_begin(true, true)
		var file_name = d.get_next()
		while file_name != "":
			if file_name.get_extension() == "csv":
				var f = File.new()
				if f.open(d.get_current_dir().plus_file(file_name), File.READ) == OK:
					while f.get_position() < f.get_len():
						var csv_line = f.get_csv_line()
						embeddings[csv_line[0]] = csv_line[1]
					f.close()
			file_name = d.get_next()

	return embeddings


func _on_Rewind_pressed():
	var context_data = context_list.get_context_data(context_list.context_selected, "chat")
	context_data.pop_back()

	context_list.set_context_data(context_list.context_selected, "chat", context_data)
	context_list.save_context(context_list.context_selected)

	_on_ContextList_context_selected(context_list.context_selected)


func _on_Prompt_text_changed(new_text):
	send_button.disabled = new_text.empty()


func _on_Prompt_text_entered(new_text):
	if not new_text.empty() and prompt_text.editable:
		_on_Send_pressed()


func _on_ChatGPTRequest_completions_request_completed(result: Dictionary):
	prompt_text.placeholder_text = ""

	if context_list.context_selected.empty():
		context_sent = ""
		return

	if context_list.contexts_data.has(context_sent):
		context_list.append_context_data(context_sent, "chat", result)
		context_list.save_context(context_sent)

		if context_sent == context_list.context_selected:
			_add_chat_text(result.content)
			chat_text.newline()
			chat_text.newline()

	context_sent = ""

	prompt_text.editable = true


func _on_ChatGPTRequest_error():
	context_sent = ""

	error_label.show()
	prompt_text.editable = true
	prompt_text.placeholder_text = ""


func _on_ContextList_context_selected(id):
	if context_sent.empty():
		prompt_text.editable = true
		send_button.disabled = prompt_text.text.empty()

	chat_text.clear()

	if context_list.has_context_data_key(id, "chat"):
		var context_data = context_list.get_context_data(id, "chat")
		for i in context_data:
			if i.role == "user":
				chat_text.push_align(RichTextLabel.ALIGN_RIGHT)

			_add_chat_text(i.content)

			if i.role == "user":
				chat_text.pop()

			chat_text.newline()
			chat_text.newline()

	$HSplitContainer/VSplitContainer/HSplitContainer/Rewind.disabled = chat_text.text.empty()

	if prompt_text.is_inside_tree():
		prompt_text.grab_focus()


func _on_ContextList_context_renamed(id):
	context_list.save_context(id)


func _on_ContextList_context_removed(id) -> void:
	if not context_list.context_selected.empty():
		return

	chat_text.clear()
	prompt_text.editable = false
	send_button.disabled = true


func _on_Chat_meta_clicked(meta) -> void:
	code_options.set_meta("code", meta.code)

	code_options.clear()
	match int(meta.type):
		ResourceType.SCRIPT:
			code_options.add_item("Copy Code", 0)
			code_options.add_item("Create Script File...", 1)

			if not meta.code.begins_with("extends"):
				code_options.set_meta("code", "extends Node\n\n\n" + meta.code)
		ResourceType.SCENE:
			code_options.add_item("Create Scene File...", 2)

	code_options.rect_position = get_global_mouse_position()
	code_options.popup()


func _on_Chat_meta_hover_started(meta) -> void:
	chat_text.mouse_default_cursor_shape = CURSOR_POINTING_HAND


func _on_Chat_meta_hover_ended(meta) -> void:
	chat_text.mouse_default_cursor_shape = CURSOR_ARROW


func _on_CodeOptions_id_pressed(id: int) -> void:
	match id:
		0: # Copy Code
			OS.clipboard = code_options.get_meta("code", "")
		1: # Create Script File...
			save_resource.filters = PoolStringArray(["*.gd ; GDScript Files"])
			save_resource.popup_centered_ratio()
			var line = save_resource.get_line_edit()
			line.text = "new_script.gd"
			line.select(0, line.text.get_basename().length())
		2: # Create Scene File...
			save_resource.filters = PoolStringArray(["*.tscn ; Godot Scene Files"])
			save_resource.popup_centered_ratio()
			var line = save_resource.get_line_edit()
			line.text = "new_scene.tscn"
			line.select(0, line.text.get_basename().length())


func _on_FileDialog_file_selected(path: String) -> void:
	var file = File.new()
	file.open(path, File.WRITE)
	file.store_string(code_options.get_meta("code"))
	file.close()

	editor_interface.edit_resource(load(path))
