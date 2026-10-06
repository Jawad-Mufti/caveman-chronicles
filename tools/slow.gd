extends Node
func _ready() -> void:
	Critter.slow_time(get_tree(), 0.07, 0.08)
	print("right after: ", Engine.time_scale)
	await get_tree().create_timer(0.3, true, false, true).timeout
	print("0.3 s real later: ", Engine.time_scale)
	get_tree().quit()
