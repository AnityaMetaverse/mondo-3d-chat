extends Spatial


# Declare member variables here. Examples:
# var a = 2
# var b = "text"


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass


func _on_Control_show_product(id):
	match id:
		666:
			$meta_quest_3_low_poly_oculus_quest_2.visible = true
		999:
			$apple_vision_pro_ios15.visible = true
		_:
			printerr("Product id not recognized")
			return

	$AnimationPlayer.play("show")
