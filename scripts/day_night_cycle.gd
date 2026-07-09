extends DirectionalLight3D

class_name DayNightCycle

@export var time_speed: float = 2.0
var time_of_day_str: String = "☁️ Overcast Noon"

func _physics_process(delta: float) -> void:
	rotate_x(deg_to_rad(-time_speed * delta))
	
	var angle := rad_to_deg(rotation.x)
	while angle > 180.0: angle -= 360.0
	while angle < -180.0: angle += 360.0
	
	var t := (angle + 90.0) / 180.0
	t = clamp(t, 0.0, 1.0)
	var day_t := sin(t * PI)
	
	# Grimdark overcast cycle: dim/cold at dawn and evening, brighter neutral at noon
	light_energy = lerp(0.35, 1.25, day_t)
	
	# Cool blue-gray low light into pale neutral overcast noon light
	var cold_tint := Color(0.52, 0.60, 0.74, 1)
	var noon_tint := Color(0.82, 0.82, 0.78, 1)
	light_color = cold_tint.lerp(noon_tint, day_t)
	
	if angle > -45.0 and angle <= 45.0:
		time_of_day_str = "☁️ Bleak Noon"
	elif angle > -90.0 and angle <= -45.0:
		time_of_day_str = "☁️ Grey Afternoon"
	elif angle > -135.0 and angle <= -90.0:
		time_of_day_str = "☁️ Sullen Evening"
	else:
		time_of_day_str = "☁️ Cold Dawn"

	var hud := get_tree().root.find_child("HUD", true, false) as HUD
	if hud and hud.has_method("update_time"):
		hud.update_time(time_of_day_str)
