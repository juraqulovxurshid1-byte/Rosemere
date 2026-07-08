extends StaticBody3D

class_name GroqNPCAI

# --- GROQ API CONFIGURATION ---
# Uses shared GroqConfig autoload (set your API key ONCE in the GroqConfig node)
@export var npc_name: String = "Gareth the Blacksmith"
@export_multiline var npc_persona: String = "You are Gareth, a gruff but kind medieval blacksmith in a Witcher/Dragon's Dogma inspired fantasy realm. You craft weapons and armor. You speak succinctly with a slight old-english tone. You despise bandits who raid trade caravans."

@onready var http_request: HTTPRequest = HTTPRequest.new()

signal response_received(npc_name: String, reply_text: String)
signal request_failed(error_message: String)

var groq_config: GroqConfig = null

func _ready() -> void:
	add_child(http_request)
	http_request.request_completed.connect(_on_request_completed)
	
	# Find the GroqConfig autoload
	groq_config = get_tree().root.find_child("GroqConfig", true, false) as GroqConfig
	if not groq_config:
		# Fallback: try to find it as a sibling or elsewhere
		groq_config = get_node_or_null("/root/GroqConfig") as GroqConfig
	
	if not groq_config:
		print("[GroqNPCAI] ERROR: GroqConfig not found! Make sure GroqConfig.tscn is added as an autoload in Project Settings.")
	else:
		print("[GroqNPCAI] ", npc_name, " connected to GroqConfig. Model: ", groq_config.model_name)

# Call this function when the player talks to the NPC!
func talk_to_npc(player_message: String) -> void:
	# Check shared config first
	if groq_config and groq_config.is_key_valid():
		_do_groq_request(player_message)
		return
	
	# Fallback: check local export (for backward compat)
	if has_meta("groq_api_key_override"):
		var override_key: String = get_meta("groq_api_key_override")
		if not (override_key.is_empty() or override_key == "YOUR_GROQ_API_KEY_HERE"):
			_do_groq_request(player_message, override_key)
			return
	
	# No valid key found anywhere
	var msg := "⚠️ Set your Groq API Key!\n\n1. Go to Project > Project Settings > Autoload\n2. Select 'GroqConfig' node in the scene tree\n3. Paste your API key in the Inspector under 'Groq Api Key'\n\nOne key works for ALL NPCs!"
	emit_signal("request_failed", msg)
	print("ERROR: Missing Groq API Key for ", npc_name)

func _do_groq_request(player_message: String, api_key_override: String = "") -> void:
	var api_key: String = ""
	
	if not api_key_override.is_empty():
		api_key = api_key_override
	elif groq_config:
		api_key = groq_config.groq_api_key.strip_edges()
	
	var model = "llama-3.3-70b-versatile"
	if groq_config:
		model = groq_config.model_name
	
	var url := "https://api.groq.com/openai/v1/chat/completions"
	var headers := [\
		"Content-Type: application/json",\
		"Authorization: Bearer " + api_key\
	]
	
	var body := {
		"model": model,
		"messages": [\
			{"role": "system", "content": npc_persona},\
			{"role": "user", "content": player_message}\
		],
		"temperature": 0.7,
		"max_tokens": 150
	}
	
	var json_body := JSON.stringify(body)
	var error := http_request.request(url, headers, HTTPClient.METHOD_POST, json_body)
	
	if error != OK:
		emit_signal("request_failed", "HTTP Request failed to send.")
		print("ERROR: Failed to send request to Groq API.")

func _on_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code != 200:
		var raw_body := body.get_string_from_utf8()
		var error_msg := "HTTP " + str(response_code)
		
		# Parse exact error message from Groq
		var json := JSON.new()
		if json.parse(raw_body) == OK:
			var data: Dictionary = json.get_data()
			if data.has("error") and data["error"].has("message"):
				error_msg += ": " + str(data["error"]["message"])
			else:
				error_msg += ": " + raw_body
		else:
			error_msg += ": " + raw_body
		
		emit_signal("request_failed", error_msg)
		print("Groq API Error for ", npc_name, ": ", error_msg)
		return
	
	var json := JSON.new()
	var parse_err := json.parse(body.get_string_from_utf8())
	if parse_err == OK:
		var response_data: Dictionary = json.get_data()
		if response_data.has("choices") and response_data["choices"].size() > 0:
			var reply: String = response_data["choices"][0]["message"]["content"]
			emit_signal("response_received", npc_name, reply)
			print("[", npc_name, "]: ", reply)
		else:
			emit_signal("request_failed", "Invalid response structure from Groq.")
	else:
		emit_signal("request_failed", "Failed to parse JSON response.")
