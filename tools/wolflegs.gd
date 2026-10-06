extends Node
var level: Node
var p: CaveMan
func _ready() -> void:
	GameState.reset()
	GameState.seen["level2"] = true
	level = load("res://level2/level2.tscn").instantiate()
	add_child(level)
	_run.call_deferred()
func _run() -> void:
	await get_tree().physics_frame
	p = level.player
	p.global_position = Vector2(700, 590)
	var w := NightBeasts.Wolf.new()
	w.left_x = 800.0
	w.right_x = 1400.0
	w.position = Vector2(900, 600)
	level.add_child(w)
	for i in 30: await get_tree().physics_frame
	for c in level.get_children():
		if c is Dialogue: c.queue_free()
	# watch it for a second: how far it goes, and whether its gait runs
	var x0 := w.position.x
	var strides := []
	for i in 60:
		await get_tree().physics_frame
		if i % 10 == 0:
			strides.append("%s mv%.0f st%.0f" % [w.state, w._moving, w._stride])
	print("moved %d px in a second; samples: %s" % [absf(w.position.x - x0), strides])
	get_tree().quit()
