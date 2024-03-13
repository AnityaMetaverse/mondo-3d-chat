extends EditorInspectorPlugin


signal edit_with_ai_requested(texture)


func can_handle(object):
	if object is StreamTexture:
		var image = object.get_data()
		if image.is_empty():
			return false

		var button = Button.new()
		button.text = tr("Edit With AI")
		add_custom_control(button)
		button.connect("pressed", self, "emit_signal", ["edit_with_ai_requested", object])

		return true

	return false
