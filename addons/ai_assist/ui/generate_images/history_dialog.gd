tool
extends WindowDialog


signal image_pressed(texture)
signal images_removed(ids, last)

var sections := []
var last_active_section: GridContainer

onready var _contents = $VBox/Scroll/Contents


func _ready():
	# Don't run if it's being edited instead of being in plugin mode.
	if get_tree().edited_scene_root == self:
		return

	if not ProjectSettings.has_setting("ai_assist/limits/image_history"):
		ProjectSettings.set_setting("ai_assist/limits/image_history", 5)
	ProjectSettings.set_initial_value("ai_assist/limits/image_history", 5)
	ProjectSettings.connect("project_settings_changed", self, "_on_project_settings_changed")

	$VBox/Scroll.add_stylebox_override("bg", get_stylebox("bg", "Tree"))

	connect("visibility_changed", self, "_update_scrollbar_value", [], CONNECT_ONESHOT)


func add_section(prompt: String, request_json:="", negative_prompt:="") -> void:
	var section_container := HBoxContainer.new()
	_contents.add_child(section_container)

	section_container.add_child(VSeparator.new())

	var vbox := VBoxContainer.new()
	section_container.add_child(vbox)

	var hbox := HBoxContainer.new()
	vbox.add_child(hbox)

	var remove := Button.new()
	remove.icon = get_icon("Remove", "EditorIcons")
	remove.flat = true
	remove.hint_tooltip = "Move to Trash"
	remove.connect("pressed", self, "_on_remove_pressed", [section_container])
	hbox.add_child(remove)

	var label := Label.new()
	label.text = prompt.strip_edges()
	label.clip_text = true
	label.size_flags_horizontal = SIZE_EXPAND_FILL
	label.rect_min_size.x = 100
	hbox.add_child(label)

	if not request_json.empty():
		var json := Button.new()
		json.icon = get_icon("Script", "EditorIcons")
		json.flat = true
		json.hint_tooltip = "Show Request JSON"
		json.connect("pressed", self, "_on_json_pressed", [request_json])
		hbox.add_child(json)

	var section := {
		"prompt": prompt,
		"request_json": request_json,
		"negative_prompt": negative_prompt,
		"image_ids": [],
	}
	sections.append(section)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.set_meta("section", section)
	vbox.add_child(grid)
	last_active_section = grid

	if sections.size() > ProjectSettings.get_setting("ai_assist/limits/image_history"):
		_remove_section(0)

	$VBox/ClearHistory.disabled = false

	_update_scrollbar_value()


func add_image(texture: Texture, id:="") -> void:
	if last_active_section == null:
		printerr("ERROR: A section needs to be added first.")
		return

	if id.empty():
		var rand = RandomNumberGenerator.new()
		rand.randomize()
		id = str(rand.randi_range(100000000, 999999999))
	texture.set_meta("history_id", id)
	last_active_section.get_meta("section")["image_ids"].append(texture.get_meta("history_id"))

	var button := Button.new()
	button.flat = true
	button.rect_min_size = Vector2(120, 120)
	button.icon = texture
	button.expand_icon = true
	button.icon_align = Button.ALIGN_CENTER
	last_active_section.add_child(button)
	button.connect("pressed", self, "_on_image_pressed", [texture])

	_update_scrollbar_value()


func clear() -> void:
	sections.clear()

	for i in _contents.get_children():
		_contents.remove_child(i)
		i.queue_free()

	$VBox/ClearHistory.disabled = true


func get_history_data() -> Array:
	return sections.duplicate(true)


func _remove_section(index: int, emitting_signal:=true) -> Array:
	var section_container = _contents.get_child(index)
	_contents.remove_child(section_container)
	section_container.queue_free()

	var last = index == sections.size() - 1
	var images: Array = sections[index]["image_ids"]
	sections.remove(index)

	if last:
		$VBox/ClearHistory.disabled = true

	if emitting_signal:
		emit_signal("images_removed", images, last)

	return images


func _update_scrollbar_value() -> void:
	yield(VisualServer, "frame_post_draw")
	$VBox/Scroll.get_h_scrollbar().value = $VBox/Scroll.get_h_scrollbar().max_value


func _on_remove_pressed(section_container: HBoxContainer) -> void:
	_remove_section(section_container.get_index())


func _on_json_pressed(request_json: String) -> void:
	$RequestJSON/VBox/Code.bbcode_text = "[code]" + request_json + "[/code]"
	$RequestJSON.popup_centered()


func _on_image_pressed(texture: Texture) -> void:
	hide()
	emit_signal("image_pressed", texture)


func _on_project_settings_changed() -> void:
	var limit: int = ProjectSettings.get_setting("ai_assist/limits/image_history")
	if limit < 1:
		printerr('ERROR: History limit needs to be at least "1".')
		return

	if limit < _contents.get_child_count():
		for i in _contents.get_child_count() - limit:
			_remove_section(i)


func _on_ClearHistory_pressed() -> void:
	var images := []
	for i in _contents.get_child_count():
		images.append_array(_remove_section(0, false))

	emit_signal("images_removed", images, true)


func _on_Copy_pressed() -> void:
	OS.clipboard = $RequestJSON/VBox/Code.text
