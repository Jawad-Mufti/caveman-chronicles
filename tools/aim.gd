extends Node
## Test harness (not shipped): AIMING. The arrows aim swings and throws, 8
## ways; UP no longer jumps (SPACE does). An upward swing hits what is above
## him; UP + RIGHT throws at 45 degrees; a rock ricochets off a beast and
## bounces off the ground. One PASS/FAIL line each.
##   shots - also save screenshots (run with rendering) to C:/tmp/shots/aim_*
var level: Node
var p: CaveMan
var shots := false

func _ready() -> void:
	GameState.reset()
	GameState.seen["level2"] = true
	level = load("res://level2/level2.tscn").instantiate()
	add_child(level)
	_run.call_deferred()

func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
		for c in level.get_children():
			if c is Dialogue:
				c.queue_free()
		p.talking = false
		p.invuln = 1.0

func shot(name: String) -> void:
	if not shots:
		return
	level.cam.zoom = Vector2(1.8, 1.8)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("C:/tmp/shots/aim_%s.png" % name)

func check(name: String, ok: bool, info: String = "") -> void:
	print("%s %s %s" % ["PASS" if ok else "FAIL", name, info])

func release() -> void:
	for k in p.touch.keys():
		p.touch[k] = false

func pinned_wolf(at: Vector2) -> Critter:
	var w := NightBeasts.Wolf.new()
	w.left_x = at.x - 1.0
	w.right_x = at.x + 1.0
	w.position = at
	level.add_child(w)
	w.hp = 300
	w.set_physics_process(false)
	return w

func newest_rock() -> Node:
	var r: Node = null
	for c in level.get_children():
		if c is World.ThrownRock:
			r = c
	return r

func _run() -> void:
	shots = OS.get_cmdline_user_args().has("shots")
	p = level.player
	await frames(5)
	p.pick_up_stick()
	for c in level.get_children():
		if c is NightBeasts.Wolf or c is NightBeasts.Bat:
			c.free()
	level._move_player(Vector2(1100, 590), 1)
	p.facing = 1
	await frames(20)
	# 1. the aim, and UP no longer jumps
	p.touch["up"] = true
	p.touch["right"] = true
	await frames(1)
	var a := p.aim()
	await frames(10)
	var stayed := p.is_on_floor()
	release()
	check("aim up-right = 45 degrees", absf(a.x - 0.707) < 0.01 and absf(a.y + 0.707) < 0.01, "aim %s" % a)
	check("UP does not jump", stayed)
	await frames(10)
	# 2. an upward swing hits a beast above him
	var above := pinned_wolf(p.global_position + Vector2(0, -95))
	var hp0 := above.hp
	p.touch["up"] = true
	p.touch["attack"] = true
	await frames(20)
	await shot("swing_up")
	release()
	check("swing up hits above", above.hp < hp0, "hp %d -> %d" % [hp0, above.hp])
	above.free()
	await frames(10)
	# 3. UP + RIGHT throws at 45 degrees
	p.rocks = 3
	p.touch["up"] = true
	p.touch["right"] = true
	p.touch["throw"] = true
	await frames(2)
	release()
	var r := newest_rock()
	var ang := rad_to_deg(r.vel.angle()) if r != null else 0.0
	check("throw at 45 degrees", r != null and absf(ang + 45.0) < 8.0, "angle %.0f" % ang)
	# it comes back down and bounces off the ground
	var bounced := false
	for i in 120:
		await frames(1)
		if not is_instance_valid(r):
			break
		if r._bounces > 0:
			bounced = true
			await shot("clack")
			break
	check("rock bounces off the ground", bounced)
	await frames(30)
	# 4. straight ahead into a beast: BONK, and it ricochets up off it
	var w := pinned_wolf(Vector2(1185, 600))
	hp0 = w.hp
	p.touch["throw"] = true
	await frames(2)
	release()
	r = newest_rock()
	var rico := false
	for i in 60:
		await frames(1)
		if not is_instance_valid(r):
			break
		if r._hits > 0:
			rico = r.vel.y < 0.0
			await shot("bonk")
			break
	check("rock bonks and ricochets", w.hp < hp0 and rico, "hp %d -> %d, ricochet %s" % [hp0, w.hp, rico])
	get_tree().quit()
