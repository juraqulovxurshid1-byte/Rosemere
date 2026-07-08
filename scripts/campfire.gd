extends Node3D

class_name Campfire

@onready var light: OmniLight3D = $OmniLight3D
@onready var heal_area: Area3D = $HealArea

func _ready() -> void:
	if heal_area:
		heal_area.monitoring = true

func _physics_process(delta: float) -> void:
	# Flicker light realistically with sine wave crackling
	if light:
		light.light_energy = 2.4 + sin(Time.get_ticks_msec() * 0.012) * 0.5
		
	# Heal nearby player when they rest at the fire
	if heal_area:
		for body in heal_area.get_overlapping_bodies():
			if body is PlayerController and body.current_health < body.max_health:
				body.take_healing(25.0 * delta)
