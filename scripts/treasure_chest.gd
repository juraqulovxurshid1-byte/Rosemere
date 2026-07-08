extends StaticBody3D

class_name TreasureChest

@export var chest_name: String = "Old Wooden Chest"
@export var gold_reward: int = 25
@export var heal_reward: float = 50.0
var is_opened: bool = false

@onready var prompt_label: Label3D = $PromptLabel
@onready var sprite: Sprite3D = $Sprite3D

func interact(player: PlayerController) -> void:
	if is_opened:
		return
	is_opened = true
	print("[Chest] Opened chest! Rewarding gold and healing!")
	if player:
		if player.has_method("add_gold"):
			player.add_gold(gold_reward)
		if player.has_method("take_healing"):
			player.take_healing(heal_reward)
	if prompt_label:
		prompt_label.text = "💰 " + chest_name + " [Empty]"
		prompt_label.modulate = Color(0.5, 0.5, 0.5, 1)
	if sprite:
		sprite.modulate = Color(0.4, 0.3, 0.2, 1) # Darken when empty
