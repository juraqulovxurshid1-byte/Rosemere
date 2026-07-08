extends Node

@export var shadow_opacity: float = 0.3

var _blob_tex: Texture2D = null
var _blob_tex_soft: Texture2D = null

func _ready() -> void:
	_blob_tex = load("res://art_v2/shadow_blob.png") as Texture2D
	_blob_tex_soft = load("res://art_v2/shadow_blob_soft.png") as Texture2D
	if not _blob_tex:
		push_error("[ShadowManager] Could not load shadow_blob.png")
		return
	call_deferred("_add_shadows")

func _add_shadows() -> void:
	var count := 0
	var sprites := get_tree().root.find_children("*", "Sprite3D", true, false)
	
	for s in sprites:
		if not s is Sprite3D:
			continue
		var path := str(s.get_path())
		if path.contains("HUD") or path.contains("DialogueUI"):
			continue
		if path.contains("Nameplate") or path.contains("Label"):
			continue
		if path.contains("_Shadow") or path.contains("Background") or path.contains("GroundDetail"):
			continue
		if path.contains("Foreground") or path.contains("Midground"):
			continue
		if path.contains("Deco") or path.contains("Tree"):
			continue
		if not s.texture or not s.visible:
			continue
		if s.texture.get_size().y < 50:
			continue
		if _add_shadow(s):
			count += 1
	
	print("[ShadowManager] Added ", count, " blob shadows.")

func _add_shadow(sprite: Sprite3D) -> bool:
	var tex := sprite.texture
	var tex_h: float = tex.get_size().y
	
	# Choose texture based on object size
	var use_soft: bool = tex_h > 200
	var blob_tex: Texture2D = _blob_tex_soft if use_soft else _blob_tex
	
	# Calculate size proportional to sprite
	var sx: float = abs(sprite.scale.x)
	var sy: float = abs(sprite.scale.y)
	var avg_scale: float = (sx + sy) / 2.0
	var base_w: float = tex.get_size().x * 0.01 * sx
	var shadow_w: float = base_w * 0.6
	var shadow_d: float = shadow_w * 0.45
	
	shadow_w = clamp(shadow_w, 0.3, 6.0)
	shadow_d = clamp(shadow_d, 0.15, 2.5)
	
	# Create a Sprite3D lying flat - NO custom material, just a texture
	var shadow := Sprite3D.new()
	shadow.name = sprite.name + "_Shadow"
	shadow.texture = blob_tex
	
	var pos: Vector3 = sprite.global_position
	shadow.global_position = Vector3(pos.x, 0.025, pos.z)
	shadow.scale = Vector3(shadow_w, shadow_d, 1.0)
	shadow.rotation.x = -PI / 2.0
	
	# No billboard - lies flat on ground
	shadow.billboard = 0
	
	var parent = sprite.get_parent()
	if parent:
		parent.add_child(shadow)
		return true
	return false
