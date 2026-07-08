extends Node

class_name GroqConfig

# --- SHARED GROQ API KEY ---
# Set this ONCE and all NPCs will use it.
@export var groq_api_key: String = "YOUR_GROQ_API_KEY_HERE"
@export var model_name: String = "llama-3.3-70b-versatile"

func _ready() -> void:
    # Auto-upgrade legacy model IDs
    if model_name == "llama3-70b-8192" or model_name.is_empty():
        model_name = "llama-3.3-70b-versatile"
    
    print("[GroqConfig] Loaded. Model: ", model_name)

func is_key_valid() -> bool:
    return not (groq_api_key == "YOUR_GROQ_API_KEY_HERE" or groq_api_key.is_empty())
