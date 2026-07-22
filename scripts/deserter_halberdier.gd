extends CharacterBody3D

class_name DeserterHalberdier

## The first enemy behavior pass: detect the player and approach, but do not attack yet.
@export var enemy_name: String = "Deserter Halberdier"
@export var max_health: float = 100.0
@export var move_speed: float = 3.5
@export var stop_distance: float = 6.125
@export var attack_range: float = 6.125
@export var attack_damage: float = 25.0

@onready var sprite: Sprite3D = $Sprite3D
@onready var aggro_area: Area3D = $AggroArea
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

const IDLE_SHEET_PATH := "res://art_v2/deserter_halberdier_idle_sheet.png"
const WALK_SHEET_PATH := "res://art_v2/deserter_halberdier_walk_sheet.png"
const ATTACK_SHEET_PATH := "res://art_v2/deserter_halberdier_attack_sheet.png"
const HURT_SHEET_PATH := "res://art_v2/deserter_halberdier_hurt_sheet.png"
const DEATH_SHEET_PATH := "res://art_v2/deserter_halberdier_death_sheet.png"
const IDLE_FPS := 6.0
const WALK_FPS := 5.0
const ATTACK_FPS := 8.0
const IDLE_PIXEL_SIZE := 0.016
const WALK_PIXEL_SIZE := 0.020
const ATTACK_PIXEL_SIZE := 0.025
const WALK_FRAME_SIZE := Vector2i(320, 480)
const WALK_FRAME_COUNT := 8
const ATTACK_FRAME_SIZE := Vector2i(384, 400)
const ATTACK_FRAME_COUNT := 8
const ATTACK_HIT_FRAME := 4
const HURT_FPS := 8.0
const HURT_PIXEL_SIZE := 0.0122
const HURT_FRAME_SIZE := Vector2i(540, 740)
const HURT_FRAME_COUNT := 4
const DEATH_FPS := 6.0
const DEATH_PIXEL_SIZE := 0.021
const DEATH_FRAME_SIZE := Vector2i(400, 460)
const DEATH_FRAME_COUNT := 4
const IDLE_FRAMES: Array[Rect2] = [
	Rect2(0, 0, 279, 567),
	Rect2(283, 0, 286, 567),
	Rect2(572, 0, 314, 567),
	Rect2(888, 0, 280, 567),
	Rect2(1171, 0, 279, 567),
	Rect2(1450, 0, 279, 567),
]

var idle_texture: Texture2D = null
var walk_texture: Texture2D = null
var attack_texture: Texture2D = null
var hurt_texture: Texture2D = null
var death_texture: Texture2D = null
var idle_frame: int = 0
var idle_timer: float = 0.0
var walk_frame: int = 0
var walk_timer: float = 0.0
var attack_frame: int = 0
var attack_timer: float = 0.0
var is_attacking: bool = false
var attack_has_hit: bool = false
var hurt_frame: int = 0
var hurt_timer: float = 0.0
var is_hurt: bool = false
var death_frame: int = 0
var death_timer: float = 0.0
var is_dying: bool = false
var current_health: float = 0.0
var target_player: Node3D = null
var facing_direction: Vector3 = Vector3(0.0, 0.0, 1.0)
var attack_facing_direction: Vector3 = Vector3(0.0, 0.0, 1.0)
var montante_attacker: Node3D = null
var gravity: float = 9.8
var is_dead: bool = false

func _ready() -> void:
	current_health = max_health
	idle_texture = load(IDLE_SHEET_PATH) as Texture2D
	walk_texture = load(WALK_SHEET_PATH) as Texture2D
	attack_texture = load(ATTACK_SHEET_PATH) as Texture2D
	hurt_texture = load(HURT_SHEET_PATH) as Texture2D
	death_texture = load(DEATH_SHEET_PATH) as Texture2D
	if idle_texture:
		sprite.texture = idle_texture
		sprite.region_enabled = true
		sprite.pixel_size = IDLE_PIXEL_SIZE
		sprite.position = Vector3(0.0, 4.53, 0.0)
		_apply_idle_frame(0)
	else:
		push_error("[Deserter Halberdier] Missing idle sheet: " + IDLE_SHEET_PATH)
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
	if not is_on_floor():
		velocity.y -= gravity * delta

	if montante_attacker:
		if not is_instance_valid(montante_attacker) or not bool(montante_attacker.get("is_montante_attacking")) or global_position.distance_to(montante_attacker.global_position) > attack_range + 0.5:
			montante_attacker = null
			is_hurt = false
			_apply_idle_frame(0)
		else:
			_stop_horizontal(delta)
			is_hurt = true
			_update_hurt_animation(delta)
			move_and_slide()
			return

	if is_hurt:
		_stop_horizontal(delta)
		_update_hurt_animation(delta)
		move_and_slide()
		return

	if is_attacking:
		# During the telegraph, cancel and retarget if the player slips behind
		# the halberdier. Once the strike begins, the attack direction is locked.
		if attack_frame < ATTACK_HIT_FRAME and not _is_attack_target_valid():
			_cancel_attack_and_retarget()
		else:
			_stop_horizontal(delta)
			_update_attack_animation(delta)
			move_and_slide()
		return

	if target_player and is_instance_valid(target_player):
		var to_player := target_player.global_position - global_position
		to_player.y = 0.0
		if to_player.length() > stop_distance:
			var direction: Vector3 = to_player.normalized()
			facing_direction = direction
			velocity.x = direction.x * move_speed
			velocity.z = direction.z * move_speed
			if sprite and abs(velocity.x) > 0.1:
				sprite.flip_h = velocity.x < 0.0
		else:
			_stop_horizontal(delta)
			if to_player.length() <= attack_range:
				_start_attack()
	else:
		_stop_horizontal(delta)

	move_and_slide()
	_update_animation(delta)

func _stop_horizontal(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, move_speed * 6.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, move_speed * 6.0 * delta)

func _update_animation(delta: float) -> void:
	var is_walking := Vector2(velocity.x, velocity.z).length() > 0.1
	if is_walking and walk_texture:
		walk_timer += delta
		var walk_frame_time := 1.0 / WALK_FPS
		if walk_timer >= walk_frame_time:
			var steps := int(walk_timer / walk_frame_time)
			walk_timer -= float(steps) * walk_frame_time
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
		idle_frame = (idle_frame + steps) % IDLE_FRAMES.size()
		_apply_idle_frame(idle_frame)

func _apply_idle_frame(frame_index: int) -> void:
	if not sprite or not idle_texture:
		return
	idle_frame = clampi(frame_index, 0, IDLE_FRAMES.size() - 1)
	sprite.texture = idle_texture
	sprite.region_enabled = true
	sprite.pixel_size = IDLE_PIXEL_SIZE
	sprite.position = Vector3(0.0, 4.53, 0.0)
	sprite.region_rect = IDLE_FRAMES[idle_frame]

func _apply_walk_frame(frame_index: int) -> void:
	if not sprite or not walk_texture:
		return
	walk_frame = clampi(frame_index, 0, WALK_FRAME_COUNT - 1)
	sprite.texture = walk_texture
	sprite.region_enabled = true
	sprite.pixel_size = WALK_PIXEL_SIZE
	# Walk atlas cells are shorter than the idle cells; keep feet on the ground.
	sprite.position = Vector3(0.0, 4.8, 0.0)
	sprite.region_rect = Rect2(walk_frame * WALK_FRAME_SIZE.x, 0, WALK_FRAME_SIZE.x, WALK_FRAME_SIZE.y)

func set_montante_suppressed(attacker: Node3D) -> void:
	if is_dead:
		return
	if montante_attacker == attacker:
		return
	montante_attacker = attacker
	is_attacking = false
	attack_has_hit = false
	_start_hurt()

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
			if montante_attacker:
				hurt_frame = 0
				_apply_hurt_frame(0)
				return
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
	sprite.position = Vector3(0.0, 4.51, 0.0)
	sprite.region_rect = Rect2(hurt_frame * HURT_FRAME_SIZE.x, 0, HURT_FRAME_SIZE.x, HURT_FRAME_SIZE.y)

func _is_attack_target_valid() -> bool:
	if not target_player or not is_instance_valid(target_player):
		return false
	var to_player: Vector3 = target_player.global_position - global_position
	to_player.y = 0.0
	if to_player.length() <= 0.001:
		return false
	return to_player.length() <= attack_range + 0.5 and attack_facing_direction.dot(to_player.normalized()) > 0.0

func _cancel_attack_and_retarget() -> void:
	is_attacking = false
	attack_has_hit = false
	attack_frame = 0
	attack_timer = 0.0
	if target_player and is_instance_valid(target_player):
		var to_player: Vector3 = target_player.global_position - global_position
		to_player.y = 0.0
		if to_player.length() > 0.001:
			facing_direction = to_player.normalized()
			if sprite and abs(facing_direction.x) > 0.1:
				sprite.flip_h = facing_direction.x < 0.0
	_apply_idle_frame(0)

func _start_attack() -> void:
	if not attack_texture or not target_player:
		return
	is_attacking = true
	attack_has_hit = false
	attack_facing_direction = facing_direction.normalized()
	attack_frame = 0
	attack_timer = 0.0
	_apply_attack_frame(0)
	print("[", enemy_name, "] begins an overhead halberd attack.")

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
			var to_player: Vector3 = target_player.global_position - global_position
			to_player.y = 0.0
			var distance := to_player.length()
			var is_in_front := distance > 0.001 and attack_facing_direction.dot(to_player.normalized()) > 0.0
			if distance <= attack_range + 0.5 and is_in_front:
				target_player.take_damage(attack_damage, self)
				print("[", enemy_name, "] hit the player for ", attack_damage, " damage.")
			else:
				print("[", enemy_name, "] attack missed — player is behind the halberdier.")

func _finish_attack() -> void:
	is_attacking = false
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
	sprite.position = Vector3(0.0, 5.0, 0.0)
	sprite.region_rect = Rect2(attack_frame * ATTACK_FRAME_SIZE.x, 0, ATTACK_FRAME_SIZE.x, ATTACK_FRAME_SIZE.y)

func _on_body_entered_aggro(body: Node3D) -> void:
	if body is PlayerController and not is_dead:
		target_player = body
		print("[", enemy_name, "] spotted the player and is approaching.")

func _on_body_exited_aggro(body: Node3D) -> void:
	if body == target_player:
		target_player = null
		print("[", enemy_name, "] lost sight of the player.")

func take_damage(amount: float) -> void:
	if is_dead:
		return
	current_health = maxf(0.0, current_health - amount)
	print("[", enemy_name, "] took ", amount, " damage! HP remaining: ", current_health)

	var feedback = _get_combat_feedback()
	var impact_pos := global_position + Vector3(0.0, 1.1, 0.0)
	if feedback:
		feedback.spawn_damage_number(amount, impact_pos + Vector3(0.0, 0.55, 0.0), Color(1.0, 0.86, 0.28, 1.0), false)
		feedback.spawn_impact_effect(impact_pos, Color(1.0, 0.78, 0.22, 1.0), 0.55, 7)
		feedback.hit_flash(sprite, Color.WHITE, 0.035, 0.11)

	if current_health <= 0.0:
		die()
	else:
		_start_hurt()

func die() -> void:
	is_dead = true
	velocity = Vector3.ZERO
	if collision_shape:
		collision_shape.set_deferred("disabled", true)
	print("[", enemy_name, "] has been slain!")

	var feedback = _get_combat_feedback()
	if feedback:
		feedback.spawn_death_effect(global_position + Vector3(0.0, 1.0, 0.0), false)
		feedback.screen_shake(0.20, 0.18)

	is_dying = true
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
	sprite.position = Vector3(0.0, 4.83, 0.0)
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
