extends Node
## Test harness (not shipped): the furred beasts up close — the mammoth herd on the
## Steppe, the wolves by the camp. PNGs to C:/tmp/shots/beast_*. Run with rendering.
var level: Node
var p: CaveMan
var at := Vector2.ZERO
var zoom := 1.6

func _ready() -> void:
	process_priority = 100
	GameState.reset()
	GameState.seen["level2"] = true
	level = load("res://level2/level2.tscn").instantiate()
	add_child(level)
	_run.call_deferred()

func _process(_d: float) -> void:
	if p != null:
		level.cam.zoom = Vector2(zoom, zoom)
		level.cam.position_smoothing_enabled = false
		level.cam.global_position = at

func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
		for c in level.get_children():
			if c is Dialogue:
				c.queue_free()
		p.talking = false
		p.torch_fuel = 1.0
		p.invuln = 9.0

func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("C:/tmp/shots/beast_%s.png" % name)
	print("shot ", name)

func _run() -> void:
	p = level.player
	await frames(5)
	p.give_torch()
	level.hud.visible = false
	var m: Node2D = null
	for c in level.get_children():
		if c is Steppe.Mammoth:
			m = c
			break
	level._move_player(m.global_position + Vector2(-260, 0), 1)
	for i in 3:
		at = m.global_position + Vector2(0, -150)
		await frames(25)
		await shot("mammoth%d" % i)
	var w: Node2D = null
	for c in level.get_children():
		if c is NightBeasts.Wolf:
			w = c
			break
	zoom = 2.4
	level._move_player(w.global_position + Vector2(-320, 0), 1)
	for i in 3:
		at = w.global_position + Vector2(0, -50)
		await frames(20)
		await shot("wolf%d" % i)
	get_tree().quit()
