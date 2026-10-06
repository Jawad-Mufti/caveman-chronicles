extends Node
var level: Node
var p: CaveMan
func _ready() -> void:
	GameState.reset()
	GameState.seen["level2"] = true
	level = load("res://level2/level2.tscn").instantiate()
	level.key_cave = 1
	add_child(level)
	_run.call_deferred()
func _run() -> void:
	for i in 5: await get_tree().physics_frame
	p = level.player
	for c in level.get_children():
		if c is Dialogue: c.queue_free()
	p.talking = false
	level._enter_cave(1)
	for i in 40: await get_tree().physics_frame
	var ex: Caves.CaveExit = null
	for c in level.get_children():
		if c is Caves.CaveExit and c.global_position.x > 36300:
			ex = c
	print("exit at ", ex.global_position, " player ", p.global_position, " talking ", p.talking)
	p.global_position = Vector2(37220, 590)
	p.facing = -1
	p.touch["left"] = true
	for i in 40:
		await get_tree().physics_frame
		if i % 5 == 0:
			print("f%d x %.0f floor %s facing %d overlap %s hold %.2f talking %s hp %d region %d" % [i, p.global_position.x, p.is_on_floor(), p.facing, ex.overlaps_body(p), ex._hold, p.talking, p.hp, level._region])
	get_tree().quit()
