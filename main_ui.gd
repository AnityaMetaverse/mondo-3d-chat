extends Control


var completions := []


# Called when the node enters the scene tree for the first time.
func _ready():
	add_completions("you're a waiter at a bar", "system")
	

func _on_completions_request_completed(result):
	add_completions(result.content, result.role)
	$Label.text += "\n" + result.content


func _on_Button_pressed():
	add_completions($TextEdit.text, "user")
	$ChatGPTRequest.completions(completions)
	$TextEdit.text = ""


func add_completions(prompt: String, role: String):
	completions.push_back({
		"content": prompt,
		"role": role
	})
