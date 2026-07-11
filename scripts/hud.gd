extends CanvasLayer

class_name HUD

const HUD_TEXT_COLOR: Color = Color(0.690196, 0.552941, 0.341176, 1.0)

@onready var health_bar: TextureProgressBar = $Control/HudPanel/VBoxContainer/HPBar
@onready var stamina_bar: TextureProgressBar = $Control/HudPanel/VBoxContainer/StaminaBar
@onready var mana_bar: TextureProgressBar = $Control/HudPanel/VBoxContainer/ManaBar
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

func _ready() -> void:
	set_process(true)
	_update_clock_label()
	if notification_label:
		notification_label.modulate.a = 0.0
	if boss_container:
		boss_container.visible = false

func update_health(current: float, max_val: float) -> void:
	if health_bar:
		health_bar.max_value = max_val
		health_bar.value = current

func update_stamina(current: float, max_val: float) -> void:
	if stamina_bar:
		stamina_bar.max_value = max_val
		stamina_bar.value = current

func update_mana(current: float, max_val: float) -> void:
	if mana_bar:
		mana_bar.max_value = max_val
		mana_bar.value = current

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
			boss_label.text = "👹 Boss: " + boss_name + " (" + str(int(current_hp)) + " / " + str(int(max_hp)) + ")"

func show_notification(text: String, color: Color = Color(1, 0.84, 0.0, 1)) -> void:
	if not notification_label:
		return
	notification_label.text = text
	notification_label.modulate = color
	notification_label.modulate.a = 1.0
	
	var tween := create_tween()
	tween.tween_interval(1.5)
	tween.tween_property(notification_label, "modulate:a", 0.0, 0.8)
