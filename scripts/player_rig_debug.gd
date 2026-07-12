extends Node2D

# DEBUG: temporary frame-counter for PlayerRig inside the SubViewport.
# Used to compare process cadence against the main scene.
var process_count: int = 0

func _process(_delta: float) -> void:
	process_count += 1

func get_process_count() -> int:
	var count := process_count
	process_count = 0
	return count
