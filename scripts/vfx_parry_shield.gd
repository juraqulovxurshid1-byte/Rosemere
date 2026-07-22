extends Sprite3D

class_name ParryShieldVFX

const SHEET_PATH := "res://art_v2/vfx_parry_shield_sheet.png"
const FRAME_W := 555
const FRAME_H := 643
const GAP := 4
const FPS := 8.0
const PIXEL_SIZE := 0.006
# Match the damage-number anchor used by CombatFeedback:
# player position + (0, 1.15, 0), then + (0, 0.75, 0).
const DAMAGE_TEXT_Y_OFFSET := 1.9
const HAND_DEFENCE_Y_OFFSET := 4.26 # 3.55 × 1.2
const HAND_DEFENCE_X_OFFSET := 0.32

var player_target: Node3D = null
var attacker_target: Node3D = null
var follow_y_offset: float = DAMAGE_TEXT_Y_OFFSET
var follow_x_offset: float = 0.0


func _process(_delta: float) -> void:
	# Keep the effect anchored to the active combatants while its frames play.
	# This prevents it from being left behind when the player moves.
	if not player_target or not is_instance_valid(player_target):
		return

	# Damage numbers use this same anchor, so the shield sits exactly where
	# "-25" or "-12.5" is displayed and follows the player.
	var anchor := player_target.global_position + Vector3(follow_x_offset, follow_y_offset, 0.0)
	global_position = anchor


func _ready() -> void:
	# Load texture
	var tex := load(SHEET_PATH) as Texture2D
	if tex == null:
		push_error("ParryShieldVFX: Failed to load sheet: " + SHEET_PATH)
		queue_free()
		return
	texture = tex

	# Use Sprite3D's native texture material. The PNG already contains an alpha
	# channel; a material override can replace the texture with an opaque quad.
	shaded = false
	texture_filter = 0

	# Match the floating damage text render behavior so the shield is visible
	# in front of the player instead of being occluded by the player sprite.
	set("no_depth_test", true)
	render_priority = 100

	# Billboard facing camera
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	centered = true
	pixel_size = PIXEL_SIZE
	
	# Region-based animation (4 frames horizontal)
	region_enabled = true
	region_rect = Rect2(0, 0, FRAME_W, FRAME_H)
	
	# Animate through frames with tweens
	var tween := create_tween()
	for i in range(4):
		var frame_idx := i
		tween.tween_callback(func(): region_rect.position.x = frame_idx * (FRAME_W + GAP))
		tween.tween_interval(1.0 / FPS)
	
	# Auto-cleanup after animation completes
	tween.tween_callback(queue_free)


static func spawn_parry_vfx(parent: Node, world_pos: Vector3, facing_right: bool, player: Node3D = null, attacker: Node3D = null, y_offset: float = DAMAGE_TEXT_Y_OFFSET, x_offset: float = 0.0) -> void:
	var vfx := ParryShieldVFX.new()
	vfx.player_target = player
	vfx.attacker_target = attacker
	vfx.follow_y_offset = y_offset
	vfx.follow_x_offset = x_offset
	parent.add_child(vfx)

	# Initial position is supplied immediately; _process keeps it tracking.
	vfx.global_position = world_pos
	vfx.flip_h = not facing_right
