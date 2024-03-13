tool
class_name Dalle2Request
extends ImageAIBase


const END_POINT = "https://api.openai.com/v1/"

# USE THIS SIGNALS TO GET RESULTS
signal completions_request_completed(result)
signal image_downloaded(index, texture)
signal embeddings_completed(result)

# EXCEPTION SIGNALS
signal error(message)

var image_request_id = -1

var prompt := ""

var dimensions: int
var samples: int

var request_json := ""


static func get_default_options() -> Dictionary:
	var options := {}
	options["image_generation/dalle_2/dimensions"] = 2
	options["image_generation/dalle_2/samples"] = 4

	return options


func set_options(options: Dictionary) -> void:
	dimensions = options["image_generation/dalle_2/dimensions"]
	samples = options["image_generation/dalle_2/samples"]


func has_variations() -> bool:
	return true


func is_square_image_required() -> bool:
	return true


func get_asset_quantity() -> int:
	return samples


func get_request_json() -> String:
	return request_json


# Helper functions
func custom_headers(content_type = "application/json") -> PoolStringArray:
	return PoolStringArray([
		"Authorization: Bearer " + get_node("/root/AIPluginManager").get_openai_api_key(),
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


func download_image(index: int, url: String, id: int):
	var http = HTTPRequest.new()
	add_child(http)
	var http_error = http.request(url)

	if http_error == OK:
		var result = yield(http, "request_completed")
		if id != image_request_id:
			return

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


func _on_request_completed(result: int, response_code: int, headers: PoolStringArray, body: PoolByteArray, callback: String):
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
			var msg := "You didn't provide an OpenAI API key. You can obtain an API key from " +\
					"https://platform.openai.com/account/api-keys. Then set it up inside the " +\
					'"env" file in the ".ai_assist" folder, and reload it.'
			printerr(msg)
			emit_signal("error", msg)
		_:
			printerr(to_json(json.result.error.message))
			emit_signal("error", "")


# CHATBOT
func _on_completions_request_completed(result):
	emit_signal("completions_request_completed", result.choices[0].message)


func completions(messages: Array):
	var request_params = {
		"model": "gpt-3.5-turbo",
		"messages": messages,
		"max_tokens": 1920,
		"temperature": 0,
		"top_p": 1,
		"frequency_penalty": 0.5,
		"presence_penalty": 0.5,
	}

	connect("request_completed", self, "_on_request_completed", ["_on_completions_request_completed"], CONNECT_ONESHOT)
	request_raw(END_POINT + "chat/completions", custom_headers(), false, HTTPClient.METHOD_POST, to_json(request_params).to_utf8())


# IMAGE GENERATION
func _on_image_request_completed(result):
	image_request_id = int(Time.get_unix_time_from_system())

	for i in range(result.data.size()):
		download_image(i, result.data[i].url, image_request_id)


func generate_asset():
	var request_params := _get_base_request_params()
	request_params["prompt"] = prompt

	request_json = to_json(request_params)

	connect("request_completed", self, "_on_request_completed", ["_on_image_request_completed"], CONNECT_ONESHOT)
	request_raw(END_POINT + "images/generations", custom_headers(), false, HTTPClient.METHOD_POST, to_json(request_params).to_utf8())


func generate_asset_variations(image: Image):
	var request_params := _get_base_request_params()
	request_params["image"] = image

	var time_boundary = "--" + String(Time.get_ticks_msec())
	var body = multipart_body(time_boundary, request_params)

	request_json = to_json(request_params)

	connect("request_completed", self, "_on_request_completed", ["_on_image_request_completed"], CONNECT_ONESHOT)
	request_raw(END_POINT + "images/variations", custom_headers("multipart/form-data; boundary=" + time_boundary), false, HTTPClient.METHOD_POST, body)


func _get_base_request_params() -> Dictionary:
	var size = ""
	match dimensions:
			0:
				size = "256x256"
			1:
				size = "512x512"
			2:
				size = "1024x1024"

	return {
		"model": "dall-e-2",
		"n": samples,
		"size": size,
	}


func image_edit(prompt: String, image: Image, mask: Image):
	var time_boundary = "--" + String(Time.get_ticks_msec())

	var request_params := _get_base_request_params()
	request_params["prompt"] = prompt
	request_params["image"] = image
	request_params["mask"] = mask

	var body = multipart_body(time_boundary, request_params)

	connect("request_completed", self, "_on_request_completed", ["_on_image_request_completed"], CONNECT_ONESHOT)
	request_raw(END_POINT + "images/edits", custom_headers("multipart/form-data; boundary=" + time_boundary), false, HTTPClient.METHOD_POST, body)


func image_edit_rect(prompt: String, image: Image, rect: Rect2):
	var mask = Image.new()
	mask.create(
		image.get_width(),
		image.get_height(),
		false,
		Image.FORMAT_RGBA8
	)
	mask.fill(Color.black)
	mask.fill_rect(rect, Color.transparent)

	image_edit(prompt, image, mask)

# EMBEDDINGS
func _on_embeddings_request_completed(result):
	emit_signal("embeddings_completed", result.data[0].embedding)


func embeddings(input: String):
	var request_params = {
		"model": "text-embedding-ada-002",
		"input": input,
	}

	connect("request_completed", self, "_on_request_completed", ["_on_embeddings_request_completed"], CONNECT_ONESHOT)
	request_raw(END_POINT + "embeddings", custom_headers(), false, HTTPClient.METHOD_POST, to_json(request_params).to_utf8())


# Math

# Compute the cosine distance between 1-D arrays.
# Cosine distance is also referred to as 'uncentered correlation'.
# The correlation coefficient lies between –1 and +1; hence the distance lies between 0 and 2
func cosine_distance(u: PoolRealArray, v: PoolRealArray):
	return clamp(correlation(u, v), 0, 2)


# Compute the correlation distance between two 1-D arrays.
func correlation(u: PoolRealArray, v: PoolRealArray) -> float:
	assert(u.size() == v.size())

	var uv = array_average(array_dot(u, v))
	var uu = array_average(array_dot(u, u))
	var vv = array_average(array_dot(v, v))
	var d = 1.0 - uv / sqrt(uu * vv)
	return abs(d)


# Get the dot product of two 1-D arrays.
# Since its 1-D, no transpose is needed.
func array_dot(u: PoolRealArray, v: PoolRealArray) -> PoolRealArray:
	var dot: PoolRealArray
	for i in range(u.size()):
		dot.push_back(u[i] * v[i])

	return dot


# Get the average of 1-D array values.
func array_average(arr: PoolRealArray) -> float:
	var sum := 0.0
	for n in arr:
		sum += n

	return sum / float(arr.size())
