tool
class_name StableDiffusionRequest
extends ImageAIBase


const END_POINT = "https://api.stability.ai/v1/generation/stable-diffusion-v1-6/"

# USE THIS SIGNALS TO GET RESULTS
signal image_downloaded(index, texture)

# EXCEPTION SIGNALS
signal error(message)

var prompt := ""

var gen_seed: int
var dimensions := Vector2()
var samples: int
var steps: int
var style: int
var cfg_scale: int

var request_json := ""


static func get_default_options() -> Dictionary:
	var options := {}
	options["image_generation/stable_diffusion/seed"] = 0
	options["image_generation/stable_diffusion/dimensions"] = var2str(Vector2(512, 512))
	options["image_generation/stable_diffusion/samples"] = 4
	options["image_generation/stable_diffusion/steps"] = 30
	options["image_generation/stable_diffusion/style"] = 0
	options["image_generation/stable_diffusion/cfg_scale"] = 7

	return options


func set_options(options: Dictionary) -> void:
	gen_seed = options["image_generation/stable_diffusion/seed"]
	dimensions = str2var(options["image_generation/stable_diffusion/dimensions"])
	samples = options["image_generation/stable_diffusion/samples"]
	steps = options["image_generation/stable_diffusion/steps"]
	style = options["image_generation/stable_diffusion/style"]
	cfg_scale = options["image_generation/stable_diffusion/cfg_scale"]


func has_masking() -> bool:
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
		401:
			var msg := "You didn't provide a StabilityAI API key. You can obtain an API key from " +\
					'https://beta.dreamstudio.ai/account. Then set it up inside the "env" file ' +\
					'in the ".ai_assist" folder, and reload it.'
			printerr(msg)
			emit_signal("error", msg)
		_:
			printerr(JSON.print(json.result.message))
			emit_signal("error", "")


# IMAGE GENERATION
func _on_image_request_completed(result):
	var textures: Array
	for i in range(result.artifacts.size()):
		var image = Image.new()
		var image_error = image.load_png_from_buffer(Marshalls.base64_to_raw(result.artifacts[i].base64))
		if image_error != OK:
			print("An error occurred while trying to display the image.")

		var texture = ImageTexture.new()
		texture.create_from_image(image)
		emit_signal("image_downloaded", i, texture)


func generate_asset():
	var request_params := _get_base_request_params()
	request_params["text_prompts"] = [
		{
			"text": prompt,
			"weight": 0.5
		}
	]
	request_params["width"] = dimensions.x
	request_params["height"] = dimensions.y

	request_json = to_json(request_params)

	connect("request_completed", self, "_on_request_completed", ["_on_image_request_completed"], CONNECT_ONESHOT)
	request_raw(END_POINT + "text-to-image", custom_headers(), false,
			HTTPClient.METHOD_POST, JSON.print(request_params).to_utf8())


func generate_asset_with_mask(mask_src: Image, img_init: Image):
	var request_params := _get_base_request_params()
	request_params["text_prompts[0][text]"] = prompt
	request_params["text_prompts[0][weight]"] = 1
	request_params["init_image"] = img_init
	request_params["mask_image"] = mask_src
	request_params["mask_source"] = "MASK_IMAGE_WHITE"

	request_json = to_json(request_params)

	var time_boundary = "--" + String(Time.get_ticks_msec())
	var body = multipart_body(time_boundary, request_params)

	connect("request_completed", self, "_on_request_completed", ["_on_image_request_completed"], CONNECT_ONESHOT)
	request_raw(END_POINT + "image-to-image/masking", custom_headers(
			"multipart/form-data; boundary=" + time_boundary), false, HTTPClient.METHOD_POST, body)


func _get_base_request_params() -> Dictionary:
	var request_params := {
		"seed": gen_seed,
		"cfg_scale": cfg_scale,
		"clip_guidance_preset": "FAST_BLUE",
		"samples": samples,
		"steps": steps,
	}

	if style > 0:
		match style:
			1:
				request_params["style_preset"] = "enhance"
			2:
				request_params["style_preset"] = "anime"
			3:
				request_params["style_preset"] = "photographic"
			4:
				request_params["style_preset"] = "digital-art"
			5:
				request_params["style_preset"] = "comic-book"
			6:
				request_params["style_preset"] = "fantasy-art"
			7:
				request_params["style_preset"] = "line-art"
			8:
				request_params["style_preset"] = "analog-film"
			9:
				request_params["style_preset"] = "neon-punk"
			10:
				request_params["style_preset"] = "isometric"
			11:
				request_params["style_preset"] = "low-poly"
			12:
				request_params["style_preset"] = "origami"
			13:
				request_params["style_preset"] = "modeling-compound"
			14:
				request_params["style_preset"] = "cinematic"
			15:
				request_params["style_preset"] = "3d-model"
			16:
				request_params["style_preset"] = "pixel-art"
			17:
				request_params["style_preset"] = "tile-texture"

	return request_params


#func image_variation(image: Image):
#	var time_boundary = "--" + String(Time.get_ticks_msec())
#	var request_params = {
#		"image": image,
#		"n": 4,
#
#		# Must be one of 256x256, 512x512, or 1024x1024
#		"size": "1024x1024",
#	}
#	var body = multipart_body(time_boundary, request_params)
#
#	connect("request_completed", self, "_on_request_completed", ["_on_image_request_completed"], CONNECT_ONESHOT)
#	request_raw(endpoint + "images/variations", custom_headers("multipart/form-data; boundary=" + time_boundary), false, HTTPClient.METHOD_POST, body)
#
#
#func image_edit(prompt: String, image: Image, mask: Image):
#	var time_boundary = "--" + String(Time.get_ticks_msec())
#	var request_params = {
#		"prompt": prompt,
#		"image": image,
#		"mask": mask,
#		"n": 4,
#
#		# Must be one of 256x256, 512x512, or 1024x1024
#		"size": "1024x1024",
#	}
#	var body = multipart_body(time_boundary, request_params)
#
#	connect("request_completed", self, "_on_request_completed", ["_on_image_request_completed"], CONNECT_ONESHOT)
#	request_raw(endpoint + "images/edits", custom_headers("multipart/form-data; boundary=" + time_boundary), false, HTTPClient.METHOD_POST, body)

