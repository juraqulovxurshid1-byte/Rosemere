extends CharacterBody3D

class_name NorthRoadBandit

## First Bandit pass: fast approach and wider awareness, with idle/walk only.
## Attack, hurt, and death animations will be added from their own sheets later.
@export var enemy_name: String = "North Road Bandit"
@export var max_health: float = 80.0
@export var move_speed: float = 5.5
@export var stop_distance: float = 2.2
@export var attack_range: float = 2.8
@export var attack_damage: float = 30.0
@export var attack_cooldown_time: float = 0.10

@onready var sprite: Sprite3D = $Sprite3D
@onready var aggro_area: Area3D = $AggroArea
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

const IDLE_SHEET_PATH := "res://art_v2/north_road_bandit_idle_sheet.png"
const WALK_SHEET_PATH := "res://art_v2/north_road_bandit_walk_sheet.png"
const ATTACK_SHEET_PATH := "res://art_v2/north_road_bandit_attack_sheet.png"
const HURT_SHEET_PATH := "res://art_v2/north_road_bandit_hurt_sheet.png"
const ROLL_SHEET_PATH := "res://art_v2/north_road_bandit_roll_sheet.png"
const DEATH_SHEET_PATH := "res://art_v2/north_road_bandit_death_sheet.png"
const IDLE_FPS := 6.0
const WALK_FPS := 8.0
const ATTACK_FPS := 12.0
const IDLE_PIXEL_SIZE := 0.016
const WALK_PIXEL_SIZE := 0.018
const IDLE_FRAME_SIZE := Vector2i(360, 540)
const IDLE_FRAME_COUNT := 6
const WALK_FRAME_SIZE := Vector2i(440, 440)
const WALK_FRAME_COUNT := 6
const ATTACK_PIXEL_SIZE := 0.019
const ATTACK_FRAME_SIZE := Vector2i(440, 440)
const ATTACK_FRAME_COUNT := 8
const ATTACK_HIT_FRAME := 3
const HURT_FPS := 8.0
const HURT_PIXEL_SIZE := 0.015
const HURT_FRAME_SIZE := Vector2i(560, 580)
const HURT_FRAME_COUNT := 4
const ROLL_FPS := 12.0
const ROLL_PIXEL_SIZE := 0.016
const ROLL_FRAME_SIZE := Vector2i(520, 520)
const ROLL_FRAME_COUNT := 6
const ROLL_SPEED := 10.0
const ROLL_COOLDOWN_TIME := 0.8
const DEATH_FPS := 6.0
const DEATH_PIXEL_SIZE := 0.0197
const DEATH_FRAME_SIZE := Vector2i(500, 430)
const DEATH_FRAME_COUNT := 4
const AGGRO_RADIUS := 22.0

var idle_texture: Texture2D = null
var walk_texture: Texture2D = null
var attack_texture: Texture2D = null
var hurt_texture: Texture2D = null
var roll_texture: Texture2D = null
var death_texture: Texture2D = null
var idle_frame: int = 0
var idle_timer: float = 0.0
var walk_frame: int = 0
var walk_timer: float = 0.0
var attack_frame: int = 0
var attack_timer: float = 0.0
var attack_cooldown: float = 0.0
var is_attacking: bool = false
var attack_has_hit: bool = false
var hurt_frame: int = 0
var hurt_timer: float = 0.0
var is_hurt: bool = false
var roll_frame: int = 0
var roll_timer: float = 0.0
var roll_cooldown: float = 0.0
var roll_direction: Vector3 = Vector3.ZERO
var is_rolling: bool = false
var death_frame: int = 0
var death_timer: float = 0.0
var is_dying: bool = false
var current_health: float = 0.0
var target_player: Node3D = null
var gravity: float = 9.8
var is_dead: bool = false

func _ready() -> void:
	current_health = max_health
	idle_texture = load(IDLE_SHEET_PATH) as Texture2D
	walk_texture = load(WALK_SHEET_PATH) as Texture2D
	attack_texture = load(ATTACK_SHEET_PATH) as Texture2D
	hurt_texture = load(HURT_SHEET_PATH) as Texture2D
	roll_texture = load(ROLL_SHEET_PATH) as Texture2D
	death_texture = load(DEATH_SHEET_PATH) as Texture2D
	if idle_texture:
		sprite.texture = idle_texture
		sprite.region_enabled = true
		sprite.pixel_size = IDLE_PIXEL_SIZE
		sprite.position = Vector3(0.0, 4.32, 0.0)
		_apply_idle_frame(0)
	else:
		push_error("[North Road Bandit] Missing idle sheet: " + IDLE_SHEET_PATH)

	if aggro_area:
		aggro_area.monitoring = true
		aggro_area.monitorable = true
		aggro_area.body_entered.connect(_on_body_entered_aggro)
		aggro_area.body_exited.connect(_on_body_exited_aggro)

func _physics_process(delta: float) -> void:
	if is_dying:
		_update_death_animation(delta)
		return
	if is_dead:
		return
	if attack_cooldown > 0.0:
		attack_cooldown -= delta
	if roll_cooldown > 0.0:
		roll_cooldown -= delta
	if not is_on_floor():
		velocity.y -= gravity * delta

	if is_rolling:
		velocity.x = roll_direction.x * ROLL_SPEED
		velocity.z = roll_direction.z * ROLL_SPEED
		_update_roll_animation(delta)
		move_and_slide()
		return

	if target_player and is_instance_valid(target_player) and _player_is_attacking() and roll_cooldown <= 0.0 and not is_hurt and not is_attacking:
		if global_position.distance_to(target_player.global_position) <= 8.125:
			_start_roll()
			move_and_slide()
			return

	if is_hurt:
		_stop_horizontal(delta)
		_update_hurt_animation(delta)
		move_and_slide()
		return

	if is_attacking:
		_stop_horizontal(delta)
		_update_attack_animation(delta)
		move_and_slide()
		return

	if target_player and is_instance_valid(target_player):
		var to_player: Vector3 = target_player.global_position - global_position
		to_player.y = 0.0
		if to_player.length() > stop_distance:
			var direction: Vector3 = to_player.normalized()
			velocity.x = direction.x * move_speed
			velocity.z = direction.z * move_speed
			if sprite and abs(velocity.x) > 0.1:
				sprite.flip_h = velocity.x < 0.0
		else:
			_stop_horizontal(delta)
			if to_player.length() <= attack_range and attack_cooldown <= 0.0:
				_start_attack()
	else:
		_stop_horizontal(delta)

	move_and_slide()
	_update_animation(delta)

func _stop_horizontal(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, move_speed * 7.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, move_speed * 7.0 * delta)

func _update_animation(delta: float) -> void:
	var is_walking := Vector2(velocity.x, velocity.z).length() > 0.1
	if is_walking and walk_texture:
		walk_timer += delta
		var frame_time := 1.0 / WALK_FPS
		if walk_timer >= frame_time:
			var steps := int(walk_timer / frame_time)
			walk_timer -= float(steps) * frame_time
			walk_frame = (walk_frame + steps) % WALK_FRAME_COUNT
		_apply_walk_frame(walk_frame)
	else:
		_update_idle_animation(delta)

func _update_idle_animation(delta: float) -> void:
	if not idle_texture or not sprite:
		return
	idle_timer += delta
	var frame_time := 1.0 / IDLE_FPS
	if idle_timer >= frame_time:
		var steps := int(idle_timer / frame_time)
		idle_timer -= float(steps) * frame_time
		idle_frame = (idle_frame + steps) % IDLE_FRAME_COUNT
		_apply_idle_frame(idle_frame)

func _apply_idle_frame(frame_index: int) -> void:
	if not sprite or not idle_texture:
		return
	idle_frame = clampi(frame_index, 0, IDLE_FRAME_COUNT - 1)
	sprite.texture = idle_texture
	sprite.region_enabled = true
	sprite.pixel_size = IDLE_PIXEL_SIZE
	sprite.position = Vector3(0.0, 4.32, 0.0)
	sprite.region_rect = Rect2(idle_frame * IDLE_FRAME_SIZE.x, 0, IDLE_FRAME_SIZE.x, IDLE_FRAME_SIZE.y)

func _apply_walk_frame(frame_index: int) -> void:
	if not sprite or not walk_texture:
		return
	walk_frame = clampi(frame_index, 0, WALK_FRAME_COUNT - 1)
	sprite.texture = walk_texture
	sprite.region_enabled = true
	sprite.pixel_size = WALK_PIXEL_SIZE
	sprite.position = Vector3(0.0, 3.96, 0.0)
	sprite.region_rect = Rect2(walk_frame * WALK_FRAME_SIZE.x, 0, WALK_FRAME_SIZE.x, WALK_FRAME_SIZE.y)

func _player_is_attacking() -> bool:
	if not target_player or not is_instance_valid(target_player):
		return false
	return bool(target_player.get("is_attacking")) or bool(target_player.get("is_montante_attacking"))

func _start_roll() -> void:
	if not roll_texture or not target_player:
		return
	var to_player: Vector3 = target_player.global_position - global_position
	to_player.y = 0.0
	if to_player.length() <= 0.001:
		return
	roll_direction = to_player.normalized()
	is_rolling = true
	is_attacking = false
	is_hurt = false
	roll_frame = 0
	roll_timer = 0.0
	roll_cooldown = ROLL_COOLDOWN_TIME
	_apply_roll_frame(0)
	print("[", enemy_name, "] forward-rolls through the incoming attack.")

func _update_roll_animation(delta: float) -> void:
	roll_timer += delta
	var frame_time := 1.0 / ROLL_FPS
	if roll_timer >= frame_time:
		var steps := int(roll_timer / frame_time)
		roll_timer -= float(steps) * frame_time
		roll_frame += steps
		if roll_frame >= ROLL_FRAME_COUNT:
			is_rolling = false
			roll_frame = 0
			_apply_idle_frame(0)
			return
		_apply_roll_frame(roll_frame)

func _apply_roll_frame(frame_index: int) -> void:
	if not sprite or not roll_texture:
		return
	roll_frame = clampi(frame_index, 0, ROLL_FRAME_COUNT - 1)
	sprite.texture = roll_texture
	sprite.region_enabled = true
	sprite.pixel_size = ROLL_PIXEL_SIZE
	sprite.position = Vector3(0.0, 4.16, 0.0)
	sprite.region_rect = Rect2(roll_frame * ROLL_FRAME_SIZE.x, 0, ROLL_FRAME_SIZE.x, ROLL_FRAME_SIZE.y)

func _start_hurt() -> void:
	if not hurt_texture or is_dead:
		return
	is_hurt = true
	hurt_frame = 0
	hurt_timer = 0.0
	_apply_hurt_frame(0)

func _update_hurt_animation(delta: float) -> void:
	hurt_timer += delta
	var frame_time := 1.0 / HURT_FPS
	if hurt_timer >= frame_time:
		var steps := int(hurt_timer / frame_time)
		hurt_timer -= float(steps) * frame_time
		hurt_frame += steps
		if hurt_frame >= HURT_FRAME_COUNT:
			is_hurt = false
			hurt_frame = 0
			_apply_idle_frame(0)
			return
		_apply_hurt_frame(hurt_frame)

func _apply_hurt_frame(frame_index: int) -> void:
	if not sprite or not hurt_texture:
		return
	hurt_frame = clampi(frame_index, 0, HURT_FRAME_COUNT - 1)
	sprite.texture = hurt_texture
	sprite.region_enabled = true
	sprite.pixel_size = HURT_PIXEL_SIZE
	sprite.position = Vector3(0.0, 4.35, 0.0)
	sprite.region_rect = Rect2(hurt_frame * HURT_FRAME_SIZE.x, 0, HURT_FRAME_SIZE.x, HURT_FRAME_SIZE.y)

func _start_attack() -> void:
	if not attack_texture or not target_player:
		return
	is_attacking = true
	attack_has_hit = false
	attack_frame = 0
	attack_timer = 0.0
	_apply_attack_frame(0)

func _update_attack_animation(delta: float) -> void:
	if not attack_texture:
		_finish_attack()
		return
	attack_timer += delta
	var frame_time := 1.0 / ATTACK_FPS
	if attack_timer >= frame_time:
		var steps := int(attack_timer / frame_time)
		attack_timer -= float(steps) * frame_time
		attack_frame += steps
		if attack_frame >= ATTACK_FRAME_COUNT:
			_finish_attack()
			return
		_apply_attack_frame(attack_frame)

	if attack_frame >= ATTACK_HIT_FRAME and not attack_has_hit:
		attack_has_hit = true
		if target_player and is_instance_valid(target_player) and target_player.has_method("take_damage"):
			if global_position.distance_to(target_player.global_position) <= attack_range + 0.5:
				target_player.take_damage(attack_damage, self)
				print("[", enemy_name, "] lands a dagger flurry hit for ", attack_damage, " damage.")

func _finish_attack() -> void:
	is_attacking = false
	attack_cooldown = attack_cooldown_time
	attack_frame = 0
	attack_timer = 0.0
	_apply_idle_frame(0)

func _apply_attack_frame(frame_index: int) -> void:
	if not sprite or not attack_texture:
		return
	attack_frame = clampi(frame_index, 0, ATTACK_FRAME_COUNT - 1)
	sprite.texture = attack_texture
	sprite.region_enabled = true
	sprite.pixel_size = ATTACK_PIXEL_SIZE
	sprite.position = Vector3(0.0, 4.4, 0.0)
	sprite.region_rect = Rect2(attack_frame * ATTACK_FRAME_SIZE.x, 0, ATTACK_FRAME_SIZE.x, ATTACK_FRAME_SIZE.y)

func _on_body_entered_aggro(body: Node3D) -> void:
	if body is PlayerController and not is_dead:
		target_player = body
		print("[", enemy_name, "] spotted the player and is approaching quickly.")

func _on_body_exited_aggro(body: Node3D) -> void:
	if body == target_player:
		target_player = null
		print("[", enemy_name, "] lost sight of the player.")

func take_earthshatter_damage(amount: float) -> void:
	if is_dead:
		return
	# Earthshatter is the roll counter: it can hit the Bandit while rolling.
	if is_rolling:
		is_rolling = false
		roll_cooldown = ROLL_COOLDOWN_TIME
		_apply_idle_frame(0)
	take_damage(amount)

func take_damage(amount: float) -> void:
	if is_dead or is_rolling:
		return
	# If the player's slash reaches the Bandit before the roll trigger runs,
	# immediately roll and completely evade that hit.
	if target_player and is_instance_valid(target_player) and _player_is_attacking() and roll_cooldown <= 0.0:
		_start_roll()
		return
	current_health = maxf(0.0, current_health - amount)
	print("[", enemy_name, "] took ", amount, " damage! HP remaining: ", current_health)
	var feedback = _get_combat_feedback()
	var impact_pos := global_position + Vector3(0.0, 1.1, 0.0)
	if feedback:
		feedback.spawn_damage_number(amount, impact_pos + Vector3(0.0, 0.55, 0.0), Color(1.0, 0.86, 0.28, 1.0), false)
		feedback.spawn_impact_effect(impact_pos, Color(1.0, 0.78, 0.22, 1.0), 0.45, 6)
		feedback.hit_flash(sprite, Color.WHITE, 0.035, 0.11)
	if current_health <= 0.0:
		die()
	else:
		_start_hurt()

func die() -> void:
	is_dead = true
	is_dying = true
	velocity = Vector3.ZERO
	if collision_shape:
		collision_shape.set_deferred("disabled", true)
	var feedback = _get_combat_feedback()
	if feedback:
		feedback.spawn_death_effect(global_position + Vector3(0.0, 1.0, 0.0), false)
	var player := get_tree().root.find_child("Player", true, false) as PlayerController
	if player:
		if player.has_method("add_gold"):
			player.add_gold(15)
		if player.has_method("on_bandit_slain"):
			player.on_bandit_slain()
	death_frame = 0
	death_timer = 0.0
	if death_texture:
		_apply_death_frame(0)
	else:
		queue_free()

func _update_death_animation(delta: float) -> void:
	if not death_texture:
		queue_free()
		return
	death_timer += delta
	var frame_time := 1.0 / DEATH_FPS
	if death_timer >= frame_time:
		var steps := int(death_timer / frame_time)
		death_timer -= float(steps) * frame_time
		death_frame += steps
		if death_frame >= DEATH_FRAME_COUNT:
			var feedback = _get_combat_feedback()
			if feedback and feedback.has_method("spawn_enemy_death_skull"):
				feedback.spawn_enemy_death_skull(global_position + Vector3(0.0, 1.6, 0.0))
			queue_free()
			return
		_apply_death_frame(death_frame)

func _apply_death_frame(frame_index: int) -> void:
	if not sprite or not death_texture:
		return
	death_frame = clampi(frame_index, 0, DEATH_FRAME_COUNT - 1)
	sprite.texture = death_texture
	sprite.region_enabled = true
	sprite.pixel_size = DEATH_PIXEL_SIZE
	sprite.position = Vector3(0.0, 4.24, 0.0)
	sprite.region_rect = Rect2(death_frame * DEATH_FRAME_SIZE.x, 0, DEATH_FRAME_SIZE.x, DEATH_FRAME_SIZE.y)

func _get_combat_feedback():
	var feedback = get_tree().root.find_child("CombatFeedback", true, false)
	if feedback:
		return feedback
	var feedback_script = load("res://scripts/combat_feedback.gd")
	if feedback_script == null:
		return null
	feedback = Node.new()
	feedback.name = "CombatFeedback"
	feedback.set_script(feedback_script)
	var parent: Node = get_tree().current_scene
	if parent == null:
		parent = get_tree().root
	parent.add_child(feedback)
	return feedback
