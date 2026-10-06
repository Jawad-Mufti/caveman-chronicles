extends Node
## Test harness (not shipped): how long the mountain's chunk rebuild takes, by part.
func _ready() -> void:
	GameState.reset()
	GameState.seen["level2"] = true
	var level: Node = load("res://level2/level2.tscn").instantiate()
	add_child(level)
	await get_tree().process_frame
	var t: Terrain = level.mountain
	var fs: PackedFloat32Array = t._fields[Terrain.F_SOLID]
	var u := Time.get_ticks_usec()
	for i in 10:
		t._build_chunk(9)
	print("chunk rebuild: %.2f ms" % ((Time.get_ticks_usec() - u) / 10000.0))
	u = Time.get_ticks_usec()
	var e := []
	for i in 10:
		for r in t._h - 1:
			for c in range(72, 80):
				t._cell(fs, c, r, e)
	print("  one field's cells: %.2f ms" % ((Time.get_ticks_usec() - u) / 10000.0))
	u = Time.get_ticks_usec()
	for i in 10:
		t._refield(72, 25, 76, 29)
	print("  refield 5x5: %.2f ms" % ((Time.get_ticks_usec() - u) / 10000.0))
	get_tree().quit()
