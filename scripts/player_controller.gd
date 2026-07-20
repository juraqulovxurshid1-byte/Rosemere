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
@export var max_health: float = 300.0
@export var max_stamina: float = 100.0
@export var max_focus: float = 100.0
@export var attack_duration: float = 0.67
@export var attack_damage: float = 25.0
var current_health: float = max_health
var current_stamina: float = max_stamina
var current_focus: float = max_focus
var gold_coins: int = 0
var current_weapon_name: String = "Rusty Sword"
var is_attacking: bool = false
var is_matrix_dodging: bool = false
var is_defencing: bool = false
var is_montante_attacking: bool = false
var is_hand_defencing: bool = false
var matrix_dodge_face_left: bool = false
var current_speed: float = move_speed
var stamina_regen_timer: float = 0.0
var focus_regen_timer: float = 0.0

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
const WALK_JUMP_SHEET_PATH := "res://art_v2/player_walk_jump_sheet.png"
const IDLE_JUMP_SHEET_PATH := "res://art_v2/player_idle_jump_sheet.png"
const MATRIX_DODGE_SHEET_PATH := "res://art_v2/player_matrix_dodge_sheet.png"
const DEFENCE_SHEET_PATH := "res://art_v2/player_defence_sheet.png"

const IDLE_FRAME_COUNT := 6
const WALK_FRAME_COUNT := 8
const RUN_FRAME_COUNT := 10
const ATTACK_FRAME_COUNT := 10
const RUN_JUMP_FRAME_COUNT := 9
const WALK_JUMP_FRAME_COUNT := 13
const IDLE_JUMP_FRAME_COUNT := 7
const MATRIX_DODGE_FRAME_COUNT := 8
const DEFENCE_FRAME_COUNT := 9
const DEFENCE_FRAME_SIZE := Vector2i(403, 418)
const DEFENCE_COLUMNS := 9
const RUN_JUMP_APEX_FRAME := 4  # peak pose
const IDLE_FRAME_SIZE := Vector2i(328, 466)
const WALK_FRAME_SIZE := Vector2i(640, 640)
const RUN_FRAME_SIZE := Vector2i(640, 640)
const ATTACK_FRAME_SIZE := Vector2i(596, 306)
const IDLE_JUMP_FRAME_SIZE := Vector2i(303, 742)  # 5×2 anchor-aligned individual frames
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
# Run-jump one-shot (9 frames, sprint_jump_velocity=6.6). ~1.48s total at 5.2 FPS.
# Physics: sprint_jump_velocity=6.6, gravity=9.8 -> 1.3469s air time.
# Frame 7 (Landing) at index 7: 7 x frame_time = 7/5.2 = 1.3462s <- exact match.
const RUN_JUMP_FPS := 5.197
# Walk-jump one-shot (13 frames). Frame 12 (grounded recovery) starts at exactly
# the physics landing moment: 7 air frames x frame_time = total_air_time = 1.0612s.
const WALK_JUMP_FPS := 6.6
# Idle-jump one-shot (7 frames). ~1.49s total at 4.71 FPS.
# Physics: jump_velocity=5.2, gravity=9.8 -> 1.0612s air time.
# Frame 5 (Landing) at index 5: 5 x frame_time = 5/4.71 = 1.0612s <- exact match.
const IDLE_JUMP_FPS := 4.71
# Dodge one-shot (8 frames). ~0.57s total at 14 FPS (faster than attack's 0.67s).
const MATRIX_DODGE_FPS := 14.0
const DEFENCE_FPS := 8.0
# Montante attack one-shot (14 frames). ~1.17s total at 12 FPS.
# Held-channel: player must hold Alt+Left Click throughout.
const MONTANTE_SHEET_PATH := "res://art_v2/player_montante_attack_sheet.png"
const MONTANTE_FRAME_COUNT := 11
const MONTANTE_LOOP_START := 3  # frames 0-2 windup, then loop from 3 to 10
const MONTANTE_FPS := 6.0
const MONTANTE_FRAME_SIZE := Vector2i(395, 328)
const MONTANTE_COLUMNS := 11
const MONTANTE_PIXEL_SIZE := 0.02381  # match idle body: 4.19u / 176px (frame 0 body width)
const MONTANTE_FOCUS_DRAIN_RATE := 15.0  # focus drained per second while channeling
const MONTANTE_HIT_FRAME_START := 5
const MONTANTE_HIT_FRAME_END := 10
# Hand defence one-shot (7 frames). Right Click. Half damage taken while active.
const HAND_DEFENCE_SHEET_PATH := "res://art_v2/player_hand_defence_sheet.png"
const HAND_DEFENCE_FRAME_COUNT := 6
const HAND_DEFENCE_FPS := 10.0
const HAND_DEFENCE_FRAME_SIZE := Vector2i(407, 370)
const HAND_DEFENCE_COLUMNS := 7
const HAND_DEFENCE_PIXEL_SIZE := 0.022  # compensate for hunched defence posture
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
# New 9-frame sheet at 3:1 ratio. Frames are ~214px wide; pixel_size scaled to
# match RUN width (7.29 world units): 7.29 / 214 = 0.03407.
const RUN_JUMP_PIXEL_SIZE := 0.03407
const RUN_JUMP_SPRITE_Y := 4.091

# Walk-jump sheet (first frame removed → 13 frames)
# Clean single-row atlas. Body scale already tuned to match walk (0.0315).
const WALK_JUMP_PIXEL_SIZE := 0.0315
const WALK_JUMP_SPRITE_Y := 3.60
const IDLE_JUMP_PIXEL_SIZE := 0.01747  # match IDLE_PIXEL_SIZE
const IDLE_JUMP_SPRITE_Y := 3.852     # match IDLE_SPRITE_Y
# Dodge sheet: 2172x724 (3:1), 8 frames. Pixel_size scaled to match RUN width.
# Frame 0 content ~219px at 0.03329 = 7.29 world units (matches RUN).
const MATRIX_DODGE_PIXEL_SIZE := 0.01747  # match IDLE_PIXEL_SIZE
const MATRIX_DODGE_SPRITE_Y := 3.852  # same feet placement as idle
const DEFENCE_PIXEL_SIZE := 0.01747  # match IDLE_PIXEL_SIZE
const DEFENCE_SPRITE_Y := 3.852

# Controls for "crouch before liftoff" feel without delaying the actual physics jump
# Strategy:
# - Physics jump (velocity.y) is ALWAYS instant (no combat delay)
# - Animation starts at the crouch (frame 2)
# - The crouch/windup frames (2-4) play at very high speed so they flash by quickly
# - As soon as we detect we are airborne, we skip straight to the first real air frame (5)
const WALK_JUMP_TAKEOFF_START_FRAME := 4   # start directly at the deepest crouch (frame 4) so we show almost no "feet on ground" before air
const WALK_JUMP_AIR_START_FRAME := 5          # first frame that is clearly in the air
const WALK_JUMP_FAST_WINDUP_FRAMES := 4
const WALK_JUMP_FAST_WINDUP_MULTIPLIER := 2.8

# Hardcoded from the corrected player_walk_jump_sheet.json (13 frames)
# FULL ORIGINAL FRAME CONTENT (no tight-bbox / no extra cropping)
# Every painted pixel from the source is preserved — including the very bottom of the feet.
# NATURAL FOOT PLACEMENT (per user spec):
#   Frames 2,3,4 : feet still on ground
#   Frames 5-11  : in the air (pyramid lift, max at frame 9)
#   Frame 12     : feet back on ground
# First original frame was removed. Single-row atlas.
const WALK_JUMP_FRAMES: Array[Rect2] = [
	Rect2(20, 20, 1550, 720),  # 0
	Rect2(1576, 20, 1550, 720),  # 1
	Rect2(3132, 20, 1550, 720),  # 2
	Rect2(4688, 20, 1550, 720),  # 3
	Rect2(6244, 20, 1550, 720),  # 4
	Rect2(7800, 20, 1550, 720),  # 5
	Rect2(9356, 20, 1550, 720),  # 6
	Rect2(10912, 20, 1550, 720),  # 7
	Rect2(12468, 20, 1550, 720),  # 8
	Rect2(14024, 20, 1550, 720),  # 9
	Rect2(15580, 20, 1550, 720),  # 10
	Rect2(17136, 20, 1550, 720),  # 11
	Rect2(18692, 20, 1550, 720),  # 12
]

# Idle-jump frames: 7 frames laid out in a 2120x742 single-row atlas.
# Frames are positioned to follow the jump arc naturally (apex high, landing low).
# The centered=true sprite uses the center of each varying-size rect,
# so the character rises and falls through the animation automatically.
# Phase 1: Anticipation (frames 0-1) - crouch then launch
# Phase 2: Ascent & Apex (frames 2-4) - rising, peak, falling
# Phase 3: Impact & Recovery (frames 5-6) - landing, recover
const IDLE_JUMP_FRAMES: Array[Rect2] = [
	Rect2(11, 333, 279, 314),   # 0: crouch / wind-up
	Rect2(333, 130, 242, 514),  # 1: launch / explode upward
	Rect2(647, 100, 219, 394),  # 2: rising
	Rect2(930, 50, 260, 316),   # 3: APEX / peak
	Rect2(1244, 168, 237, 454), # 4: falling
	Rect2(1450, 384, 430, 265), # 5: landing / impact
	Rect2(1861, 258, 214, 388), # 6: recovery
]

# Run-jump frames: 9 frames on a 2172x724 canvas (3:1 ratio).
# Each frame is tightly cropped to content + 8px padding, positioned to follow
# the sprint-jump arc (launch low -> apex high -> land low).
# Per-frame sprite.position.y = (rect.h / 2 - feet_from_bottom) * RUN_JUMP_PIXEL_SIZE
# ensures feet always sit at y=0 ground level.
const RUN_JUMP_FRAMES: Array[Rect2] = [
	Rect2(81, 525, 221, 199),   # 0: launch
	Rect2(306, 435, 256, 225),  # 1: rising
	Rect2(566, 379, 236, 218),  # 2: rising
	Rect2(806, 355, 227, 178),  # 3: rising
	Rect2(1037, 252, 198, 218), # 4: APEX
	Rect2(1239, 302, 186, 253), # 5: falling
	Rect2(1429, 481, 247, 158), # 6: falling
	Rect2(1680, 507, 223, 217), # 7: landing
	Rect2(1907, 503, 183, 221), # 8: recovery
]

# Matrix dodge frames: 8 frames on a 2172x724 canvas (3:1 ratio).
# Ground-level dodge back. All frames bottom-aligned (feet on ground).
const MATRIX_DODGE_FRAMES: Array[Rect2] = [
	Rect2(116, 318, 226, 411),  # 0
	Rect2(346, 358, 259, 371),  # 1
	Rect2(609, 401, 263, 328),  # 2
	Rect2(876, 410, 275, 320),  # 3
	Rect2(1155, 357, 227, 372), # 4
	Rect2(1386, 338, 215, 391), # 5
	Rect2(1605, 313, 215, 416), # 6
	Rect2(1824, 321, 231, 408), # 7
]

enum AnimState { IDLE, WALK, RUN, ATTACK, RUN_JUMP, WALK_JUMP, IDLE_JUMP, MATRIX_DODGE, DEFENCE, MONTANTE, HAND_DEFENCE }

var tex_idle: Texture2D = null
var tex_idle_sheet: Texture2D = null
var tex_walk_sheet: Texture2D = null
var tex_run_sheet: Texture2D = null
var tex_attack_sheet: Texture2D = null
var tex_run_jump_sheet: Texture2D = null
var tex_walk_jump_sheet: Texture2D = null
var tex_idle_jump_sheet: Texture2D = null
var tex_matrix_dodge_sheet: Texture2D = null
var tex_defence_sheet: Texture2D = null
var tex_montante_sheet: Texture2D = null
var tex_hand_defence_sheet: Texture2D = null
var anim_timer: float = 0.0
var anim_frame: int = 0
var current_anim: AnimState = AnimState.IDLE
var was_sprinting_on_jump: bool = false
var run_jump_face_left: bool = false
var run_jump_left_ground: bool = false
var walk_jump_left_ground: bool = false
var walk_jump_face_left: bool = false
var idle_jump_left_ground: bool = false
var idle_jump_face_left: bool = false
var dialogue_ui: DialogueUI = null
var hud: HUD = null


func _ready() -> void:
	current_health = max_health
	current_stamina = max_stamina
	current_focus = max_focus

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
	tex_walk_jump_sheet = load(WALK_JUMP_SHEET_PATH) as Texture2D
	tex_idle_jump_sheet = load(IDLE_JUMP_SHEET_PATH) as Texture2D
	tex_matrix_dodge_sheet = load(MATRIX_DODGE_SHEET_PATH) as Texture2D
	tex_defence_sheet = load(DEFENCE_SHEET_PATH) as Texture2D
	tex_montante_sheet = load(MONTANTE_SHEET_PATH) as Texture2D
	tex_hand_defence_sheet = load(HAND_DEFENCE_SHEET_PATH) as Texture2D

	if tex_walk_jump_sheet == null:
		push_error("CRITICAL: Failed to load walk-jump sheet: " + WALK_JUMP_SHEET_PATH)
	else:
		print("[Player] Successfully loaded walk-jump sheet: ", WALK_JUMP_SHEET_PATH)

	if tex_idle_jump_sheet == null:
		push_warning("Missing idle-jump sheet: " + IDLE_JUMP_SHEET_PATH)
	else:
		print("[Player] Loaded idle-jump sheet: ", IDLE_JUMP_SHEET_PATH)

	if tex_run_jump_sheet == null:
		push_warning("Missing run-jump sheet: " + RUN_JUMP_SHEET_PATH)
	if tex_walk_jump_sheet == null:
		push_warning("Missing walk-jump sheet: " + WALK_JUMP_SHEET_PATH)
	if tex_idle_jump_sheet == null:
		push_warning("Missing idle-jump sheet: " + IDLE_JUMP_SHEET_PATH)
	if tex_matrix_dodge_sheet == null:
		push_warning("Missing dodge sheet: " + MATRIX_DODGE_SHEET_PATH)
	if tex_defence_sheet == null:
		push_warning("Missing defence sheet: " + DEFENCE_SHEET_PATH)
	if tex_montante_sheet == null:
		push_warning("Missing montante sheet: " + MONTANTE_SHEET_PATH)
	if tex_hand_defence_sheet == null:
		push_warning("Missing hand defence sheet: " + HAND_DEFENCE_SHEET_PATH)

	_set_anim_state(AnimState.IDLE, true)

func _ensure_input_mappings() -> void:
	var key_mappings := {
		"move_forward": [KEY_W, KEY_UP],
		"move_backward": [KEY_S, KEY_DOWN],
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"interact": [KEY_E],
		"sprint": [KEY_SHIFT],
		"defence": [KEY_R]
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
		if hud.has_method("update_focus"):
			hud.update_focus(current_focus, max_focus)
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
	elif type == "fanfare": sm.play_fanfare()
	elif type == "voice": sm.play_voice(extra)

func stop_voice() -> void:
	var sm := get_tree().root.find_child("SoundManager", true, false) as SoundManager
	if sm and sm.has_method("stop_voice"):
		sm.stop_voice()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		try_interact()
	
	# Montante Attack: Alt + Left Click (held channel)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and Input.is_key_pressed(KEY_ALT) and not is_montante_attacking and not is_attacking and not is_matrix_dodging and not is_defencing and is_on_floor():
		if current_focus >= 10.0:
			start_montante()
		else:
			if hud and hud.has_method("show_notification"):
				hud.show_notification("Not enough Focus!", Color(0.3, 0.6, 1.0, 1))

	# Matrix Dodge: Alt + Right Click
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed and Input.is_key_pressed(KEY_ALT) and not is_matrix_dodging and is_on_floor():
		if current_focus >= 25.0:
			start_matrix_dodge()
		else:
			if hud and hud.has_method("show_notification"):
				hud.show_notification("Not enough Focus!", Color(0.3, 0.6, 1.0, 1))

	# Hand Defence: Right Click (no Alt)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed and not Input.is_key_pressed(KEY_ALT) and not is_hand_defencing and not is_attacking and not is_matrix_dodging and is_on_floor():
		start_hand_defence()

	if event.is_action_pressed("defence") and not is_defencing and is_on_floor():
		if current_stamina >= 10.0:
			start_defence()
		else:
			if hud and hud.has_method("show_notification"):
				hud.show_notification("Not enough Stamina!", Color(1, 0.4, 0.4, 1))

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
	if Input.is_action_just_pressed("attack") and not Input.is_key_pressed(KEY_ALT) and not is_attacking and not is_matrix_dodging and is_on_floor():
		if current_stamina >= 15.0:
			start_attack()
		else:
			if hud and hud.has_method("show_notification"):
				hud.show_notification("Not enough Stamina!", Color(1, 0.4, 0.4, 1))


	# Montante held-channel: update animation + movement in physics
	if is_montante_attacking:
		if not Input.is_key_pressed(KEY_ALT) or not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_finish_montante()
		else:
			# Drain focus (15/sec) and stamina (7.5/sec, 1x slower)
			current_focus = max(0.0, current_focus - MONTANTE_FOCUS_DRAIN_RATE * delta)
			current_stamina = max(0.0, current_stamina - MONTANTE_FOCUS_DRAIN_RATE * 0.5 * delta)
			stamina_regen_timer = 0.7
			if hud and hud.has_method("update_focus"):
				hud.update_focus(current_focus, max_focus)
			if hud and hud.has_method("update_stamina"):
				hud.update_stamina(current_stamina, max_stamina)
			if current_focus <= 0 or current_stamina <= 0:
				_finish_montante()
			else:
				# Advance montante animation — loop frames 3-10 forever
				_apply_montante_frame(anim_frame)
				anim_timer += delta
				var ft := 1.0 / MONTANTE_FPS
				if anim_timer >= ft:
					var steps := int(anim_timer / ft)
					anim_timer -= steps * ft
					var next_frame := anim_frame + steps
					# Loop: frames 0-2 play once (windup), then 3-10 loop
					if next_frame > MONTANTE_FRAME_COUNT - 1:
						next_frame = MONTANTE_LOOP_START + ((next_frame - MONTANTE_LOOP_START) % (MONTANTE_FRAME_COUNT - MONTANTE_LOOP_START))
					anim_frame = next_frame
					_apply_montante_frame(anim_frame)
					_sync_montante_hitbox()

	if is_attacking or is_matrix_dodging or is_defencing or is_hand_defencing:
		velocity.x = move_toward(velocity.x, 0, acceleration * delta)
		velocity.z = move_toward(velocity.z, 0, acceleration * delta)
		_update_sprite_animation(delta)
		move_and_slide()
		_clamp_to_world_bounds()
		return

	# 3. Handle Jump
	# Sprint-jump: high pyramid arc + forward leap + full RUN_JUMP sheet.
	# Idle/walk-jump: lower hop (no run-jump sheet yet).
	var is_in_jump_anim := current_anim == AnimState.RUN_JUMP or current_anim == AnimState.WALK_JUMP or current_anim == AnimState.IDLE_JUMP or current_anim == AnimState.MATRIX_DODGE or current_anim == AnimState.DEFENCE or current_anim == AnimState.HAND_DEFENCE
	if not is_in_jump_anim and Input.is_action_just_pressed("ui_accept") and is_on_floor() and not is_attacking and not is_matrix_dodging and not is_defencing and not is_montante_attacking and not is_hand_defencing:
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

			# Sprint-jump drains stamina at higher rate (old sprint rate)
			current_stamina = max(0.0, current_stamina - 20.0 * delta)
			stamina_regen_timer = 0.7
			if hud and hud.has_method("update_stamina"):
				hud.update_stamina(current_stamina, max_stamina)

			run_jump_face_left = sprite.flip_h if sprite else (velocity.x < 0.0)
			run_jump_left_ground = false
			anim_timer = 0.0
			anim_frame = 0
			_set_anim_state(AnimState.RUN_JUMP, true)
			_apply_run_jump_frame(0)
			if sprite:
				sprite.flip_h = run_jump_face_left
		else:
			# Determine whether this is a walk jump (moving) or idle jump (standing still)
			var move_input_jump := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
			var is_moving_for_jump := move_input_jump.length() > 0.35 or Vector2(velocity.x, velocity.z).length() > 0.35

			if is_moving_for_jump:
				# WALK JUMP using walk-jump sheet (connected feel while moving)
				# Physics jump is INSTANT (combat responsive).
				print("[Player] Walk jump -> WALK_JUMP")
				velocity.y = jump_velocity
				walk_jump_face_left = sprite.flip_h if sprite else (velocity.x < 0.0)
				walk_jump_left_ground = false
				anim_timer = 0.0
				anim_frame = WALK_JUMP_TAKEOFF_START_FRAME
				print("[Jump] Walk jump (moving) -> WALK_JUMP state")
				_set_anim_state(AnimState.WALK_JUMP, true)
				_apply_walk_jump_frame(anim_frame)
				if sprite:
					sprite.flip_h = walk_jump_face_left
			else:
				# IDLE JUMP using idle-jump sheet (jump from standing still)
				# 7-frame one-shot: crouch -> launch -> rise -> apex -> fall -> land -> recover
				print("[Player] Idle jump -> IDLE_JUMP")
				velocity.y = jump_velocity
				idle_jump_face_left = sprite.flip_h if sprite else (velocity.x < 0.0)
				idle_jump_left_ground = false
				anim_timer = 0.0
				anim_frame = 0
				print("[Jump] Idle jump (standing) -> IDLE_JUMP state")
				_set_anim_state(AnimState.IDLE_JUMP, true)
				_apply_idle_jump_frame(0)
				if sprite:
					sprite.flip_h = idle_jump_face_left

	# Do not let the normal locomotion state machine override jump one-shots.
	# But keep processing so stamina keeps draining during jumps.
	# 4. Handle Sprint, Stamina & Focus Regen (with 0.7s delay like Dark Souls)
	if is_montante_attacking:
		current_speed = move_speed * 0.5  # slow walk during montante
	elif Input.is_action_pressed("sprint") and velocity.length() > 0.5 and current_stamina > 0:
		current_speed = sprint_speed
		current_stamina = max(0.0, current_stamina - 10.0 * delta)
		stamina_regen_timer = 0.7
	else:
		current_speed = move_speed
		if stamina_regen_timer > 0:
			stamina_regen_timer -= delta
		else:
			current_stamina = min(max_stamina, current_stamina + 8.0 * delta)

	# Don't regen focus during montante — the drain handles it
	if not is_montante_attacking:
		if focus_regen_timer > 0:
			focus_regen_timer -= delta
		else:
			current_focus = min(max_focus, current_focus + 8.0 * delta)

	if hud:
		if hud.has_method("update_stamina"):
			hud.update_stamina(current_stamina, max_stamina)
		if hud.has_method("update_focus"):
			hud.update_focus(current_focus, max_focus)

	# Skip movement input during jump animations — stamina already processed above
	if is_in_jump_anim:
		_update_sprite_animation(delta)
		move_and_slide()
		_clamp_to_world_bounds()
		return

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
	elif sprite and current_anim == AnimState.WALK_JUMP:
		sprite.flip_h = walk_jump_face_left
	elif sprite and current_anim == AnimState.IDLE_JUMP:
		sprite.flip_h = idle_jump_face_left
	elif sprite and current_anim == AnimState.MATRIX_DODGE:
		sprite.flip_h = matrix_dodge_face_left
	elif sprite and current_anim == AnimState.DEFENCE:
		sprite.flip_h = velocity.x < 0.0
	elif sprite and current_anim == AnimState.MONTANTE:
		sprite.flip_h = velocity.x < 0.0
	elif sprite and current_anim == AnimState.HAND_DEFENCE:
		sprite.flip_h = velocity.x < 0.0
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

	# Idle-jump one-shot: 7-frame sequence (standing jump)
	if current_anim == AnimState.IDLE_JUMP:
		if not is_on_floor():
			idle_jump_left_ground = true

		# Always keep correct texture/region bound
		_apply_idle_jump_frame(anim_frame)

		anim_timer += delta
		var frame_time := 1.0 / IDLE_JUMP_FPS
		if anim_timer >= frame_time:
			var steps := int(anim_timer / frame_time)
			anim_timer -= steps * frame_time
			anim_frame = mini(anim_frame + steps, IDLE_JUMP_FRAME_COUNT - 1)
			_apply_idle_jump_frame(anim_frame)

		# Early land: skip to landing/recover frames
		if idle_jump_left_ground and is_on_floor():
			var land_start := IDLE_JUMP_FRAME_COUNT - 2  # show landing frame
			if anim_frame < land_start:
				anim_frame = land_start
				_apply_idle_jump_frame(anim_frame)
			if anim_frame >= IDLE_JUMP_FRAME_COUNT - 1:
				_finish_idle_jump()
				return

		if anim_frame >= IDLE_JUMP_FRAME_COUNT - 1:
			if is_on_floor() and idle_jump_left_ground:
				_finish_idle_jump()
		return

	# Dodge one-shot: 8-frame sequence
	if current_anim == AnimState.MATRIX_DODGE:
		_apply_matrix_dodge_frame(anim_frame)

		anim_timer += delta
		var frame_time := 1.0 / MATRIX_DODGE_FPS
		if anim_timer >= frame_time:
			var steps := int(anim_timer / frame_time)
			anim_timer -= steps * frame_time
			anim_frame = mini(anim_frame + steps, MATRIX_DODGE_FRAME_COUNT - 1)
			_apply_matrix_dodge_frame(anim_frame)

		if anim_frame >= MATRIX_DODGE_FRAME_COUNT - 1:
			_finish_matrix_dodge()
		return

	# Defence one-shot: 9-frame sequence
	if current_anim == AnimState.DEFENCE:
		_apply_defence_frame(anim_frame)

		anim_timer += delta
		var frame_time := 1.0 / DEFENCE_FPS
		if anim_timer >= frame_time:
			var steps := int(anim_timer / frame_time)
			anim_timer -= steps * frame_time
			anim_frame = mini(anim_frame + steps, DEFENCE_FRAME_COUNT - 1)
			_apply_defence_frame(anim_frame)

		if anim_frame >= DEFENCE_FRAME_COUNT - 1:
			_finish_defence()
		return

	# Hand defence one-shot: 7-frame sequence
	if current_anim == AnimState.HAND_DEFENCE:
		_apply_hand_defence_frame(anim_frame)

		anim_timer += delta
		var frame_time := 1.0 / HAND_DEFENCE_FPS
		if anim_timer >= frame_time:
			var steps := int(anim_timer / frame_time)
			anim_timer -= steps * frame_time
			anim_frame = mini(anim_frame + steps, HAND_DEFENCE_FRAME_COUNT - 1)
			_apply_hand_defence_frame(anim_frame)

		if anim_frame >= HAND_DEFENCE_FRAME_COUNT - 1:
			_finish_hand_defence()
		return

	# Montante: handled in _physics_process, just guard against locomotion override
	if current_anim == AnimState.MONTANTE:
		return

	# Walk-jump one-shot (new connected walk-to-jump animation)
	if current_anim == AnimState.WALK_JUMP:
		if not is_on_floor():
			walk_jump_left_ground = true

		# CRITICAL FIX: Never show ground/crouch frames while we are actually airborne.
		# Physics jump is instant. We must not wait for is_on_floor() to update.
		# Use velocity.y > 0 (we are moving upward) as the reliable airborne signal.
		var is_airborne_now := not is_on_floor() or velocity.y > 0.1
		if walk_jump_left_ground and is_airborne_now and anim_frame < WALK_JUMP_AIR_START_FRAME:
			anim_frame = WALK_JUMP_AIR_START_FRAME
			anim_timer = 0.0

		_apply_walk_jump_frame(anim_frame)

		# Play the crouch anticipation frames VERY FAST (almost a blink).
		# We want the player to see "he crouched to jump" without the feet appearing stuck on ground.
		var effective_fps := WALK_JUMP_FPS
		if anim_frame < WALK_JUMP_AIR_START_FRAME:
			effective_fps = 60.0   # extremely fast — frames 3 and 4 together last ~0.033 seconds

		anim_timer += delta
		var frame_time := 1.0 / effective_fps
		if anim_timer >= frame_time:
			var steps := int(anim_timer / frame_time)
			anim_timer -= steps * frame_time
			anim_frame = mini(anim_frame + steps, WALK_JUMP_FRAME_COUNT - 1)
			_apply_walk_jump_frame(anim_frame)

		# Early land → go to last frames
		if walk_jump_left_ground and is_on_floor():
			if anim_frame < WALK_JUMP_FRAME_COUNT - 1:
				anim_frame = WALK_JUMP_FRAME_COUNT - 1   # show frame 12 (on the ground)
				_apply_walk_jump_frame(anim_frame)
			if anim_frame >= WALK_JUMP_FRAME_COUNT - 1:
				_finish_walk_jump()
				return

		if anim_frame >= WALK_JUMP_FRAME_COUNT - 1:
			if is_on_floor() and walk_jump_left_ground:
				_finish_walk_jump()
			return

		# IMPORTANT: prevent the locomotion state machine below from overriding the one-shot
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
			# Per-frame Y position set in _apply_run_jump_frame()
			sprite.region_enabled = true
			_apply_run_jump_frame(0)
		AnimState.WALK_JUMP:
			if tex_walk_jump_sheet:
				sprite.texture = tex_walk_jump_sheet
			sprite.offset = Vector2.ZERO
			sprite.centered = true
			sprite.pixel_size = WALK_JUMP_PIXEL_SIZE
			sprite.position = Vector3(0.0, WALK_JUMP_SPRITE_Y, 0.0)
			sprite.region_enabled = true
			# Respect the takeoff start frame (usually 2) so we begin showing the crouch immediately
			var start_f := anim_frame if anim_frame > 0 else WALK_JUMP_TAKEOFF_START_FRAME
			_apply_walk_jump_frame(start_f)
		AnimState.IDLE_JUMP:
			if tex_idle_jump_sheet:
				sprite.texture = tex_idle_jump_sheet
			sprite.offset = Vector2.ZERO
			sprite.centered = true
			sprite.pixel_size = IDLE_JUMP_PIXEL_SIZE
			sprite.position = Vector3(0.0, IDLE_JUMP_SPRITE_Y, 0.0)
			sprite.region_enabled = true
			_apply_idle_jump_frame(0)
		AnimState.MATRIX_DODGE:
			if tex_matrix_dodge_sheet:
				sprite.texture = tex_matrix_dodge_sheet
			sprite.offset = Vector2.ZERO
			sprite.centered = true
			sprite.pixel_size = MATRIX_DODGE_PIXEL_SIZE
			# Per-frame Y position set in _apply_matrix_dodge_frame()
			sprite.region_enabled = true
			_apply_matrix_dodge_frame(0)
		AnimState.DEFENCE:
			if tex_defence_sheet:
				sprite.texture = tex_defence_sheet
			sprite.offset = Vector2.ZERO
			sprite.centered = true
			sprite.pixel_size = DEFENCE_PIXEL_SIZE
			sprite.region_enabled = true
			_apply_defence_frame(0)
		AnimState.MONTANTE:
			if tex_montante_sheet:
				sprite.texture = tex_montante_sheet
			sprite.offset = Vector2.ZERO
			sprite.centered = true
			sprite.pixel_size = MONTANTE_PIXEL_SIZE
			sprite.region_enabled = true
			_apply_montante_frame(0)
		AnimState.HAND_DEFENCE:
			if tex_hand_defence_sheet:
				sprite.texture = tex_hand_defence_sheet
			sprite.offset = Vector2.ZERO
			sprite.centered = true
			sprite.pixel_size = HAND_DEFENCE_PIXEL_SIZE
			sprite.position = Vector3(0.0, (HAND_DEFENCE_FRAME_SIZE.y / 2.0 - 4.0) * HAND_DEFENCE_PIXEL_SIZE, 0.0)
			sprite.region_enabled = true
			_apply_hand_defence_frame(0)


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

	# Use individual precomputed rects (tight crops + Y-arc positioning)
	var rect: Rect2 = RUN_JUMP_FRAMES[frame_index]

	if sprite.texture != tex_run_jump_sheet:
		sprite.texture = tex_run_jump_sheet
	sprite.centered = true
	sprite.offset = Vector2.ZERO
	sprite.pixel_size = RUN_JUMP_PIXEL_SIZE
	# Per-frame Y: feet are 4px from bottom of each rect.
	# (rect.h / 2 - 4) * pixel_size puts feet at y=0.
	sprite.position = Vector3(0.0, (rect.size.y / 2.0 - 4.0) * RUN_JUMP_PIXEL_SIZE, 0.0)
	sprite.region_enabled = true
	sprite.region_rect = rect


func _apply_matrix_dodge_frame(frame_index: int) -> void:
	if sprite == null:
		return
	if tex_matrix_dodge_sheet == null:
		return
	frame_index = clampi(frame_index, 0, MATRIX_DODGE_FRAME_COUNT - 1)

	var rect: Rect2 = MATRIX_DODGE_FRAMES[frame_index]

	if sprite.texture != tex_matrix_dodge_sheet:
		sprite.texture = tex_matrix_dodge_sheet
	sprite.centered = true
	sprite.offset = Vector2.ZERO
	sprite.pixel_size = MATRIX_DODGE_PIXEL_SIZE
	# Per-frame Y: feet are ~5px from bottom of each rect.
	# (rect.h / 2 - 5) * pixel_size puts feet at y=0.
	sprite.position = Vector3(0.0, (rect.size.y / 2.0 - 5.0) * MATRIX_DODGE_PIXEL_SIZE, 0.0)
	sprite.region_enabled = true
	sprite.region_rect = rect


func _apply_montante_frame(frame_index: int) -> void:
	if sprite == null:
		return
	if tex_montante_sheet == null:
		return
	frame_index = clampi(frame_index, 0, MONTANTE_FRAME_COUNT - 1)
	if sprite.texture != tex_montante_sheet:
		sprite.texture = tex_montante_sheet
	sprite.centered = true
	sprite.offset = Vector2.ZERO
	sprite.pixel_size = MONTANTE_PIXEL_SIZE
	# Feet are at bottom of uniform cell (8px padding from bottom)
	sprite.position = Vector3(0.0, (MONTANTE_FRAME_SIZE.y / 2.0 - 4.0) * MONTANTE_PIXEL_SIZE, 0.0)
	sprite.region_enabled = true
	sprite.region_rect = Rect2(frame_index * (MONTANTE_FRAME_SIZE.x + 4), 0, MONTANTE_FRAME_SIZE.x, MONTANTE_FRAME_SIZE.y)


func _sync_montante_hitbox() -> void:
	if melee_hitbox == null:
		return
	var active := (
		current_anim == AnimState.MONTANTE
		and anim_frame >= MONTANTE_HIT_FRAME_START
		and anim_frame <= MONTANTE_HIT_FRAME_END
	)
	melee_hitbox.monitoring = active


func _apply_hand_defence_frame(frame_index: int) -> void:
	if sprite == null:
		return
	if tex_hand_defence_sheet == null:
		return
	frame_index = clampi(frame_index, 0, HAND_DEFENCE_FRAME_COUNT - 1)
	if sprite.texture != tex_hand_defence_sheet:
		sprite.texture = tex_hand_defence_sheet
	sprite.centered = true
	sprite.offset = Vector2.ZERO
	sprite.pixel_size = HAND_DEFENCE_PIXEL_SIZE
	sprite.position = Vector3(0.0, (HAND_DEFENCE_FRAME_SIZE.y / 2.0 - 4.0) * HAND_DEFENCE_PIXEL_SIZE, 0.0)
	sprite.region_enabled = true
	sprite.region_rect = Rect2(frame_index * (HAND_DEFENCE_FRAME_SIZE.x + 4), 0, HAND_DEFENCE_FRAME_SIZE.x, HAND_DEFENCE_FRAME_SIZE.y)


func _apply_defence_frame(frame_index: int) -> void:
	if sprite == null:
		return
	if tex_defence_sheet == null:
		return
	frame_index = clampi(frame_index, 0, DEFENCE_FRAME_COUNT - 1)
	if sprite.texture != tex_defence_sheet:
		sprite.texture = tex_defence_sheet
	sprite.centered = true
	sprite.offset = Vector2.ZERO
	sprite.pixel_size = DEFENCE_PIXEL_SIZE
	sprite.position = Vector3(0.0, (DEFENCE_FRAME_SIZE.y / 2.0 - 6.0) * DEFENCE_PIXEL_SIZE, 0.0)
	sprite.region_enabled = true
	sprite.region_rect = Rect2(frame_index * (DEFENCE_FRAME_SIZE.x + 4), 0, DEFENCE_FRAME_SIZE.x, DEFENCE_FRAME_SIZE.y)


func _apply_idle_jump_frame(frame_index: int) -> void:
	if sprite == null or tex_idle_jump_sheet == null:
		return
	frame_index = clampi(frame_index, 0, IDLE_JUMP_FRAME_COUNT - 1)

	# Use precomputed rects - each frame has its own position and size
	# so the character naturally rises and falls through the jump arc
	# via the varying center point of each rect.
	var rect: Rect2 = IDLE_JUMP_FRAMES[frame_index]

	if sprite.texture != tex_idle_jump_sheet:
		sprite.texture = tex_idle_jump_sheet
	sprite.centered = true
	sprite.offset = Vector2.ZERO
	sprite.pixel_size = IDLE_JUMP_PIXEL_SIZE
	sprite.position = Vector3(0.0, IDLE_JUMP_SPRITE_Y, 0.0)
	sprite.region_enabled = true
	sprite.region_rect = rect


func _apply_walk_jump_frame(frame_index: int) -> void:
	if sprite == null or tex_walk_jump_sheet == null:
		return
	frame_index = clampi(frame_index, 0, WALK_JUMP_FRAME_COUNT - 1)

	# Use precomputed rects from the JSON (trimmed atlas, not uniform grid)
	var rect: Rect2 = WALK_JUMP_FRAMES[frame_index]

	if sprite.texture != tex_walk_jump_sheet:
		sprite.texture = tex_walk_jump_sheet
	sprite.centered = true
	sprite.offset = Vector2.ZERO
	sprite.pixel_size = WALK_JUMP_PIXEL_SIZE
	sprite.position = Vector3(0.0, WALK_JUMP_SPRITE_Y, 0.0)
	sprite.region_enabled = true
	sprite.region_rect = rect


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


func _finish_walk_jump() -> void:
	walk_jump_left_ground = false
	# Return to walk or idle so the animation feels connected to normal locomotion.
	var planar_speed := Vector2(velocity.x, velocity.z).length()
	if planar_speed > 0.35:
		_set_anim_state(AnimState.WALK, true)
	else:
		_set_anim_state(AnimState.IDLE, true)


func _finish_matrix_dodge() -> void:
	is_matrix_dodging = false
	_set_anim_state(AnimState.IDLE, true)

func _finish_defence() -> void:
	is_defencing = false
	_set_anim_state(AnimState.IDLE, true)

func _finish_hand_defence() -> void:
	is_hand_defencing = false
	_set_anim_state(AnimState.IDLE, true)


func _finish_montante() -> void:
	is_montante_attacking = false
	if melee_hitbox:
		melee_hitbox.monitoring = false
	_set_anim_state(AnimState.IDLE, true)


func _finish_idle_jump() -> void:
	idle_jump_left_ground = false
	# Return to idle - the player jumped from standing still.
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
func start_matrix_dodge() -> void:
	is_matrix_dodging = true
	matrix_dodge_face_left = sprite.flip_h if sprite else false
	current_focus = max(0.0, current_focus - 25.0)
	if hud and hud.has_method("update_focus"):
		hud.update_focus(current_focus, max_focus)
	focus_regen_timer = 0.7
	anim_timer = 0.0
	anim_frame = 0
	print("[Player] Matrix Dodge!")
	_set_anim_state(AnimState.MATRIX_DODGE, true)
	_apply_matrix_dodge_frame(0)
	if sprite:
		sprite.flip_h = matrix_dodge_face_left


func start_defence() -> void:
	is_defencing = true
	current_stamina = max(0.0, current_stamina - 10.0)
	if hud and hud.has_method("update_stamina"):
		hud.update_stamina(current_stamina, max_stamina)
	stamina_regen_timer = 0.7
	anim_timer = 0.0
	anim_frame = 0
	print("[Player] Defence!")
	_set_anim_state(AnimState.DEFENCE, true)
	_apply_defence_frame(0)


func start_hand_defence() -> void:
	is_hand_defencing = true
	anim_timer = 0.0
	anim_frame = 0
	print("[Player] Hand defence!")
	_set_anim_state(AnimState.HAND_DEFENCE, true)
	_apply_hand_defence_frame(0)


func start_montante() -> void:
	is_montante_attacking = true
	focus_regen_timer = 0.7
	anim_timer = 0.0
	anim_frame = 0
	print("[Player] Montante attack!")
	_set_anim_state(AnimState.MONTANTE, true)
	_apply_montante_frame(0)
	if melee_hitbox:
		melee_hitbox.monitoring = false


func start_attack() -> void:
	is_attacking = true
	_play_sound("slash")
	current_stamina = max(0.0, current_stamina - 15.0)
	if hud and hud.has_method("update_stamina"):
		hud.update_stamina(current_stamina, max_stamina)
	stamina_regen_timer = 0.7

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

	# Hand defence halves incoming damage
	if is_hand_defencing:
		amount = amount * 0.5

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
		current_focus = max_focus
		if hud:
			if hud.has_method("update_health"):
				hud.update_health(current_health, max_health)
			if hud.has_method("update_stamina"):
				hud.update_stamina(current_stamina, max_stamina)
			if hud.has_method("update_focus"):
				hud.update_focus(current_focus, max_focus)

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
	max_focus += 25.0
	current_focus = max_focus
	print("[Player] LEVELED UP! Now Level ", player_level)
	_play_sound("fanfare")
	if hud:
		if hud.has_method("update_health"):
			hud.update_health(current_health, max_health)
		if hud.has_method("update_stamina"):
			hud.update_stamina(current_stamina, max_stamina)
		if hud.has_method("update_focus"):
			hud.update_focus(current_focus, max_focus)
		if hud.has_method("show_notification"):
			hud.show_notification("✨ LEVEL UP! HP, Stamina & Focus Boosted!", Color(0.3, 1.0, 0.4, 1))
