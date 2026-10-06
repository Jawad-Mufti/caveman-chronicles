extends Node
## Test harness (not shipped): screenshots of the METEOR STOMP and the stomp
## spots. PNGs to C:/tmp/shots/stomp_*. Run with rendering (not headless).
## args: "nodark"
var level: Node
var p: CaveMan
var cam: Camera2D

func _ready() -> void:
	GameState.reset()
	GameState.seen["level2"] = true
	GameState.learn("sunfire")
	level = load("res://level2/level2.tscn").instantiate()
	add_child(level)
	_run.call_deferred()

func quiet() -> void:
	for c in level.get_children():
		if c is Dialogue or c is ItemGet:
			c.queue_free()
	p.talking = false

func wait(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
		quiet()
		p.torch_fuel = 1.0

func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var tag := "_nodark" if OS.get_cmdline_user_args().has("nodark") else ""
	get_viewport().get_texture().get_image().save_png("C:/tmp/shots/stomp_%s%s.png" % [name, tag])
	print("shot ", name)

## Jump (twice for a mega), T at the top; shots of the spin, the drop and the blast.
func stomp(double: bool, tag: String) -> void:
	while not p.is_on_floor():
		await wait(1)
	p.touch["jump"] = true
	var jumped2 := not double
	var pressed := false
	for i in 200:
		await wait(1)
		if not jumped2 and p.velocity.y > -150.0:
			p.touch["jump"] = false
			await wait(1)
			p.touch["jump"] = true
			jumped2 = true
			continue
		if jumped2 and not pressed and p.velocity.y > -120.0 and not p.is_on_floor():
			p.touch["stomp"] = true
			pressed = true
			await wait(5)
			await shot("charge" + tag)
			continue
		if pressed:
			p.touch["stomp"] = false
			if p.stomp_state == "dive" and p.velocity.y > 0.0:
				await wait(2)
				await shot("dive" + tag)
				while p.stomp_state != "":
					await wait(1)
				await wait(3)
				await shot("impact" + tag)
				break
	p.touch["jump"] = false

func _run() -> void:
	p = level.player
	await wait(5)
	p.give_torch()
	p.invuln = 99999.0
	for c in level.get_children():
		if c is Critter and not c is OldScar:
			c.queue_free()
	if OS.get_cmdline_user_args().has("nodark"):
		level.night.table = [[0.0, 0.0]]
	cam = get_viewport().get_camera_2d()
	cam.zoom = Vector2(1.3, 1.3)
	cam.offset = Vector2(0, 120)
	cam.limit_bottom = 100000
	# a cracked slab: before, then a plain stomp
	level._move_player(Vector2(1020, 590), 1)
	await wait(40)
	await shot("crack")
	level._move_player(Vector2(1100, 590), 1)
	await wait(20)
	await stomp(false, "1")
	await wait(30)
	await shot("found")
	# a rune seal: a plain stomp bounces off; then the MEGA STOMP
	level._move_player(Vector2(3720, 590), 1)
	await wait(40)
	await shot("seal")
	level._move_player(Vector2(3800, 590), 1)
	await wait(20)
	await stomp(false, "_clang")
	await wait(50)
	await stomp(true, "2")
	await wait(30)
	await shot("seal_open")
	get_tree().quit()
