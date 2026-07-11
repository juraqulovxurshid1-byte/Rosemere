extends Node

enum WeatherState { CLEAR, OVERCAST, STORM }

var current_weather = WeatherState.CLEAR
var target_weather = WeatherState.CLEAR
var transition_duration = 4.0
var transition_progress = 1.0
var _prev_mods = {}
var _target_mods = {}
var _needs_transition = false
var auto_cycle_enabled = false
var _cycle_timer = 0.0
var _cycle_interval = 180.0

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	_prev_mods = _build_mods(WeatherState.CLEAR)
	_target_mods = _build_mods(WeatherState.CLEAR)

func _process(delta):
	if _needs_transition:
		transition_progress = min(1.0, transition_progress + delta / max(transition_duration, 0.01))
		if transition_progress >= 1.0:
			_needs_transition = false
			current_weather = target_weather
	if auto_cycle_enabled:
		_cycle_timer += delta
		if _cycle_timer >= _cycle_interval:
			_cycle_timer = 0.0
			_cycle_interval = randf_range(120.0, 360.0)
			var r = randi() % 10
			if r < 6:
				set_weather(WeatherState.CLEAR)
			elif r < 8:
				set_weather(WeatherState.OVERCAST)
			else:
				set_weather(WeatherState.STORM)

func set_weather(state, instant = false):
	if state == current_weather and not _needs_transition:
		return
	target_weather = state
	if instant or transition_progress >= 1.0:
		_prev_mods = _build_mods(state)
		_target_mods = _build_mods(state)
		transition_progress = 1.0
		current_weather = state
		_needs_transition = false
	else:
		_prev_mods = get_modifiers()
		_target_mods = _build_mods(state)
		transition_progress = 0.0
		_needs_transition = true

func get_modifiers():
	if not _needs_transition:
		return _target_mods
	var t = _smoothstep(transition_progress)
	return {
		"direct_color_mod": _prev_mods["direct_color_mod"].lerp(_target_mods["direct_color_mod"], t),
		"direct_energy_mod": lerp(_prev_mods["direct_energy_mod"], _target_mods["direct_energy_mod"], t),
		"ambient_color_mod": _prev_mods["ambient_color_mod"].lerp(_target_mods["ambient_color_mod"], t),
		"ambient_energy_mod": lerp(_prev_mods["ambient_energy_mod"], _target_mods["ambient_energy_mod"], t),
		"fog_color_mod": _prev_mods["fog_color_mod"].lerp(_target_mods["fog_color_mod"], t),
		"fog_density_add": lerp(_prev_mods["fog_density_add"], _target_mods["fog_density_add"], t),
		"sky_color_mod": _prev_mods["sky_color_mod"].lerp(_target_mods["sky_color_mod"], t),
		"sky_horizon_mod": _prev_mods["sky_horizon_mod"].lerp(_target_mods["sky_horizon_mod"], t)
	}

func _build_mods(state):
	if state == WeatherState.CLEAR:
		return {
			"direct_color_mod": Color(1, 1, 1, 1),
			"direct_energy_mod": 1.0,
			"ambient_color_mod": Color(1, 1, 1, 1),
			"ambient_energy_mod": 1.0,
			"fog_color_mod": Color(1, 1, 1, 1),
			"fog_density_add": 0.0,
			"sky_color_mod": Color(1, 1, 1, 1),
			"sky_horizon_mod": Color(1, 1, 1, 1)
		}
	if state == WeatherState.OVERCAST:
		return {
			"direct_color_mod": Color(0.55, 0.55, 0.55, 1),
			"direct_energy_mod": 0.55,
			"ambient_color_mod": Color(0.60, 0.60, 0.60, 1),
			"ambient_energy_mod": 0.55,
			"fog_color_mod": Color(0.55, 0.55, 0.58, 1),
			"fog_density_add": 0.0012,
			"sky_color_mod": Color(0.50, 0.50, 0.52, 1),
			"sky_horizon_mod": Color(0.55, 0.55, 0.55, 1)
		}
	if state == WeatherState.STORM:
		return {
			"direct_color_mod": Color(0.35, 0.35, 0.38, 1),
			"direct_energy_mod": 0.30,
			"ambient_color_mod": Color(0.40, 0.40, 0.42, 1),
			"ambient_energy_mod": 0.30,
			"fog_color_mod": Color(0.30, 0.30, 0.32, 1),
			"fog_density_add": 0.0030,
			"sky_color_mod": Color(0.30, 0.30, 0.32, 1),
			"sky_horizon_mod": Color(0.35, 0.35, 0.36, 1)
		}
	return _build_mods(WeatherState.CLEAR)

func _smoothstep(t):
	return t * t * (3.0 - 2.0 * t)
