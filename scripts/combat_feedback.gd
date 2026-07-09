extends Node

# Centralized, non-gameplay combat feedback: floating damage text,
# hit flashes, screen shake, impact bursts, and death puffs.
# This script intentionally does NOT change damage, cooldowns, stamina, mana, AI, or hit rules.

var _rng := RandomNumberGenerator.new()
var _impact_texture: Texture2D = null
var _spark_texture: Texture2D = null
var _smoke_texture: Texture2D = null

var _active_camera: Camera3D = null
var _base_h_offset: float = 0.0
var _base_v_offset: float = 0.0
var _shake_time_left: float = 0.0
var _shake_duration: float = 0.001
var _shake_strength: float = 0.0

func _ready() -> void:
	_rng.randomize()
	set_process(false)

func _process(delta: float) -> void:
	_update_screen_shake(delta)

# --- HIT FLASH -------------------------------------------------------------
func hit_flash(sprite: Sprite3D, flash_color: Color = Color(1, 1, 1, 1), flash_in: float = 0.035, flash_out: float = 0.11) -> void:
	if sprite == null or not is_instance_valid(sprite):
		return

	var base_color: Color = sprite.modulate
	var tween := sprite.create_tween()
	tween.tween_property(sprite, "modulate", flash_color, flash_in)
	tween.tween_property(sprite, "modulate", base_color, flash_out)

# --- FLOATING TEXT / DAMAGE NUMBERS ---------------------------------------
func spawn_damage_number(amount: float, world_position: Vector3, color: Color = Color(1, 0.9, 0.35, 1), big: bool = false) -> void:
	var font_size := 56
	var rise := 1.25
	if big:
		font_size = 74
		rise = 1.65
	spawn_floating_text("-" + str(int(round(amount))), world_position, color, font_size, rise)

func spawn_floating_text(text: String, world_position: Vector3, color: Color = Color(1, 1, 1, 1), font_size: int = 56, rise: float = 1.25) -> void:
	var label := Label3D.new()
	label.name = "FloatingCombatText"
	label.text = text
	label.billboard = 1
	label.font_size = font_size
	label.outline_size = max(8, int(font_size * 0.18))
	label.modulate = color
	label.scale = Vector3(0.75, 0.75, 0.75)
	label.set("no_depth_test", true)
	add_child(label)
	label.global_position = world_position + Vector3(_rng.randf_range(-0.25, 0.25), _rng.randf_range(0.05, 0.25), _rng.randf_range(-0.15, 0.15))

	var peak_position := label.global_position + Vector3(_rng.randf_range(-0.20, 0.20), rise, _rng.randf_range(-0.10, 0.10))

	var pop := label.create_tween()
	pop.tween_property(label, "scale", Vector3(1.18, 1.18, 1.18), 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop.tween_property(label, "scale", Vector3(1.0, 1.0, 1.0), 0.10)

	var drift := label.create_tween()
	drift.set_parallel(true)
	drift.tween_property(label, "global_position", peak_position, 0.75).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	drift.tween_property(label, "modulate:a", 0.0, 0.42).set_delay(0.30)
	drift.chain().tween_callback(label.queue_free)

# --- SCREEN SHAKE ----------------------------------------------------------
func screen_shake(strength: float = 0.12, duration: float = 0.12) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return

	if camera != _active_camera:
		_reset_camera_offsets()
		_active_camera = camera
		_base_h_offset = camera.h_offset
		_base_v_offset = camera.v_offset

	_shake_strength = max(_shake_strength, strength)
	_shake_duration = max(_shake_duration, duration)
	_shake_time_left = max(_shake_time_left, duration)
	set_process(true)

func _update_screen_shake(delta: float) -> void:
	if _active_camera == null or not is_instance_valid(_active_camera):
		_active_camera = null
		set_process(false)
		return

	if _shake_time_left <= 0.0:
		_reset_camera_offsets()
		_shake_strength = 0.0
		_shake_duration = 0.001
		set_process(false)
		return

	_shake_time_left -= delta
	var t: float = clamp(_shake_time_left / max(_shake_duration, 0.001), 0.0, 1.0)
	var amount: float = _shake_strength * t * t
	_active_camera.h_offset = _base_h_offset + _rng.randf_range(-amount, amount)
	_active_camera.v_offset = _base_v_offset + _rng.randf_range(-amount, amount)

func _reset_camera_offsets() -> void:
	if _active_camera != null and is_instance_valid(_active_camera):
		_active_camera.h_offset = _base_h_offset
		_active_camera.v_offset = _base_v_offset

# --- IMPACT / DEATH EFFECTS ------------------------------------------------
func spawn_impact_effect(world_position: Vector3, color: Color = Color(1, 0.82, 0.28, 1), radius: float = 0.55, spark_count: int = 7) -> void:
	_ensure_textures()

	var burst := Sprite3D.new()
	burst.name = "HitImpactBurst"
	burst.texture = _impact_texture
	burst.billboard = 1
	burst.texture_filter = 0
	burst.modulate = color
	burst.scale = Vector3(radius, radius, 1.0)
	burst.set("no_depth_test", true)
	add_child(burst)
	burst.global_position = world_position

	var burst_tween := burst.create_tween()
	burst_tween.set_parallel(true)
	burst_tween.tween_property(burst, "scale", Vector3(radius * 1.9, radius * 1.9, 1.0), 0.16).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	burst_tween.tween_property(burst, "modulate:a", 0.0, 0.16)
	burst_tween.chain().tween_callback(burst.queue_free)

	for i in range(spark_count):
		_spawn_spark(world_position, color, radius)

func spawn_death_effect(world_position: Vector3, is_boss: bool = false) -> void:
	_ensure_textures()
	var radius := 0.82
	var text := "SLAIN"
	var text_color := Color(1.0, 0.68, 0.28, 1)
	var spark_count := 11
	var puff_count := 5
	var font_size := 58
	var text_rise := 1.05

	if is_boss:
		radius = 1.35
		text = "BOSS SLAIN"
		text_color = Color(1.0, 0.35, 0.25, 1)
		spark_count = 18
		puff_count = 10
		font_size = 82
		text_rise = 1.45

	spawn_impact_effect(world_position, Color(1.0, 0.28, 0.12, 1), radius, spark_count)
	spawn_floating_text(text, world_position + Vector3(0, 0.45, 0), text_color, font_size, text_rise)

	for i in range(puff_count):
		_spawn_smoke_puff(world_position, radius, is_boss)

func _spawn_spark(world_position: Vector3, color: Color, radius: float) -> void:
	var spark := Sprite3D.new()
	spark.name = "HitSpark"
	spark.texture = _spark_texture
	spark.billboard = 1
	spark.texture_filter = 0
	spark.modulate = color
	spark.set("no_depth_test", true)
	var start_scale := _rng.randf_range(0.12, 0.22) * radius
	spark.scale = Vector3(start_scale, start_scale, 1.0)
	add_child(spark)
	spark.global_position = world_position + Vector3(_rng.randf_range(-0.08, 0.08), _rng.randf_range(-0.05, 0.10), _rng.randf_range(-0.08, 0.08))

	var angle := _rng.randf_range(0.0, TAU)
	var dir := Vector3(cos(angle), _rng.randf_range(0.20, 0.75), sin(angle)).normalized()
	var end_pos := spark.global_position + dir * _rng.randf_range(radius * 0.55, radius * 1.25)
	var duration := _rng.randf_range(0.16, 0.28)

	var tween := spark.create_tween()
	tween.set_parallel(true)
	tween.tween_property(spark, "global_position", end_pos, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(spark, "scale", Vector3(0.01, 0.01, 1.0), duration)
	tween.tween_property(spark, "modulate:a", 0.0, duration)
	tween.chain().tween_callback(spark.queue_free)

func _spawn_smoke_puff(world_position: Vector3, radius: float, is_boss: bool) -> void:
	var puff := Sprite3D.new()
	puff.name = "DeathSmokePuff"
	puff.texture = _smoke_texture
	puff.billboard = 1
	puff.texture_filter = 0
	if is_boss:
		puff.modulate = Color(0.25, 0.12, 0.28, 0.8)
	else:
		puff.modulate = Color(0.18, 0.16, 0.18, 0.72)
	puff.set("no_depth_test", true)
	var start_scale := _rng.randf_range(0.20, 0.38) * radius
	puff.scale = Vector3(start_scale, start_scale, 1.0)
	add_child(puff)
	puff.global_position = world_position + Vector3(_rng.randf_range(-radius * 0.35, radius * 0.35), _rng.randf_range(-0.15, 0.25), _rng.randf_range(-radius * 0.25, radius * 0.25))

	var end_pos := puff.global_position + Vector3(_rng.randf_range(-0.25, 0.25), _rng.randf_range(0.55, 1.05) * radius, _rng.randf_range(-0.18, 0.18))
	var end_scale := start_scale * _rng.randf_range(2.0, 3.2)
	var duration := _rng.randf_range(0.45, 0.85)

	var tween := puff.create_tween()
	tween.set_parallel(true)
	tween.tween_property(puff, "global_position", end_pos, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(puff, "scale", Vector3(end_scale, end_scale, 1.0), duration)
	tween.tween_property(puff, "modulate:a", 0.0, duration)
	tween.chain().tween_callback(puff.queue_free)

# --- PROCEDURAL TEXTURES ---------------------------------------------------
func _ensure_textures() -> void:
	if _impact_texture == null:
		_impact_texture = _make_impact_texture()
	if _spark_texture == null:
		_spark_texture = _make_soft_circle_texture(32, 0.85)
	if _smoke_texture == null:
		_smoke_texture = _make_soft_circle_texture(64, 0.55)

func _make_impact_texture() -> Texture2D:
	var size := 64
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(size * 0.5, size * 0.5)
	for y in range(size):
		for x in range(size):
			var p := Vector2(x, y)
			var local := (p - center) / (size * 0.5)
			var r := local.length()
			var angle := atan2(local.y, local.x)
			var ring: float = clamp(1.0 - abs(r - 0.46) / 0.08, 0.0, 1.0)
			var core: float = clamp(1.0 - r / 0.32, 0.0, 1.0)
			var rays: float = clamp(1.0 - r, 0.0, 1.0) * pow(abs(cos(angle * 6.0)), 12.0)
			var alpha: float = clamp(max(core * 0.8, max(ring, rays)), 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, alpha))
	return ImageTexture.create_from_image(img)

func _make_soft_circle_texture(size: int, edge_power: float) -> Texture2D:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(size * 0.5, size * 0.5)
	for y in range(size):
		for x in range(size):
			var r := (Vector2(x, y) - center).length() / (size * 0.5)
			var alpha: float = pow(clamp(1.0 - r, 0.0, 1.0), edge_power)
			img.set_pixel(x, y, Color(1, 1, 1, alpha))
	return ImageTexture.create_from_image(img)
