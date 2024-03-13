tool
extends HBoxContainer


signal save_requested


func set_options(options: Dictionary) -> void:
	set_block_signals(true)

	$"%Dimensions".selected = options["image_generation/dalle_3/dimensions"]
	$"%Samples".value = options["image_generation/dalle_3/samples"]
	$"%Quality".selected = options["image_generation/dalle_3/quality"]
	$"%Style".selected = options["image_generation/dalle_3/style"]

	set_block_signals(false)


func get_options() -> Dictionary:
	var options := {}
	options["image_generation/dalle_3/dimensions"] = $"%Dimensions".selected
	options["image_generation/dalle_3/samples"] = $"%Samples".value
	options["image_generation/dalle_3/quality"] = $"%Quality".selected
	options["image_generation/dalle_3/style"] = $"%Style".selected

	return options


func _on_option_value_changed(_value) -> void:
	emit_signal("save_requested")
