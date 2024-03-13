tool
extends VBoxContainer


signal save_requested

const SEED_MAX = 4294967295
var _gen_seed := 0


func _ready() -> void:
	# Don't run if it's being edited instead of being in plugin mode.
	if get_tree().edited_scene_root != self:
		$"%NewSeed".icon = get_icon("Reload", "EditorIcons")


func set_options(options: Dictionary) -> void:
	set_block_signals(true)

	_gen_seed = options["image_generation/meshy/seed"]
	$"%Seed".text = str(_gen_seed)
	$"%Style".selected = options["image_generation/meshy/art_style"]

	set_block_signals(false)


func get_options() -> Dictionary:
	var options := {}
	options["image_generation/meshy/seed"] = _gen_seed
	options["image_generation/meshy/art_style"] = $"%Style".selected

	return options


func _on_option_value_changed(_value) -> void:
	emit_signal("save_requested")


func _on_Seed_text_changed(new_text: String) -> void:
	if not new_text.is_valid_integer():
		$"%Seed".text = str(_gen_seed)
		return

	var int_seed = int(new_text)
	if int_seed < 0 or int_seed > SEED_MAX:
		$"%Seed".text = str(_gen_seed)
		return

	_gen_seed = int_seed

	emit_signal("save_requested")


func _on_NewSeed_pressed():
	_gen_seed = randi() % SEED_MAX + 1
	$"%Seed".text = str(_gen_seed)

	emit_signal("save_requested")
