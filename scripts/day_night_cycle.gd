extends DirectionalLight3D

class_name DayNightCycle

const SECONDS_PER_DAY: float = 86400.0

# Time-of-day keyframes. day_progress is derived only from GameClock:
#   0.00 / 1.00 = 00:00 midnight
#   0.25        = 06:00 dawn / sunrise
#   0.50        = 12:00 noon
#   0.75        = 18:00 dusk / sunset
# Values are intentionally muted/desaturated for Rosemere's grimdark tone.
const NIGHT_DIRECT_COLOR := Color(0.32, 0.38, 0.46, 1.0) # cool dark grey-blue, playable not black
const NIGHT_DIRECT_ENERGY := 0.42
const NIGHT_AMBIENT_COLOR := Color(0.26, 0.30, 0.36, 1.0)
const NIGHT_AMBIENT_ENERGY := 0.42
const NIGHT_FOG_COLOR := Color(0.25, 0.30, 0.37, 1.0)
const NIGHT_SKY_TOP_COLOR := Color(0.16, 0.20, 0.26, 1.0)
const NIGHT_SKY_HORIZON_COLOR := Color(0.24, 0.28, 0.34, 1.0)

const DAWN_DIRECT_COLOR := Color(0.60, 0.48, 0.44, 1.0) # dusty rose / grey-brown, muted
const DAWN_DIRECT_ENERGY := 0.72
const DAWN_AMBIENT_COLOR := Color(0.43, 0.39, 0.38, 1.0)
const DAWN_AMBIENT_ENERGY := 0.56
const DAWN_FOG_COLOR := Color(0.44, 0.39, 0.38, 1.0)
const DAWN_SKY_TOP_COLOR := Color(0.38, 0.32, 0.31, 1.0)
const DAWN_SKY_HORIZON_COLOR := Color(0.52, 0.43, 0.39, 1.0)

const DAY_DIRECT_COLOR := Color(0.78, 0.80, 0.78, 1.0) # pale desaturated grey-white, not pure white
const DAY_DIRECT_ENERGY := 1.18
const DAY_AMBIENT_COLOR := Color(0.55, 0.57, 0.58, 1.0)
const DAY_AMBIENT_ENERGY := 0.86
const DAY_FOG_COLOR := Color(0.50, 0.52, 0.53, 1.0)
const DAY_SKY_TOP_COLOR := Color(0.53, 0.56, 0.58, 1.0)
const DAY_SKY_HORIZON_COLOR := Color(0.66, 0.66, 0.63, 1.0)

const DUSK_DIRECT_COLOR := Color(0.50, 0.36, 0.32, 1.0) # dark muted rust/brown-grey
const DUSK_DIRECT_ENERGY := 0.64
const DUSK_AMBIENT_COLOR := Color(0.34, 0.31, 0.32, 1.0)
const DUSK_AMBIENT_ENERGY := 0.50
const DUSK_FOG_COLOR := Color(0.38, 0.31, 0.30, 1.0)
const DUSK_SKY_TOP_COLOR := Color(0.33, 0.25, 0.25, 1.0)
const DUSK_SKY_HORIZON_COLOR := Color(0.46, 0.34, 0.31, 1.0)

var time_of_day_str: String = "☁️ Cold Dawn"
var _environment: Environment = null
var _sky_material: ProceduralSkyMaterial = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_cache_world_environment()

func _process(_delta: float) -> void:
	var day_progress: float = fposmod(GameClock.elapsed_seconds, SECONDS_PER_DAY) / SECONDS_PER_DAY
	var sun_angle_deg: float = day_progress * 360.0 - 180.0
	rotation_degrees.x = sun_angle_deg

	_apply_atmosphere(day_progress)

	if sun_angle_deg > -45.0 and sun_angle_deg <= 45.0:
		time_of_day_str = "☁️ Bleak Noon"
	elif sun_angle_deg > -90.0 and sun_angle_deg <= -45.0:
		time_of_day_str = "☁️ Cold Morning"
	elif sun_angle_deg > 45.0 and sun_angle_deg <= 90.0:
		time_of_day_str = "☁️ Sullen Evening"
	else:
		time_of_day_str = "☁️ Deep Night"

func _cache_world_environment() -> void:
	var world_environment := get_tree().root.find_child("WorldEnvironment", true, false) as WorldEnvironment
	if world_environment:
		_environment = world_environment.environment
		if _environment and _environment.sky and _environment.sky.sky_material is ProceduralSkyMaterial:
			_sky_material = _environment.sky.sky_material as ProceduralSkyMaterial

func _apply_atmosphere(day_progress: float) -> void:
	# Lighting/sky interpolation happens here, using the same day_progress that drives sun rotation.
	# No second timer or independent cycle is introduced.
	var direct_color: Color = _sample_color(day_progress, NIGHT_DIRECT_COLOR, DAWN_DIRECT_COLOR, DAY_DIRECT_COLOR, DUSK_DIRECT_COLOR)
	var direct_energy: float = _sample_float(day_progress, NIGHT_DIRECT_ENERGY, DAWN_DIRECT_ENERGY, DAY_DIRECT_ENERGY, DUSK_DIRECT_ENERGY)
	var ambient_color: Color = _sample_color(day_progress, NIGHT_AMBIENT_COLOR, DAWN_AMBIENT_COLOR, DAY_AMBIENT_COLOR, DUSK_AMBIENT_COLOR)
	var ambient_energy: float = _sample_float(day_progress, NIGHT_AMBIENT_ENERGY, DAWN_AMBIENT_ENERGY, DAY_AMBIENT_ENERGY, DUSK_AMBIENT_ENERGY)
	var fog_color: Color = _sample_color(day_progress, NIGHT_FOG_COLOR, DAWN_FOG_COLOR, DAY_FOG_COLOR, DUSK_FOG_COLOR)
	var sky_top_color: Color = _sample_color(day_progress, NIGHT_SKY_TOP_COLOR, DAWN_SKY_TOP_COLOR, DAY_SKY_TOP_COLOR, DUSK_SKY_TOP_COLOR)
	var sky_horizon_color: Color = _sample_color(day_progress, NIGHT_SKY_HORIZON_COLOR, DAWN_SKY_HORIZON_COLOR, DAY_SKY_HORIZON_COLOR, DUSK_SKY_HORIZON_COLOR)

	light_color = direct_color
	light_energy = direct_energy

	if _environment == null or _sky_material == null:
		_cache_world_environment()
	if _environment:
		_environment.ambient_light_color = ambient_color
		_environment.ambient_light_energy = ambient_energy
		# Keep fog density/enabled state unchanged; only tint it with the time-of-day palette.
		_environment.fog_light_color = fog_color
	if _sky_material:
		# Godot 4.7 exposes the procedural sky colors at runtime, but not the serialized
		# sky_energy/sky_cover_modulator keys from the .tscn, so only tint valid color fields here.
		_sky_material.sky_top_color = sky_top_color
		_sky_material.sky_horizon_color = sky_horizon_color
		_sky_material.ground_bottom_color = sky_top_color.darkened(0.28)
		_sky_material.ground_horizon_color = sky_horizon_color.darkened(0.18)

func _sample_color(day_progress: float, midnight: Color, dawn: Color, noon: Color, dusk: Color) -> Color:
	if day_progress < 0.25:
		return midnight.lerp(dawn, _smooth_segment(day_progress, 0.0, 0.25))
	elif day_progress < 0.5:
		return dawn.lerp(noon, _smooth_segment(day_progress, 0.25, 0.5))
	elif day_progress < 0.75:
		return noon.lerp(dusk, _smooth_segment(day_progress, 0.5, 0.75))
	return dusk.lerp(midnight, _smooth_segment(day_progress, 0.75, 1.0))

func _sample_float(day_progress: float, midnight: float, dawn: float, noon: float, dusk: float) -> float:
	if day_progress < 0.25:
		return lerp(midnight, dawn, _smooth_segment(day_progress, 0.0, 0.25))
	elif day_progress < 0.5:
		return lerp(dawn, noon, _smooth_segment(day_progress, 0.25, 0.5))
	elif day_progress < 0.75:
		return lerp(noon, dusk, _smooth_segment(day_progress, 0.5, 0.75))
	return lerp(dusk, midnight, _smooth_segment(day_progress, 0.75, 1.0))

func _smooth_segment(value: float, start: float, end: float) -> float:
	var t: float = clamp((value - start) / (end - start), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)
