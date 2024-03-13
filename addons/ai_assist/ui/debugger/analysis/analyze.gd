tool
extends Control


const CHAT_EMBEDDINGS_DIRECTORY = "chat_embeddings"

var files: Dictionary
var save_path = ""

var needs_reanalyzing := []


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Don't run if it's being edited instead of being in plugin mode.
	if get_tree().edited_scene_root == self:
		return

	$"%FileList".create_item()

	$"%AddFiles".set_button_icon(get_icon("Add", "EditorIcons"))

	var dir = Directory.new()
	save_path = get_node("/root/AIPluginManager").get_save_path().plus_file(CHAT_EMBEDDINGS_DIRECTORY)
	if not dir.dir_exists(save_path) and dir.make_dir_recursive(save_path) != OK:
		printerr("ERROR: Couldn't create directory for saving embeddings at \"%s\"." % save_path)
		save_path = ""

		return

	var file = File.new()
	var file_path = save_path.plus_file(".files.json")
	var result = file.open(file_path, File.READ)
	if result != OK:
		if result != ERR_FILE_NOT_FOUND:
			printerr('ERROR: Unable to load file analysis list in path "%s".' % file_path)

		return

	var json = parse_json(file.get_as_text())
	file.close()

	if not json is Dictionary:
		printerr("ERROR: Invalid data inside file analysis list file.")
		return

	files = json

	var file_list = $"%FileList"
	var script_icon = get_icon("Script", "EditorIcons")
	var remove_icon = get_icon("Remove", "EditorIcons")
	for i in files.keys():
		var item = file_list.create_item(file_list.get_root())
		item.set_icon(0, script_icon)
		item.set_text(0, i)
		item.add_button(0, remove_icon, -1, false, "Remove File")

		validate_item(item)

	update_buttons()

	get_node("/root/AIPluginManager").connect("resource_saved", self, "_on_AIPluginManager_resource_saved")


func _on_Analyze_pressed() -> void:
	$"%AnalyzeDialog".popup(get_parent().editor_interface.get_editor_viewport().get_global_rect())
	$AnalyzeDialog/MarginContainer/VBox/HBox/Space/Close.grab_focus()


## Add files to Tree
func _on_AddFile_pressed() -> void:
	$FileDialog.popup(get_parent().editor_interface.get_editor_viewport().get_global_rect())


## Remove files from Tree
func _on_FileList_button_pressed(item: TreeItem, column: int, id: int) -> void:
	var file_list = $"%FileList"
	var dir = Directory.new()
	item.select(0)
	while item != null:
		files.erase(item.get_text(0))
		needs_reanalyzing.erase(item.get_text(0))

		file_list.get_root().remove_child(item)

		var path = save_path.plus_file(item.get_text(0).md5_text() + ".csv")
		if dir.file_exists(path) and dir.remove(path) != OK:
			printerr('ERROR: Unable to delete embedding file in path "%s".' % path)

		item = file_list.get_next_selected(null)

	save_file_list()
	update_buttons()


func _on_FileDialog_files_selected(paths: PoolStringArray) -> void:
	var file_list = $"%FileList"
	var file = File.new()
	var script_icon = get_icon("Script", "EditorIcons")
	var remove_icon = get_icon("Remove", "EditorIcons")
	for path in paths:
		if files.has(path) or not path.ends_with(".gd"):
			continue

		files[path] = ""
		needs_reanalyzing.append(path)

		var item = file_list.create_item(file_list.get_root())
		item.set_icon(0, script_icon)
		item.set_text(0, path)
		item.add_button(0, remove_icon, -1, false, "Remove File")
		item.set_custom_color(0, get_color("warning_color", "Editor"))
		item.set_metadata(0, file.get_md5(path))

	save_file_list()
	update_buttons()


## Process Embeddings
func _on_AnalyzeFiles_pressed() -> void:
	$"%AddFiles".disabled = true
	$"%AnalyzeFiles".disabled = true

	var file = File.new()
	var dir = Directory.new()
	var item = $"%FileList".get_root().get_children()
	var timer_icon = get_icon("Timer", "EditorIcons")
	var script_icon = get_icon("Script", "EditorIcons")
	var remove_icon = get_icon("Remove", "EditorIcons")
	while item != null:
		var script_filename = item.get_text(0)
		var correct_md5 = item.get_metadata(0)
		if correct_md5.empty() or files[script_filename] == correct_md5:
			item = item.get_next()
			continue

		# Prepare file to save the embeddings.
		var embedding_filename = save_path.plus_file(correct_md5 + ".csv")
		if file.open(embedding_filename, File.WRITE) != OK:
			printerr("ERROR: Couldn't create embeddings file for script \"%s\". Skipping..." %
					script_filename)

			item = item.get_next()

			continue

		# Load and process the script.
		var script = load(script_filename)
		var script_info = process_script(script)

		# Add a script definition to the embedding process.
		var embeddings: PoolStringArray = [generate_script_definition(
				script_info, script.resource_path, script.get_base_script())]

		# Add every function declaration.
		for method in script_info["methods"]:
			if method.has("declaration"):
				embeddings.push_back(method["declaration"])

		item.set_icon(0, timer_icon)
		item.set_button_disabled(0, 0, true)

		# Embed all texts.
		for embed in embeddings:
			$ChatGPTRequest.embeddings(embed)
			var current_embedding = yield($ChatGPTRequest, "embeddings_completed")
			file.store_csv_line([embed, current_embedding])

			# Wait a frame before starting a new HTTP request.
			yield(get_tree(), "idle_frame")

		file.close()

		# Delete old file.
		embedding_filename = save_path.plus_file(files[script_filename] + ".csv")
		if dir.file_exists(embedding_filename):
			dir.remove(embedding_filename)

		item.set_icon(0, script_icon)
		item.set_button_disabled(0, 0, false)

		files[script_filename] = correct_md5
		validate_item(item)

		item = item.get_next()

	$"%AddFiles".disabled = false

	save_file_list()
	update_buttons()


func _on_AIPluginManager_resource_saved(resource: Resource) -> void:
	if not resource is Script:
		return

	var path = resource.resource_path
	if not files.has(path):
		return

	var item = $"%FileList".get_root().get_children()
	while item != null:
		if item.get_text(0) == path:
			validate_item(item)
			break

		item = item.get_next()

	update_buttons()


func process_script(script: GDScript) -> Dictionary:
	var script_info: Dictionary

	# Map all script functions for iteration
	var method_list = script.get_script_method_list()
	var methods_map: Dictionary
	for i in range(method_list.size()):
		methods_map[method_list[i].name] = i

	# iterate over all source code lines
	var func_name: String
	var func_tab_count: int
	for source_line in script.source_code.split("\n"):
		if not source_line.strip_edges().empty():
			var def_position = -1

			# try to find if its one of our functions definition
			for method_name in methods_map.keys():
				def_position = source_line.find("func " + method_name)
				if def_position > -1:
					func_name = method_name
					func_tab_count = source_line.count("\t", 0, def_position)
					method_list[methods_map[func_name]]["declaration"] = source_line
					break

			# if no definition was found, determine if this line is part of a function's declaration
			if def_position == -1 and not func_name.empty() and \
				source_line.begins_with(String("\t").repeat(func_tab_count + 1)):
					method_list[methods_map[func_name]]["declaration"] += "\n" + source_line

	script_info["methods"] = method_list
	script_info["properties"] = script.get_script_property_list()
	script_info["signals"] = script.get_script_signal_list()
	script_info["base"] = script.get_instance_base_type()

	return script_info


func validate_item(item: TreeItem) -> void:
	var path = item.get_text(0)
	var md5 = File.new().get_md5(path)
	item.set_metadata(0, md5)

	if md5.empty():
		item.set_custom_color(0, get_color("error_color", "Editor"))

		if not needs_reanalyzing.has(path):
			needs_reanalyzing.append(path)
	elif files[path] != md5:
		item.set_custom_color(0, get_color("warning_color", "Editor"))

		if not needs_reanalyzing.has(path):
			needs_reanalyzing.append(path)
	else:
		item.set_custom_color(0, get_color("font_color", "Editor"))

		if needs_reanalyzing.has(path):
			needs_reanalyzing.erase(path)


func save_file_list() -> void:
	var file = File.new()
	var result = file.open(save_path.plus_file(".files.json"), File.WRITE)
	if result != OK:
		if result != ERR_FILE_NOT_FOUND:
			printerr('ERROR: Unable to save file analysis list in directory "%s".' % save_path)
	else:
		file.store_string(to_json(files))
		file.close()


func get_class_from_typeof(_typeof: int) -> String:
	match _typeof:
		TYPE_NIL:
			return "Variant"
		TYPE_BOOL:
			return "bool"
		TYPE_INT:
			return "int"
		TYPE_REAL:
			return "float"
		TYPE_STRING:
			return "String"
		TYPE_ARRAY:
			return "Array"
		TYPE_DICTIONARY:
			return "Dictionary"
		TYPE_VECTOR2:
			return "Vector2"
		TYPE_VECTOR3:
			return "Vector3"

	return ""


func generate_script_definition(
		script_info: Dictionary, script_path: String, script_base: GDScript) -> String:
	var properties: PoolStringArray
	for i in range(script_info["properties"].size()):
		var p = script_info["properties"][i]
		properties.push_back((p["class_name"] if not p["class_name"].empty() else \
			get_class_from_typeof(p["type"])) + " " + p["name"])

	var signals: PoolStringArray
	for i in range(script_info["signals"].size()):
		var s = script_info["signals"][i]
		var args: PoolStringArray
		for arg in s["args"]:
			args.push_back(arg["name"])
		signals.push_back(s["name"] + "(" + args.join(", ") + ")")

	var methods: PoolStringArray
	for i in range(script_info["methods"].size()):
		var m = script_info["methods"][i]
		if not m["name"] in methods and m.has("declaration"):
			# get the function definition from the first line in the declaration.
			# parameter information from get_script_method_list() is vague
			var definition = m["declaration"].substr(0, m["declaration"].find(":"))

			# may have multiple lines (one per parameter?). remove them
			var method_lines = definition.split("\n")
			for j in range(method_lines.size()):
				method_lines[j] = method_lines[j].strip_edges()

			methods.push_back(method_lines.join("").trim_prefix("func "))

	return String("""%s

==Script Description==
class %s%s

==Properties==
%s

==Signals==
%s

==Method List==
%s""" % [
		script_path,
		script_info["base"],
		String(" extended from \"%s\"" % script_base.resource_path) if script_base else "",
		properties.join("\n"),
		signals.join("\n"),
		methods.join("\n"),
	]).strip_edges()


func update_buttons() -> void:
	$Button.icon = null if needs_reanalyzing.empty() else get_icon("StatusWarning", "EditorIcons")

	$"%AnalyzeFiles".disabled = needs_reanalyzing.empty()
	$"%EmptyTip".visible = files.empty()
