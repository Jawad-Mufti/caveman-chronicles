extends Node
## Test harness (not shipped): pictures of treasure, Moonpuffs and deaths.
var level: Node
var p: CaveMan
var which := "l2"
func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		which = a
	GameState.reset()
	GameState.seen["level2"] = true
	level = load("res://level1/level1.tscn" if which == "l1" else "res://level2/level2.tscn").instantiate()
	add_child(level)
	_run.call_deferred()
func snap(n: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/shots/%s.png" % n)
func quiet() -> void:
	for c in level.get_children():
		if c is Dialogue:
			c.queue_free()
	p.talking = false
func wait(s: float) -> void:
	var t := 0.0
	while t < s:
		await get_tree().process_frame
		t += get_process_delta_time() / maxf(Engine.time_scale, 0.01)
		quiet()
func _run() -> void:
	await get_tree().process_frame
	p = level.player
	p.invuln = 999.0
	if which == "l1":
		var boar: Bestiary.Boar = level.boar
		p.global_position = Vector2(boar.position.x - 260.0, 590)
		await wait(0.5)
		boar.state = "charge"
		boar.vx = 420.0
		boar.take_hit(999, 1)
		await wait(1.1)
		await snap("tuskar")
		get_tree().quit()
		return
	p.give_torch()
	# treasure: the first ledge's cluster, and the camp log
	p.global_position = Vector2(800, 590)
	await wait(0.8)
	await snap("treasure")
	# a Moonpuff mid-bounce
	p.global_position = Vector2(8140, -30)
	p.velocity = Vector2.ZERO
	await wait(0.55)
	await snap("moonpuff")
	# a wolf, the moment after a killing blow
	var wolf: Critter = null
	for c in level.get_children():
		if c is NightBeasts.Wolf and (wolf == null or absf(c.position.x - 1330.0) < absf(wolf.position.x - 1330.0)):
			wolf = c
	p.global_position = Vector2(1150, 590)
	await wait(0.4)
	wolf.position = Vector2(1250, 600)
	wolf.take_hit(99, 1)
	await wait(0.22)
	await snap("wolf_death")
	# Old Scar, down, and then roaring at the sky
	level._snuffed = true
	level._panicked = true
	level._met_toolmaker = true
	p.global_position = Vector2(32600, 590)
	await wait(5.0)
	var sc: OldScar = level.scar
	sc.hp = 2
	sc.take_hit(3, 1)
	await wait(1.4)
	await snap("scar_down")
	await wait(2.0)
	await snap("scar_roar")
	get_tree().quit()
