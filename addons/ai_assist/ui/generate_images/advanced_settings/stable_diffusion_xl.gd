tool
extends VBoxContainer


signal save_requested

signal lora_selected(lora, strength)

const SEED_MAX = 4294967295
var _gen_seed := -1

var _was_first_shown := false


func _ready() -> void:
	# Don't run if it's being edited instead of being in plugin mode.
	if get_tree().edited_scene_root == self:
		return

	$"%NewSeed".icon = get_icon("Reload", "EditorIcons")
	$"%TilingHelp".texture = get_icon("InformationSign", "EditorIcons")

	$"%LoRa".get_popup().connect("index_pressed", self, "_on_LoRa_index_pressed")


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not _was_first_shown and\
			is_visible_in_tree() and get_tree().edited_scene_root != self:
		_was_first_shown = true
		$StableDiffusionXLRequest.update_loras()


func set_options(options: Dictionary) -> void:
	set_block_signals(true)

	_gen_seed = options["image_generation/stable_diffusion_xl/seed"]
	$"%Seed".text = str(_gen_seed)
	var dimensions = str2var(options["image_generation/stable_diffusion_xl/dimensions"])
	$"%Width".value = dimensions.x
	$"%Height".value = dimensions.y
	$"%Samples".value = options["image_generation/stable_diffusion_xl/samples"]
	$"%Steps".value = options["image_generation/stable_diffusion_xl/steps"]
	$"%CFGScale".value = options["image_generation/stable_diffusion_xl/cfg_scale"]
	$"%TilingX".pressed = options["image_generation/stable_diffusion_xl/tiling_x"]
	$"%TilingY".pressed = options["image_generation/stable_diffusion_xl/tiling_y"]

	set_block_signals(false)


func get_options() -> Dictionary:
	var options := {}
	options["image_generation/stable_diffusion_xl/seed"] = _gen_seed
	options["image_generation/stable_diffusion_xl/dimensions"] =\
			var2str(Vector2($"%Width".value, $"%Height".value))
	options["image_generation/stable_diffusion_xl/samples"] = $"%Samples".value
	options["image_generation/stable_diffusion_xl/steps"] = $"%Steps".value
	options["image_generation/stable_diffusion_xl/cfg_scale"] = $"%CFGScale".value
	options["image_generation/stable_diffusion_xl/tiling_x"] = $"%TilingX".pressed
	options["image_generation/stable_diffusion_xl/tiling_y"] = $"%TilingY".pressed

	return options


func _on_option_value_changed(_value) -> void:
	emit_signal("save_requested")


func _on_Seed_text_changed(new_text: String) -> void:
	if not new_text.is_valid_integer():
		$"%Seed".text = str(_gen_seed)
		return

	var int_seed = int(new_text)
	if int_seed < -1 or int_seed > SEED_MAX:
		$"%Seed".text = str(_gen_seed)
		return

	_gen_seed = int_seed

	emit_signal("save_requested")


func _on_NewSeed_pressed():
	_gen_seed = randi() % SEED_MAX + 1
	$"%Seed".text = str(_gen_seed)

	emit_signal("save_requested")


func _on_LoRa_index_pressed(index: int) -> void:
	emit_signal("lora_selected", $"%LoRa".get_popup().get_item_text(index), $"%LoRaStrength".value)


func _on_StableDiffusionXLRequest_loras_updated(loras: PoolStringArray) -> void:
	var lora := $"%LoRa".get_popup() as PopupMenu
	lora.clear()

	for i in loras:
		lora.add_item(i)

	$"%LoRa".disabled = loras.empty()
