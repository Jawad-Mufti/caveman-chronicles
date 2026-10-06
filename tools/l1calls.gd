extends Node
func _ready() -> void:
	var l: Node = load("res://level1/level1.tscn").instantiate()
	add_child(l)
	for i in 60:
		await get_tree().process_frame
	var t := 0.0
	for i in 20:
		await get_tree().process_frame
		t += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	print("level 1 draw calls: ", t / 20.0)
	get_tree().quit()
