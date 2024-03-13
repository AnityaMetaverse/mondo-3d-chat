tool
class_name ImageAIBase
extends HTTPRequest


func _ready() -> void:
	use_threads = true


func is_square_image_required() -> bool:
	return false


func has_negative_prompting() -> bool:
	return false


func has_masking() -> bool:
	return false


func has_variations() -> bool:
	return false


func has_depth() -> bool:
	return false


func has_normal() -> bool:
	return false
