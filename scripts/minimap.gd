extends Control

@onready var map_texture: TextureRect = $MinimapMask/MapTexture
@onready var player_dot: ColorRect = $MinimapMask/PlayerDot

# Player reference — found at runtime
var _player: Node3D = null

# Map image is 896×1200, rendered at 3× zoom = 2688×3600
const MAP_TEX_W := 896.0
const MAP_TEX_H := 1200.0
const ZOOM := 1.2
const MINIMAP_SIZE := 200.0

# World area the map covers (tune these to match your kingdom layout)
const WORLD_MIN_X := -2700.0
const WORLD_MAX_X := 2700.0
const WORLD_MIN_Z := -2700.0
const WORLD_MAX_Z := 2700.0

# Derived constants
var world_w: float
var world_h: float
var px_per_world_x: float
var px_per_world_z: float

func _ready() -> void:
	world_w = WORLD_MAX_X - WORLD_MIN_X
	world_h = WORLD_MAX_Z - WORLD_MIN_Z
	px_per_world_x = (MAP_TEX_W * ZOOM) / world_w
	px_per_world_z = (MAP_TEX_H * ZOOM) / world_h
	_player = _find_player()

func _find_player() -> Node3D:
	var tree := get_tree()
	if tree == null:
		return null
	var p := tree.root.find_child("Player", true, false)
	if p is Node3D:
		return p
	return null

func _process(_delta: float) -> void:
	if _player == null or map_texture == null:
		_player = _find_player()
		return

	var wx: float = _player.global_position.x
	var wz: float = _player.global_position.z

	# World → map pixel (origin is top-left of map image)
	var map_px: float = (wx - WORLD_MIN_X) * px_per_world_x
	var map_pz: float = (wz - WORLD_MIN_Z) * px_per_world_z

	# Offset so player position sits at minimap center (100, 100)
	map_texture.offset_left   = map_px * -1.0 + MINIMAP_SIZE * 0.5
	map_texture.offset_top    = map_pz * -1.0 + MINIMAP_SIZE * 0.5
	map_texture.offset_right  = map_texture.offset_left + MAP_TEX_W * ZOOM
	map_texture.offset_bottom = map_texture.offset_top  + MAP_TEX_H * ZOOM
