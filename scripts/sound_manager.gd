extends Node

class_name SoundManager

@onready var player_sfx: AudioStreamPlayer = AudioStreamPlayer.new()
@onready var player_voice: AudioStreamPlayer = AudioStreamPlayer.new()

var stream_slash: AudioStream = null
var stream_coin: AudioStream = null
var stream_igni: AudioStream = null
var stream_quen: AudioStream = null
var stream_fanfare: AudioStream = null

var voice_gareth: AudioStream = null
var voice_elora: AudioStream = null
var voice_levelup: AudioStream = null

# Dynamic conversation voices - loaded from generated files
var conversation_voices: Dictionary = {}
var current_conversation_speaker: String = ""

func _ready() -> void:
	add_child(player_sfx)
	add_child(player_voice)
	
	if ResourceLoader.exists("res://audio/slash.wav"):
		stream_slash = load("res://audio/slash.wav") as AudioStream
	if ResourceLoader.exists("res://audio/coin.wav"):
		stream_coin = load("res://audio/coin.wav") as AudioStream
	if ResourceLoader.exists("res://audio/igni.wav"):
		stream_igni = load("res://audio/igni.wav") as AudioStream
	if ResourceLoader.exists("res://audio/quen.wav"):
		stream_quen = load("res://audio/quen.wav") as AudioStream
	if ResourceLoader.exists("res://audio/fanfare.wav"):
		stream_fanfare = load("res://audio/fanfare.wav") as AudioStream
		
	if ResourceLoader.exists("res://audio/gareth_greet.mp3"):
		voice_gareth = load("res://audio/gareth_greet.mp3") as AudioStream
	if ResourceLoader.exists("res://audio/elora_greet.mp3"):
		voice_elora = load("res://audio/elora_greet.mp3") as AudioStream
	if ResourceLoader.exists("res://audio/level_up.mp3"):
		voice_levelup = load("res://audio/level_up.mp3") as AudioStream
	
	# Scan for conversation voice files
	_scan_conversation_voices()

func _scan_conversation_voices() -> void:
	var dir = DirAccess.open("res://audio/")
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.begins_with("voice_") and file_name.ends_with(".mp3"):
				var full_path = "res://audio/" + file_name
				if ResourceLoader.exists(full_path):
					var voice_stream = load(full_path) as AudioStream
					if voice_stream:
						conversation_voices[file_name] = voice_stream
						print("[SoundManager] Loaded conversation voice: ", file_name)
			file_name = dir.get_next()
		dir.list_dir_end()

func _play_sfx(stream: AudioStream, pitch_variance: float = 0.1) -> void:
	if stream and player_sfx:
		player_sfx.stream = stream
		player_sfx.pitch_scale = randf_range(1.0 - pitch_variance, 1.0 + pitch_variance)
		player_sfx.play()

func play_slash() -> void:
	_play_sfx(stream_slash, 0.15)

func play_coin() -> void:
	_play_sfx(stream_coin, 0.05)

func play_igni() -> void:
	_play_sfx(stream_igni, 0.1)

func play_quen() -> void:
	_play_sfx(stream_quen, 0.05)

func play_fanfare() -> void:
	_play_sfx(stream_fanfare, 0.0)

func play_voice(npc_name: String) -> void:
	if not player_voice:
		return
	stop_voice()
	
	if npc_name.contains("Gareth") and voice_gareth:
		player_voice.stream = voice_gareth
		current_conversation_speaker = "gareth"
		player_voice.play()
	elif npc_name.contains("Elora") and voice_elora:
		player_voice.stream = voice_elora
		current_conversation_speaker = "elora"
		player_voice.play()
	elif npc_name.contains("Level") and voice_levelup:
		player_voice.stream = voice_levelup
		player_voice.play()

func play_conversation_voice(filename: String) -> void:
	if not player_voice:
		return
	
	if conversation_voices.has(filename):
		stop_voice()
		player_voice.stream = conversation_voices[filename]
		player_voice.play()
		return
	
	var full_path = "res://audio/" + filename
	if ResourceLoader.exists(full_path):
		var voice_stream = load(full_path) as AudioStream
		if voice_stream:
			conversation_voices[filename] = voice_stream
			stop_voice()
			player_voice.stream = voice_stream
			player_voice.play()

func _hash_string(s: String) -> String:
	# Simple hash for filename matching - just use length + first 4 chars
	var result = str(s.length()) + "_"
	for i in range(min(4, s.length())):
		result += str(ord(s[i]))
	return result

func play_voice_for_text(text: String, speaker: String) -> bool:
	# Try exact hash match first
	var text_hash = _hash_string(text)
	var filename = "voice_" + speaker + "_" + text_hash + ".mp3"
	
	if conversation_voices.has(filename):
		play_conversation_voice(filename)
		return true
	
	# Try shorter patterns
	filename = "voice_" + speaker + "_" + str(text.length()) + ".mp3"
	if conversation_voices.has(filename):
		play_conversation_voice(filename)
		return true
	
	return false

func stop_voice() -> void:
	if player_voice and player_voice.playing:
		player_voice.stop()
	current_conversation_speaker = ""

func get_available_voices() -> Array:
	return conversation_voices.keys()