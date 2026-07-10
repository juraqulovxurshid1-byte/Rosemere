extends CanvasLayer

@onready var minimap_button: Button = $MinimapContainer/MinimapButton
@onready var full_map_overlay: ColorRect = $FullMapOverlay
@onready var close_map_button: Button = $FullMapOverlay/CloseMapButton
@onready var map_image: TextureRect = $FullMapOverlay/MapImage
@onready var full_map_dot: ColorRect = $FullMapOverlay/MapImage/FullMapPlayerDot

var _player: Node3D = null

# Full map display size (matches offsets in scene: 700×940)
const MAP_DISPLAY_W := 700.0
const MAP_DISPLAY_H := 940.0

# Original map image dimensions
const MAP_TEX_W := 896.0
const MAP_TEX_H := 1200.0

# World bounds the map covers — must match minimap.gd values
const WORLD_MIN_X := -2700.0
const WORLD_MAX_X := 2700.0
const WORLD_MIN_Z := -2700.0
const WORLD_MAX_Z := 2700.0

# Dot size (half-width for centering)
const DOT_HALF := 5.0

func _ready() -> void:
	if minimap_button:
		minimap_button.pressed.connect(_on_minimap_clicked)
	if close_map_button:
		close_map_button.pressed.connect(_on_close_map)
	if full_map_overlay:
		full_map_overlay.visible = false
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
	if _player == null:
		_player = _find_player()
		return
	if full_map_overlay == null or not full_map_overlay.visible:
		return
	if full_map_dot == null:
		return

	var wx: float = _player.global_position.x
	var wz: float = _player.global_position.z

	# Normalize to 0..1 within world bounds
	var nx: float = (wx - WORLD_MIN_X) / (WORLD_MAX_X - WORLD_MIN_X)
	var nz: float = (wz - WORLD_MIN_Z) / (WORLD_MAX_Z - WORLD_MIN_Z)

	# Map to display pixel coordinates
	full_map_dot.position.x = nx * MAP_DISPLAY_W - DOT_HALF
	full_map_dot.position.y = nz * MAP_DISPLAY_H - DOT_HALF

func _on_minimap_clicked() -> void:
	if full_map_overlay:
		full_map_overlay.visible = true

func _on_close_map() -> void:
	if full_map_overlay:
		full_map_overlay.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_M:
			if full_map_overlay:
				full_map_overlay.visible = !full_map_overlay.visible

