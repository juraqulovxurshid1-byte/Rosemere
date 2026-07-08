extends CharacterBody3D

class_name EnemyAI

@export var enemy_name: String = "Forest Bandit"
@export var max_health: float = 75.0
@export var move_speed: float = 3.5
@export var aggro_radius: float = 10.0
@export var attack_range: float = 1.5
@export var attack_damage: float = 10.0

@onready var sprite: Sprite3D = $Sprite3D
@onready var aggro_area: Area3D = $AggroArea

var current_health: float = max_health
var target_player: Node3D = null
var gravity: float = 9.8
var is_dead: bool = false
var attack_cooldown: float = 0.0

func _ready() -> void:
	current_health = max_health
	if aggro_area:
		aggro_area.body_entered.connect(_on_body_entered_aggro)
		aggro_area.body_exited.connect(_on_body_exited_aggro)

func _physics_process(delta: float) -> void:
	if is_dead:
		return
		
	if attack_cooldown > 0:
		attack_cooldown -= delta
		
	if not is_on_floor():
		velocity.y -= gravity * delta

	if target_player:
		var dir_to_player := target_player.global_position - global_position
		dir_to_player.y = 0.0
		var dist := dir_to_player.length()
		
		if dist > attack_range:
			dir_to_player = dir_to_player.normalized()
			velocity.x = dir_to_player.x * move_speed
			velocity.z = dir_to_player.z * move_speed
			
			if sprite:
				if velocity.x > 0.1:
					sprite.flip_h = false
				elif velocity.x < -0.1:
					sprite.flip_h = true
		else:
			velocity.x = 0
			velocity.z = 0
			if attack_cooldown <= 0 and target_player.has_method("take_damage"):
				attack_player()
	else:
		velocity.x = move_toward(velocity.x, 0, move_speed * delta)
		velocity.z = move_toward(velocity.z, 0, move_speed * delta)

	move_and_slide()

func attack_player() -> void:
	if not target_player or is_dead:
		return
		
	print("[", enemy_name, "] swings their weapon at the player!")
	target_player.take_damage(attack_damage)
	attack_cooldown = 1.5
	
	if sprite:
		var tween := create_tween()
		tween.tween_property(sprite, "scale", Vector3(1.3, 1.3, 1.3), 0.15)
		tween.tween_property(sprite, "scale", Vector3(1.0, 1.0, 1.0), 0.15)

func take_damage(amount: float) -> void:
	if is_dead:
		return
		
	current_health -= amount
	print("[", enemy_name, "] took ", amount, " damage! HP remaining: ", current_health)
	
	if sprite:
		var tween := create_tween()
		tween.tween_property(sprite, "modulate", Color(1, 0, 0, 1), 0.1)
		tween.tween_property(sprite, "modulate", Color(0.9, 0.3, 0.3, 1), 0.1)
		
	if current_health <= 0:
		die()

func die() -> void:
	is_dead = true
	print("[", enemy_name, "] has been slain!")
	
	var player := get_tree().root.find_child("Player", true, false) as PlayerController
	if player:
		if player.has_method("add_gold"):
			player.add_gold(15)
		if player.has_method("on_bandit_slain"):
			player.on_bandit_slain()
	
	if sprite:
		var tween := create_tween()
		tween.tween_property(sprite, "rotation:z", deg_to_rad(90), 0.4)
		tween.parallel().tween_property(sprite, "modulate:a", 0.0, 0.8)
		tween.tween_callback(queue_free)

func _on_body_entered_aggro(body: Node3D) -> void:
	if body is PlayerController and not is_dead:
		target_player = body
		print("[", enemy_name, "] spotted the player! Charging!")

func _on_body_exited_aggro(body: Node3D) -> void:
	if body == target_player:
		target_player = null
		print("[", enemy_name, "] lost sight of the player.")
