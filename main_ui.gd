extends Control


signal show_product(id)


var completions := []


# Called when the node enters the scene tree for the first time.
func _ready():
	add_completions("You are a virtual assistant designed to engage with users interested in virtual reality (VR), augmented reality (AR), and mixed reality (XR) glasses. You are selling for an online platform named 'Super Dooper Glasses Store' where potential customers can explore and purchase such products. Your primary goal is to persuade users of the necessity and benefits of owning VR, AR, or XR glasses by highlighting their immersive experiences, practical applications, and transformative potentials across various industries and personal interests. Always salute new customers with a nice welcome message. Always show the product when you talk about it with the show_product command.", "system")
	add_completions("To use the show_product command type this syntax: [show_product id=]. Don't use markdown, bbcode or any other formatting in the description", "system")
#	add_completions("Customers are from differnt ", "system")
	add_completions("These are the products separated by comma: Vision Pro (costs $1300) id=999, Meta Quest 3 ($500) id=666", "system")

func _on_completions_request_completed(result):
	var stripped_result = result.content
	var regex = RegEx.new()
	regex.compile("\\[show_product id=(\\d+)\\]")
	var regex_result = regex.search(stripped_result)
	if regex_result:
		print("showing product " + regex_result.get_string(1))
		stripped_result = stripped_result.replace(regex_result.get_string(), "")
		emit_signal("show_product", int(regex_result.get_string(1)))

	add_completions(stripped_result, result.role)
	$Label.bbcode_text += "\n[color=#ffffff]%s[/color]" % stripped_result
	$TextToSpeech.say(stripped_result, TextToSpeechEngine.VOICE_SLT, 1.0)


func _on_Button_pressed():
	add_completions($Prompt/TextEdit.text, "user")
	$ChatGPTRequest.completions(completions)
	$Label.bbcode_text += "\n[color=#cccccc]%s[/color]" % $Prompt/TextEdit.text
	$Prompt/TextEdit.text = ""


func add_completions(prompt: String, role: String):
	completions.push_back({
		"content": prompt,
		"role": role
	})


func _unhandled_input(event):
	if event is InputEventKey and event.scancode == KEY_ENTER and not event.shift:
		get_tree().set_input_as_handled()
		_on_Button_pressed()
