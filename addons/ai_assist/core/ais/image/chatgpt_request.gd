tool
class_name ChatGPTRequest
extends HTTPRequest


const END_POINT = "https://api.openai.com/v1/"

# USE THIS SIGNALS TO GET RESULTS
signal completions_request_completed(result)
signal embeddings_completed(result)
signal function_call_requested(fn, args)

# EXCEPTION SIGNALS
signal error(message)

var image_request_id = -1

var prompt := ""

var dimensions: int
var samples: int


func _ready() -> void:
	use_threads = true


# Helper functions
func custom_headers(content_type = "application/json") -> PoolStringArray:
	return PoolStringArray([
		"Authorization: Bearer " + get_node("/root/AIPluginManager").get_openai_api_key(),
		"Content-Type: %s" % content_type,
	])


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
	match result.choices[0]["finish_reason"]:
		"function_call":
			var function = result.choices[0].message.function_call
			var arguments = JSON.parse(function.arguments).result
			emit_signal("function_call_requested", function.name, arguments)
		"stop":
			emit_signal("completions_request_completed", result.choices[0].message)


func completions(messages: Array):
	var request_params = {
		"model": "gpt-4",
		"messages": messages,
		"max_tokens": 1920,
		"temperature": 0,
		"top_p": 0,
		"frequency_penalty": 0.2,
		"presence_penalty": 0.4,
		"functions":[
			{"name":"show_product", "description":"this function is used to show a product",
				"parameters": {
					"type": "object",
					"properties": {
						"product_id": {
							"type": "integer",
							"description": "The unique identifier of the product.",
						}
					},
					"required": ["product_id"]}},
			{"name":"direct_to", "description":"this function is used to direct the user to another person in the company",
				"parameters": {
					"type": "object",
					"properties": {
						"person_name": {
							"type": "string",
							"description": "The name of the person in the company",
						}
					},
					"required": ["person_name"]}},
			{"name":"purchase_product", "description":"this function is used to purchase the product for the user",
				"parameters": {
					"type": "object",
					"properties": {
						"product_name": {
							"type": "string",
							"description": "The product name",
						}
					},
					"required": ["product_name"]}}],
		"function_call": "auto",
	}

	connect("request_completed", self, "_on_request_completed", ["_on_completions_request_completed"], CONNECT_ONESHOT)
	request_raw(END_POINT + "chat/completions", custom_headers(), false, HTTPClient.METHOD_POST, to_json(request_params).to_utf8())


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
