extends TextureRect

# Generated at runtime: pure white circle texture for masking
var _circle_tex: ImageTexture = null

func _ready() -> void:
	_circle_tex = _make_circle_texture(200, 200)
	texture = _circle_tex

func _make_circle_texture(w: int, h: int) -> ImageTexture:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var cx := w * 0.5
	var cy := h * 0.5
	var radius: float = min(cx, cy)
	for y in range(h):
		for x in range(w):
			var dx := x - cx + 0.5
			var dy := y - cy + 0.5
			if dx * dx + dy * dy <= radius * radius:
				img.set_pixel(x, y, Color(1, 1, 1, 1))
			else:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
	return ImageTexture.create_from_image(img)
