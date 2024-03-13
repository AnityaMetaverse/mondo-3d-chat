tool
class_name MeshyRequest
extends ModelAIBase


const END_POINT = "https://api.meshy.ai/"

var prompt := ""
var negative_prompt := ""

var gen_seed: int
var art_style: int

var request_json := ""

var _preview: Image


static func get_default_options() -> Dictionary:
	var options := {}
	options["image_generation/meshy/seed"] = -1
	options["image_generation/meshy/art_style"] = 0

	return options


func generate_asset():
	var request_params := _get_base_request_params()
	request_json = to_json(request_params)

	connect("request_completed", self, "_on_request_completed", ["_check_progress"], CONNECT_ONESHOT)
	request_raw(END_POINT + "v2/text-to-3d", _custom_headers(), false,
			HTTPClient.METHOD_POST, JSON.print(request_params).to_utf8())


func set_options(options: Dictionary) -> void:
	gen_seed = options["image_generation/meshy/seed"]
	art_style = options["image_generation/meshy/art_style"]


func has_negative_prompting() -> bool:
	return true


func get_asset_quantity() -> int:
	return 1


func get_request_json() -> String:
	return request_json


func _custom_headers(content_type = "application/json") -> PoolStringArray:
	return PoolStringArray([
		"Authorization: Bearer " + get_node("/root/AIPluginManager").get_meshy_api_key(),
		"Content-Type: %s" % content_type,
	])


func _on_request_completed(result: int, response_code: int, headers: PoolStringArray,
		body: PoolByteArray, callback: String):
	if callback == "create_image":
		_preview = Image.new()
		if _preview.load_png_from_buffer(body) != OK:
			printerr("Error creating model thumbnail.")

		return

	var json_text: String = body.get_string_from_utf8()
	if not validate_json(json_text).empty():
		printerr("Invalid JSON returned: " + json_text)
		emit_signal("error", "")

		return

	var json = JSON.parse(json_text)
	match response_code:
		200, 202:
			call(callback, json.result)
		401:
			var msg := "You didn't provide a Meshy API key. You can obtain an API key from " +\
					'https://app.meshy.ai/settings/api. Then set it up inside the "env" file ' +\
					'in the ".ai_assist" folder, and reload it.'
			printerr(msg)
			emit_signal("error", msg)
		_:
			printerr(JSON.print(json.result.message))
			emit_signal("error", "")


func _check_progress(result) -> void:
	var id := ""
	if result.has("result"):
		id = result["result"]
	elif result.has("id"):
		id = result["id"]

		if result["progress"] == 100:
			Directory.new().make_dir("res://model_" + id)
			download_file = "res://model_%s/%s.glb" % [id, id]
			var path: String = download_file

			request(result["model_urls"]["glb"])
			yield(self, "request_completed")

			download_file = ""

			connect("request_completed", self, "_on_request_completed", ["create_image"], CONNECT_ONESHOT)
			request(result["thumbnail_url"])
			print(result["thumbnail_url"])
			yield(self, "request_completed")

			var texture := ImageTexture.new()
			texture.create_from_image(_preview)

			emit_signal("model_downloaded", 0, path, texture)

			return

	yield(get_tree().create_timer(5), "timeout")

	connect("request_completed", self, "_on_request_completed", ["_check_progress"], CONNECT_ONESHOT)
	request_raw(END_POINT + "v2/text-to-3d/" + id, _custom_headers(), false)


func _get_base_request_params() -> Dictionary:
	var request_params := {
		"prompt": prompt,
		"negative_prompt": negative_prompt,
		"mode": "preview",
		"seed": gen_seed,
	}

	match art_style:
		0:
			request_params["art_style"] = "realistic"
		1:
			request_params["art_style"] = "cartoon"
		2:
			request_params["art_style"] = "low-poly"

	return request_params
