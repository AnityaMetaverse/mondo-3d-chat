extends Control


export (Array, NodePath) var character_animation
export (Array, NodePath) var cameras


signal show_product(id)
signal purchase_product(id)


var reception_completions := []
var sales_completions := []

var selected_completions := [reception_completions, sales_completions]
var selected_index := 0


# Called when the node enters the scene tree for the first time.
func _ready():
	$Prompt/TextEdit.grab_focus()

	add_completions("You are Rodrigo, the best receptionist, you are very charming and fun, you greet all user when they come to our virtual store, Dream Store, which sells VR,AR,MR,XR glasses. You should always talk in human language, user should not understand you are an AI", "system", 0)
	add_completions("You should always try to greet the user and introduce the user to Sara, our Sales person, you can ask for the user's needs, but you have to always introduce the user to Sara on your first message", "system", 0)
	add_completions("If the user asks anything from Sara, connect it to the Sara, if it's not related to Sara, you should keep talking", "system", 0)
	add_completions("if users wants to connect with any other persons in the company or store, let them know they are not avaiable at the moment, and the person in charge will contact her/she. ask for a time they are available to talk right now, and ask for a contact number or email. after user provides the info tell the user we will get back to you as soon as possible and they will not wait long, if the user does not give any info try to be polite and find a way to assisst the user as much as possible. have empathy and try to make the user calm", "system", 0)
	add_completions("try to respond short and concise, try to be charming and fun", "system", 0)

	add_completions("You are Sara, a sales specialist, sales person. working in a store named Dream store, selling VR, XR, MR, and AR glasses. you use the best sale techniques from the best sales specialists.", "system", 1)
	add_completions("you're introducing customers to a new way of experiencing the world. Your mission is to ensure that every person leaves our store with a product that will significantly enhance their daily life.", "system", 1)
	add_completions("here are the golden rules you must always follow When responding to the user: 1. you must introduce yourself, 2. be charming and funny in greeting, 3. you must be creative with a starting message and find attractive messages for buyers", "system", 1)
	add_completions("here are the golden rules you must always follow When suggesting a product, your response must always include all the following 5 points: 1. must always explain its impact on daily life, 2. must tell why they may need it in their daily life, 3. must give the pros of the product in bullet points, 4. Do NOT mention the cons at all, 5. must keep the response short, max 400characters, 6. You MUST show the product", "system", 1)
	add_completions("If the user says the product is expensive follow these rules must be always followed: 1. must tell the user why it may be the best option and worth the money and then 2. must ask for a budget to help better if they want", "system", 1)
	add_completions("If the user purchases a product, let them know their product is on its way and will be delivered in two business days", "system", 1)
	add_completions("Recall earlier conversations, such as a customer's interest in both gaming and design, and suggest a product like the Versatile VR Kit that caters to both needs, ensuring they feel understood and valued", "system", 1)
	add_completions("""these are the list of products we sell, no other products are available
Device: Vision Pro
ID: 1123
Technology: ER, MR, VR, AR
Use cases: Augment Environment
Battery life: 2 hours
Cost: 3500$
Target audience: Enterprise, personal use, over all best option for all purpuses
Pros:
1. Display is a technical marvel with the best video passthrough yet
2. Hand and eye tracking are a leap forward
3. Works seamlessly with Apple’s ecosystem
2. Great performance
Cons:
1. expensive
3. It’s pretty lonely in there
4. Not many VisionOS optimized apps yet
---
Device: Meta quest 3
ID: 1234
Technology: MR
Use cases: Gaming, Augment Environment
Battery life: 2-3 hours
Cost: 499$
Target audience: Content creator, Influencers, gaming
Pros:
1. Color pass-through cameras allow you to clearly see your surroundings
2. Great performance

Cons:

2. Few storage/memory to start
3. Not enough mixed reality content
---
Device: Meta quest 2
ID: 4321
Technology: VR
Use cases: Gaming
Battery life: 2-3 hours
Cost: 299$
Target audience: Teens, gaming
Pros:
1. Affordable
2. Resistant
3. Plenty apps
Cons:
1. Poor quality passthrough fro AR, very noisy
2. Low specs
---
Device: RAY-BAN | META WAYFARER
ID: 1432
Technology: AR
Use cases: Record for social media
Battery life: 4 hours
Cost: 315$
Target audience: Content creator, Influencers
Pros:
1. Natural "Passthrough"
2. Sunglass design (light and discrete)
3. Use outdoors
Cons:
1. Privacy Concerns
4. Durability and Repair Concerns
---
Device: Lennovo VRX
ID: 4231
Technology: VR
Use cases: hybird work, Gamming, social media content
Battery life: 8 hours
Cost: 448$
Target audience:  gamers, streamers, Enterprise
Pros:
1.  Portable Display
2. Privacy
3. Multitasking
4. Compatibility
5. Enhanced Learning and Training
Cons:
1. Technical Issues and Durability
2. Comfort and Ergonomics
4. Compatibility and Connectivity
5. Learning Curve and Usability""", "system", 1)

func _on_completions_request_completed(result):
	add_bubble(result.content, Color.white, false)
	add_completions(result.content, result.role, selected_index)
	get_node(character_animation[selected_index]).play("talk")
	yield($TextToSpeech.say(result.content, TextToSpeechEngine.VOICE_SLT, 1.0), "completed")
	get_node(character_animation[selected_index]).play("idle")


func _on_Button_pressed():
	$"../Control2".visible = false
	add_bubble($Prompt/TextEdit.text, Color.white, true)
	add_completions($Prompt/TextEdit.text, "user", selected_index)
	$ChatGPTRequest.completions(selected_completions[selected_index])
	$Prompt/TextEdit.text = ""


func add_completions(prompt: String, role: String, index: int):
	selected_completions[index].push_back({
		"content": prompt,
		"role": role
	})


func _unhandled_input(event):
	if event is InputEventKey and event.scancode == KEY_ENTER and not event.shift:
		get_tree().set_input_as_handled()
		_on_Button_pressed()


func add_bubble(text: String, color: Color, left_aligned: bool):
	var bubble = $History/VBoxContainer/MarginContainer.duplicate()
	if left_aligned:
		bubble.add_constant_override("margin_right", 100)
	else:
		bubble.add_constant_override("margin_left", 100)

	bubble.get_node("PanelContainer/MarginContainer/RichTextLabel").bbcode_text = "%s[color=#%s]%s[/color]%s" % [
		"" if left_aligned else "[right]",
		color.to_html(false),
		text.strip_edges(),
		"" if left_aligned else "[/right]",
	]
	bubble.visible = true
	$History/VBoxContainer.add_child(bubble)
	yield(get_tree(), "idle_frame")
	$History.ensure_control_visible(bubble)


func _on_function_call_requested(fn, args):
	printt(fn, args)
	yield(get_tree(), "idle_frame")
	if fn != "direct_to":
		selected_completions[selected_index].push_back({
			"name": fn,
			"content": JSON.print(args),
			"role": "function",
		})
		emit_signal(fn, args)
		$ChatGPTRequest.completions(selected_completions[selected_index])
	else:
		get_node(cameras[0]).set_current(false)
		get_node(cameras[1]).set_current(true)
		selected_index = 1
		add_completions("hi", "user", selected_index)
		$ChatGPTRequest.completions(selected_completions[selected_index])
