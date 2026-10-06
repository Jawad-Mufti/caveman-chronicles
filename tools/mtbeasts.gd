extends Node
## Test harness (not shipped): the mountain's own creatures. No bats in the
## mountain; a cave worm bonked drops a grub that heals him; a risen skeleton
## rattles up when he comes near, hurts him, goes down, gets up ONCE more,
## and the second time stays down. One PASS/FAIL line each.
##   shots - also save screenshots (run with rendering) to C:/tmp/shots/mtb_*
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

func shot(name: String) -> void:
	if not shots:
		return
	level.cam.zoom = Vector2(2.2, 2.2)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("C:/tmp/shots/mtb_%s.png" % name)

func check(name: String, ok: bool, info: String = "") -> void:
	print("%s %s %s" % ["PASS" if ok else "FAIL", name, info])

func _run() -> void:
	shots = OS.get_cmdline_user_args().has("shots")
	p = level.player
	await frames(5)
	p.pick_up_stick()
	# 1. no bats anywhere over or in the mountain
	var bats := 0
	for c in level.get_children():
		if c is NightBeasts.Bat and c.global_position.x > 5640.0 and c.global_position.x < 12080.0:
			bats += 1
	check("no mountain bats", bats == 0, "%d left" % bats)
	# 2. a cave worm: bonk it, eat its grub
	var worm: Critter = null
	var skel: Critter = null
	for c in level.get_children():
		if worm == null and c is Mountain.CaveWorm:
			worm = c
		if skel == null and c is Mountain.RisenSkeleton:
			skel = c
	level._move_player(worm.global_position + Vector2(-120, -10), 1)
	await frames(30)
	p.invuln = 5.0
	await shot("worm")
	p.hp = 2
	worm._under = 0.0
	worm.take_hit(1, 1)
	await frames(30)
	var grub: Node2D = null
	for c in level.get_children():
		if c is Mountain.GrubPickup:
			grub = c
	var hp0 := 2
	if grub != null:
		level._move_player(grub.global_position + Vector2(0, -10), 1)
		await frames(20)
	check("worm grub heals", p.hp > hp0, "hp %d -> %d (grub %s)" % [hp0, p.hp, "eaten at once" if grub == null else "walked to"])
	# 3. a skeleton: up it comes when he is near
	p.hp = p.max_hp
	level._move_player(skel.global_position + Vector2(-200, -10), 1)
	p.facing = 1
	await frames(20)
	var t := 0
	while skel.state != "walk" and t < 180:
		await frames(1)
		t += 1
		if t == 40:
			await shot("rise")
	check("skeleton rises", skel.state == "walk", "in %.1f s" % (t / 60.0))
	await shot("up")
	# it comes for him and swings
	p.invuln = 0.0
	var hp1 := p.hp
	t = 0
	while p.hp >= hp1 and t < 360:
		await frames(1)
		t += 1
		if skel.state == "swing" and skel._tst > 0.3 and skel._tst < 0.33:
			await shot("swing")
	check("skeleton attacks", p.hp < hp1, "hp %d -> %d after %.1f s" % [hp1, p.hp, t / 60.0])
	p.invuln = 99.0
	# down... and up again
	skel.take_hit(9, 1)
	await frames(5)
	var went_down: bool = skel.state == "down" and skel.dying <= 0.0
	await shot("down")
	t = 0
	while skel.state != "walk" and t < 360:
		await frames(1)
		t += 1
	check("gets up once more", went_down and skel.state == "walk", "down %s, up after %.1f s" % [went_down, t / 60.0])
	skel.take_hit(9, 1)
	await frames(5)
	check("second time: gone", skel.dying > 0.0)
	get_tree().quit()
