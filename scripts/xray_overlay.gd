extends Node3D
class_name PlayerXRayOverlay
## Stencil X-ray for the player (Godot 4.5+ stencil buffer, PR #80710 pattern).
##
## Why a mirror node: Sprite3D's material is auto-generated from its flags and
## can't carry stencil state. So this node mirrors the sprite onto a QuadMesh
## with a StandardMaterial3D that DOES carry the built-in XRAY stencil preset:
##   1. base material renders the knight normally (lit, cutout) and writes
##      stencil wherever its pixels FAIL the depth test (= occluded by a house);
##   2. its next_pass "ghost" material draws an unshaded tinted silhouette with
##      no depth test, but ONLY where stencil says the base was occluded.
## Result: knight stays visually identical, and a "spirit glow" of him appears
## through any building in front of him. Occluders require ZERO setup.
##
## Synced per frame from the real Sprite3D: texture, region rect, flip_h,
## pixel_size, transform — so all animation states (walk/attack/rest…) track.

@export var camera_push := 0.03   ## nudge toward camera so the mirror beats the real sprite in depth

var _sprite: Sprite3D
var _mi: MeshInstance3D
var _quad: QuadMesh
var _base: StandardMaterial3D
var _ghost: StandardMaterial3D
var _cam: Camera3D
var _norm_cache: Dictionary = {}   ## albedo resource_path -> normal Texture2D (or null)


func _ready() -> void:
	_sprite = get_parent().get_node_or_null("Sprite3D")
	_mi = get_node_or_null("GhostMesh")
	if _mi:
		_quad = _mi.mesh as QuadMesh
		_base = _mi.get_surface_override_material(0) as StandardMaterial3D
		if _base:
			_ghost = _base.next_pass as StandardMaterial3D
	set_process(_sprite != null and _mi != null and _base != null and _quad != null)


func _process(_delta: float) -> void:
	if _cam == null:
		_cam = get_viewport().get_camera_3d()
	var tex: Texture2D = _sprite.texture
	if tex == null or _sprite.pixel_size <= 0.0:
		return
	var tw := float(tex.get_width())
	var th := float(tex.get_height())
	var px := tw
	var py := th
	var u0 := 0.0
	var v0 := 0.0
	var su := 1.0
	var sv := 1.0
	if _sprite.region_enabled:
		var r := _sprite.region_rect
		px = r.size.x
		py = r.size.y
		u0 = r.position.x / tw
		v0 = r.position.y / th
		su = r.size.x / tw
		sv = r.size.y / th
	var uv_off := Vector3(u0, v0, 0.0)
	var uv_scale := Vector3(su, sv, 1.0)
	if _sprite.flip_h:
		uv_off.x = u0 + su
		uv_scale.x = -su
	_quad.size = Vector2(px * _sprite.pixel_size, py * _sprite.pixel_size)
	for m in [_base, _ghost]:
		if m:
			m.albedo_texture = tex
			m.uv1_offset = uv_off
			m.uv1_scale = uv_scale
	# rim-light support: swap in the matching beveled normal map (same sheet layout)
	var ntex := _resolve_normal(tex)
	if ntex != null:
		_base.normal_texture = ntex
	var gt := _sprite.global_transform
	if _cam:
		gt.origin += (_cam.global_position - gt.origin).normalized() * camera_push
	_mi.global_transform = gt


## Finds "<sheet>_normal.png" next to the current albedo sheet (cached).
func _resolve_normal(tex: Texture2D) -> Texture2D:
	var key := tex.resource_path
	if key.is_empty():
		return null
	if not _norm_cache.has(key):
		var npath := key.get_basename() + "_normal.png"
		_norm_cache[key] = load(npath) if ResourceLoader.exists(npath) else null
	return _norm_cache[key]
