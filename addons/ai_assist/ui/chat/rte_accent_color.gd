tool
extends RichTextEffect


var bbcode = "accent_color"
var control


func _process_custom_fx(char_fx: CharFXTransform) -> bool:
	if control is Control:
		var color = control.get_color("default_color", "RichTextLabel")
		var accent_color = control.get_color("accent_color", "Editor")
		color = color.linear_interpolate(accent_color, char_fx.env.get("weight", 1.0))
		char_fx.color = color.to_html(false)

	return true
