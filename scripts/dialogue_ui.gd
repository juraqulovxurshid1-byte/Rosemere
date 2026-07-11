extends CanvasLayer

class_name DialogueUI

@onready var panel: Panel = $Control/Panel
@onready var npc_name_label: Label = $Control/Panel/VBoxContainer/NPCNameLabel
@onready var chat_history: RichTextLabel = $Control/Panel/VBoxContainer/ChatHistory
@onready var input_field: LineEdit = $Control/Panel/VBoxContainer/HBoxContainer/InputField
@onready var send_button: Button = $Control/Panel/VBoxContainer/HBoxContainer/SendButton

# Shop & Leave Buttons
@onready var shop_container: HBoxContainer = $Control/Panel/VBoxContainer/ShopContainer
@onready var buy_sword_btn: Button = $Control/Panel/VBoxContainer/ShopContainer/BuySwordBtn
@onready var buy_axe_btn: Button = $Control/Panel/VBoxContainer/ShopContainer/BuyAxeBtn
@onready var buy_potion_btn: Button = $Control/Panel/VBoxContainer/ShopContainer/BuyPotionBtn
@onready var claim_reward_btn: Button = $Control/Panel/VBoxContainer/ShopContainer/ClaimRewardBtn
@onready var leave_btn: Button = $Control/Panel/VBoxContainer/ShopContainer/LeaveBtn

# Voice System
@onready var voice_container: HBoxContainer = $Control/Panel/VBoxContainer/VoiceContainer
@onready var generate_voice_btn: Button = $Control/Panel/VBoxContainer/VoiceContainer/GenerateVoiceBtn
@onready var voice_status_label: Label = $Control/Panel/VBoxContainer/VoiceContainer/VoiceStatusLabel

var active_npc: GroqNPCAI = null
var is_open: bool = false
var player: PlayerController = null

# Voice queue - only NPC lines get queued (player text has no voice)
var voice_queue: Array = []
var is_speaking: bool = false
var typewriter_timer: float = 0.0
var current_speaking_text: String = ""
var current_speaking_displayed: int = 0
var speaking_char_delay: float = 0.025  # 25ms per character - faster for Elora

# Sound manager reference for playing voices
var sound_manager: Node = null

func _ready() -> void:
	panel.visible = false
	
	# Find sound manager
	sound_manager = get_tree().root.find_child("SoundManager", true, false)
	
	if send_button:
		send_button.pressed.connect(_on_send_pressed)
	if input_field:
		input_field.text_submitted.connect(_on_input_submitted)
	if leave_btn:
		leave_btn.pressed.connect(close_dialogue)
	if buy_sword_btn:
		buy_sword_btn.pressed.connect(_on_buy_sword)
	if buy_axe_btn:
		buy_axe_btn.pressed.connect(_on_buy_axe)
	if buy_potion_btn:
		buy_potion_btn.pressed.connect(_on_buy_potion)
	if claim_reward_btn:
		claim_reward_btn.pressed.connect(_on_claim_reward)
	if generate_voice_btn:
		generate_voice_btn.pressed.connect(_on_generate_voice_pressed)
	
	if voice_container:
		voice_container.visible = false
	if voice_status_label:
		voice_status_label.text = ""

func _input(event: InputEvent) -> void:
	if is_open and event.is_action_pressed("ui_cancel"):
		close_dialogue()
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if is_speaking and current_speaking_text.length() > 0:
		typewriter_timer += delta
		
		# Elora speaks faster, Gareth slower
		var char_delay := speaking_char_delay
		if active_npc and active_npc.npc_name.contains("Elora"):
			char_delay = 0.018  # Faster for woman
		else:
			char_delay = 0.035  # Slower for old man
		
		if typewriter_timer >= char_delay:
			typewriter_timer = 0.0
			current_speaking_displayed += 1
			
			var lines = chat_history.text.split("\n")
			if lines.size() >= 1:
				var new_lines: Array = []
				for i in range(lines.size() - 1):
					new_lines.append(lines[i])
				
				var displayed = current_speaking_text.substr(0, current_speaking_displayed)
				new_lines.append("[color=#aaaaaa][i]" + displayed + "[/i][/color]")
				
				chat_history.text = "\n".join(new_lines)
				chat_history.scroll_to_line(chat_history.get_line_count() - 1)
			
			if current_speaking_displayed >= current_speaking_text.length():
				_finish_speaking()

func open_dialogue(npc: GroqNPCAI) -> void:
	if is_open:
		return
		
	active_npc = npc
	is_open = true
	panel.visible = true
	player = get_tree().root.find_child("Player", true, false) as PlayerController
	
	if player and player.has_method("stop_voice"):
		player.stop_voice()
	
	npc_name_label.text = npc.npc_name
	
	# Clear voice queue when opening new dialogue
	voice_queue.clear()
	if voice_container:
		voice_container.visible = false
	
	var is_smith := (npc.npc_name.contains("Gareth") or npc.npc_name.contains("Blacksmith"))
	var is_inn := (npc.npc_name.contains("Elora") or npc.npc_name.contains("Innkeeper"))
	
	# SHORT, CONCISE greetings - Gareth gruff, Elora quick
	var greeting_text: String
	var greeting_voice_key: String
	if is_smith:
		greeting_text = "Forge's busy. What d'ye want?"
		greeting_voice_key = "greeting"
	else:
		greeting_text = "Shelter or elixir?"
		greeting_voice_key = "welcome"
	
	chat_history.text = "[color=#f3ad43][b]" + npc.npc_name + ":[/b][/color] " + greeting_text + "\n"
	
	# Queue NPC greeting for voice (NOT player)
	_add_to_voice_queue(greeting_text, "npc", greeting_voice_key)
	
	# Play greeting voice immediately
	_play_npc_voice(greeting_voice_key, is_smith)
	
	if shop_container:
		shop_container.visible = (is_smith or is_inn)
		if buy_sword_btn: buy_sword_btn.visible = is_smith
		if buy_axe_btn: buy_axe_btn.visible = is_smith
		if buy_potion_btn: buy_potion_btn.visible = is_inn
		if claim_reward_btn and player:
			claim_reward_btn.visible = (is_smith and player.quest_completed and player.bandits_slain >= player.quest_target)
	
	if not npc.response_received.is_connected(_on_npc_response):
		npc.response_received.connect(_on_npc_response)
	if not npc.request_failed.is_connected(_on_npc_error):
		npc.request_failed.connect(_on_npc_error)
		
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	input_field.clear()
	input_field.grab_focus()

func close_dialogue() -> void:
	if not is_open:
		return
	is_open = false
	is_speaking = false
	panel.visible = false
	if player and player.has_method("stop_voice"):
		player.stop_voice()
	# Also stop via sound manager
	if sound_manager and sound_manager.has_method("stop_voice"):
		sound_manager.stop_voice()
	if active_npc:
		if active_npc.response_received.is_connected(_on_npc_response):
			active_npc.response_received.disconnect(_on_npc_response)
		if active_npc.request_failed.is_connected(_on_npc_error):
			active_npc.request_failed.disconnect(_on_npc_error)
		active_npc = null
		
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _add_to_voice_queue(text: String, speaker: String, voice_key: String = "") -> void:
	# Only queue NPC lines - player has no voice
	if speaker != "npc":
		return
	
	var is_duplicate := false
	for item in voice_queue:
		if item["text"] == text:
			is_duplicate = true
			break
	if not is_duplicate:
		voice_queue.append({"text": text, "speaker": speaker, "key": voice_key})
		_update_voice_button()

func _update_voice_button() -> void:
	if voice_container:
		voice_container.visible = (voice_queue.size() > 0)
	if voice_status_label:
		voice_status_label.text = "📢 " + str(voice_queue.size()) + " NPC lines"

func _play_npc_voice(voice_key: String, is_smith: bool) -> void:
	if not sound_manager:
		return
	
	var filename := ""
	if is_smith:
		match voice_key:
			"greeting": filename = "voice_gareth_greeting.mp3"
			"sword": filename = "voice_gareth_sword.mp3"
			"axe": filename = "voice_gareth_axe.mp3"
			"reward": filename = "voice_gareth_reward.mp3"
			_: filename = "voice_gareth_greeting.mp3"
	else:
		match voice_key:
			"welcome": filename = "voice_elora_welcome.mp3"
			"greeting": filename = "voice_elora_greeting.mp3"
			"potion": filename = "voice_elora_potion.mp3"
			_: filename = "voice_elora_greeting.mp3"
	
	if not filename.is_empty():
		sound_manager.play_conversation_voice(filename)

func _on_buy_sword() -> void:
	if not player:
		return
	if player.gold_coins >= 30:
		if player.has_method("add_gold"):
			player.add_gold(-30)
		if player.has_method("equip_weapon"):
			player.equip_weapon("Silver Sword", 40.0, Color(0.75, 0.9, 1.0, 1))
		chat_history.append_text("\n[color=#f3ad43][b]Gareth:[/b][/color] Silver sword. Good steel. 30 coins.\n")
		_add_to_voice_queue("Silver sword. Good steel. 30 coins.", "npc", "sword")
		_play_npc_voice("sword", true)
	else:
		chat_history.append_text("\n[color=#ff5555][b]Gareth:[/b][/color] No coin. No sword. Simple.\n")

func _on_buy_axe() -> void:
	if not player:
		return
	if player.gold_coins >= 60:
		if player.has_method("add_gold"):
			player.add_gold(-60)
		if player.has_method("equip_weapon"):
			player.equip_weapon("Dwarven Battleaxe", 70.0, Color(1.0, 0.55, 0.2, 1))
		chat_history.append_text("\n[color=#f3ad43][b]Gareth:[/b][/color] Battleaxe. Heavy. 60 coins. Worth it.\n")
		_add_to_voice_queue("Battleaxe. Heavy. 60 coins. Worth it.", "npc", "axe")
		_play_npc_voice("axe", true)
	else:
		chat_history.append_text("\n[color=#ff5555][b]Gareth:[/b][/color] Axe costs 60. Hunt first.\n")

func _on_buy_potion() -> void:
	if not player:
		return
	if player.gold_coins >= 20:
		if player.has_method("add_gold"):
			player.add_gold(-20)
		if player.has_method("take_healing"):
			player.take_healing(50.0)
		chat_history.append_text("\n[color=#33ff66][b]Elora:[/b][/color] Healing elixir. 20 coins. Drink now.\n")
		_add_to_voice_queue("Healing elixir. 20 coins. Drink now.", "npc", "potion")
		_play_npc_voice("potion", false)
	else:
		chat_history.append_text("\n[color=#ff5555][b]Elora:[/b][/color] 20 coins needed. Got any gold?\n")

func _on_claim_reward() -> void:
	if not player:
		return
	if player.has_method("add_gold"):
		player.add_gold(50)
	if player.has_method("level_up"):
		player.level_up()
	if claim_reward_btn:
		claim_reward_btn.visible = false
	chat_history.append_text("\n[color=#33ff66][b]Gareth:[/b][/color] Ye cleared the road. Here's yer bounty. Well done.\n")
	_add_to_voice_queue("Ye cleared the road. Here's yer bounty. Well done.", "npc", "reward")
	_play_npc_voice("reward", true)

func _on_send_pressed() -> void:
	_send_message(input_field.text)

func _on_input_submitted(text: String) -> void:
	_send_message(text)

func _send_message(text: String) -> void:
	var clean_text := text.strip_edges()
	if clean_text.is_empty() or not active_npc:
		return
		
	chat_history.append_text("\n[color=#6bb3f2][b]You:[/b][/color] " + clean_text + "\n")
	
	# NO voice for player - only text!
	
	chat_history.append_text("[color=#888888][i]" + active_npc.npc_name + " is pondering...[/i][/color]\n")
	
	input_field.clear()
	input_field.editable = false
	send_button.disabled = true
	
	active_npc.talk_to_npc(clean_text)

func _on_npc_response(npc_name: String, reply_text: String) -> void:
	input_field.editable = true
	send_button.disabled = false
	input_field.grab_focus()
	
	# Replace "pondering" line with actual response
	var current_text = chat_history.text
	var pondering_marker = "[color=#888888][i]" + npc_name + " is pondering...[/i][/color]"
	chat_history.text = current_text.replace(pondering_marker, "")
	
	# Start typewriter effect
	_start_typewriter(npc_name, reply_text)
	
	# Queue NPC's response for voice generation (NOT player)
	_add_to_voice_queue(reply_text, "npc", "response")

func _start_typewriter(npc_name: String, full_text: String) -> void:
	chat_history.append_text("\n[color=#f3ad43][b]" + npc_name + ":[/b][/color] [color=#aaaaaa][i]...[/i][/color]\n")
	
	is_speaking = true
	current_speaking_text = full_text
	current_speaking_displayed = 0
	typewriter_timer = 0.0

func _finish_speaking() -> void:
	is_speaking = false
	
	var lines = chat_history.text.split("\n")
	if lines.size() >= 2:
		var new_lines: Array = []
		for i in range(lines.size() - 2):
			new_lines.append(lines[i])
		
		var speaker_label = "Gareth"
		if active_npc and active_npc.npc_name.contains("Elora"):
			speaker_label = "Elora"
		
		new_lines.append("[color=#f3ad43][b]" + speaker_label + ":[/b][/color] " + current_speaking_text)
		
		chat_history.text = "\n".join(new_lines)
		chat_history.scroll_to_line(chat_history.get_line_count() - 1)
	
	current_speaking_text = ""
	current_speaking_displayed = 0

func _on_npc_error(error_msg: String) -> void:
	input_field.editable = true
	send_button.disabled = false
	if active_npc:
		var current_text = chat_history.text
		var pondering_marker = "[color=#888888][i]" + active_npc.npc_name + " is pondering...[/i][/color]"
		chat_history.text = current_text.replace(pondering_marker, "")
	chat_history.append_text("\n[color=#ff5555][b]System Error:[/b][/color] " + error_msg + "\n")

func _on_generate_voice_pressed() -> void:
	if voice_queue.size() == 0:
		chat_history.append_text("\n[color=#888888][i]No NPC lines to voice yet. Talk to them first![/i][/color]\n")
		return
	
	# Show NPC lines only
	chat_history.append_text("\n[color=#ffaa00][b]🎤 NPC VOICE QUEUE:[/b][/color]\n")
	chat_history.append_text("[color=#aaaaaa]Say \"Generate my NPC conversation voices\" and I'll create the audio!\n[/color]")
	chat_history.append_text("\n[color=#888888]📋 NPC Lines (" + str(voice_queue.size()) + "):[/color]\n")
	
	for i in range(min(10, voice_queue.size())):
		var item = voice_queue[i]
		var speaker_label = "🔨 Gareth"
		if active_npc and active_npc.npc_name.contains("Elora"):
			speaker_label = "🏠 Elora"
		
		var preview = item["text"].substr(0, 60)
		if item["text"].length() > 60:
			preview += "..."
		
		chat_history.append_text("[color=#888888]  " + str(i + 1) + ". " + speaker_label + ": \"" + preview + "\"[/color]\n")
	
	if voice_queue.size() > 10:
		chat_history.append_text("[color=#888888]  ... and " + str(voice_queue.size() - 10) + " more[/color]\n")
	
	chat_history.append_text("\n[color=#66ddff]💡 Player text has no voice - only NPCs speak![/color]\n")