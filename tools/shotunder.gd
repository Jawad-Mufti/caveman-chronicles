extends Node
## Test harness (not shipped): screenshots of the underground, in place under the
## graveyard: the opened shaft from the ground, digging down, the den and THE GULPER,
## the Root Hollows. PNGs to C:/tmp/shots/under_*. Run with rendering.
var level: Node
var p: CaveMan

func _ready() -> void:
	GameState.reset()
	GameState.seen["level2"] = true
	level = load("res://level2/level2.tscn").instantiate()
	add_child(level)
	_run.call_deferred()

func quiet() -> void:
	for c in level.get_children():
		if c is Dialogue:
			c.queue_free()
	p.talking = false

func wait(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
		quiet()
		p.torch_fuel = 1.0

func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("C:/tmp/shots/under_%s.png" % name)
	print("shot ", name)

func blow() -> void:
	p.touch["down"] = true
	p.touch["attack"] = true
	await wait(2)
	p.touch["attack"] = false
	await wait(24)
	p.touch["down"] = false

func _run() -> void:
	p = level.player
	await wait(5)
	p.give_torch()
	p.invuln = 99999.0
	var b: Underground.Burrow = level._burrow
	b.open = true
	b.opened.emit()
	level._move_player(Vector2(b.global_position.x - 200.0, 590), 1)
	await wait(40)
	await shot("hole")
	level._move_player(Vector2(b.global_position.x, 600), 1)
	await wait(20)
	for i in 9:
		await blow()
	await wait(30)
	await shot("shaft")
	# the den: in, and the Gulper bursting out
	var den: Rect2 = level.DEN
	level._move_player(Vector2(den.position.x + 160.0, den.end.y - 4.0), 1)
	var g: Dig.Gulper = level._gulper
	for i in 600:
		await wait(1)
		if g.state == "lunge" and g._st > 0.3:
			break
	await shot("gulper")
	for i in 600:
		await wait(1)
		if g.state == "stuck" and g._st > 0.3:
			break
	await shot("stuck")
	# the Root Hollows
	level._move_player(Vector2(16000, 2128), 1)
	await wait(40)
	await shot("hollows")
	get_tree().quit()
