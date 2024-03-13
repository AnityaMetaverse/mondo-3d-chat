tool
extends HBoxContainer


signal save_requested


func set_options(options: Dictionary) -> void:
	set_block_signals(true)

	$"%Dimensions".selected = options["image_generation/dalle_2/dimensions"]
	$"%Samples".value = options["image_generation/dalle_2/samples"]

	set_block_signals(false)


func get_options() -> Dictionary:
	var options := {}
	options["image_generation/dalle_2/dimensions"] = $"%Dimensions".selected
	options["image_generation/dalle_2/samples"] = $"%Samples".value

	return options


func _on_option_value_changed(_value) -> void:
	emit_signal("save_requested")
