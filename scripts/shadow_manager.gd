extends Node

@export var shadow_opacity: float = 0.38
@export var npc_shadow_scale: float = 1.3
@export var tree_shadow_scale: float = 1.8

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
		
		# --- Explicit self-lit / VFX exclusion ---
		# Never add shadows under torches, campfires, glows, or other emissive VFX
		if path.contains("Torch") or path.contains("Campfire") or path.contains("FireSprite") or path.contains("Fire") or path.contains("Glow"):
			continue
		
		# --- UI / system exclusion ---
		if path.contains("HUD") or path.contains("DialogueUI"):
			continue
		if path.contains("Nameplate") or path.contains("Label"):
			continue
		if path.contains("_Shadow"):
			continue
		
		# --- Environment / decal exclusion ---
		# GroundDetails are now Decal nodes, not Sprite3D, but keep for safety
		if path.contains("Background") or path.contains("GroundDetail"):
			continue
		if path.contains("Foreground") or path.contains("Midground") or path.contains("BackgroundDepth"):
			continue
		# Props clutter (Barrel, Signpost, FenceMarket, etc.) – skip, we only want NPCs + trees
		if path.contains("/Props/"):
			continue
		
		# --- Root contact shadow allowlist: NPCs and trees only ---
		var is_character := (
			path.contains("/Player/") or
			path.contains("/Enemies/") or
			path.contains("Bandit") or
			path.contains("Boss") or
			path.contains("Troll") or
			path.contains("/Villagers/") or
			path.contains("BlacksmithNPC") or
			path.contains("InnkeeperNPC") or
			path.contains("NPC")
		)
		var is_tree := path.contains("/Trees/") and path.contains("Tree")
		
		if not (is_character or is_tree):
			continue
		
		if not s.texture or not s.visible:
			continue
		if s.texture.get_size().y < 50:
			continue
		
		if _add_shadow(s):
			count += 1
	
	print("[ShadowManager] Added ", count, " root contact shadows (NPCs + trees).")

func _add_shadow(sprite: Sprite3D) -> bool:
	var tex := sprite.texture
	var tex_h: float = tex.get_size().y
	
	# Choose texture based on object size - use soft blob for all characters/trees
	var use_soft: bool = tex_h > 120
	var blob_tex: Texture2D = _blob_tex_soft if use_soft else _blob_tex
	
	# Calculate size proportional to sprite
	var sx: float = abs(sprite.scale.x)
	var sy: float = abs(sprite.scale.y)
	var base_w: float = tex.get_size().x * 0.01 * sx
	var shadow_w: float = base_w * 0.6
	var shadow_d: float = shadow_w * 0.45
	
	shadow_w = clamp(shadow_w, 0.3, 6.0)
	shadow_d = clamp(shadow_d, 0.15, 2.5)
	
	# Determine if this is a tree or character for root contact shadow tuning
	var path := str(sprite.get_path())
	var is_tree := path.contains("/Trees/") and path.contains("Tree")
	var is_character := (
		path.contains("/Player/") or
		path.contains("/Enemies/") or
		path.contains("Bandit") or
		path.contains("Boss") or
		path.contains("Troll") or
		path.contains("/Villagers/") or
		path.contains("NPC")
	)
	
	var shadow_alpha := shadow_opacity
	
	if is_tree:
		# Tree contact shadow boost – grimdark_tree.svg has a narrow trunk, so widen the blob
		shadow_w *= tree_shadow_scale
		shadow_d *= tree_shadow_scale
		shadow_alpha = shadow_opacity * 0.85
	elif is_character:
		# NPC root contact shadow – soft blob under feet to ground characters
		shadow_w *= npc_shadow_scale
		shadow_d *= npc_shadow_scale
		shadow_alpha = min(0.55, shadow_opacity * 1.15)
	
	# Create a Sprite3D lying flat - NO custom material, just a texture
	var shadow := Sprite3D.new()
	shadow.name = sprite.name + "_Shadow"
	shadow.texture = blob_tex
	shadow.shaded = false
	shadow.no_depth_test = true
	shadow.render_priority = -1
	# shadow_blob.png is white/gray – tint black with alpha
	shadow.modulate = Color(0, 0, 0, shadow_alpha)
	
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
