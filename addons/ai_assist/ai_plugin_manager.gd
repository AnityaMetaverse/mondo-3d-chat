tool
extends Node


const STORAGE_PATH = "res://.ai_assist"
const API_KEY_PATH = STORAGE_PATH + "/env"

var _openai_api_key := ""
var _stabilityai_api_key := ""
var _meshy_api_key := ""

# Emitted by the EditorPlugin script.
signal resource_saved(resource)


func _ready() -> void:
	# Don't run if it's being edited instead of being in plugin mode.
#	if not Engine.editor_hint or get_tree().edited_scene_root == self:
#		return

	var config := ConfigFile.new()
	var file := File.new()
	if not file.file_exists(API_KEY_PATH):
		if file.open(API_KEY_PATH, File.WRITE) != OK:
			printerr('Unable to create "env" file.')
			return

		file.close()

	if config.load(API_KEY_PATH) != OK:
		printerr('Unable to load "env" file.')
		return

	var should_save := false
	if config.has_section_key("api_keys", "OPENAI_API_KEY"):
		_openai_api_key = config.get_value("api_keys", "OPENAI_API_KEY")
	else:
		config.set_value("api_keys", "OPENAI_API_KEY", "")
		should_save = true

	if config.has_section_key("api_keys", "STABILITYAI_API_KEY"):
		_stabilityai_api_key = config.get_value("api_keys", "STABILITYAI_API_KEY")
	else:
		config.set_value("api_keys", "STABILITYAI_API_KEY", "")
		should_save = true

	if config.has_section_key("api_keys", "MESHY_API_KEY"):
		_meshy_api_key = config.get_value("api_keys", "MESHY_API_KEY")
	else:
		config.set_value("api_keys", "MESHY_API_KEY", "")
		should_save = true

	if should_save:
		config.save(API_KEY_PATH)


func get_save_path() -> String:
	return STORAGE_PATH.plus_file(get_git_user())


func get_openai_api_key() -> String:
	return _openai_api_key


func get_stabilityai_api_key() -> String:
	return _stabilityai_api_key


func get_meshy_api_key() -> String:
	return _meshy_api_key


func get_git_user():
	var result = []
	# TODO: Make this cross-platform.
	if OS.execute("git", ["config", "user.name"], true, result) == OK:
		return result[0].strip_edges()

	return "Unknown"
