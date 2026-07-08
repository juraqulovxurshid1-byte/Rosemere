extends Node

@export var shadow_strength: float = 0.4
@export var shadow_size_mult: float = 1.0
@export var enable_shadows: bool = true
@export var enable_pivot_fix: bool = true

func _ready() -> void:
	# DISABLED for debugging - no grounding/pivot fix applied
	pass
