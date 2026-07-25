extends Node3D
class_name OcclusionFader
## Paper-2.5D occlusion fix (Rosemere).
##
## Problem: 2D paper buildings around a fixed-pitch camera hide the player
## completely when he walks behind them.
##
## Solution: every physics frame, cast a ray camera -> player chest. Any
## building hit ("occluder": a StaticBody3D whose parent has a 'Visual' child
## with MeshInstance3D layers — our Building template) gets its layer materials
## swapped for alpha-hashed duplicates: a screen-door dither that keeps writing
## depth and keeps casting sun shadows while faded (unlike true alpha blend).
## Materials are never mutated in place — originals are cached and restored,
## so one shared material set serves all 12+ instances safely.
##
## Future upgrades (docs/kingdom_plan.md §8.3): stencil-buffer X-ray player
## silhouette, screen-space cone cutout shader.

@export var fade_alpha := 0.30          ## how ghostly buildings go when they cover the player
@export var max_occluders := 6          ## max stacked buildings between camera and player
@export var restore_delay_frames := 6   ## hysteresis so the fade doesn't flicker on seams
@export var ray_chest_height := 1.5     ## height above player origin the ray aims at
@export_flags_3d_physics var occlusion_mask := 0xFFFFFFFF

var _camera: Camera3D
var _faded: Dictionary = {}     ## building root instance_id -> { root: Node, miss: int }
var _mat_cache: Dictionary = {} ## original material instance_id -> faded duplicate (shared)
var _orig_mats: Dictionary = {} ## MeshInstance3D instance_id -> original material


func _physics_process(_delta: float) -> void:
	if _camera == null or not is_instance_valid(_camera):
		_camera = get_viewport().get_camera_3d()
		if _camera == null:
			return
	_update_fades(_collect_occluders())


func _collect_occluders() -> Dictionary:
	var space := get_world_3d().direct_space_state
	var player := get_parent() as Node3D
	var from: Vector3 = _camera.global_position
	var to: Vector3 = player.global_position + Vector3(0, ray_chest_height, 0)
	var exclude: Array[RID] = []
	if player is CollisionObject3D:
		exclude.append(player.get_rid())
	var found := {}
	for i in max_occluders:
		var q := PhysicsRayQueryParameters3D.create(from, to, occlusion_mask, exclude)
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			break
		var body := hit.collider as Node
		if body == null:
			break
		var root := body.get_parent()
		if root != null and root.has_node("Visual"):
			found[root.get_instance_id()] = root
		exclude.append(hit.rid)  # keep shooting past everything to catch stacked buildings
	return found


func _update_fades(occluded: Dictionary) -> void:
	for id in occluded:
		if _faded.has(id):
			_faded[id]["miss"] = 0
		else:
			_set_root_faded(occluded[id], true)
			_faded[id] = { "root": occluded[id], "miss": 0 }
	var to_restore: Array = []
	for id in _faded.keys():
		if not occluded.has(id):
			_faded[id]["miss"] += 1
			if _faded[id]["miss"] > restore_delay_frames:
				to_restore.append(id)
	for id in to_restore:
		_set_root_faded(_faded[id]["root"], false)
		_faded.erase(id)


func _set_root_faded(root: Node, faded: bool) -> void:
	if not is_instance_valid(root):
		return
	var visual := root.get_node_or_null("Visual")
	if visual == null:
		return
	for mi in visual.find_children("*", "MeshInstance3D", true, false):
		_set_layer_faded(mi, faded)


func _set_layer_faded(mi: MeshInstance3D, faded: bool) -> void:
	var key := mi.get_instance_id()
	if faded:
		var orig := mi.get_surface_override_material(0)
		if orig == null:
			return
		_orig_mats[key] = orig
		var dup := _faded_material(orig)
		if dup != null:
			mi.set_surface_override_material(0, dup)
	elif _orig_mats.has(key):
		mi.set_surface_override_material(0, _orig_mats[key])
		_orig_mats.erase(key)


func _faded_material(orig: Material) -> Material:
	var key := orig.get_instance_id()
	if not _mat_cache.has(key):
		var faded: StandardMaterial3D = null
		var dup := orig.duplicate()
		if dup is StandardMaterial3D:
			faded = dup
			faded.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_HASH
			var c := faded.albedo_color
			faded.albedo_color = Color(c.r, c.g, c.b, fade_alpha)
		_mat_cache[key] = faded
	return _mat_cache[key]
