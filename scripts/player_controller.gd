extends CharacterBody3D

class_name PlayerController

# --- MOVEMENT SETTINGS ---
@export_group("Movement")
@export var move_speed: float = 6.0
@export var sprint_speed: float = 9.0
@export var acceleration: float = 10.0
# Standing / walk jump (lower hop).
@export var jump_velocity: float = 5.2
# Sprint jump: higher/farther than idle, but not absurd.
# apex ≈ v^2 / (2g): 5.2→1.4 units, 8.2→3.4 units (~2.5× higher).
@export var sprint_jump_velocity: float = 6.6
@export var sprint_jump_forward_boost: float = 3.2
@export var gravity: float = 9.8

# --- WORLD BOUNDS ---
# Must stay in sync with minimap.gd/minimap_controller.gd world bounds.
# The margin keeps the player's capsule center safely inside the 5400×5400 ground.
const WORLD_MIN_X := -2700.0
const WORLD_MAX_X := 2700.0
const WORLD_MIN_Z := -2700.0
const WORLD_MAX_Z := 2700.0
const WORLD_BOUNDARY_MARGIN := 0.6

# --- COMBAT & STATS ---
@export_group("Combat")
@export var max_health: float = 100.0
@export var max_stamina: float = 100.0
@export var max_mana: float = 100.0
@export var attack_duration: float = 0.67
@export var attack_damage: float = 25.0
var current_health: float = max_health
var current_stamina: float = max_stamina
var current_mana: float = max_mana
var gold_coins: int = 0
var current_weapon_name: String = "Rusty Sword"
var is_attacking: bool = false
var has_quen_shield: bool = false
var current_speed: float = move_speed

# --- QUEST & XP ---
@export_group("Quest & XP")
var bandits_slain: int = 0
var quest_target: int = 3
var quest_completed: bool = false
var player_level: int = 1

# --- NODE REFERENCES ---
@onready var camera_pivot: Node3D = $CameraPivot
@onready var sprite: Sprite3D = $Sprite3D
@onready var melee_hitbox: Area3D = $MeleeHitbox
@onready var interact_area: Area3D = $InteractArea

# --- SPRITE SHEET ANIMATION (SpriteCook walk / run / attack) ---
const IDLE_TEX_PATH := "res://art_v2/player_knight.png"  # fallback still portrait
const IDLE_SHEET_PATH := "res://art_v2/player_idle_sheet.png"
const WALK_SHEET_PATH := "res://art_v2/player_walk_sheet.png"
const RUN_SHEET_PATH := "res://art_v2/player_run_sheet.png"
const ATTACK_SHEET_PATH := "res://art_v2/player_attack_sheet.png"
const RUN_JUMP_SHEET_PATH := "res://art_v2/player_run_jump_sheet.png"

const IDLE_FRAME_COUNT := 6
const WALK_FRAME_COUNT := 8
const RUN_FRAME_COUNT := 10
const ATTACK_FRAME_COUNT := 10
const RUN_JUMP_FRAME_COUNT := 13
const RUN_JUMP_APEX_FRAME := 6  # peak pose
const IDLE_FRAME_SIZE := Vector2i(328, 466)
const WALK_FRAME_SIZE := Vector2i(640, 640)
const RUN_FRAME_SIZE := Vector2i(640, 640)
const ATTACK_FRAME_SIZE := Vector2i(596, 306)  # 5×2 anchor-aligned individual frames
const RUN_JUMP_FRAME_SIZE := Vector2i(776, 700)  # ready sheet, body-locked
const IDLE_COLUMNS := 6
const WALK_COLUMNS := 8
const RUN_COLUMNS := 10
const ATTACK_COLUMNS := 5
const RUN_JUMP_COLUMNS := 13
const IDLE_FPS := 6.0  # gentle breathing/cloak loop
const WALK_FPS := 10.0
const RUN_FPS := 14.0
# 10-frame overhead slash; ~0.67s total at 15 FPS (slightly longer read).
const ATTACK_FPS := 15.0
# Run-jump one-shot (~0.87s). Hold landing frames a touch longer in code.
const RUN_JUMP_FPS := 14.0
# Active hit frames: big sword arcs (poses 5–7, 0-based 4–6).
const ATTACK_HIT_FRAME_START := 4
const ATTACK_HIT_FRAME_END := 6

# Idle portrait was tuned separately (1408×768 full texture).
const IDLE_PIXEL_SIZE := 0.01747  # match walk/run body height
const IDLE_SPRITE_Y := 3.852
# Walk/run sheets are 640px tall; scale so body height matches idle, feet on ground.
const ANIM_PIXEL_SIZE := 0.01205
const WALK_SPRITE_Y := 3.850   # feet near bottom of each walk frame
const RUN_SPRITE_Y := 3.604    # avg opaque feet ~row 619 on run sheet
# Attack cells are 366px tall, feet bottom-aligned; match idle body height.
const ATTACK_PIXEL_SIZE := 0.03192
const ATTACK_SPRITE_Y := 4.325
# Run-jump strip cells 258px; match idle body height, feet bottom-aligned.
const RUN_JUMP_PIXEL_SIZE := 0.01205  # == ANIM_PIXEL_SIZE (walk/run)
const RUN_JUMP_SPRITE_Y := 4.091

enum AnimState { IDLE, WALK, RUN, ATTACK, RUN_JUMP }

var tex_idle: Texture2D = null
var tex_idle_sheet: Texture2D = null
var tex_walk_sheet: Texture2D = null
var tex_run_sheet: Texture2D = null
var tex_attack_sheet: Texture2D = null
var tex_run_jump_sheet: Texture2D = null
var anim_timer: float = 0.0
var anim_frame: int = 0
var current_anim: AnimState = AnimState.IDLE
var was_sprinting_on_jump: bool = false
var run_jump_face_left: bool = false
var run_jump_left_ground: bool = false
var dialogue_ui: DialogueUI = null
var hud: HUD = null


func _ready() -> void:
	current_health = max_health
	current_stamina = max_stamina
	current_mana = max_mana

	_ensure_input_mappings()
	_setup_sprite_animation()

	if camera_pivot:
		camera_pivot.top_level = true

	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if melee_hitbox:
		melee_hitbox.monitoring = false
		melee_hitbox.body_entered.connect(_on_melee_hit)

	call_deferred("_find_ui")


func _setup_sprite_animation() -> void:
	tex_idle = load(IDLE_TEX_PATH) as Texture2D
	tex_idle_sheet = load(IDLE_SHEET_PATH) as Texture2D
	tex_walk_sheet = load(WALK_SHEET_PATH) as Texture2D
	tex_run_sheet = load(RUN_SHEET_PATH) as Texture2D
	tex_attack_sheet = load(ATTACK_SHEET_PATH) as Texture2D
	tex_run_jump_sheet = load(RUN_JUMP_SHEET_PATH) as Texture2D
	if tex_run_jump_sheet == null:
		push_warning("Missing run-jump sheet: " + RUN_JUMP_SHEET_PATH)
	_set_anim_state(AnimState.IDLE, true)

func _ensure_input_mappings() -> void:
	var key_mappings := {
		"move_forward": [KEY_W, KEY_UP],
		"move_backward": [KEY_S, KEY_DOWN],
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"interact": [KEY_E],
		"sprint": [KEY_SHIFT],
		"cast_igni": [KEY_Q],
		"cast_quen": [KEY_R]
	}
	for action in key_mappings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key_code in key_mappings[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key_code
			if not InputMap.action_has_event(action, event):
				InputMap.action_add_event(action, event)

	if not InputMap.has_action("attack"):
		InputMap.add_action("attack")
		var mouse_event := InputEventMouseButton.new()
		mouse_event.button_index = MOUSE_BUTTON_LEFT
		if not InputMap.action_has_event("attack", mouse_event):
			InputMap.action_add_event("attack", mouse_event)

func _find_ui() -> void:
	dialogue_ui = get_tree().root.find_child("DialogueUI", true, false) as DialogueUI
	hud = get_tree().root.find_child("HUD", true, false) as HUD
	if hud:
		if hud.has_method("update_health"):
			hud.update_health(current_health, max_health)
		if hud.has_method("update_stamina"):
			hud.update_stamina(current_stamina, max_stamina)
		if hud.has_method("update_mana"):
			hud.update_mana(current_mana, max_mana)
		if hud.has_method("update_gold"):
			hud.update_gold(gold_coins)
		if hud.has_method("update_weapon"):
			hud.update_weapon(current_weapon_name, attack_damage)
		if hud.has_method("update_quest"):
			hud.update_quest(bandits_slain, quest_target, quest_completed)

func _play_sound(type: String, extra: String = "") -> void:
	var sm := get_tree().root.find_child("SoundManager", true, false) as SoundManager
	if not sm:
		return
	if type == "slash": sm.play_slash()
	elif type == "coin": sm.play_coin()
	elif type == "igni": sm.play_igni()
	elif type == "quen": sm.play_quen()
	elif type == "fanfare": sm.play_fanfare()
	elif type == "voice": sm.play_voice(extra)

func stop_voice() -> void:
	var sm := get_tree().root.find_child("SoundManager", true, false) as SoundManager
	if sm and sm.has_method("stop_voice"):
		sm.stop_voice()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		try_interact()

	if event.is_action_pressed("ui_cancel") and (not dialogue_ui or not dialogue_ui.is_open):
		# Camera has no mouse-look, so keep the cursor visible. Esc only toggles
		# whether the visible cursor is confined to the game window.
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CONFINED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CONFINED)

func _physics_process(delta: float) -> void:
	_clamp_to_world_bounds()

	if camera_pivot:
		camera_pivot.global_position = global_position + Vector3(0, 0, 0)

	if dialogue_ui and dialogue_ui.is_open:
		velocity.x = move_toward(velocity.x, 0, acceleration * delta)
		velocity.z = move_toward(velocity.z, 0, acceleration * delta)
		_update_sprite_animation(delta)
		move_and_slide()
		_clamp_to_world_bounds()
		return

	# 1. Apply Gravity
	if not is_on_floor():
		velocity.y -= gravity * delta

	# 2. Handle Combat / Attacking & Magic Signs
	if Input.is_action_just_pressed("attack") and not is_attacking and is_on_floor():
		if current_stamina >= 15.0:
			start_attack()
		else:
			if hud and hud.has_method("show_notification"):
				hud.show_notification("Not enough Stamina!", Color(1, 0.4, 0.4, 1))

	if Input.is_action_just_pressed("cast_igni") and not is_attacking and is_on_floor():
		if current_mana >= 35.0:
			cast_igni()
		else:
			if hud and hud.has_method("show_notification"):
				hud.show_notification("Not enough Mana for Igni!", Color(0.3, 0.6, 1.0, 1))

	if Input.is_action_just_pressed("cast_quen") and not is_attacking and is_on_floor():
		if current_mana >= 40.0:
			cast_quen()
		else:
			if hud and hud.has_method("show_notification"):
				hud.show_notification("Not enough Mana for Quen!", Color(0.3, 0.6, 1.0, 1))

	if is_attacking:
		velocity.x = move_toward(velocity.x, 0, acceleration * delta)
		velocity.z = move_toward(velocity.z, 0, acceleration * delta)
		_update_sprite_animation(delta)
		move_and_slide()
		_clamp_to_world_bounds()
		return

	# 3. Handle Jump
	# Sprint-jump: high pyramid arc + forward leap + full RUN_JUMP sheet.
	# Idle/walk-jump: lower hop (no run-jump sheet yet).
	if Input.is_action_just_pressed("ui_accept") and is_on_floor() and not is_attacking:
		var planar := Vector2(velocity.x, velocity.z).length()
		var move_input := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
		# Treat as sprint-jump if Shift is held and we are (or were) moving.
		# Do NOT require stamina or exact current_speed — that was freezing on a run frame.
		was_sprinting_on_jump = (
			Input.is_action_pressed("sprint")
			and (planar > 0.35 or move_input.length() > 0.1 or current_anim == AnimState.RUN)
		)

		if was_sprinting_on_jump:
			velocity.y = sprint_jump_velocity

			var boost_dir := Vector3(velocity.x, 0.0, velocity.z)
			if boost_dir.length() < 0.15:
				boost_dir = Vector3(move_input.x, 0.0, move_input.y)
			if boost_dir.length() > 0.001:
				boost_dir = boost_dir.normalized()
				var target_planar := maxf(planar, sprint_speed) + sprint_jump_forward_boost
				velocity.x = boost_dir.x * target_planar
				velocity.z = boost_dir.z * target_planar

			run_jump_face_left = sprite.flip_h if sprite else (velocity.x < 0.0)
			run_jump_left_ground = false
			anim_timer = 0.0
			anim_frame = 0
			_set_anim_state(AnimState.RUN_JUMP, true)
			_apply_run_jump_frame(0)
			if sprite:
				sprite.flip_h = run_jump_face_left
		else:
			velocity.y = jump_velocity

	# 4. Handle Sprint, Stamina & Mana Regen
	if Input.is_action_pressed("sprint") and velocity.length() > 0.5 and current_stamina > 0:
		current_speed = sprint_speed
		current_stamina = max(0.0, current_stamina - 20.0 * delta)
	else:
		current_speed = move_speed
		current_stamina = min(max_stamina, current_stamina + 15.0 * delta)

	current_mana = min(max_mana, current_mana + 12.0 * delta)

	if hud:
		if hud.has_method("update_stamina"):
			hud.update_stamina(current_stamina, max_stamina)
		if hud.has_method("update_mana"):
			hud.update_mana(current_mana, max_mana)

	# 5. Movement in World Cardinal Directions
	# Player NEVER rotates - always faces camera (Cult of the Lamb style)
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction := Vector3(input_dir.x, 0, input_dir.y).normalized()

	if direction:
		var air_speed := current_speed
		# Sprint-jump carries farther: allow up to sprint speed in air during RUN_JUMP.
		if current_anim == AnimState.RUN_JUMP:
			air_speed = maxf(current_speed, sprint_speed)
		velocity.x = lerp(velocity.x, direction.x * air_speed, acceleration * delta)
		velocity.z = lerp(velocity.z, direction.z * air_speed, acceleration * delta)
	else:
		# Don't kill run-jump forward momentum when keys are released mid-air.
		var decel := acceleration * delta
		if current_anim == AnimState.RUN_JUMP and not is_on_floor():
			decel *= 0.25
		velocity.x = move_toward(velocity.x, 0, decel)
		velocity.z = move_toward(velocity.z, 0, decel)

	# Flip sprite horizontally based on horizontal movement.
	# Walk/run sheets face right; flip_h = true faces left.
	# Lock facing during run-jump so the one-shot doesn't mirror mid-cycle.
	if sprite and current_anim == AnimState.RUN_JUMP:
		sprite.flip_h = run_jump_face_left
	elif sprite and abs(velocity.x) > 0.1:
		sprite.flip_h = velocity.x < 0.0

	_update_sprite_animation(delta)

	move_and_slide()
	_clamp_to_world_bounds()


func _update_sprite_animation(delta: float) -> void:
	if sprite == null:
		return

	# One-shot attack: advance frames, enable hitbox on slash frames, then release.
	if current_anim == AnimState.ATTACK:
		anim_timer += delta
		var frame_time := 1.0 / ATTACK_FPS
		if anim_timer >= frame_time:
			var steps := int(anim_timer / frame_time)
			anim_timer -= steps * frame_time
			anim_frame += steps
			if anim_frame >= ATTACK_FRAME_COUNT:
				_finish_attack()
				return
			_apply_sheet_frame(ATTACK_FRAME_SIZE, anim_frame, ATTACK_COLUMNS)
			_sync_attack_hitbox()
		return

	# Run-jump one-shot: sequential strip playback, body-locked sheet.
	if current_anim == AnimState.RUN_JUMP:
		if not is_on_floor():
			run_jump_left_ground = true

		# Always keep correct texture/region bound.
		_apply_run_jump_frame(anim_frame)

		anim_timer += delta
		var frame_time := 1.0 / RUN_JUMP_FPS
		if anim_timer >= frame_time:
			var steps := int(anim_timer / frame_time)
			anim_timer -= float(steps) * frame_time
			anim_frame = mini(anim_frame + steps, RUN_JUMP_FRAME_COUNT - 1)
			_apply_run_jump_frame(anim_frame)

		# Early land: skip to landing/recover frames.
		if run_jump_left_ground and is_on_floor():
			var land_start := maxi(RUN_JUMP_FRAME_COUNT - 4, RUN_JUMP_APEX_FRAME)
			if anim_frame < land_start:
				anim_frame = land_start
				_apply_run_jump_frame(anim_frame)
			if anim_frame >= RUN_JUMP_FRAME_COUNT - 1:
				_finish_run_jump()
				return

		# Finished strip: hand off (if still airborne, wait until land).
		if anim_frame >= RUN_JUMP_FRAME_COUNT - 1:
			if is_on_floor() and run_jump_left_ground:
				_finish_run_jump()
		return

	# Horizontal speed only for ground locomotion.
	# While airborne without a dedicated jump anim, keep last walk/run loop.
	var planar_speed := Vector2(velocity.x, velocity.z).length()
	var wanted: AnimState = AnimState.IDLE

	if planar_speed > 0.35 and not is_attacking:
		if current_speed >= sprint_speed - 0.05 and Input.is_action_pressed("sprint") and current_stamina > 0.0:
			wanted = AnimState.RUN
		else:
			wanted = AnimState.WALK

	if wanted != current_anim:
		_set_anim_state(wanted)

	# Idle / walk / run sheet loops
	var fps: float
	var frame_count: int
	var frame_size: Vector2i
	var columns: int
	if current_anim == AnimState.IDLE:
		fps = IDLE_FPS
		frame_count = IDLE_FRAME_COUNT
		frame_size = IDLE_FRAME_SIZE
		columns = IDLE_COLUMNS
	elif current_anim == AnimState.RUN:
		fps = RUN_FPS
		frame_count = RUN_FRAME_COUNT
		frame_size = RUN_FRAME_SIZE
		columns = RUN_COLUMNS
	else:
		fps = WALK_FPS
		frame_count = WALK_FRAME_COUNT
		frame_size = WALK_FRAME_SIZE
		columns = WALK_COLUMNS

	anim_timer += delta
	var frame_time := 1.0 / fps
	if anim_timer >= frame_time:
		var steps := int(anim_timer / frame_time)
		anim_timer -= steps * frame_time
		anim_frame = (anim_frame + steps) % frame_count
		_apply_sheet_frame(frame_size, anim_frame, columns)


func _set_anim_state(state: AnimState, force: bool = false) -> void:
	if sprite == null:
		return
	if state == current_anim and not force:
		return

	current_anim = state
	anim_timer = 0.0
	anim_frame = 0
	# Keep Sprite3D pivot stable across sheet swaps (centered billboard).
	sprite.offset = Vector2.ZERO
	sprite.centered = true
	sprite.pixel_size = sprite.pixel_size  # no-op keep; real size set per-state below
	sprite.rotation.z = 0.0

	match state:
		AnimState.IDLE:
			if tex_idle_sheet:
				sprite.texture = tex_idle_sheet
				sprite.region_enabled = true
				sprite.pixel_size = IDLE_PIXEL_SIZE
				sprite.position = Vector3(0.0, IDLE_SPRITE_Y, 0.0)
				_apply_sheet_frame(IDLE_FRAME_SIZE, 0, IDLE_COLUMNS)
			elif tex_idle:
				sprite.texture = tex_idle
				sprite.region_enabled = false
				sprite.pixel_size = IDLE_PIXEL_SIZE
				sprite.position = Vector3(0.0, IDLE_SPRITE_Y, 0.0)
		AnimState.WALK:
			if tex_walk_sheet:
				sprite.texture = tex_walk_sheet
			sprite.region_enabled = true
			sprite.pixel_size = ANIM_PIXEL_SIZE
			sprite.position = Vector3(0.0, WALK_SPRITE_Y, 0.0)
			_apply_sheet_frame(WALK_FRAME_SIZE, 0, WALK_COLUMNS)
		AnimState.RUN:
			if tex_run_sheet:
				sprite.texture = tex_run_sheet
			sprite.region_enabled = true
			sprite.pixel_size = ANIM_PIXEL_SIZE
			sprite.position = Vector3(0.0, RUN_SPRITE_Y, 0.0)
			_apply_sheet_frame(RUN_FRAME_SIZE, 0, RUN_COLUMNS)
		AnimState.ATTACK:
			if tex_attack_sheet:
				sprite.texture = tex_attack_sheet
			sprite.region_enabled = true
			sprite.pixel_size = ATTACK_PIXEL_SIZE
			sprite.position = Vector3(0.0, ATTACK_SPRITE_Y, 0.0)
			_apply_sheet_frame(ATTACK_FRAME_SIZE, 0, ATTACK_COLUMNS)
		AnimState.RUN_JUMP:
			if tex_run_jump_sheet:
				sprite.texture = tex_run_jump_sheet
			sprite.offset = Vector2.ZERO
			sprite.centered = true
			sprite.pixel_size = RUN_JUMP_PIXEL_SIZE
			sprite.position = Vector3(0.0, RUN_JUMP_SPRITE_Y, 0.0)
			# CRITICAL: region must be on BEFORE display, single 276x276 cell only.
			sprite.region_enabled = true
			_apply_run_jump_frame(0)


func _apply_sheet_frame(frame_size: Vector2i, frame_index: int, columns: int = 1) -> void:
	if sprite == null:
		return
	frame_index = clampi(frame_index, 0, max(columns * 64, 1))
	var col := frame_index % columns
	var row := int(frame_index / float(columns))
	sprite.region_enabled = true
	sprite.region_rect = Rect2(
		col * frame_size.x,
		row * frame_size.y,
		frame_size.x,
		frame_size.y
	)



func _apply_run_jump_frame(frame_index: int) -> void:
	if sprite == null:
		return
	if tex_run_jump_sheet == null:
		return
	frame_index = clampi(frame_index, 0, RUN_JUMP_FRAME_COUNT - 1)
	# Same pipeline as walk/run: one sheet, crop exactly one cell.
	if sprite.texture != tex_run_jump_sheet:
		sprite.texture = tex_run_jump_sheet
	sprite.centered = true
	sprite.offset = Vector2.ZERO
	sprite.pixel_size = RUN_JUMP_PIXEL_SIZE
	sprite.position = Vector3(0.0, RUN_JUMP_SPRITE_Y, 0.0)
	sprite.region_enabled = true
	sprite.region_rect = Rect2(
		frame_index * RUN_JUMP_FRAME_SIZE.x,
		0,
		RUN_JUMP_FRAME_SIZE.x,
		RUN_JUMP_FRAME_SIZE.y
	)


func _sync_attack_hitbox() -> void:
	if melee_hitbox == null:
		return
	var active := (
		current_anim == AnimState.ATTACK
		and anim_frame >= ATTACK_HIT_FRAME_START
		and anim_frame <= ATTACK_HIT_FRAME_END
	)
	melee_hitbox.monitoring = active


func _finish_attack() -> void:
	is_attacking = false
	if melee_hitbox:
		melee_hitbox.monitoring = false
	# Snap back via normal locomotion selection next frame.
	current_anim = AnimState.IDLE
	if sprite:
		sprite.rotation.z = 0.0
	_set_anim_state(AnimState.IDLE, true)


func _finish_run_jump() -> void:
	was_sprinting_on_jump = false
	run_jump_left_ground = false
	# Prefer continuing the sprint cycle so landing doesn't snap to a different silhouette.
	var planar_speed := Vector2(velocity.x, velocity.z).length()
	if planar_speed > 0.35 and Input.is_action_pressed("sprint") and current_stamina > 0.0:
		_set_anim_state(AnimState.RUN, true)
	elif planar_speed > 0.35:
		_set_anim_state(AnimState.WALK, true)
	else:
		_set_anim_state(AnimState.IDLE, true)


func _clamp_to_world_bounds() -> void:
	var min_x := WORLD_MIN_X + WORLD_BOUNDARY_MARGIN
	var max_x := WORLD_MAX_X - WORLD_BOUNDARY_MARGIN
	var min_z := WORLD_MIN_Z + WORLD_BOUNDARY_MARGIN
	var max_z := WORLD_MAX_Z - WORLD_BOUNDARY_MARGIN

	var old_position := global_position
	var clamped_position := old_position
	clamped_position.x = clamp(clamped_position.x, min_x, max_x)
	clamped_position.z = clamp(clamped_position.z, min_z, max_z)

	if clamped_position == old_position:
		return

	global_position = clamped_position

	# Stop velocity pushing out of bounds so the player does not repeatedly slide/fall at the edge.
	if (old_position.x < min_x and velocity.x < 0.0) or (old_position.x > max_x and velocity.x > 0.0):
		velocity.x = 0.0
	if (old_position.z < min_z and velocity.z < 0.0) or (old_position.z > max_z and velocity.z > 0.0):
		velocity.z = 0.0

# --- WITCHER MAGIC SIGNS (AoE - hits all around, no directional cone) ---
func cast_igni() -> void:
	current_mana = max(0.0, current_mana - 35.0)
	print("[Magic] Casting IGNI (Fireblast)!")
	_play_sound("igni")
	if hud and hud.has_method("show_notification"):
		hud.show_notification("🔥 IGNI FIREBLAST CAST!", Color(1.0, 0.4, 0.1, 1))

	# AoE burst - hits ALL enemies within 7 units (360 degrees)
	var all_enemies := get_tree().root.find_children("*", "CharacterBody3D", true, false)
	for enemy in all_enemies:
		if (enemy is EnemyAI or enemy is BossTroll) and not enemy.is_dead:
			var dist: float = global_position.distance_to(enemy.global_position)
			if dist <= 7.0:
				print("[Magic] Igni burned: ", enemy.enemy_name)
				enemy.take_damage(45.0)

	if sprite:
		var tween := create_tween()
		tween.tween_property(sprite, "modulate", Color(1.0, 0.3, 0.0, 1), 0.15)
		tween.tween_property(sprite, "modulate", Color(1, 1, 1, 1), 0.15)

func cast_quen() -> void:
	current_mana = max(0.0, current_mana - 40.0)
	has_quen_shield = true
	print("[Magic] Casting QUEN (Magic Shield)!")
	_play_sound("quen")
	if hud and hud.has_method("show_notification"):
		hud.show_notification("🛡️ QUEN SHIELD ACTIVE! Absorbs next hit!", Color(1.0, 0.9, 0.2, 1))
	if sprite:
		sprite.modulate = Color(1.0, 0.9, 0.3, 1)

# --- INTERACTION LOGIC ---
func try_interact() -> void:
	print("[Interact] Pressed E! Checking for nearby objects...")
	if not dialogue_ui:
		_find_ui()

	# 1. Check Treasure Chests
	var all_chests := get_tree().root.find_children("*", "TreasureChest", true, false)
	for chest in all_chests:
		if chest is TreasureChest and not chest.is_opened:
			var dist: float = global_position.distance_to(chest.global_position)
			if dist <= 4.0:
				print("[Interact] Opening chest: ", chest.chest_name)
				chest.interact(self)
				return

	# 2. Check Groq NPCs
	if interact_area and dialogue_ui:
		for body in interact_area.get_overlapping_bodies():
			if body is GroqNPCAI:
				print("[Interact] Opening dialogue with: ", body.npc_name)
				dialogue_ui.open_dialogue(body)
				return

	# 3. Check Villagers
	if interact_area and dialogue_ui:
		for body in interact_area.get_overlapping_bodies():
			if body.has_method("interact") and body.has_method("_pick_new_target"):
				var vname = body.villager_name if "villager_name" in body else "Villager"
				print("[Interact] Talking to villager: ", vname)
				body.interact()
				return

	# 4. Distance failsafe
	if dialogue_ui:
		var all_nodes := get_tree().root.find_children("*", "Node3D", true, false)
		for node in all_nodes:
			if node is GroqNPCAI:
				var dist: float = global_position.distance_to(node.global_position)
				if dist <= 5.0:
					print("[Interact] Distance check: opening dialogue with: ", node.npc_name)
					dialogue_ui.open_dialogue(node)
					return

		for node in all_nodes:
			if node.has_method("interact") and node.has_method("_pick_new_target"):
				var dist: float = global_position.distance_to(node.global_position)
				if dist <= 5.0:
					var vname2 = node.villager_name if "villager_name" in node else "Villager"
					print("[Interact] Talking to villager (distance): ", vname2)
					node.interact()
					return

	print("[Interact] Nothing in reach!")
	if hud and hud.has_method("show_notification"):
		hud.show_notification("Nothing in reach to interact with!", Color(1, 0.7, 0.2, 1))

# --- COMBAT FUNCTIONS ---
func start_attack() -> void:
	is_attacking = true
	_play_sound("slash")
	current_stamina = max(0.0, current_stamina - 15.0)
	if hud and hud.has_method("update_stamina"):
		hud.update_stamina(current_stamina, max_stamina)

	print("Swinging sword/axe! (Attack initiated)")

	# Cancel any leftover z-rotation from older attack tween polish.
	if sprite:
		sprite.rotation.z = 0.0

	# Hitbox stays off during wind-up; enabled on slash frames by _sync_attack_hitbox().
	if melee_hitbox:
		melee_hitbox.monitoring = false

	_set_anim_state(AnimState.ATTACK, true)
	_sync_attack_hitbox()

func _on_melee_hit(body: Node3D) -> void:
	if body.has_method("take_damage") and body != self:
		body.take_damage(attack_damage)
		print("Hit target: ", body.name, " for ", attack_damage, " damage!")

func _get_combat_feedback():
	var tree := get_tree()
	var feedback = tree.root.find_child("CombatFeedback", true, false)
	if feedback:
		return feedback

	var feedback_script = load("res://scripts/combat_feedback.gd")
	if feedback_script == null:
		return null

	feedback = Node.new()
	feedback.name = "CombatFeedback"
	feedback.set_script(feedback_script)

	var parent: Node = tree.current_scene
	if parent == null:
		parent = tree.root
	parent.add_child(feedback)
	return feedback

func take_damage(amount: float) -> void:
	var feedback = _get_combat_feedback()
	var impact_pos := global_position + Vector3(0, 1.15, 0)

	if has_quen_shield:
		has_quen_shield = false
		print("[Magic] Quen Shield absorbed the attack!")
		if feedback:
			feedback.spawn_floating_text("BLOCK", impact_pos + Vector3(0, 0.65, 0), Color(1.0, 0.9, 0.25, 1), 58, 1.2)
			feedback.spawn_impact_effect(impact_pos, Color(1.0, 0.9, 0.25, 1), 0.72, 9)
			feedback.screen_shake(0.11, 0.12)
		if hud and hud.has_method("show_notification"):
			hud.show_notification("✨ Quen Shield Absorbed " + str(amount) + " Dmg!", Color(1.0, 0.9, 0.2, 1))
		if sprite:
			sprite.modulate = Color(1, 1, 1, 1)
		return

	current_health = max(0.0, current_health - amount)
	print("[Player] OUCH! Took ", amount, " damage from enemy! Health remaining: ", current_health)

	if feedback:
		feedback.spawn_damage_number(amount, impact_pos + Vector3(0, 0.75, 0), Color(1.0, 0.25, 0.18, 1), amount >= 30.0)
		feedback.spawn_impact_effect(impact_pos, Color(1.0, 0.16, 0.10, 1), 0.62, 8)
		feedback.screen_shake(0.18, 0.18)
		feedback.hit_flash(sprite, Color(1.0, 0.08, 0.05, 1), 0.04, 0.12)

	if hud:
		if hud.has_method("update_health"):
			hud.update_health(current_health, max_health)
		if hud.has_method("show_notification"):
			hud.show_notification("Took " + str(amount) + " Damage!", Color(1, 0.2, 0.2, 1))

	if current_health <= 0:
		print("[Player] You have fallen in battle! Respawning...")
		if hud and hud.has_method("show_notification"):
			hud.show_notification("You Died! Respawning...", Color(1, 0.1, 0.1, 1))
		global_position = Vector3(0, 0.5, 5)
		current_health = max_health
		current_stamina = max_stamina
		current_mana = max_mana
		has_quen_shield = false
		if hud:
			if hud.has_method("update_health"):
				hud.update_health(current_health, max_health)
			if hud.has_method("update_stamina"):
				hud.update_stamina(current_stamina, max_stamina)
			if hud.has_method("update_mana"):
				hud.update_mana(current_mana, max_mana)

func take_healing(amount: float) -> void:
	var old_hp := current_health
	current_health = min(max_health, current_health + amount)
	if current_health > old_hp and hud:
		if hud.has_method("update_health"):
			hud.update_health(current_health, max_health)

func add_gold(amount: int) -> void:
	gold_coins += amount
	_play_sound("coin")
	if hud:
		if hud.has_method("update_gold"):
			hud.update_gold(gold_coins)
		if hud.has_method("show_notification"):
			hud.show_notification("+ " + str(amount) + " Gold Coins Bounty!", Color(1, 0.84, 0.0, 1))

func equip_weapon(weapon_name: String, new_damage: float, tint: Color) -> void:
	current_weapon_name = weapon_name
	attack_damage = new_damage
	print("[Player] Equipped new weapon: ", weapon_name, " (Damage: ", attack_damage, ")")
	if hud:
		if hud.has_method("update_weapon"):
			hud.update_weapon(weapon_name, attack_damage)
		if hud.has_method("show_notification"):
			hud.show_notification("Equipped: " + weapon_name + "!", tint)
	if sprite:
		var tween := create_tween()
		tween.tween_property(sprite, "modulate", tint, 0.2)
		tween.tween_property(sprite, "modulate", Color(1, 1, 1, 1), 0.2)

func on_bandit_slain() -> void:
	bandits_slain += 1
	print("[Quest] Bandit slain! Progress: ", bandits_slain, " / ", quest_target)
	if hud and hud.has_method("update_quest"):
		hud.update_quest(bandits_slain, quest_target, quest_completed)

	if bandits_slain >= quest_target and not quest_completed:
		quest_completed = true
		print("[Quest] Quest Complete! Return to Gareth for your reward!")
		if hud and hud.has_method("show_notification"):
			hud.show_notification("📜 Quest Complete! Return to Gareth!", Color(0.3, 1.0, 0.4, 1))

func level_up() -> void:
	player_level += 1
	max_health += 50.0
	current_health = max_health
	max_stamina += 25.0
	current_stamina = max_stamina
	max_mana += 25.0
	current_mana = max_mana
	print("[Player] LEVELED UP! Now Level ", player_level)
	_play_sound("fanfare")
	if hud:
		if hud.has_method("update_health"):
			hud.update_health(current_health, max_health)
		if hud.has_method("update_stamina"):
			hud.update_stamina(current_stamina, max_stamina)
		if hud.has_method("update_mana"):
			hud.update_mana(current_mana, max_mana)
		if hud.has_method("show_notification"):
			hud.show_notification("✨ LEVEL UP! HP, Stamina & Mana Boosted!", Color(0.3, 1.0, 0.4, 1))
