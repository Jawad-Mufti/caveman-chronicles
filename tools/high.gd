extends Node
## Test harness (not shipped): can the high shells be reached with one jump, or only two?
var level: Node
var p: CaveMan
func _ready() -> void:
	GameState.reset()
	GameState.seen["level2"] = true
	level = load("res://level2/level2.tscn").instantiate()
	add_child(level)
	_run.call_deferred()
func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
func jump_at(x: float, twice: bool) -> int:
	GameState.reset()
	GameState.seen["level2"] = true
	for c in level.get_children():
		if c is Dialogue: c.queue_free()
	p.talking = false
	p.global_position = Vector2(x, 590)
	p.velocity = Vector2.ZERO
	await frames(10)
	var before := GameState.shells
	p.touch["jump"] = true
	await frames(22)
	p.touch["jump"] = false
	if twice:
		await frames(2)
		p.touch["jump"] = true
		await frames(18)
		p.touch["jump"] = false
	await frames(60)
	return GameState.shells - before
func _run() -> void:
	await frames(5)
	p = level.player
	for x in [1130.0, 3460.0, 23210.0, 30110.0]:
		var one := await jump_at(x, false)
		print("x %d: one jump got %d" % [x, one])
	# fresh level for the double jumps (the shells above are taken now)
	get_tree().quit()
	get_tree().quit()
