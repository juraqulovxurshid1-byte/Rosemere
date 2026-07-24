extends CanvasLayer

@onready var minimap_button: Button = $MinimapContainer/MinimapButton
@onready var full_map_overlay: ColorRect = $FullMapOverlay
@onready var close_map_button: Button = $FullMapOverlay/CloseMapButton
@onready var map_image: TextureRect = $FullMapOverlay/MapImage
@onready var full_map_dot: ColorRect = $FullMapOverlay/MapImage/FullMapPlayerDot

var _player: Node3D = null
var _is_dragging: bool = false
var _drag_start_mouse: Vector2 = Vector2.ZERO
var _drag_start_map_pos: Vector2 = Vector2.ZERO

var _zoom_level: float = 1.0
var _min_zoom: float = 0.5
const MAX_ZOOM := 2.5
const ZOOM_STEP := 0.1

# Base Expanded Map Constants (2752x1536 source)
const BASE_MAP_W := 2752.0
const BASE_MAP_H := 1536.0

var map_display_w: float = BASE_MAP_W
var map_display_h: float = BASE_MAP_H

const MAP_TEX_W := 2752.0
const MAP_TEX_H := 1536.0

# World bounds the map covers — must match minimap.gd values
const WORLD_MIN_X := -2700.0
const WORLD_MAX_X := 2700.0
const WORLD_MIN_Z := -2700.0
const WORLD_MAX_Z := 2700.0

# Dot size (half-width for centering)
const DOT_HALF := 5.0

func _ready() -> void:
	if map_image:
		# Use Anisotropic filtering to keep the ink lines crisp at all zoom levels
		map_image.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		
	if close_map_button:
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
	
	# Dynamically calculate minimum zoom to ensure the map always fills the screen
	var viewport_size = get_viewport().get_visible_rect().size
	_min_zoom = max(viewport_size.x / BASE_MAP_W, viewport_size.y / BASE_MAP_H)
	_zoom_level = max(_zoom_level, _min_zoom)
	
	# Update display dimensions based on zoom
	map_display_w = BASE_MAP_W * _zoom_level
	map_display_h = BASE_MAP_H * _zoom_level
	map_image.size = Vector2(map_display_w, map_display_h)

	# Update player dot position on the expanded map
	if full_map_dot:
		var wx: float = _player.global_position.x
		var wz: float = _player.global_position.z

		# Normalize to 0..1 within world bounds
		var nx: float = (wx - WORLD_MIN_X) / (WORLD_MAX_X - WORLD_MIN_X)
		var nz: float = (wz - WORLD_MIN_Z) / (WORLD_MAX_Z - WORLD_MIN_Z)

		# Map to display pixel coordinates
		full_map_dot.position.x = nx * map_display_w - DOT_HALF
		full_map_dot.position.y = nz * map_display_h - DOT_HALF

	# Update map panning if dragging
	if _is_dragging:
		var mouse_pos = get_viewport().get_mouse_position()
		var diff = mouse_pos - _drag_start_mouse
		var new_pos = _drag_start_map_pos + diff
		
		# Clamping logic: ensure the map always fills the viewport
		_clamp_map_position(new_pos)

func _clamp_map_position(target_pos: Vector2) -> void:
	var viewport_size = get_viewport().get_visible_rect().size
	
	# If map is smaller than viewport, center it. Otherwise clamp.
	var min_x = viewport_size.x - map_display_w
	var min_y = viewport_size.y - map_display_h
	
	var final_x = clamp(target_pos.x, min_x, 0.0) if map_display_w > viewport_size.x else (viewport_size.x - map_display_w) / 2.0
	var final_y = clamp(target_pos.y, min_y, 0.0) if map_display_h > viewport_size.y else (viewport_size.y - map_display_h) / 2.0
	
	map_image.position = Vector2(final_x, final_y)

func _on_minimap_clicked() -> void:
	if full_map_overlay:
		full_map_overlay.visible = true
		_zoom_level = 1.0 # Reset zoom when opening
		# Center map on player when opening
		_center_map_on_player()

func _center_map_on_player() -> void:
	if not _player or not map_image: return
	
	var nx: float = (_player.global_position.x - WORLD_MIN_X) / (WORLD_MAX_X - WORLD_MIN_X)
	var nz: float = (_player.global_position.z - WORLD_MIN_Z) / (WORLD_MAX_Z - WORLD_MIN_Z)
	
	var viewport_size = get_viewport().get_visible_rect().size
	var target_x = viewport_size.x / 2.0 - (nx * map_display_w)
	var target_y = viewport_size.y / 2.0 - (nz * map_display_h)
	
	_clamp_map_position(Vector2(target_x, target_y))

func _on_close_map() -> void:
	if full_map_overlay:
		full_map_overlay.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_M:
			if full_map_overlay:
				full_map_overlay.visible = !full_map_overlay.visible
				if full_map_overlay.visible:
					_zoom_level = 1.0
					_center_map_on_player()

func _on_close_map_button_gui_input(event: InputEvent) -> void:
	if full_map_overlay == null or not full_map_overlay.visible:
		return
		
	# Dragging logic
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_is_dragging = true
				_drag_start_mouse = event.global_position
				_drag_start_map_pos = map_image.position
			else:
				_is_dragging = false
		
		# Zoom logic (Scroll Wheel)
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_adjust_zoom(ZOOM_STEP, event.global_position)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_adjust_zoom(-ZOOM_STEP, event.global_position)

		# TEMP DEV/TEST TOOL: right-click the full map image to teleport the player.
		if not event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
			if map_image:
				var map_rect: Rect2 = map_image.get_global_rect()
				if map_rect.has_point(event.global_position):
					_teleport_player_to_map_position(event.global_position - map_rect.position)
					_on_close_map()
					get_viewport().set_input_as_handled()

func _adjust_zoom(delta: float, mouse_pos: Vector2) -> void:
	var old_zoom = _zoom_level
	_zoom_level = clamp(_zoom_level + delta, _min_zoom, MAX_ZOOM)
	
	if old_zoom == _zoom_level: return
	
	# Calculate offset to zoom towards mouse position
	var map_local_mouse = mouse_pos - map_image.global_position
	var zoom_ratio = _zoom_level / old_zoom
	var new_pos = mouse_pos - (map_local_mouse * zoom_ratio)
	
	_clamp_map_position(new_pos)

func _teleport_player_to_map_position(map_pixel_position: Vector2) -> void:
	if _player == null:
		_player = _find_player()
	if _player == null:
		return

	# Inverse of FullMapPlayerDot tracking above:
	# world -> normalized -> map pixels becomes map pixels -> normalized -> world.
	var nx: float = clamp(map_pixel_position.x / map_display_w, 0.0, 1.0)
	var nz: float = clamp(map_pixel_position.y / map_display_h, 0.0, 1.0)
	var world_x: float = clamp(lerp(WORLD_MIN_X, WORLD_MAX_X, nx), WORLD_MIN_X, WORLD_MAX_X)
	var world_z: float = clamp(lerp(WORLD_MIN_Z, WORLD_MAX_Z, nz), WORLD_MIN_Z, WORLD_MAX_Z)

	_player.global_position = Vector3(world_x, _player.global_position.y, world_z)
