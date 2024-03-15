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


func _on_Control_show_product(result):
	$meta_quest_3_low_poly_oculus_quest_2.visible = false
	$apple_vision_pro_ios15.visible = false
	$Lenovo_VRX.visible = false
	$oculus_quest_2.visible = false
	$sunglass.visible = false
	match int(result.product_id):
		1234:
			$meta_quest_3_low_poly_oculus_quest_2.visible = true
		1123:
			$apple_vision_pro_ios15.visible = true
		4321:
			$oculus_quest_2.visible = true
		1432:
			$sunglass.visible = true
		4231:
			$Lenovo_VRX.visible = true
		_:
			printerr("Product id not recognized")
			return

	$AnimationPlayer.play("show")
	yield($AnimationPlayer, "animation_finished")
	$AnimationPlayer.play("loop")


func _on_Control_purchase_product(result):
	$"../Control2/Label".text = "You've purchased %s succesfully" % result.product_name
	$"../Control2".visible = true
