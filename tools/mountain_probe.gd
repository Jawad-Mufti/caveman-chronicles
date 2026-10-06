extends Node
## Test harness (not shipped): prints every floor of the mountain at some x's.
func _ready() -> void:
	GameState.reset()
	GameState.seen["level2"] = true
	var level: Node = load("res://level2/level2.tscn").instantiate()
	add_child(level)
	await get_tree().process_frame
	var t: Terrain = level.mountain
	var xs: Array = [9760, 9780, 9800, 9820, 9840, 9860, 9880]
	if not OS.get_cmdline_user_args().is_empty():
		xs = Array(OS.get_cmdline_user_args()).map(func(a: String) -> int: return int(a))
	for x in xs:
		var floors := []
		var y := -800.0
		while y < 1100.0:
			var g: float = t.ground_y(float(x), y)
			if g == INF:
				break
			floors.append(int(g))
			y = g + 5.0
		print("x %d: %s" % [x, str(floors)])
	get_tree().quit()
