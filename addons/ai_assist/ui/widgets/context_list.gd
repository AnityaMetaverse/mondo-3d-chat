tool
extends VBoxContainer


signal context_renamed(item)
signal context_selected(item)
signal context_removed(item)
signal context_created_new(id)

var save_path = "" setget set_save_path

var context_selected = ""
var contexts_data = {}

onready var contexts := $Contexts as Tree


func _ready():
	contexts.create_item()


func set_save_path(path):
	var dir = Directory.new()
	save_path = path

	if not dir.dir_exists(save_path):
		if dir.make_dir_recursive(save_path) != OK:
			printerr("ERROR: Couldn't create directory for saving contexts at \"%s\"." % save_path)
			save_path = ""


func create_context(id=null, data=null, select=false) -> String:
	var item = contexts.create_item(contexts.get_root())
	item.set_editable(0, true)
	item.add_button(0, get_icon("Remove", "EditorIcons"))

	if id == null:
		id = str(int(Time.get_unix_time_from_system()))

	item.set_metadata(0, id)

	if data != null:
		contexts_data[id] = data
		item.set_text(0, data.name)
	else:
		contexts_data[id] = {"name": "New Context", "data": {}}
		item.set_text(0, contexts_data[id].name)

	if context_selected.empty():
		$Contexts/Tip.hide()

	if select:
		# Give time to give data to it.
		item.call_deferred("select", 0)

	return id


func load_contexts():
	if save_path.empty():
		printerr("ERROR: No save path has been set for contexts.")
		return

	var selected = ""

	var file = File.new()
	var result = file.open(save_path.plus_file(".selected"), File.READ)
	if result != OK:
		if result != ERR_FILE_NOT_FOUND:
			printerr('ERROR: Unable to open last selected context inside directory "%s".' % save_path)
	else:
		selected = file.get_as_text()
		file.close()

	var dir = Directory.new()
	if dir.open(save_path) != OK:
		printerr('ERROR: Unable to open the context directory "%s".' % save_path)
		return

	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name == ".selected" or dir.current_is_dir():
			file_name = dir.get_next()
			continue

		var context_file = save_path.plus_file(file_name)
		if file.open(context_file, File.READ) != OK:
			file_name = dir.get_next()
			printerr('ERROR: Unable to open context save in path "%s".' % context_file)
			continue

		var text = file.get_as_text()
		file.close()

		if text.empty():
			file_name = dir.get_next()
			continue

		result = validate_json(text)
		if not result.empty():
			file_name = dir.get_next()
			printerr("ERROR: Invalid JSON: %s" % result)
			continue

		var data = parse_json(text)
		if typeof(data) != TYPE_DICTIONARY:
			file_name = dir.get_next()
			printerr('ERROR: Invalid context content in path "%s".' % context_file)
			continue

		create_context(file_name, data, file_name == selected)

		file_name = dir.get_next()


func save_context(id):
	if save_path.empty():
		printerr("ERROR: No save path has been set for contexts.")
		return

	var dir = Directory.new()
	if not dir.dir_exists(save_path):
		return

	var file = File.new()
	if file.open(save_path.plus_file(id), File.WRITE) != OK:
		printerr("ERROR: Unable to create file for context %s." % id)
		return

	file.store_string(to_json(contexts_data[id]))
	file.close()


func give_focus():
	if not context_selected.empty() or contexts.get_root().get_children() != null:
		contexts.grab_focus()
	else:
		$New.grab_focus()


func has_contexts() -> bool:
	return contexts.get_root().get_children() != null


func has_context_data_key(id, key):
	if not contexts_data.has(id):
		printerr('ERROR: Context ID "%s" doesn\'t exist.' % id)
		return

	return contexts_data[id].data.has(key)


func set_context_data(id, key, value):
	if not contexts_data.has(id):
		printerr('ERROR: Context ID "%s" doesn\'t exist.' % id)
		return

	contexts_data[id].data[key] = value

	_highlight_context(id)


func append_context_data(id, key, value):
	if not contexts_data.has(id):
		printerr('ERROR: Context ID "%s" doesn\'t exist.' % id)
		return

	if not contexts_data[id].data.has(key):
		contexts_data[id].data[key] = [value]
		return

	if not contexts_data[id].data[key] is Array:
		printerr('ERROR: Non-array key "%s" can\'t be appended to inside context ID "%s".' % [key, id])
		return

	contexts_data[id].data[key].append(value)

	_highlight_context(id)


func get_context_data(id, key):
	if not contexts_data.has(id):
		printerr('ERROR: Context ID "%s" doesn\'t exist.' % id)
		return

	if not contexts_data[id].data.has(key):
		printerr('ERROR: Key "%s" doesn\'t exist inside context ID "%s".' % [key, id])
		return

	return contexts_data[id].data[key].duplicate(true)


func add_context_image_file(id, image, file_name):
	if not contexts_data.has(id):
		printerr('ERROR: Context ID "%s" doesn\'t exist.' % id)
		return

	var dir = Directory.new()
	var path = save_path.plus_file(id + "_files")
	if not dir.dir_exists(path):
		if dir.make_dir_recursive(path) != OK:
			printerr("ERROR: Couldn't create directory for saving files for context \"%s\"." % id)
			return

	path = path.plus_file(file_name)
	var result = image.save_png(path)
	if result != OK:
		printerr('ERROR: Unable to save context image file in path "%s".' % path)


func get_context_image_file(id, file_name):
	if not contexts_data.has(id):
		printerr('ERROR: Context ID "%s" doesn\'t exist.' % id)
		return

	var dir = Directory.new()
	var path = save_path.plus_file(id + "_files").plus_file(file_name)
	if not dir.file_exists(path):
		printerr('ERROR: Unable to load context resource file in path "%s".' % path)
		return

	var image = Image.new()
	if image.load(path) != OK:
		printerr('ERROR: Unable to load context resource file in path "%s".' % path)
		return

	var image_texture = ImageTexture.new()
	image_texture.create_from_image(image)
	return image_texture


func remove_context_file(id, file_name):
	if not contexts_data.has(id):
		printerr('ERROR: Context ID "%s" doesn\'t exist.' % id)
		return

	var path = save_path.plus_file(id + "_files").plus_file(file_name)
	if Directory.new().file_exists(path):
		OS.move_to_trash(ProjectSettings.globalize_path(path))


func _highlight_context(id):
	if id == context_selected:
		return

	var item = contexts.get_root().get_children()
	while item != null:
		if id == item.get_metadata(0):
			item.set_custom_color(0, get_color("accent_color", "Editor"))

			break

		item = item.get_next()


func _on_New_pressed():
	var id = create_context(null, null, true)
	emit_signal("context_created_new", id)

	save_context(id)


func _on_Contexts_item_selected():
	var item = contexts.get_selected()
	if context_selected == item.get_metadata(0):
		return

	item.clear_custom_color(0)

	context_selected = item.get_metadata(0)

	if not save_path.empty():
		var dir = Directory.new()
		if not dir.dir_exists(save_path):
			return

		var file = File.new()
		var result = file.open(save_path.plus_file(".selected"), File.WRITE)
		if result != OK:
			printerr('ERROR: Unable to save last selected context inside directory "%s".' % save_path)
		else:
			file.store_string(context_selected)
			file.close()

	emit_signal("context_selected", context_selected)


func _on_Contexts_item_edited():
	var item = contexts.get_edited()
	contexts_data[item.get_metadata(0)].name = item.get_text(0)

	emit_signal("context_renamed", item.get_metadata(0))


func _on_Contexts_button_pressed(item, column, id):
	var dir = Directory.new()
	var path = save_path.plus_file(item.get_metadata(0))
	if dir.file_exists(path):
		OS.move_to_trash(ProjectSettings.globalize_path(path))

	path += "_files"
	if dir.dir_exists(path):
		OS.move_to_trash(ProjectSettings.globalize_path(path))

	contexts_data.erase(item.get_metadata(0))
	if contexts_data.empty():
		$Contexts/Tip.show()

	contexts.get_root().remove_child(item)

	if item.get_metadata(0) == context_selected:
		context_selected = ""

	emit_signal("context_removed", str(id))
