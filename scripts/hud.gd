extends CanvasLayer

class_name HUD

const HUD_TEXT_COLOR: Color = Color(0.690196, 0.552941, 0.341176, 1.0)

@onready var health_bar: TextureProgressBar = $Control/HudPanel/VBoxContainer/HPBar
@onready var stamina_bar: TextureProgressBar = $Control/HudPanel/VBoxContainer/StaminaBar
@onready var focus_bar: TextureProgressBar = $Control/HudPanel/VBoxContainer/FocusBar
@onready var health_text: Label = $Control/HudPanel/VBoxContainer/HPBar/HealthText
@onready var stamina_text: Label = $Control/HudPanel/VBoxContainer/StaminaBar/StaminaText
@onready var focus_text: Label = $Control/HudPanel/VBoxContainer/FocusBar/FocusText
@onready var gold_label: Label = $Control/HudPanel/VBoxContainer/GoldRow/GoldLabel
@onready var weapon_label: Label = $Control/HudPanel/VBoxContainer/WeaponRow/WeaponLabel
@onready var quest_label: Label = $Control/HudPanel/VBoxContainer/QuestRow/QuestLabel
@onready var time_label: Label = $Control/TimePanel/TimeInner/TimeRow/TimeLabel
@onready var day_label: Label = $Control/TimePanel/TimeInner/TimeRow/DayLabel
@onready var notification_label: Label = $Control/NotificationLabel

# Boss Bar References
@onready var boss_container: Control = $Control/BossContainer
@onready var boss_bar: ProgressBar = $Control/BossContainer/BossBar
@onready var boss_label: Label = $Control/BossContainer/BossBar/BossLabel

# TEMP DEV: clock click -> time input popup
@onready var time_panel = $Control/TimePanel
var _dev_time_popup = null
var _dev_time_input = null

func _ready() -> void:
	set_process(true)
	_update_clock_label()
	if notification_label:
		notification_label.modulate.a = 0.0
	if boss_container:
		boss_container.visible = false

	# TEMP DEV/TEST TOOL: click the clock to manually set in-game time for lighting/weather preview.
	# Remove once day/night + weather system is verified across the full cycle.
	_setup_dev_time_tool()

func _setup_dev_time_tool() -> void:
	call_deferred("_create_dev_time_popup")

	time_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_set_children_mouse_pass(time_panel)
	time_panel.gui_input.connect(_on_time_panel_gui_input)

func _set_children_mouse_pass(parent_node) -> void:
	for child in parent_node.get_children():
		child.mouse_filter = Control.MOUSE_FILTER_PASS
		_set_children_mouse_pass(child)

func _create_dev_time_popup() -> void:
	var root = $Control

	_dev_time_popup = Panel.new()
	_dev_time_popup.name = "DevTimePopup"
	_dev_time_popup.visible = false
	_dev_time_popup.offset_left = 16.0
	_dev_time_popup.offset_top = 56.0
	_dev_time_popup.offset_right = 210.0
	_dev_time_popup.offset_bottom = 84.0
	_dev_time_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	var popup_style = StyleBoxFlat.new()
	popup_style.bg_color = Color(0.1, 0.1, 0.1, 0.9)
	popup_style.border_width_left = 1
	popup_style.border_width_top = 1
	popup_style.border_width_right = 1
	popup_style.border_width_bottom = 1
	popup_style.border_color = Color(0.5, 0.5, 0.5, 1)
	_dev_time_popup.add_theme_stylebox_override("panel", popup_style)
	root.add_child(_dev_time_popup)

	_dev_time_input = LineEdit.new()
	_dev_time_input.name = "DevTimeInput"
	_dev_time_input.placeholder_text = "HH:MM or HH:MM:SS"
	_dev_time_input.anchor_left = 0.0
	_dev_time_input.anchor_top = 0.0
	_dev_time_input.anchor_right = 1.0
	_dev_time_input.anchor_bottom = 1.0
	_dev_time_input.offset_left = 4.0
	_dev_time_input.offset_top = 4.0
	_dev_time_input.offset_right = -4.0
	_dev_time_input.offset_bottom = -4.0
	_dev_time_input.text_submitted.connect(_on_dev_time_submitted)
	_dev_time_input.focus_exited.connect(_hide_dev_time_popup)
	_dev_time_popup.add_child(_dev_time_input)

func _on_time_panel_gui_input(event) -> void:
	# TEMP DEV/TEST TOOL: click the clock to open the dev time input.
	# Remove once day/night + weather system is verified across the full cycle.
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_show_dev_time_popup()

func _show_dev_time_popup() -> void:
	if _dev_time_popup and _dev_time_input:
		_dev_time_input.text = GameClock.get_time_string()
		_dev_time_popup.visible = true
		_dev_time_input.grab_focus()
		_dev_time_input.select_all()

func _hide_dev_time_popup() -> void:
	if _dev_time_popup:
		_dev_time_popup.visible = false

func _on_dev_time_submitted(text) -> void:
	# TEMP DEV/TEST TOOL: parse the entered time and set GameClock.elapsed_seconds.
	# Format: "HH:MM" or "HH:MM:SS" (24-hour).
	# Example: "19:00" -> 19:00:00, "06:30" -> 06:30:00, "06:30:45" -> 06:30:45.
	# Preserves the current day count - only the time-of-day component changes.
	var parts = text.split(":")
	var h = 0
	var m = 0
	var s = 0
	if parts.size() == 1:
		h = clampi(int(parts[0]), 0, 23)
	elif parts.size() == 2:
		h = clampi(int(parts[0]), 0, 23)
		m = clampi(int(parts[1]), 0, 59)
	elif parts.size() == 3:
		h = clampi(int(parts[0]), 0, 23)
		m = clampi(int(parts[1]), 0, 59)
		s = clampi(int(parts[2]), 0, 59)
	else:
		_hide_dev_time_popup()
		return

	var target_day_seconds = float(h * 3600 + m * 60 + s)
	# Preserve the current day count
	var days_elapsed = floor(GameClock.elapsed_seconds / 86400.0)
	GameClock.elapsed_seconds = days_elapsed * 86400.0 + target_day_seconds

	print("[DEV] Time set to ", GameClock.get_time_string(), " . Day ", GameClock.get_day())
	_hide_dev_time_popup()

func _unhandled_input(event) -> void:
	# TEMP DEV/TEST TOOL: keyboard shortcuts for weather preview.
	# 1 = Clear, 2 = Overcast, 3 = Storm.
	# Remove once day/night + weather system is verified.
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_1:
			if WeatherManager != null and is_instance_valid(WeatherManager):
				WeatherManager.set_weather(WeatherManager.WeatherState.CLEAR, true)
				print("[DEV] Weather set to CLEAR")
				show_notification("DEV: Weather -> Clear", Color(1, 1, 1, 1))
				get_viewport().set_input_as_handled()
		elif event.keycode == KEY_2:
			if WeatherManager != null and is_instance_valid(WeatherManager):
				WeatherManager.set_weather(WeatherManager.WeatherState.OVERCAST, true)
				print("[DEV] Weather set to OVERCAST")
				show_notification("DEV: Weather -> Overcast", Color(0.6, 0.6, 0.7, 1))
				get_viewport().set_input_as_handled()
		elif event.keycode == KEY_3:
			if WeatherManager != null and is_instance_valid(WeatherManager):
				WeatherManager.set_weather(WeatherManager.WeatherState.STORM, true)
				print("[DEV] Weather set to STORM")
				show_notification("DEV: Weather -> Storm", Color(0.4, 0.4, 0.5, 1))
				get_viewport().set_input_as_handled()

func update_health(current: float, max_val: float) -> void:
	if health_bar:
		health_bar.max_value = max_val
		health_bar.value = current
	if health_text:
		health_text.text = str(int(current)) + " / " + str(int(max_val))

func update_stamina(current: float, max_val: float) -> void:
	if stamina_bar:
		stamina_bar.max_value = max_val
		stamina_bar.value = current
	if stamina_text:
		stamina_text.text = str(int(current)) + " / " + str(int(max_val))

func update_focus(current: float, max_val: float) -> void:
	if focus_bar:
		focus_bar.max_value = max_val
		focus_bar.value = current
	if focus_text:
		focus_text.text = str(int(current)) + " / " + str(int(max_val))

func update_gold(amount: int) -> void:
	if gold_label:
		gold_label.text = "Gold Coins: " + str(amount)
		gold_label.modulate = HUD_TEXT_COLOR

func update_weapon(weapon_name: String, damage: float) -> void:
	if weapon_label:
		weapon_label.text = "Weapon: " + weapon_name + " (" + str(damage) + " Dmg)"
		weapon_label.modulate = HUD_TEXT_COLOR

func update_quest(slain: int, target: int, completed: bool) -> void:
	if not quest_label:
		return
	if completed:
		quest_label.text = "Quest Complete! Return to Gareth!"
	else:
		quest_label.text = "Quest: Slay North Road Bandits (" + str(slain) + " / " + str(target) + ")"
	quest_label.modulate = HUD_TEXT_COLOR

func _process(_delta: float) -> void:
	_update_clock_label()

func _update_clock_label() -> void:
	if time_label:
		time_label.text = GameClock.get_time_string()
		time_label.modulate = HUD_TEXT_COLOR
	if day_label:
		day_label.text = "Day " + str(GameClock.get_day())
		day_label.modulate = HUD_TEXT_COLOR

func update_time(time_str: String) -> void:
	if time_label:
		time_label.text = time_str
		time_label.modulate = HUD_TEXT_COLOR

func show_boss_bar(boss_name: String, current_hp: float, max_hp: float) -> void:
	if not boss_container or not boss_bar:
		return
	if current_hp <= 0 or boss_name.is_empty():
		boss_container.visible = false
	else:
		boss_container.visible = true
		boss_bar.max_value = max_hp
		boss_bar.value = current_hp
		if boss_label:
			boss_label.text = "Boss: " + boss_name + " (" + str(int(current_hp)) + " / " + str(int(max_hp)) + ")"

func show_notification(text: String, color: Color = Color(1, 0.84, 0.0, 1)) -> void:
	if not notification_label:
		return
	notification_label.text = text
	notification_label.modulate = color
	notification_label.modulate.a = 1.0

	var tween := create_tween()
	tween.tween_interval(1.5)
	tween.tween_property(notification_label, "modulate:a", 0.0, 0.8)
