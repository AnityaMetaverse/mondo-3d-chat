tool
class_name StableDiffusionXLRequest
extends ImageAIBase


# USE THIS SIGNALS TO GET RESULTS
signal image_downloaded(index, texture)

# EXCEPTION SIGNALS
signal error(message)

signal loras_updated(loras)

var prompt := ""
var negative_prompt := ""

var gen_seed: int
var dimensions = Vector2()
var samples: int
var steps: int
var cfg_scale: int
var tiling_x: bool
var tiling_y: bool

var request_json := ""


static func get_default_options() -> Dictionary:
	var options := {}
	options["image_generation/stable_diffusion_xl/seed"] = -1
	options["image_generation/stable_diffusion_xl/dimensions"] = var2str(Vector2(1024, 1024))
	options["image_generation/stable_diffusion_xl/samples"] = 4
	options["image_generation/stable_diffusion_xl/steps"] = 30
	options["image_generation/stable_diffusion_xl/cfg_scale"] = 7
	options["image_generation/stable_diffusion_xl/tiling_x"] = false
	options["image_generation/stable_diffusion_xl/tiling_y"] = false

	return options


func set_options(options: Dictionary) -> void:
	gen_seed = options["image_generation/stable_diffusion_xl/seed"]
	dimensions = str2var(options["image_generation/stable_diffusion_xl/dimensions"])
	samples = options["image_generation/stable_diffusion_xl/samples"]
	steps = options["image_generation/stable_diffusion_xl/steps"]
	cfg_scale = options["image_generation/stable_diffusion_xl/cfg_scale"]
	tiling_x = options["image_generation/stable_diffusion_xl/tiling_x"]
	tiling_y = options["image_generation/stable_diffusion_xl/tiling_y"]


func has_negative_prompting() -> bool:
	return true


func has_masking() -> bool:
	return true


func has_depth() -> bool:
	return true


func has_normal() -> bool:
	return true


func get_asset_quantity() -> int:
	return samples


func get_request_json() -> String:
	return request_json


# Helper functions
func custom_headers(content_type = "application/json") -> PoolStringArray:
	return PoolStringArray([
		"Authorization: Bearer " + get_node("/root/AIPluginManager").get_stabilityai_api_key(),
		"Content-Type: %s" % content_type,
	])


func multipart_body(time_boundary: String, request_params: Dictionary) -> PoolByteArray:
	var body : PoolByteArray
	for k in request_params.keys():
		var v = request_params[k]
		# BIG HACK!
		if v is Array:
			v = v[0]
		elif v is Dictionary:
			v = v["controlnet"]["args"]["input_image"]

		body.append_array(String("--" + time_boundary).to_utf8())
		body.append_array(String("\r\nContent-Disposition: form-data; name=\"%s\"" % k).to_utf8())

		if v is Image:
			body.append_array(String("; filename=\"test.png\"").to_utf8())

		body.append_array(String("\r\n\r\n").to_utf8())

		if v is Image:
			body.append_array(v.save_png_to_buffer())
		else:
			body.append_array(String(v).to_utf8())

		body.append_array("\r\n".to_utf8())

	if not body.empty():
		body.append_array(String("--" + time_boundary + "--").to_utf8())

	return body


func download_image(index: int, url: String):
	var http = HTTPRequest.new()
	add_child(http)
	var http_error = http.request(url)

	if http_error == OK:
		var result = yield(http, "request_completed")

		var image = Image.new()
		var image_error = image.load_png_from_buffer(result[3])
		if image_error != OK:
			print("An error occurred while trying to display the image.")
		else:
			var texture = ImageTexture.new()
			texture.create_from_image(image)
			emit_signal("image_downloaded", index, texture)
	else:
		print("An error occurred in the HTTP request.")

	http.queue_free()


func _on_request_completed(result: int, response_code: int, headers: PoolStringArray,
		body: PoolByteArray, callback: String):
	var json_text: String = body.get_string_from_utf8()
	if not validate_json(json_text).empty():
		printerr("Invalid JSON returned: " + json_text)
		emit_signal("error", "")

		return

	var json = JSON.parse(json_text)
	match response_code:
		200:
			call(callback, json.result)
		_:
			if json.error == OK and json.result != null and json.result.has("message"):
				printerr(JSON.print(json.result.message))
			else:
				printerr(json_text)

			emit_signal("error", "")


# IMAGE GENERATION
func _on_image_request_completed(result):
	var textures : Array
	for i in range(result.images.size()):
		var image = Image.new()
		var image_error = image.load_png_from_buffer(Marshalls.base64_to_raw(result.images[i]))
		if image_error != OK:
			print("An error occurred while trying to display the image.")

		var texture = ImageTexture.new()
		texture.create_from_image(image)
		emit_signal("image_downloaded", i, texture)
		#download_image(i, result.data[i].url)


func generate_asset():
	if not _is_link_valid():
		return

	var request_params := _get_base_request_params()
	request_json = to_json(request_params)

	connect("request_completed", self, "_on_request_completed", ["_on_image_request_completed"],
			CONNECT_ONESHOT)
	request_raw(ProjectSettings.get_setting("ai_assist/ais/stable_diffusion_xl_link").plus_file(
			"sdapi/v1/txt2img"), custom_headers(), false, HTTPClient.METHOD_POST, JSON.print(
			request_params).to_utf8())


func generate_asset_with_mask(mask_src: Image, img_init: Image):
	if not _is_link_valid():
		return

	var request_params := _get_base_request_params()
	request_params["init_images"] = [Marshalls.raw_to_base64(img_init.save_png_to_buffer())]
	request_params["mask"] = Marshalls.raw_to_base64(mask_src.save_png_to_buffer())

	request_json = to_json(request_params)

	connect("request_completed", self, "_on_request_completed", ["_on_image_request_completed"],
			CONNECT_ONESHOT)
	request_raw(ProjectSettings.get_setting("ai_assist/ais/stable_diffusion_xl_link").plus_file(
			"/sdapi/v1/img2img"), custom_headers(), false, HTTPClient.METHOD_POST, JSON.print(
			request_params).to_utf8())


func generate_asset_with_controlnet(model_type: String, image_src: Image):
	if not _is_link_valid() or not _is_model_valid(model_type):
		return

	var request_params := _get_base_request_params()
	request_params["alwayson_scripts"]["controlnet"] = {
		"args": [{
			"input_image": Marshalls.raw_to_base64(image_src.save_png_to_buffer()),
			"model": ProjectSettings.get_setting("ai_assist/models/" + model_type),
		}]
	}

	request_json = to_json(request_params)

	connect("request_completed", self, "_on_request_completed", ["_on_image_request_completed"],
			CONNECT_ONESHOT)
	request_raw(ProjectSettings.get_setting("ai_assist/ais/stable_diffusion_xl_link").plus_file(
			"/sdapi/v1/txt2img"), custom_headers(), false, HTTPClient.METHOD_POST, JSON.print(
			request_params).to_utf8())


func update_loras() -> void:
	if not _is_link_valid() or is_connected("request_completed", self, "_on_request_completed"):
		return

	connect("request_completed", self, "_on_request_completed", ["_on_lora_list_received"], CONNECT_ONESHOT)
	request_raw(ProjectSettings.get_setting("ai_assist/ais/stable_diffusion_xl_link").plus_file(
			"/sdapi/v1/loras"), custom_headers(), false, HTTPClient.METHOD_GET, JSON.print(
			"{}").to_utf8())


func _on_lora_list_received(result) -> void:
	if not result is Array:
		return

	var loras := PoolStringArray()
	for i in result:
		loras.append(i["alias"])

	emit_signal("loras_updated", loras)


func _is_link_valid() -> bool:
	if ProjectSettings.get_setting("ai_assist/ais/stable_diffusion_xl_link") == "":
		var msg := "You didn't provide a valid link to your Stable Diffusion XL instance. " +\
				'You can set it via "Project Settings > Ai Assist > Ais > Stable Diffusion Xl Link".'
		printerr(msg)

		emit_signal("error", msg)

		return false

	return true


func _is_model_valid(model: String) -> bool:
	if ProjectSettings.get_setting("ai_assist/models/" + model) == "":
		var msg := ("The model name for %s wasn't provided. " +
				'You can set it via "Project Settings > Ai Assist > Models > %s".') %\
				[model, model.capitalize()]
		printerr(msg)

		emit_signal("error", msg)

		return false

	return true


func _get_base_request_params() -> Dictionary:
	var params := {
		"prompt": prompt,
		"negative_prompt": negative_prompt,
		"seed": gen_seed,
		"width": dimensions.x,
		"height": dimensions.y,
		"cfg_scale": cfg_scale,
		"batch_size": samples,
		"steps": steps,
		"alwayson_scripts": {},
	}

	if tiling_x or tiling_y:
		params["alwayson_scripts"]["Asymmetric tiling"] = {
			"args": [true, tiling_x, tiling_y]
		}

	return params
