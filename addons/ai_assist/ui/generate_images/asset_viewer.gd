tool
extends VBoxContainer
class_name AssetViewer


signal go_back_requested
signal generate_variations_requested(image)

signal file_saved

const LINE_POINT_DISTANCE = 4

enum ImageModes {
	SIMPLE,
	MASK,
	DEPTH,
	NORMAL,
}

var variations_enabled := false setget set_variations_enabled
var mask_enabled := false setget set_mask_enabled

var image_mode: int = ImageModes.SIMPLE

var _textures := []
var _current_dialog_index = -1

var _line_current: Line2D
var _line_point_last: Vector2


func _ready() -> void:
	# Don't run if it's being edited instead of being in plugin mode.
	if get_tree().edited_scene_root == self:
		return

	connect("resized", self, "_on_resized")

	$"%Back".icon = get_icon("Back", "EditorIcons")
	$"%Previous".icon = get_icon("Back", "EditorIcons")
	$"%Next".icon = get_icon("Forward", "EditorIcons")


func open_image(textures: Array, idx:=-1, mode:=ImageModes.SIMPLE) -> void:
	_textures = textures

	var previous_image: Texture = $"%Image".texture
	$"%Image".texture = textures[idx]

	image_mode = mode
	_current_dialog_index = idx

	set_mask_enabled(mode == ImageModes.MASK)

	if textures.size() < 2:
		$"%Previous".hide()
		$"%Next".hide()
	else:
		$"%Previous".show()
		$"%Next".show()

	show()


func clear_mask() -> void:
	$"%MaskDraw".texture = null


func set_variations_enabled(enabled: bool) -> void:
	variations_enabled = enabled
	$"%GenerateVariations".visible = enabled


func set_mask_enabled(enabled: bool) -> void:
	mask_enabled = enabled

	if enabled:
		$"%ToggleMasking".show()
		_on_ToggleMasking_toggled($"%ToggleMasking".pressed)
	else:
		$"%ToggleMasking".hide()
		_on_ToggleMasking_toggled(false)


func has_mask_texture() -> bool:
	return $"%MaskDraw".texture != null


func get_image_data() -> Image:
	if $"%Image".texture == null:
		return null

	return $"%Image".texture.get_data()


func get_mask_data() -> Image:
	if $"%Image".texture == null:
		return null

	if $"%MaskDraw".texture == null:
		return null

	var img_size = $"%Image".texture.get_data().get_size()
	var mask = $"%MaskDraw".texture.get_data().duplicate()
	mask.resize(img_size.x, img_size.y)

	return mask


func _update_mask_size() -> void:
	var image_size: Vector2 = $"%Image".texture.get_size()
	$"%MaskRatio".ratio = image_size.x / image_size.y
	$"%MaskContainer".rect_min_size = image_size
	$"%MaskContainer".rect_size = image_size
	$"%MaskCanvas".set_size_override(true, image_size)

	_on_resized()


func _on_resized() -> void:
	yield(VisualServer, "frame_post_draw")
	$"%MaskContainer".rect_scale = $"%MaskAnchor".rect_size / $"%MaskContainer".rect_size


func _on_ToggleMasking_toggled(button_pressed: bool) -> void:
	$"%MaskPen".visible = button_pressed
	$"%MaskContainer".visible = button_pressed

	if button_pressed:
		_update_mask_size()


func _on_Previous_pressed() -> void:
	if _textures.size() < 2:
		return

	_current_dialog_index -= 1
	if _current_dialog_index < 0:
		_current_dialog_index = _textures.size() - 1

	$"%Image".texture = _textures[_current_dialog_index]

	if $"%ToggleMasking".pressed:
		_update_mask_size()


func _on_Next_pressed() -> void:
	if _textures.size() < 2:
		return

	_current_dialog_index += 1
	if _current_dialog_index > _textures.size() - 1:
		_current_dialog_index = 0

	$"%Image".texture = _textures[_current_dialog_index]

	if $"%ToggleMasking".pressed:
		_update_mask_size()


func _on_SaveImageDialog_file_selected(path: String) ->  void:
	$"%Image".texture.get_data().save_png(path)

	emit_signal("file_saved")


func _on_SaveResourceDialog_file_selected(path: String) -> void:
	var image = $"%Image".texture
	image.set_meta("_ai", {})
	ResourceSaver.save(path, $"%Image".texture)

	emit_signal("file_saved")


func _on_GenerateVariations_pressed() -> void:
	emit_signal("generate_variations_requested", $"%Image".texture.get_data())

	hide()


func _on_MaskContainer_gui_input(event: InputEvent) -> void:
	if not event is InputEventMouse:
		return

	if _line_current == null:
		if event is InputEventMouseButton and event.pressed:
			_line_current = Line2D.new()
			_line_current.width = $"%PenSize".value
			_line_current.default_color = ColorN("black" if $"%EraseMode".pressed else "white")
			_line_current.joint_mode = Line2D.LINE_JOINT_ROUND
			_line_current.begin_cap_mode = Line2D.LINE_CAP_ROUND
			_line_current.end_cap_mode = Line2D.LINE_CAP_ROUND
			_line_current.antialiased = true
			$"%MaskCanvas".add_child(_line_current)
			_line_current.add_point(event.position)
			# Make it have at least 2 points so the first blob appears.
			_line_current.add_point(event.position + Vector2(0.01, 0))
			_line_point_last = event.position
	else:
		if event is InputEventMouseButton:
			if not event.pressed:
				var texture = $"%MaskCanvas".get_texture()
				var image = texture.get_data()
				image.flip_y()

				texture = ImageTexture.new()
				texture.create_from_image(image)
				$"%MaskDraw".texture = texture

				_line_current.queue_free()
				_line_current = null
		elif event is InputEventMouseMotion and\
				event.position.distance_to(_line_point_last) > LINE_POINT_DISTANCE:
			_line_current.add_point(event.position)
			_line_point_last = event.position
