extends CanvasLayer

class_name HUD

@onready var health_bar: ProgressBar = $Control/VBoxContainer/HealthBar
@onready var stamina_bar: ProgressBar = $Control/VBoxContainer/StaminaBar
@onready var mana_bar: ProgressBar = $Control/VBoxContainer/ManaBar
@onready var gold_label: Label = $Control/VBoxContainer/GoldLabel
@onready var weapon_label: Label = $Control/VBoxContainer/WeaponLabel
@onready var quest_label: Label = $Control/VBoxContainer/QuestLabel
@onready var time_label: Label = $Control/VBoxContainer/TimeLabel
@onready var notification_label: Label = $Control/NotificationLabel

# Boss Bar References
@onready var boss_container: Control = $Control/BossContainer
@onready var boss_bar: ProgressBar = $Control/BossContainer/BossBar
@onready var boss_label: Label = $Control/BossContainer/BossBar/BossLabel

func _ready() -> void:
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
		gold_label.text = "💰 Gold Coins: " + str(amount)

func update_weapon(weapon_name: String, damage: float) -> void:
	if weapon_label:
		weapon_label.text = "⚔️ Weapon: " + weapon_name + " (" + str(damage) + " Dmg)"

func update_quest(slain: int, target: int, completed: bool) -> void:
	if not quest_label:
		return
	if completed:
		quest_label.text = "✨ Quest Complete! Return to Gareth!"
		quest_label.modulate = Color(0.3, 1.0, 0.4, 1)
	else:
		quest_label.text = "📜 Quest: Slay North Road Bandits (" + str(slain) + " / " + str(target) + ")"
		quest_label.modulate = Color(0.95, 0.8, 0.4, 1)

func update_time(time_str: String) -> void:
	if time_label:
		time_label.text = "⏰ Time: " + time_str
		if time_str.contains("Midnight"):
			time_label.modulate = Color(0.6, 0.7, 1.0, 1)
		elif time_str.contains("Golden"):
			time_label.modulate = Color(1.0, 0.7, 0.3, 1)
		else:
			time_label.modulate = Color(0.9, 0.95, 0.85, 1)

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
