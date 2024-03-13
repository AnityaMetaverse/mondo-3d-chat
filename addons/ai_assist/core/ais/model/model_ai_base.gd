tool
class_name ModelAIBase
extends HTTPRequest


signal model_downloaded(index, file_path, preview)
signal error(message)


func _ready() -> void:
	use_threads = true


func has_negative_prompting() -> bool:
	return false
