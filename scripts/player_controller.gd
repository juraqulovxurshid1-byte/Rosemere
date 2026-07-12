extends CharacterBody3D

class_name PlayerController

# --- MOVEMENT SETTINGS ---
@export_group("Movement")
@export var move_speed: float = 6.0
@export var sprint_speed: float = 9.0
@export var acceleration: float = 10.0
@export var jump_velocity: float = 4.5
@export var gravity: float = 9.8

# --- WORLD BOUNDS ---
# Must stay in sync with minimap.gd/minimap_controller.gd world bounds.
# The margin keeps the player's capsule center safely inside the 5400×5400 ground.
const WORLD_MIN_X := -2700.0
const WORLD_MAX_X := 2700.0
const WORLD_MIN_Z := -2700.0
const WORLD_MAX_Z := 2700.0
const WORLD_BOUNDARY_MARGIN := 0.6

# --- COMBAT & STATS ---
@export_group("Combat")
@export var max_health: float = 100.0
@export var max_stamina: float = 100.0
@export var max_mana: float = 100.0
@export var attack_duration: float = 0.5
@export var attack_damage: float = 25.0
var current_health: float = max_health
var current_stamina: float = max_stamina
var current_mana: float = max_mana
var gold_coins: int = 0
var current_weapon_name: String = "Rusty Sword"
var is_attacking: bool = false
var has_quen_shield: bool = false
var current_speed: float = move_speed

# --- QUEST & XP ---
@export_group("Quest & XP")
var bandits_slain: int = 0
var quest_target: int = 3
var quest_completed: bool = false
var player_level: int = 1

# --- NODE REFERENCES ---
@onready var camera_pivot: Node3D = $CameraPivot
@onready var sprite: Sprite3D = $Sprite3D
@onready var melee_hitbox: Area3D = $MeleeHitbox
@onready var interact_area: Area3D = $InteractArea

# --- RIG ANIMATION NODES ---
@onready var rig_sub_viewport: SubViewport = $RigSubViewport
@onready var rig_root: Node2D = $RigSubViewport/PlayerRig
@onready var rig_anim_player: AnimationPlayer = $RigSubViewport/PlayerRig/AnimationPlayer

# --- 2.5D SPRITE ANIMATION RESOURCES ---
var tex_idle: Texture2D = null
var tex_run1: Texture2D = null
var tex_run2: Texture2D = null
var tex_attack: Texture2D = null
var anim_timer: float = 0.0
var run_frame: int = 0
var dialogue_ui: DialogueUI = null
var hud: HUD = null


func _ready() -> void:
	current_health = max_health
	current_stamina = max_stamina
	current_mana = max_mana



	_ensure_input_mappings()

	if camera_pivot:
		camera_pivot.top_level = true

	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if melee_hitbox:
		melee_hitbox.monitoring = false
		melee_hitbox.body_entered.connect(_on_melee_hit)

	call_deferred("_find_ui")

func _ensure_input_mappings() -> void:
	var key_mappings := {
		"move_forward": [KEY_W, KEY_UP],
		"move_backward": [KEY_S, KEY_DOWN],
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"interact": [KEY_E],
		"sprint": [KEY_SHIFT],
		"cast_igni": [KEY_Q],
		"cast_quen": [KEY_R]
	}
	for action in key_mappings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key_code in key_mappings[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key_code
			if not InputMap.action_has_event(action, event):
				InputMap.action_add_event(action, event)

	if not InputMap.has_action("attack"):
		InputMap.add_action("attack")
		var mouse_event := InputEventMouseButton.new()
		mouse_event.button_index = MOUSE_BUTTON_LEFT
		if not InputMap.action_has_event("attack", mouse_event):
			InputMap.action_add_event("attack", mouse_event)

func _find_ui() -> void:
	dialogue_ui = get_tree().root.find_child("DialogueUI", true, false) as DialogueUI
	hud = get_tree().root.find_child("HUD", true, false) as HUD
	if hud:
		if hud.has_method("update_health"):
			hud.update_health(current_health, max_health)
		if hud.has_method("update_stamina"):
			hud.update_stamina(current_stamina, max_stamina)
		if hud.has_method("update_mana"):
			hud.update_mana(current_mana, max_mana)
		if hud.has_method("update_gold"):
			hud.update_gold(gold_coins)
		if hud.has_method("update_weapon"):
			hud.update_weapon(current_weapon_name, attack_damage)
		if hud.has_method("update_quest"):
			hud.update_quest(bandits_slain, quest_target, quest_completed)

func _play_sound(type: String, extra: String = "") -> void:
	var sm := get_tree().root.find_child("SoundManager", true, false) as SoundManager
	if not sm:
		return
	if type == "slash": sm.play_slash()
	elif type == "coin": sm.play_coin()
	elif type == "igni": sm.play_igni()
	elif type == "quen": sm.play_quen()
	elif type == "fanfare": sm.play_fanfare()
	elif type == "voice": sm.play_voice(extra)

func stop_voice() -> void:
	var sm := get_tree().root.find_child("SoundManager", true, false) as SoundManager
	if sm and sm.has_method("stop_voice"):
		sm.stop_voice()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		try_interact()

	if event.is_action_pressed("ui_cancel") and (not dialogue_ui or not dialogue_ui.is_open):
		# Camera has no mouse-look, so keep the cursor visible. Esc only toggles
		# whether the visible cursor is confined to the game window.
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CONFINED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CONFINED)

func _physics_process(delta: float) -> void:
	_clamp_to_world_bounds()

	if camera_pivot:
		camera_pivot.global_position = global_position + Vector3(0, 0, 0)

	if dialogue_ui and dialogue_ui.is_open:
		velocity.x = move_toward(velocity.x, 0, acceleration * delta)
		velocity.z = move_toward(velocity.z, 0, acceleration * delta)
		move_and_slide()
		_clamp_to_world_bounds()
		return

	# 1. Apply Gravity
	if not is_on_floor():
		velocity.y -= gravity * delta

	# 2. Handle Combat / Attacking & Magic Signs
	if Input.is_action_just_pressed("attack") and not is_attacking and is_on_floor():
		if current_stamina >= 15.0:
			start_attack()
		else:
			if hud and hud.has_method("show_notification"):
				hud.show_notification("Not enough Stamina!", Color(1, 0.4, 0.4, 1))

	if Input.is_action_just_pressed("cast_igni") and not is_attacking and is_on_floor():
		if current_mana >= 35.0:
			cast_igni()
		else:
			if hud and hud.has_method("show_notification"):
				hud.show_notification("Not enough Mana for Igni!", Color(0.3, 0.6, 1.0, 1))

	if Input.is_action_just_pressed("cast_quen") and not is_attacking and is_on_floor():
		if current_mana >= 40.0:
			cast_quen()
		else:
			if hud and hud.has_method("show_notification"):
				hud.show_notification("Not enough Mana for Quen!", Color(0.3, 0.6, 1.0, 1))

	if is_attacking:
		velocity.x = move_toward(velocity.x, 0, acceleration * delta)
		velocity.z = move_toward(velocity.z, 0, acceleration * delta)
		move_and_slide()
		_clamp_to_world_bounds()
		return

	# 3. Handle Jump
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = jump_velocity

	# 4. Handle Sprint, Stamina & Mana Regen
	if Input.is_action_pressed("sprint") and velocity.length() > 0.5 and current_stamina > 0:
		current_speed = sprint_speed
		current_stamina = max(0.0, current_stamina - 20.0 * delta)
	else:
		current_speed = move_speed
		current_stamina = min(max_stamina, current_stamina + 15.0 * delta)

	current_mana = min(max_mana, current_mana + 12.0 * delta)

	if hud:
		if hud.has_method("update_stamina"):
			hud.update_stamina(current_stamina, max_stamina)
		if hud.has_method("update_mana"):
			hud.update_mana(current_mana, max_mana)

	# 5. Movement in World Cardinal Directions
	# Player NEVER rotates - always faces camera (Cult of the Lamb style)
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction := Vector3(input_dir.x, 0, input_dir.y).normalized()

	if direction:
		velocity.x = lerp(velocity.x, direction.x * current_speed, acceleration * delta)
		velocity.z = lerp(velocity.z, direction.z * current_speed, acceleration * delta)
	else:
		velocity.x = move_toward(velocity.x, 0, acceleration * delta)
		velocity.z = move_toward(velocity.z, 0, acceleration * delta)

	# Flip sprite horizontally based on horizontal movement
	if sprite and abs(velocity.x) > 0.1:
		sprite.flip_h = velocity.x < 0.0

	move_and_slide()
	_clamp_to_world_bounds()

func _clamp_to_world_bounds() -> void:
	var min_x := WORLD_MIN_X + WORLD_BOUNDARY_MARGIN
	var max_x := WORLD_MAX_X - WORLD_BOUNDARY_MARGIN
	var min_z := WORLD_MIN_Z + WORLD_BOUNDARY_MARGIN
	var max_z := WORLD_MAX_Z - WORLD_BOUNDARY_MARGIN

	var old_position := global_position
	var clamped_position := old_position
	clamped_position.x = clamp(clamped_position.x, min_x, max_x)
	clamped_position.z = clamp(clamped_position.z, min_z, max_z)

	if clamped_position == old_position:
		return

	global_position = clamped_position

	# Stop velocity pushing out of bounds so the player does not repeatedly slide/fall at the edge.
	if (old_position.x < min_x and velocity.x < 0.0) or (old_position.x > max_x and velocity.x > 0.0):
		velocity.x = 0.0
	if (old_position.z < min_z and velocity.z < 0.0) or (old_position.z > max_z and velocity.z > 0.0):
		velocity.z = 0.0

# --- WITCHER MAGIC SIGNS (AoE - hits all around, no directional cone) ---
func cast_igni() -> void:
	current_mana = max(0.0, current_mana - 35.0)
	print("[Magic] Casting IGNI (Fireblast)!")
	_play_sound("igni")
	if hud and hud.has_method("show_notification"):
		hud.show_notification("🔥 IGNI FIREBLAST CAST!", Color(1.0, 0.4, 0.1, 1))

	# AoE burst - hits ALL enemies within 7 units (360 degrees)
	var all_enemies := get_tree().root.find_children("*", "CharacterBody3D", true, false)
	for enemy in all_enemies:
		if (enemy is EnemyAI or enemy is BossTroll) and not enemy.is_dead:
			var dist: float = global_position.distance_to(enemy.global_position)
			if dist <= 7.0:
				print("[Magic] Igni burned: ", enemy.enemy_name)
				enemy.take_damage(45.0)

	if sprite:
		var tween := create_tween()
		tween.tween_property(sprite, "modulate", Color(1.0, 0.3, 0.0, 1), 0.15)
		tween.tween_property(sprite, "modulate", Color(1, 1, 1, 1), 0.15)

func cast_quen() -> void:
	current_mana = max(0.0, current_mana - 40.0)
	has_quen_shield = true
	print("[Magic] Casting QUEN (Magic Shield)!")
	_play_sound("quen")
	if hud and hud.has_method("show_notification"):
		hud.show_notification("🛡️ QUEN SHIELD ACTIVE! Absorbs next hit!", Color(1.0, 0.9, 0.2, 1))
	if sprite:
		sprite.modulate = Color(1.0, 0.9, 0.3, 1)

# --- INTERACTION LOGIC ---
func try_interact() -> void:
	print("[Interact] Pressed E! Checking for nearby objects...")
	if not dialogue_ui:
		_find_ui()

	# 1. Check Treasure Chests
	var all_chests := get_tree().root.find_children("*", "TreasureChest", true, false)
	for chest in all_chests:
		if chest is TreasureChest and not chest.is_opened:
			var dist: float = global_position.distance_to(chest.global_position)
			if dist <= 4.0:
				print("[Interact] Opening chest: ", chest.chest_name)
				chest.interact(self)
				return

	# 2. Check Groq NPCs
	if interact_area and dialogue_ui:
		for body in interact_area.get_overlapping_bodies():
			if body is GroqNPCAI:
				print("[Interact] Opening dialogue with: ", body.npc_name)
				dialogue_ui.open_dialogue(body)
				return

	# 3. Check Villagers
	if interact_area and dialogue_ui:
		for body in interact_area.get_overlapping_bodies():
			if body.has_method("interact") and body.has_method("_pick_new_target"):
				var vname = body.villager_name if "villager_name" in body else "Villager"
				print("[Interact] Talking to villager: ", vname)
				body.interact()
				return

	# 4. Distance failsafe
	if dialogue_ui:
		var all_nodes := get_tree().root.find_children("*", "Node3D", true, false)
		for node in all_nodes:
			if node is GroqNPCAI:
				var dist: float = global_position.distance_to(node.global_position)
				if dist <= 5.0:
					print("[Interact] Distance check: opening dialogue with: ", node.npc_name)
					dialogue_ui.open_dialogue(node)
					return

		for node in all_nodes:
			if node.has_method("interact") and node.has_method("_pick_new_target"):
				var dist: float = global_position.distance_to(node.global_position)
				if dist <= 5.0:
					var vname2 = node.villager_name if "villager_name" in node else "Villager"
					print("[Interact] Talking to villager (distance): ", vname2)
					node.interact()
					return

	print("[Interact] Nothing in reach!")
	if hud and hud.has_method("show_notification"):
		hud.show_notification("Nothing in reach to interact with!", Color(1, 0.7, 0.2, 1))

# --- COMBAT FUNCTIONS ---
func start_attack() -> void:
	is_attacking = true
	_play_sound("slash")
	current_stamina = max(0.0, current_stamina - 15.0)
	if hud and hud.has_method("update_stamina"):
		hud.update_stamina(current_stamina, max_stamina)

	if melee_hitbox:
		melee_hitbox.monitoring = true
		print("Swinging sword/axe! (Attack initiated)")

	if sprite:
		var tween := create_tween()
		tween.tween_property(sprite, "rotation:z", deg_to_rad(-15), attack_duration * 0.3)
		tween.tween_property(sprite, "rotation:z", deg_to_rad(10), attack_duration * 0.4)
		tween.tween_property(sprite, "rotation:z", 0.0, attack_duration * 0.3)

	await get_tree().create_timer(attack_duration).timeout

	if melee_hitbox:
		melee_hitbox.monitoring = false
	is_attacking = false

func _on_melee_hit(body: Node3D) -> void:
	if body.has_method("take_damage") and body != self:
		body.take_damage(attack_damage)
		print("Hit target: ", body.name, " for ", attack_damage, " damage!")

func _get_combat_feedback():
	var tree := get_tree()
	var feedback = tree.root.find_child("CombatFeedback", true, false)
	if feedback:
		return feedback

	var feedback_script = load("res://scripts/combat_feedback.gd")
	if feedback_script == null:
		return null

	feedback = Node.new()
	feedback.name = "CombatFeedback"
	feedback.set_script(feedback_script)

	var parent: Node = tree.current_scene
	if parent == null:
		parent = tree.root
	parent.add_child(feedback)
	return feedback

func take_damage(amount: float) -> void:
	var feedback = _get_combat_feedback()
	var impact_pos := global_position + Vector3(0, 1.15, 0)

	if has_quen_shield:
		has_quen_shield = false
		print("[Magic] Quen Shield absorbed the attack!")
		if feedback:
			feedback.spawn_floating_text("BLOCK", impact_pos + Vector3(0, 0.65, 0), Color(1.0, 0.9, 0.25, 1), 58, 1.2)
			feedback.spawn_impact_effect(impact_pos, Color(1.0, 0.9, 0.25, 1), 0.72, 9)
			feedback.screen_shake(0.11, 0.12)
		if hud and hud.has_method("show_notification"):
			hud.show_notification("✨ Quen Shield Absorbed " + str(amount) + " Dmg!", Color(1.0, 0.9, 0.2, 1))
		if sprite:
			sprite.modulate = Color(1, 1, 1, 1)
		return

	current_health = max(0.0, current_health - amount)
	print("[Player] OUCH! Took ", amount, " damage from enemy! Health remaining: ", current_health)

	if feedback:
		feedback.spawn_damage_number(amount, impact_pos + Vector3(0, 0.75, 0), Color(1.0, 0.25, 0.18, 1), amount >= 30.0)
		feedback.spawn_impact_effect(impact_pos, Color(1.0, 0.16, 0.10, 1), 0.62, 8)
		feedback.screen_shake(0.18, 0.18)
		feedback.hit_flash(sprite, Color(1.0, 0.08, 0.05, 1), 0.04, 0.12)

	if hud:
		if hud.has_method("update_health"):
			hud.update_health(current_health, max_health)
		if hud.has_method("show_notification"):
			hud.show_notification("Took " + str(amount) + " Damage!", Color(1, 0.2, 0.2, 1))

	if current_health <= 0:
		print("[Player] You have fallen in battle! Respawning...")
		if hud and hud.has_method("show_notification"):
			hud.show_notification("You Died! Respawning...", Color(1, 0.1, 0.1, 1))
		global_position = Vector3(0, 0.5, 5)
		current_health = max_health
		current_stamina = max_stamina
		current_mana = max_mana
		has_quen_shield = false
		if hud:
			if hud.has_method("update_health"):
				hud.update_health(current_health, max_health)
			if hud.has_method("update_stamina"):
				hud.update_stamina(current_stamina, max_stamina)
			if hud.has_method("update_mana"):
				hud.update_mana(current_mana, max_mana)

func take_healing(amount: float) -> void:
	var old_hp := current_health
	current_health = min(max_health, current_health + amount)
	if current_health > old_hp and hud:
		if hud.has_method("update_health"):
			hud.update_health(current_health, max_health)

func add_gold(amount: int) -> void:
	gold_coins += amount
	_play_sound("coin")
	if hud:
		if hud.has_method("update_gold"):
			hud.update_gold(gold_coins)
		if hud.has_method("show_notification"):
			hud.show_notification("+ " + str(amount) + " Gold Coins Bounty!", Color(1, 0.84, 0.0, 1))

func equip_weapon(weapon_name: String, new_damage: float, tint: Color) -> void:
	current_weapon_name = weapon_name
	attack_damage = new_damage
	print("[Player] Equipped new weapon: ", weapon_name, " (Damage: ", attack_damage, ")")
	if hud:
		if hud.has_method("update_weapon"):
			hud.update_weapon(weapon_name, attack_damage)
		if hud.has_method("show_notification"):
			hud.show_notification("Equipped: " + weapon_name + "!", tint)
	if sprite:
		var tween := create_tween()
		tween.tween_property(sprite, "modulate", tint, 0.2)
		tween.tween_property(sprite, "modulate", Color(1, 1, 1, 1), 0.2)

func on_bandit_slain() -> void:
	bandits_slain += 1
	print("[Quest] Bandit slain! Progress: ", bandits_slain, " / ", quest_target)
	if hud and hud.has_method("update_quest"):
		hud.update_quest(bandits_slain, quest_target, quest_completed)

	if bandits_slain >= quest_target and not quest_completed:
		quest_completed = true
		print("[Quest] Quest Complete! Return to Gareth for your reward!")
		if hud and hud.has_method("show_notification"):
			hud.show_notification("📜 Quest Complete! Return to Gareth!", Color(0.3, 1.0, 0.4, 1))

func level_up() -> void:
	player_level += 1
	max_health += 50.0
	current_health = max_health
	max_stamina += 25.0
	current_stamina = max_stamina
	max_mana += 25.0
	current_mana = max_mana
	print("[Player] LEVELED UP! Now Level ", player_level)
	_play_sound("fanfare")
	if hud:
		if hud.has_method("update_health"):
			hud.update_health(current_health, max_health)
		if hud.has_method("update_stamina"):
			hud.update_stamina(current_stamina, max_stamina)
		if hud.has_method("update_mana"):
			hud.update_mana(current_mana, max_mana)
		if hud.has_method("show_notification"):
			hud.show_notification("✨ LEVEL UP! HP, Stamina & Mana Boosted!", Color(0.3, 1.0, 0.4, 1))
