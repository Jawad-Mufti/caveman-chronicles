extends Node
var level: Node
var p: CaveMan
func _ready() -> void:
	level = load("res://level2/level2.tscn").instantiate()
	add_child(level)
	_run.call_deferred()
func _run() -> void:
	for i in 5: await get_tree().physics_frame
	p = level.player
	for c in level.get_children():
		if c is Dialogue: c.queue_free()
	p.talking = false
	level._snuffed = true
	level._panicked = true
	p.global_position = Vector2(28760, 590)
	p.touch["right"] = true
	for i in 90:
		await get_tree().physics_frame
		if i % 15 == 0:
			print("f%d pos %s vel %s floor %s talking %s fury %.1f knock %.2f vine %s wind %.0f dialogues %d" % [i, p.global_position.round(), p.velocity.round(), p.is_on_floor(), p.talking, p.fury, p.knock, p.vine, p.wind,
				level.get_children().filter(func(c): return c is Dialogue or c is Shop).size()])
	get_tree().quit()
