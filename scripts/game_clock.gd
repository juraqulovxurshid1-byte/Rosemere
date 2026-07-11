extends Node

const TIME_SCALE: float = 6.0
const SECONDS_PER_DAY: float = 86400.0
const START_HOUR: int = 8
const START_MINUTE: int = 0
const START_SECOND: int = 0

var elapsed_seconds: float = START_HOUR * 3600.0 + START_MINUTE * 60.0 + START_SECOND

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(delta: float) -> void:
	elapsed_seconds += delta * TIME_SCALE

func get_day() -> int:
	return int(floor(elapsed_seconds / SECONDS_PER_DAY)) + 1

func get_hour() -> int:
	var day_seconds := int(fposmod(elapsed_seconds, SECONDS_PER_DAY))
	return int(day_seconds / 3600)

func get_minute() -> int:
	var day_seconds := int(fposmod(elapsed_seconds, SECONDS_PER_DAY))
	return int((day_seconds % 3600) / 60)

func get_second() -> int:
	var day_seconds := int(fposmod(elapsed_seconds, SECONDS_PER_DAY))
	return day_seconds % 60

func get_time_string() -> String:
	return "%02d:%02d:%02d" % [get_hour(), get_minute(), get_second()]
