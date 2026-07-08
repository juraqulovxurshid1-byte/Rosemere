extends CharacterBody3D

class_name VillagerAI

# --- VILLAGER SETTINGS ---
@export var villager_name: String = "Peasant"
@export var wander_radius: float = 10.0          # How far from home they wander
@export var move_speed: float = 2.0
@export var pause_min: float = 2.0                # Min idle time at waypoint
@export var pause_max: float = 5.0                # Max idle time at waypoint
@export var dialogue_color: Color = Color(0.8, 0.9, 1.0, 1)  # Speech bubble color

@export_multiline var dialogue_lines: Array[String] = [
	"Good day, traveler.",
	"The forge is that way.",
	"Watch out for bandits on the north road."
]

# --- NODE REFERENCES ---
@onready var sprite: Sprite3D = $Sprite3D
@onready var nameplate: Label3D = $Nameplate
@onready var interact_area: Area3D = $InteractArea

# --- STATE ---
var home_position: Vector3
var target_position: Vector3
var is_idle: bool = true
var idle_timer: float = 0.0
var is_talking: bool = false
var gravity: float = 9.8
var dialogue_index: int = 0
var last_interact_time: float = 0.0
var player_ref: Node3D = null

func _ready() -> void:
	home_position = global_position
	_pick_new_target()
	_pick_new_idle_time()
	
	if nameplate:
		nameplate.text = "🧑 " + villager_name
		nameplate.modulate = Color(0.9, 0.95, 1.0, 1)
	
	if interact_area:
		interact_area.body_entered.connect(_on_body_entered)
		interact_area.body_exited.connect(_on_body_exited)
	
	print("[Villager] ", villager_name, " ready at ", home_position)

func _physics_process(delta: float) -> void:
	if is_talking:
		velocity.x = move_toward(velocity.x, 0, move_speed * delta)
		velocity.z = move_toward(velocity.z, 0, move_speed * delta)
		move_and_slide()
		return
	
	if not is_on_floor():
		velocity.y -= gravity * delta
	
	# IDLE state
	if is_idle:
		idle_timer -= delta
		if idle_timer <= 0.0:
			is_idle = false
			_pick_new_target()
		
		velocity.x = move_toward(velocity.x, 0, move_speed * delta)
		velocity.z = move_toward(velocity.z, 0, move_speed * delta)
	
	# WALK state
	else:
		var dir_to_target := target_position - global_position
		dir_to_target.y = 0.0
		var dist := dir_to_target.length()
		
		if dist > 0.5:
			dir_to_target = dir_to_target.normalized()
			velocity.x = dir_to_target.x * move_speed
			velocity.z = dir_to_target.z * move_speed
			
			# Flip sprite based on movement direction
			if sprite:
				if velocity.x > 0.1:
					sprite.flip_h = false
				elif velocity.x < -0.1:
					sprite.flip_h = true
		else:
			# Arrived at target
			velocity.x = 0
			velocity.z = 0
			is_idle = true
			_pick_new_idle_time()
	
	move_and_slide()

func _pick_new_target() -> void:
	var rand_angle := randf_range(0.0, TAU)
	var rand_dist := randf_range(2.0, wander_radius)
	target_position = home_position + Vector3(
		cos(rand_angle) * rand_dist,
		0.0,
		sin(rand_angle) * rand_dist
	)

func _pick_new_idle_time() -> void:
	idle_timer = randf_range(pause_min, pause_max)

# --- INTERACTION ---
func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player") or body is PlayerController:
		player_ref = body
		# Show a floating hint
		if nameplate:
			nameplate.text = "🧑 " + villager_name + "\n[Press E]"

func _on_body_exited(body: Node3D) -> void:
	if body == player_ref:
		player_ref = null
		if nameplate:
			nameplate.text = "🧑 " + villager_name

# Called by player_controller when player presses E near this villager
func interact() -> void:
	if is_talking:
		return
	
	var now := Time.get_ticks_msec() / 1000.0
	if now - last_interact_time < 1.5:
		return  # Cooldown
	
	last_interact_time = now
	is_talking = true
	
	# Cycle through dialogue lines
	var line := dialogue_lines[dialogue_index % dialogue_lines.size()]
	dialogue_index += 1
	
	print("[Villager] ", villager_name, ": ", line)
	
	# Show speech bubble via HUD notification
	var hud := get_tree().root.find_child("HUD", true, false)
	if hud and hud.has_method("show_notification"):
		hud.show_notification("🧑 " + villager_name + ": \"" + line + "\"", dialogue_color)
	
	# Stop for a moment, then resume wandering
	await get_tree().create_timer(2.0).timeout
	is_talking = false
