tool
extends EditorPlugin


var main_panel_instance
var inspector_plugin_instance
var assisted_script_instance

var ai_options
var depth_mesh


func _enter_tree():
	add_autoload_singleton("AIPluginManager", "res://addons/ai_assist/ai_plugin_manager.gd")
	# Wait until the singleton has already been added.
	yield(get_tree(), "idle_frame")

	main_panel_instance = load("res://addons/ai_assist/ui/main_panel.tscn").instance()

	# Add the main panel to the editor's main viewport.
	var editor_interface = get_editor_interface()
	main_panel_instance.set_meta("editor_interface", editor_interface)
	editor_interface.get_editor_viewport().add_child(main_panel_instance)

	inspector_plugin_instance = load("res://addons/ai_assist/ui/inspector_plugin.gd").new()
	add_inspector_plugin(inspector_plugin_instance)
	inspector_plugin_instance.connect("edit_with_ai_requested", self, "_on_edit_with_ai_requested")

	# Add debugger plugin to the script editor interface
	var script_editor = editor_interface.get_script_editor()
	assisted_script_instance = load("res://addons/ai_assist/ui/debugger/assisted_debugger.tscn").instance()
	assisted_script_instance.set_meta("script_editor", script_editor)
	assisted_script_instance.set_meta("editor_interface", editor_interface)
	script_editor.get_child(0).add_child(assisted_script_instance)

	# Hide the main panel. Very much required.
	make_visible(false)

	User.new().initialize()

	connect("resource_saved", self, "_on_resource_saved")

	if not ProjectSettings.has_setting("ai_assist/ais/stable_diffusion_xl_link"):
		ProjectSettings.set_setting("ai_assist/ais/stable_diffusion_xl_link", "")
	ProjectSettings.set_initial_value("ai_assist/ais/stable_diffusion_xl_link", "")

	if not ProjectSettings.has_setting("ai_assist/models/depth"):
		ProjectSettings.set_setting("ai_assist/models/depth", "")
	ProjectSettings.set_initial_value("ai_assist/models/depth", "")

	if not ProjectSettings.has_setting("ai_assist/models/normal"):
		ProjectSettings.set_setting("ai_assist/models/normal", "")
	ProjectSettings.set_initial_value("ai_assist/models/normal", "")

	ai_options = MenuButton.new()
	ai_options.text = "AI"
	ai_options.switch_on_hover = true
	ai_options.get_popup().add_item("Get Depth From Viewport")
	ai_options.get_popup().add_item("Get Normal From Viewport")
	ai_options.get_popup().connect("index_pressed", self, "_on_ai_options_index_pressed")
	add_control_to_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, ai_options)

	depth_mesh = MeshInstance.new()
	depth_mesh.extra_cull_margin = 16384

	var mesh = QuadMesh.new()
	mesh.size = Vector2(2, 2)
	mesh.flip_faces = true
	depth_mesh.mesh = mesh

	depth_mesh.material_override = ShaderMaterial.new()
	depth_mesh.material_override.shader = load("res://addons/ai_assist/resources/depth.gdshader")


func _exit_tree():
	remove_autoload_singleton("AIPluginManager")

	if ai_options != null:
		remove_control_from_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, ai_options)
		ai_options.queue_free()

	if depth_mesh != null:
		depth_mesh.queue_free()

	if main_panel_instance != null:
		main_panel_instance.queue_free()

	if inspector_plugin_instance != null:
		remove_inspector_plugin(inspector_plugin_instance)

	if assisted_script_instance != null:
		assisted_script_instance.queue_free()


func has_main_screen():
	return true


func make_visible(visible):
	if main_panel_instance:
		main_panel_instance.visible = visible


func get_plugin_name():
	return "AI Assist"


func get_plugin_icon():
	# Must return some kind of Texture for the icon.
	return get_editor_interface().get_base_control().get_icon("Node", "EditorIcons")


func _on_edit_with_ai_requested(texture):
	get_editor_interface().set_main_screen_editor("AI Assist")
	main_panel_instance.switch_to_generate_picture()
	main_panel_instance.get_generate_picture().view_image(texture)


func _on_resource_saved(resource):
	get_node("/root/AIPluginManager").emit_signal("resource_saved", resource)


func _on_ai_options_index_pressed(index):
	var viewport = get_editor_interface().get_editor_viewport().\
			get_child(1).get_child(1).get_child(0).get_child(0).\
			get_child(0).get_child(0).get_child(0).get_child(0)
	# Prepare the editor viewport.
	viewport.render_target_v_flip = true
	viewport.get_camera().cull_mask = 1048575

	match index:
		0: # Depth
			viewport.add_child(depth_mesh)

			yield(VisualServer, "frame_post_draw")
			var texture = viewport.get_texture()

			get_editor_interface().set_main_screen_editor("AI Assist")
			main_panel_instance.switch_to_generate_picture()
			main_panel_instance.get_generate_picture().view_depth_image(texture)

			viewport.remove_child(depth_mesh)
		1: # Normal
			var start_node: Node = get_editor_interface().get_edited_scene_root()
			var shader := ShaderMaterial.new()
			shader.shader = load("res://addons/ai_assist/resources/normal.gdshader")
			_add_shader_to_nodes(start_node, shader)

			yield(VisualServer, "frame_post_draw")
			var texture = viewport.get_texture()

			get_editor_interface().set_main_screen_editor("AI Assist")
			main_panel_instance.switch_to_generate_picture()
			main_panel_instance.get_generate_picture().view_normal_image(texture)

			_clear_shader_from_nodes(start_node)

	# Set it back to how it was originally.
	viewport.render_target_v_flip = false
	viewport.get_camera().cull_mask = 252706815


func _add_shader_to_nodes(start_node: Node, shader: ShaderMaterial) -> void:
	if start_node is MeshInstance:
		start_node.material_override = shader

	for i in start_node.get_children():
		_add_shader_to_nodes(i, shader)


func _clear_shader_from_nodes(start_node: Node) -> void:
	if start_node is MeshInstance:
		start_node.material_override = null

	for i in start_node.get_children():
		_clear_shader_from_nodes(i)
