tool
extends Control


const IMAGE_CONTEXT_DIRECTORY = "image_context_data"

const SEED_MAX = 4294967295

enum AITypes {
	DALLE_2,
	DALLE_3,
	STABLE_DIFFUSION,
	STABLE_DIFFUSION_XL,
	MESHY,
}

export (NodePath) var root

onready var prompt_positive = $HSplit/VBox/Options/Prompts/PromptPositive
onready var prompt_negative = $HSplit/VBox/Options/Prompts/PromptNegative
onready var history_button = $HSplit/VBox/Options/Actions/History
onready var send_button = $HSplit/VBox/Options/Actions/Generate
onready var context_list = $HSplit/ContextList
onready var history_dialog = $HistoryDialog

onready var default_options = {
	"image_generation/type": 0,
	"image_generation/preset_selected": 0,
	"image_generation/advanced": false,
}

var ai_type: int = AITypes.DALLE_2
onready var ai_request = $"%Dalle2Request"
onready var ai_options = $"%Dalle2Options"

var editor_interface: EditorInterface

var preset_prompt := ""
var preset_prompt_negative := ""

var original_image_size := Vector2()
var is_image_square := false

var asset_requested := 0

var context_sent := ""


func _ready():
	# Don't run if it's being edited instead of being in plugin mode.
	if get_tree().edited_scene_root == self:
		return

	for i in $AIs.get_children():
		default_options.merge(i.get_default_options())

	# Prevent error message on start.
	if root and get_node(root).has_meta("editor_interface"):
		editor_interface = get_node(root).get_meta("editor_interface")

	context_list.save_path = get_node("/root/AIPluginManager").get_save_path().plus_file(IMAGE_CONTEXT_DIRECTORY)
	context_list.load_contexts()

	$"%SavePreset".icon = get_icon("Save", "EditorIcons")
	$"%RemovePreset".icon = get_icon("Remove", "EditorIcons")

	$HSplit/VBox/PanelContainer.add_stylebox_override("panel", get_stylebox("bg", "Tree"))


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_VISIBILITY_CHANGED:
			if is_visible_in_tree():
				if context_list.context_selected.empty():
					context_list.give_focus()
				else:
					prompt_positive.grab_focus()
		NOTIFICATION_RESIZED:
			if $"%AssetViewer".visible:
				# Re-center the dialog.
				$"%AssetViewer".rect_position =\
						(get_viewport_rect().size - $"%AssetViewer".rect_size) / 2



func view_depth_image(texture: Texture) -> void:
	if not context_sent.empty():
		$ErrorDialog.dialog_text = "Generation is currently happening, wait for the task to end."
		$ErrorDialog.popup_centered()
		return

	if not context_list.has_contexts():
		context_list.create_context()

	if ai_type != AITypes.STABLE_DIFFUSION_XL:
		$"%AIType".selected = AITypes.STABLE_DIFFUSION_XL
		_on_AIType_item_selected(AITypes.STABLE_DIFFUSION_XL)

	$"%ResultsScroll".hide()
	$"%AssetViewer".open_image([texture], -1, AssetViewer.ImageModes.DEPTH)


func view_image(texture: Texture) -> void:
	if not context_sent.empty():
		$ErrorDialog.dialog_text = "Generation is currently happening, wait for the task to end."
		$ErrorDialog.popup_centered()
		return

	if not context_list.has_contexts():
		context_list.create_context()

	_fallback_to_correct_ai()

	$"%ResultsScroll".hide()
	$"%AssetViewer".open_image([texture], -1, AssetViewer.ImageModes.MASK
			if ai_request.has_masking() else AssetViewer.ImageModes.SIMPLE)


func view_normal_image(texture: Texture) -> void:
	if not context_sent.empty():
		$ErrorDialog.dialog_text = "Generation is currently happening, wait for the task to end."
		$ErrorDialog.popup_centered()
		return

	if not context_list.has_contexts():
		context_list.create_context()

	if ai_type != AITypes.STABLE_DIFFUSION_XL:
		$"%AIType".selected = AITypes.STABLE_DIFFUSION_XL
		_on_AIType_item_selected(AITypes.STABLE_DIFFUSION_XL)

	$"%ResultsScroll".hide()
	$"%AssetViewer".open_image([texture], -1, AssetViewer.ImageModes.NORMAL)


func generate_asset_variations(image: Image) -> void:
	if not context_list.has_contexts():
		context_list.create_context()

	if not ai_request.has_variations():
		$"%AIType".selected = AITypes.DALLE_2
		_on_AIType_item_selected(AITypes.DALLE_2)

	image = image.duplicate()

	ai_request.set_options(ai_options.get_options())

	if ai_request.is_square_image_required():
		original_image_size = image.get_size()
		# Images are expected to have the same width and height. If that's not the
		# case, surround the necessary space with black bars.
		is_image_square = original_image_size.x == original_image_size.y
		if not is_image_square:
			var max_size = max(original_image_size.x, original_image_size.y)

			# Create a full black square image.
			var square_image = Image.new()
			square_image.create(max_size, max_size, false, image.get_format())
			square_image.fill(Color(0, 0, 0))

			# Center the old image into the square one.
			var dest = Vector2()
			if original_image_size.x < original_image_size.y:
				dest.x = (original_image_size.y - original_image_size.x) / 2
			else:
				dest.y = (original_image_size.x - original_image_size.y) / 2

			square_image.blit_rect(image, Rect2(Vector2(), original_image_size), dest)
			image = square_image

	asset_requested = ai_request.get_asset_quantity()
	$"%Results".columns = asset_requested
	context_sent = context_list.context_selected

	ai_request.generate_asset_variations(image)

	$"%AssetViewer".hide()
	history_dialog.add_section("", ai_request.get_request_json())

	_clear_previews()
	_update_ui_state()


func _clear_previews() -> void:
	var results = $"%Results"
	for i in results.get_children():
		results.remove_child(i)
		i.queue_free()


func _add_preview(texture: Texture) -> void:
	var results = $"%Results"

	var picture = TextureRect.new()
	picture.expand = true
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.rect_min_size.y = 200
	picture.mouse_default_cursor_shape = CURSOR_POINTING_HAND
	picture.size_flags_horizontal = SIZE_EXPAND_FILL
	picture.size_flags_vertical = SIZE_EXPAND_FILL

	picture.texture = texture
	results.add_child(picture)
	picture.connect("gui_input", self, "_on_Picture_gui_input", [picture.get_index()])


func _fallback_to_correct_ai() -> void:
	if not ProjectSettings.get_setting("ai_assist/ais/stable_diffusion_xl_link").empty():
		if ai_type != AITypes.STABLE_DIFFUSION_XL:
			$"%AIType".selected = AITypes.STABLE_DIFFUSION_XL
			_on_AIType_item_selected(AITypes.STABLE_DIFFUSION_XL)
	elif not get_node("/root/AIPluginManager").get_stabilityai_api_key().empty():
		if ai_type != AITypes.STABLE_DIFFUSION:
			$"%AIType".selected = AITypes.STABLE_DIFFUSION
			_on_AIType_item_selected(AITypes.STABLE_DIFFUSION)
	else:
		if ai_type != AITypes.DALLE_2:
			$"%AIType".selected = AITypes.DALLE_2
			_on_AIType_item_selected(AITypes.DALLE_2)


func _update_presets() -> void:
	var presets := $"%Presets" as OptionButton
	var current: int = presets.selected if presets.selected != - 1 else 0

	presets.clear()
	presets.add_item("None")

	presets.add_separator()

	presets.add_item("360° View")
	presets.set_item_metadata(2, {
		"ai": 3,
		"prompt_positive": "<lora:360RedmondResized:0.8> 360, 360 view,",
		"prompt_negative": "",
		"options": {
			"image_generation/stable_diffusion_xl/tiling_x": true,
		},
	})

	if context_list.has_context_data_key(context_list.context_selected, "image_generation/presets"):
		presets.add_separator()

		for i in context_list.get_context_data(context_list.context_selected, "image_generation/presets"):
			presets.add_item(i["name"])
			presets.set_item_metadata(presets.get_item_count() - 1, i)

	presets.select(current)


func _update_history() -> void:
	history_dialog.clear()

	if not context_list.has_context_data_key(context_list.context_selected, "history"):
		return

	for i in context_list.get_context_data(context_list.context_selected, "history"):
		history_dialog.add_section(i["prompt"], i["request_json"], i["negative_prompt"])

		for j in i["image_ids"]:
			var image: Texture =\
					context_list.get_context_image_file(context_list.context_selected, j + ".png")
			if image != null:
				history_dialog.add_image(image, j)


func _update_images_from_history(data_override:=[]) -> void:
	var data = (history_dialog.get_history_data() if data_override.empty()
			else data_override).pop_back()
	prompt_positive.text = data["prompt"] if data != null else ""
	prompt_negative.text = data["negative_prompt"] if data != null else ""

	_clear_previews()

	if data != null:
		for i in data["image_ids"]:
			var texture: Texture =\
					context_list.get_context_image_file(context_list.context_selected, i + ".png")
			if texture != null:
				_add_preview(texture)

	var columns: int = $"%Results".get_child_count()
	if context_sent == context_list.context_selected:
		columns += asset_requested
	$"%Results".columns = max(columns, 1)


func _update_ui_state() -> void:
	var is_generating = not context_sent.empty()
	if not is_generating:
		send_button.text = "Generate"

	var has_selection = not context_list.context_selected.empty()
	if has_selection:
		if is_generating:
			send_button.text = "Generating..."

			if not $"%AssetViewer".has_mask_texture():
				$"%AssetViewer".clear_mask()

			$"%AssetViewer".hide()
			$"%ResultsScroll".show()
	else:
		prompt_positive.text = ""
		prompt_negative.text = ""

		$"%AdvancedOptions".hide()

	var disable = not has_selection or is_generating
	history_button.disabled = disable
	prompt_positive.readonly = disable
	prompt_negative.readonly = disable
	send_button.disabled = disable
	$"%SavePreset".disabled = disable
	$"%Presets".disabled = disable
	$"%RemovePreset".disabled = disable
	$"%AIType".disabled = disable
	$"%AdvancedToggle".disabled = not has_selection


func _on_option_value_changed(value) -> void:
	if $SaveDelay.is_inside_tree():
		$SaveDelay.start()


func _on_Picture_gui_input(event: InputEvent, index: int) -> void:
	if not event is InputEventMouseButton or event.button_index != 1 or not event.is_pressed():
		return

	if not context_sent.empty():
		$ErrorDialog.dialog_text = "Generation is currently happening, wait for the task to end."
		$ErrorDialog.popup_centered()
		return

	var textures := []
	for i in $"%Results".get_children():
		textures.append(i.texture)

	if ai_request is ModelAIBase:
		return
#		_fallback_to_correct_ai()

	$"%ResultsScroll".hide()
	$"%AssetViewer".open_image(textures, index, AssetViewer.ImageModes.MASK
			if ai_request.has_masking() else AssetViewer.ImageModes.SIMPLE)


func _on_PromptPositive_text_changed():
	send_button.disabled = prompt_positive.text.empty()


func _on_Send_Button_pressed() -> void:
	ai_request.set_options(ai_options.get_options())

	if ai_request is ImageAIBase and ai_request.is_square_image_required():
		# A image is being generated from scratch, so make those values be ignored.
		original_image_size.x = -1
		is_image_square = true

	asset_requested = ai_request.get_asset_quantity()
	$"%Results".columns = asset_requested
	context_sent = context_list.context_selected

	ai_request.prompt = preset_prompt + prompt_positive.text
	if ai_request.has_negative_prompting():
		ai_request.negative_prompt = preset_prompt_negative + prompt_negative.text

	if ai_request is ImageAIBase and $"%AssetViewer".visible:
		match $"%AssetViewer".image_mode:
			AssetViewer.ImageModes.SIMPLE:
				ai_request.generate_asset()
			AssetViewer.ImageModes.MASK:
				ai_request.generate_asset_with_mask(
						$"%AssetViewer".get_mask_data(), $"%AssetViewer".get_image_data())
			AssetViewer.ImageModes.DEPTH:
				ai_request.generate_asset_with_controlnet(
						"depth", $"%AssetViewer".get_image_data())
			AssetViewer.ImageModes.NORMAL:
				ai_request.generate_asset_with_controlnet(
						"normal", $"%AssetViewer".get_image_data())
	else:
		ai_request.generate_asset()

	history_dialog.add_section(
			prompt_positive.text, ai_request.get_request_json(), prompt_negative.text)

	_clear_previews()
	_update_ui_state()


func _on_AIType_item_selected(index: int) -> void:
	if ai_type == index:
		return

	ai_type = index

	if ai_request.is_connected("error", self, "_on_AI_error"):
		ai_request.disconnect("error", self, "_on_AI_error")
		if ai_request is ImageAIBase:
			ai_request.disconnect("image_downloaded", self, "_on_AI_image_downloaded")
		else:
			ai_request.disconnect("model_downloaded", self, "_on_AI_model_downloaded")

	if ai_type == AITypes.DALLE_2:
		ai_request = $"%Dalle2Request"
		ai_options = $"%Dalle2Options"
	elif ai_type == AITypes.DALLE_3:
		ai_request = $"%Dalle3Request"
		ai_options = $"%Dalle3Options"
	elif ai_type == AITypes.STABLE_DIFFUSION:
		ai_request = $"%StableDiffusionRequest"
		ai_options = $"%StableDiffusionOptions"
	elif ai_type == AITypes.STABLE_DIFFUSION_XL:
		ai_request = $"%StableDiffusionXLRequest"
		ai_options = $"%StableDiffusionXLOptions"
	elif ai_type == AITypes.MESHY:
		ai_request = $"%MeshyRequest"
		ai_options = $"%MeshyOptions"

	ai_request.connect("error", self, "_on_AI_error")
	if ai_request is ImageAIBase:
		ai_request.connect("image_downloaded", self, "_on_AI_image_downloaded")

		$"%AssetViewer".variations_enabled = ai_request.has_variations()
		$"%AssetViewer".mask_enabled = ai_request.has_masking()
	else:
		ai_request.connect("model_downloaded", self, "_on_AI_model_downloaded")

	for i in $"%AdvancedOptions".get_children():
		i.visible = i == ai_options

	var has_negative_prompting = ai_request.has_negative_prompting()
	$HSplit/VBox/Options/Prompts/Label2.visible = has_negative_prompting
	$HSplit/VBox/Options/Prompts/PromptNegative.visible = has_negative_prompting

	_update_presets()


func _on_AI_image_downloaded(index: int, texture: Texture) -> void:
	if context_list.contexts_data.has(context_sent):
		if ai_request.is_square_image_required():
			if original_image_size.x != -1:
				var image = texture.get_data()
				var max_size = max(original_image_size.x, original_image_size.y)
				image.resize(max_size, max_size, Image.INTERPOLATE_LANCZOS)

			# If the image was not a square before, make it have the original
			# dimensions again. Some stuff will likely be cut out, but what you can do.
			if not is_image_square:
				var image = texture.get_data()
				var max_size = max(original_image_size.x, original_image_size.y)
				image.resize(max_size, max_size, Image.INTERPOLATE_LANCZOS)

				var new_image = Image.new()
				new_image.create(original_image_size.x, original_image_size.y,
						false, image.get_format())

				var start = Vector2()
				if original_image_size.x < original_image_size.y:
					start.x = (original_image_size.y - original_image_size.x) / 2
				else:
					start.y = (original_image_size.x - original_image_size.y) / 2

				new_image.blit_rect(image, Rect2(start, original_image_size), Vector2())
				image = new_image

				texture = ImageTexture.new()
				texture.create_from_image(image)

		if context_sent == context_list.context_selected:
			_add_preview(texture)

		history_dialog.add_image(texture)
		context_list.add_context_image_file(context_list.context_selected if context_sent.empty()
				else context_sent, texture.get_data(), texture.get_meta("history_id") + ".png")

		_on_SaveDelay_timeout()

	asset_requested -= 1
	if asset_requested == 0:
		asset_requested = 0
		context_sent = ""

		_update_history()
		_update_ui_state()


func _on_AI_model_downloaded(index: int, file_path: String, preview: Texture) -> void:
	if context_list.contexts_data.has(context_sent):
		if context_sent == context_list.context_selected:
			_add_preview(preview)

#		history_dialog.add_image(preview)
#		context_list.add_context_image_file(context_list.context_selected if context_sent.empty()
#				else context_sent, preview.get_data(), preview.get_meta("history_id") + ".png")

		_on_SaveDelay_timeout()

	editor_interface.get_resource_filesystem().scan()

	asset_requested -= 1
	if asset_requested == 0:
		asset_requested = 0
		context_sent = ""

		_update_history()
		_update_ui_state()


func _on_AI_error(message: String) -> void:
	asset_requested = 0
	context_sent = ""

	_update_history()
	_update_ui_state()

	if not message.empty():
		$ErrorDialog.dialog_text = message
		$ErrorDialog.popup_centered()


func _on_ContextList_context_selected(id: String) -> void:
	if not is_inside_tree():
		return

	if context_sent == id:
		_update_images_from_history()
	else:
		if context_sent.empty():
			_update_history()
			_update_images_from_history()
		else:
			if context_list.has_context_data_key(id, "history"):
				_update_images_from_history(context_list.get_context_data(id, "history"))
			else:
				prompt_positive.text = ""
				prompt_negative.text = ""

	_update_ui_state()

	if $"%AdvancedToggle".pressed:
		$"%AdvancedOptions".show()

	$"%AssetViewer".clear_mask()
	$"%AssetViewer".hide()
	$"%ResultsScroll".show()

	if not context_list.has_context_data_key(id, "options"):
		return

	_update_presets()

	var options = context_list.get_context_data(id, "options")
	$"%AIType".selected = options["image_generation/type"]
	_on_AIType_item_selected(options["image_generation/type"])

	$"%Presets".selected = options["image_generation/preset_selected"]
	_on_Presets_item_selected(options["image_generation/preset_selected"])

	$"%AdvancedToggle".pressed = options["image_generation/advanced"]

	ai_options.set_options(options)

	# Don't trigger another save.
	$SaveDelay.call_deferred("stop")

	if prompt_positive.is_inside_tree():
		prompt_positive.grab_focus()


func _on_ContextList_context_renamed(id: String) -> void:
	context_list.save_context(id)


func _on_ContextList_context_removed(id: String) -> void:
	if not context_list.context_selected.empty():
		return

	_clear_previews()
	_update_ui_state()

	history_dialog.clear()


func _on_ContextList_context_created_new(id: String) -> void:
	context_list.set_context_data(id, "options", default_options)


func _on_SaveDelay_timeout() -> void:
	var options = {}
	options["image_generation/type"] = ai_type
	options["image_generation/preset_selected"] = $"%Presets".selected
	options["image_generation/advanced"] = $"%AdvancedToggle".pressed

	for i in $"%AdvancedOptions".get_children():
		options.merge(i.get_options())

	var context_target =\
			context_sent if not context_sent.empty() else context_list.context_selected
	context_list.set_context_data(context_target, "options", options)
	context_list.set_context_data(context_target, "history", history_dialog.get_history_data())

	context_list.save_context(context_target)


func _on_AssetViewer_file_saved() -> void:
	editor_interface.get_resource_filesystem().scan()


func _on_HistoryDialog_image_pressed(texture: Texture) -> void:
	$"%ResultsScroll".hide()
	$"%AssetViewer".open_image([texture], -1, AssetViewer.ImageModes.MASK
			if ai_request.has_masking() else AssetViewer.ImageModes.SIMPLE)


func _on_HistoryDialog_images_removed(ids: Array, was_last_section: bool) -> void:
	for i in ids:
		context_list.remove_context_file(context_list.context_selected, i + ".png")

	_on_SaveDelay_timeout()

	if was_last_section and asset_requested == 0:
		_update_images_from_history()


func _on_SavePreset_pressed() -> void:
	$SavePresetDialog/PresetName.clear()
	$SavePresetDialog.popup_centered()


func _on_Presets_item_selected(index: int) -> void:
	$"%RemovePreset".disabled = index <= 2

	var meta: Dictionary = $"%Presets".get_item_metadata(index) if index > 1 and index != 3 else {}
	preset_prompt = meta["prompt_positive"] if index > 1 else ""
	preset_prompt_negative = meta["prompt_negative"] if index > 1 else ""

	if not meta.has("ai"):
		return

	$"%AIType".selected = meta["ai"]
	_on_AIType_item_selected(meta["ai"])

	if meta.has("options"):
		var options: Dictionary = meta["options"].duplicate()
		options.merge(ai_options.get_options())
		ai_options.set_options(options)

	_on_SaveDelay_timeout()


func _on_RemovePreset_pressed() -> void:
	var context_data = context_list.get_context_data(context_list.context_selected, "image_generation/presets")
	context_data.pop_back()

	context_list.set_context_data(context_list.context_selected, "image_generation/presets", context_data)

	_update_presets()
	_on_SaveDelay_timeout()


func _on_SavePresetDialog_confirmed() -> void:
	var preset := {}
	preset["name"] = $SavePresetDialog/PresetName.text

	var prompt: String = prompt_positive.text.strip_edges()
	if not prompt.ends_with(","):
		prompt += ","
	preset["prompt_positive"] = prompt

	prompt = prompt_negative.text.strip_edges()
	if not prompt.ends_with(","):
		prompt += ","
	preset["prompt_negative"] = prompt

	context_list.append_context_data(context_list.context_selected, "image_generation/presets", preset)

	_update_presets()

	var presets = $"%Presets"
	presets.selected = presets.get_item_count() - 1
	_on_Presets_item_selected(presets.get_item_count() - 1)

	_on_SaveDelay_timeout()


func _on_PresetName_text_changed(new_text: String) -> void:
	var is_valid := true

	var presets = $"%Presets"
	for i in presets.get_item_count():
		if new_text == presets.get_item_text(i):
			is_valid = false
			break

	$SavePresetDialog.get_ok().disabled = not is_valid or new_text.empty()
	$SavePresetDialog/PresetName.add_color_override("font_color", ColorN("white") if is_valid else ColorN("tomato"))


func _on_PresetName_text_entered(new_text: String) -> void:
	if not $SavePresetDialog.get_ok().disabled and not $SavePresetDialog/PresetName.text.empty():
		_on_SavePresetDialog_confirmed()


func _on_StableDiffusionXLOptions_lora_selected(lora: String, strength: float) -> void:
	if asset_requested > 0:
		return

	var text_add := "" if prompt_positive.text.empty() else ", "
	text_add += "<lora:%s:%s>, " % [lora, strength]

	prompt_positive.text += text_add
	prompt_positive.grab_focus()
