extends Node
## Test harness (not shipped): digging the mountain, in pictures — a tunnel dug down
## and sideways from the High Peak, buried finds glinting, a crater. C:/tmp/shots/dig2_*.
var level: Node
var p: CaveMan

func _ready() -> void:
	process_priority = 100
	GameState.reset()
	GameState.seen["level2"] = true
	level = load("res://level2/level2.tscn").instantiate()
	add_child(level)
	_run.call_deferred()

func _process(_d: float) -> void:
	if p != null:
		level.cam.zoom = Vector2(1.3, 1.3)
		level.cam.position_smoothing_enabled = false

func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
		for c in level.get_children():
			if c is Dialogue:
				c.queue_free()
		p.talking = false
		p.torch_fuel = 1.0
		p.invuln = 0.5

func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("C:/tmp/shots/dig2_%s.png" % name)
	print("shot ", name)

func blow(down: bool) -> void:
	p.touch["down"] = down
	p.touch["attack"] = true
	await frames(2)
	p.touch["attack"] = false
	await frames(24)
	p.touch["down"] = false

func _run() -> void:
	p = level.player
	await frames(5)
	p.give_torch()
	level.hud.visible = false
	level._move_player(Vector2(10060, -450), 1)
	await frames(20)
	for i in 10:
		await blow(true)
	p.facing = 1
	for i in 8:
		await blow(false)
		p.touch["right"] = true
		await frames(10)
		p.touch["right"] = false
	await frames(10)
	p.touch["attack"] = true
	await frames(6)
	await shot("tunnel")
	p.touch["attack"] = false
	await frames(30)
	# the glints: somewhere with buried finds near
	var t: Terrain = level.mountain
	var near := Vector2.ZERO
	for idx in t.loot:
		var at: Vector2 = t.position + Vector2(idx % t._w, idx / t._w) * Terrain.CELL
		var fy := t.ground_y(at.x, at.y - 200.0)
		if fy < at.y and at.y - fy < 160.0:
			near = Vector2(at.x - 40.0, fy - 2.0)
			break
	level._move_player(near, 1)
	await frames(40)
	await shot("glints")
	get_tree().quit()
