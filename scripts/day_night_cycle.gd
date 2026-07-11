extends DirectionalLight3D
class_name DayNightCycle

const SECONDS_PER_DAY = 86400.0

var _kp = [0.0, 0.166667, 0.25, 0.333333, 0.5, 0.666667, 0.75, 0.833333, 1.0]

# Direct light color - morning gold, evening red
var _dc = [
	Color(0.10, 0.12, 0.28),
	Color(0.22, 0.25, 0.45),
	Color(0.88, 0.55, 0.25),
	Color(0.95, 0.85, 0.55),
	Color(0.92, 0.95, 1.00),
	Color(0.90, 0.55, 0.25),
	Color(0.88, 0.28, 0.08),
	Color(0.30, 0.22, 0.42),
	Color(0.10, 0.12, 0.28),
]

# Direct energy - sunset cranked HIGH so it's actually visibly bright
var _de = [0.12, 0.20, 0.55, 0.90, 1.35, 0.80, 2.0, 0.25, 0.12]

# Ambient color - stays cooler/neutral than direct for contrast
var _ac = [
	Color(0.06, 0.08, 0.18),
	Color(0.14, 0.18, 0.32),
	Color(0.40, 0.30, 0.25),
	Color(0.62, 0.55, 0.46),
	Color(0.68, 0.72, 0.80),
	Color(0.48, 0.40, 0.35),
	Color(0.40, 0.32, 0.28),
	Color(0.26, 0.25, 0.40),
	Color(0.06, 0.08, 0.18),
]

var _ae = [0.10, 0.18, 0.35, 0.60, 0.95, 0.50, 0.80, 0.30, 0.10]

var _fd_ = [0.0004, 0.0005, 0.0005, 0.0003, 0.0002, 0.0003, 0.0004, 0.0004, 0.0004]

var _fc_ = [
	Color(0.08, 0.10, 0.20),
	Color(0.16, 0.18, 0.30),
	Color(0.40, 0.32, 0.24),
	Color(0.65, 0.55, 0.40),
	Color(0.65, 0.68, 0.72),
	Color(0.55, 0.42, 0.30),
	Color(0.22, 0.18, 0.16),
	Color(0.22, 0.22, 0.35),
	Color(0.08, 0.10, 0.20),
]

var _stc = [Color(0.04, 0.05, 0.14), Color(0.08, 0.10, 0.22), Color(0.22, 0.18, 0.35), Color(0.48, 0.58, 0.72), Color(0.58, 0.68, 0.85), Color(0.52, 0.50, 0.65), Color(0.32, 0.12, 0.22), Color(0.10, 0.08, 0.18), Color(0.04, 0.05, 0.14)]
var _shc = [Color(0.08, 0.10, 0.22), Color(0.18, 0.22, 0.38), Color(0.82, 0.40, 0.28), Color(0.85, 0.72, 0.55), Color(0.78, 0.80, 0.82), Color(0.85, 0.65, 0.48), Color(0.82, 0.35, 0.20), Color(0.32, 0.20, 0.28), Color(0.08, 0.10, 0.22)]

var time_of_day_str = "Night"
var _environment = null
var _sky_material = null
var _weather = null

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	_cache_world_environment()
	_find_weather()

func _process(_delta):
	var dp = fposmod(GameClock.elapsed_seconds, SECONDS_PER_DAY) / SECONDS_PER_DAY
	rotation_degrees.x = dp * 360.0 - 180.0
	var lc = _sample(dp, _dc)
	var le = _sample(dp, _de)
	var ambc = _sample(dp, _ac)
	var ambe = _sample(dp, _ae)
	var fc = _sample(dp, _fc_)
	var fd = _sample(dp, _fd_)
	var skyt = _sample(dp, _stc)
	var skyh = _sample(dp, _shc)
	if _weather != null:
		var wm = _weather.get_modifiers()
		lc = lc * wm["direct_color_mod"]
		le = le * wm["direct_energy_mod"]
		ambc = ambc * wm["ambient_color_mod"]
		ambe = ambe * wm["ambient_energy_mod"]
		fc = fc * wm["fog_color_mod"]
		fd = fd + wm["fog_density_add"]
		skyt = skyt * wm["sky_color_mod"]
		skyh = skyh * wm["sky_horizon_mod"]
	light_color = lc
	light_energy = max(le, 0.01)
	if _environment == null or _sky_material == null:
		_cache_world_environment()
	if _environment != null:
		_environment.ambient_light_color = ambc
		_environment.ambient_light_energy = ambe
		_environment.fog_light_color = fc
		_environment.fog_density = max(fd, 0.00001)
	if _sky_material != null:
		_sky_material.sky_top_color = skyt
		_sky_material.sky_horizon_color = skyh
		_sky_material.ground_bottom_color = skyt.darkened(0.28)
		_sky_material.ground_horizon_color = skyh.darkened(0.18)
	_update_label(dp)

func _sample(dp, vals):
	var n = vals.size()
	if n < 2:
		return vals[0] if n == 1 else Color(1, 1, 1, 1)
	for i in range(n - 1):
		var a = _kp[i]
		var b = _kp[i + 1]
		if dp >= a and dp <= b:
			var t = clamp((dp - a) / (b - a), 0.0, 1.0)
			t = t * t * (3.0 - 2.0 * t)
			return lerp(vals[i], vals[i + 1], t)
	if dp < _kp[0]:
		return vals[0]
	return vals[n - 1]

func _update_label(dp):
	if dp < 0.125 or dp >= 0.9167:
		time_of_day_str = "Deep Night"
	elif dp < 0.2083:
		time_of_day_str = "Astronomical Dawn"
	elif dp < 0.25:
		time_of_day_str = "Sunrise"
	elif dp < 0.375:
		time_of_day_str = "Golden Morning"
	elif dp < 0.625:
		time_of_day_str = "Bright Day"
	elif dp < 0.7083:
		time_of_day_str = "Golden Evening"
	elif dp < 0.7917:
		time_of_day_str = "Sunset"
	elif dp < 0.875:
		time_of_day_str = "Dusk"
	else:
		time_of_day_str = "Night"

func _cache_world_environment():
	var we = get_tree().root.find_child("WorldEnvironment", true, false) as WorldEnvironment
	if we != null:
		_environment = we.environment
		if _environment != null:
			_environment.fog_enabled = true
			if _environment.sky != null and _environment.sky.sky_material is ProceduralSkyMaterial:
				_sky_material = _environment.sky.sky_material as ProceduralSkyMaterial

func _find_weather():
	if WeatherManager != null and is_instance_valid(WeatherManager):
		_weather = WeatherManager
		return
	var wm = get_tree().root.find_child("WeatherManager", true, false)
	if wm != null:
		_weather = wm
