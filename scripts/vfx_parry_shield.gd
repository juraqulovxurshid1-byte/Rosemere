extends Sprite3D

class_name ParryShieldVFX

const SHEET_PATH := "res://art_v2/vfx_parry_shield_sheet.png"
const FRAME_W := 555
const FRAME_H := 643
const GAP := 4
const FPS := 15.0
const PIXEL_SIZE := 0.006


func _ready() -> void:
	# Load texture
	var tex := load(SHEET_PATH) as Texture2D
	if tex == null:
		push_error("ParryShieldVFX: Failed to load sheet: " + SHEET_PATH)
		queue_free()
		return
	texture = tex
	
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


static func spawn_parry_vfx(parent: Node, world_pos: Vector3, facing_right: bool) -> void:
	var vfx := ParryShieldVFX.new()
	parent.add_child(vfx)
	
	# Position in front of the player's face/shield arm
	if facing_right:
		vfx.position = world_pos + Vector3(0.5, 2.0, 0.0)
	else:
		vfx.position = world_pos + Vector3(-0.5, 2.0, 0.0)
		vfx.flip_h = true
