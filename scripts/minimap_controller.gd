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
		close_map_button.gui_input.connect(_on_close_map_button_gui_input)
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

func _on_close_map_button_gui_input(event: InputEvent) -> void:
	# TEMP DEV/TEST TOOL: right-click the full map image to teleport the player.
	# Remove this once Rosemere's kingdom content and normal traversal are built.
	if not (event is InputEventMouseButton):
		return
	if not event.pressed or event.button_index != MOUSE_BUTTON_RIGHT:
		return
	if full_map_overlay == null or not full_map_overlay.visible:
		return
	if map_image == null:
		return

	var map_rect: Rect2 = map_image.get_global_rect()
	if not map_rect.has_point(event.global_position):
		return

	_teleport_player_to_map_position(event.global_position - map_rect.position)
	_on_close_map()
	get_viewport().set_input_as_handled()

func _teleport_player_to_map_position(map_pixel_position: Vector2) -> void:
	if _player == null:
		_player = _find_player()
	if _player == null:
		return

	# Inverse of FullMapPlayerDot tracking above:
	# world -> normalized -> map pixels becomes map pixels -> normalized -> world.
	var nx: float = clamp(map_pixel_position.x / MAP_DISPLAY_W, 0.0, 1.0)
	var nz: float = clamp(map_pixel_position.y / MAP_DISPLAY_H, 0.0, 1.0)
	var world_x: float = clamp(lerp(WORLD_MIN_X, WORLD_MAX_X, nx), WORLD_MIN_X, WORLD_MAX_X)
	var world_z: float = clamp(lerp(WORLD_MIN_Z, WORLD_MAX_Z, nz), WORLD_MIN_Z, WORLD_MAX_Z)

	_player.global_position = Vector3(world_x, _player.global_position.y, world_z)
