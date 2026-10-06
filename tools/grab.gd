extends Node
## Test harness (not shipped): GRAB & THROW. Three wolves on the first stretch;
## he bonks the first (dazed), grabs it (THROW), holds it overhead, hurls it
## (THROW) and it bowls over the other two. One PASS/FAIL line per step.
##   shots - also save screenshots (run with rendering) to C:/tmp/shots/grab_*
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
		p.invuln = 0.5

func shot(name: String) -> void:
	if not shots:
		return
	level.cam.zoom = Vector2(2, 2)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("C:/tmp/shots/grab_%s.png" % name)

func press(k: String) -> void:
	p.touch[k] = true
	await frames(2)
	p.touch[k] = false

func check(name: String, ok: bool, info: String = "") -> void:
	print("%s %s %s" % ["PASS" if ok else "FAIL", name, info])

func _run() -> void:
	shots = OS.get_cmdline_user_args().has("shots")
	p = level.player
	await frames(5)
	p.pick_up_stick()
	for c in level.get_children():
		if c is NightBeasts.Wolf or c is NightBeasts.Bat:
			c.free()
	var wolves: Array = []
	for x in [1100.0, 1260.0, 1330.0]:
		var w := NightBeasts.Wolf.new()
		w.left_x = 1000.0
		w.right_x = 1490.0
		w.position = Vector2(x, 600)
		level.add_child(w)
		wolves.append(w)
	var a: Critter = wolves[0]
	for w in [wolves[1], wolves[2]]:
		w.set_physics_process(false)        # the pack stands still: a fair lane to bowl down
	level._move_player(Vector2(1040, 590), 1)
	p.facing = 1
	await frames(20)
	a.global_position.x = p.global_position.x + 55.0
	await press("attack")
	await frames(10)
	check("daze", CaveMan.Grab.is_dazed(a), "hp %d, %.0f px ahead" % [a.hp, a.global_position.x - p.global_position.x])
	await press("throw")
	await frames(3)
	check("grab", p.carrying == a)
	await frames(20)
	check("hold", a.global_position.y < p.global_position.y - 60.0, "wolf y %.0f, him %.0f" % [a.global_position.y, p.global_position.y])
	await shot("hold")
	var hp_b: int = wolves[1].hp + wolves[2].hp
	await press("throw")
	await frames(14)
	await shot("throw")
	var t := 0
	while t < 180 and is_instance_valid(a) and a.dying <= 0.0:
		await frames(1)
		t += 1
	check("out", not is_instance_valid(a) or a.dying > 0.0, "after %d frames" % t)
	var hp_after := 0
	for w in [wolves[1], wolves[2]]:
		hp_after += w.hp if is_instance_valid(w) else 0
	check("bowl", hp_after < hp_b, "pack hp %d -> %d" % [hp_b, hp_after])
	check("free", p.carrying == null and not CaveMan.Grab.can_grab(null))
	get_tree().quit()
