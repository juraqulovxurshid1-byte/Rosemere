extends TextureRect

# Radial tick marks around the minimap compass ring
# Draws 12 ticks at 30° intervals, skipping N/S/E/W positions

const DARK := Color(0.12, 0.1, 0.09, 1)  # #1F1A17
const TICK_COUNT := 12
const SKIP_ANGLES := [0.0, 90.0, 180.0, 270.0]  # N, E, S, W (degrees)

func _ready() -> void:
	texture = null
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()

func _draw() -> void:
	var cx := size.x * 0.5
	var cy := size.y * 0.5
	var radius_outer := cx - 2.0  # just inside the border
	var radius_inner := radius_outer - 6.0  # tick length ~6px

	for i in range(TICK_COUNT):
		var angle_deg := i * (360.0 / TICK_COUNT)
		# Skip compass label positions
		var skip := false
		for skip_angle in SKIP_ANGLES:
			if abs(angle_deg - skip_angle) < 1.0:
				skip = true
				break
		if skip:
			continue

		var angle_rad := deg_to_rad(angle_deg - 90.0)  # -90 so 0° = top (N)
		var outer_pt := Vector2(cx + cos(angle_rad) * radius_outer, cy + sin(angle_rad) * radius_outer)
		var inner_pt := Vector2(cx + cos(angle_rad) * radius_inner, cy + sin(angle_rad) * radius_inner)
		draw_line(inner_pt, outer_pt, DARK, 1.5)
