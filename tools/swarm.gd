extends Node
## Test harness (not shipped): busier, smarter beasts. Four wolves at once take
## TURNS (never more than two attacking together); each new attack happens
## (skeleton bone, bat screech, rat leap, snake spit, wolf howl); an ambush
## fires, rushes him and clears with a burst of orbs. One PASS/FAIL line each.
##   shots - also save screenshots (run with rendering) to C:/tmp/shots/swarm_*
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
		p.hp = p.max_hp
		p.invuln = 0.0 if p.invuln > 0.9 else p.invuln

func shot(name: String) -> void:
	if not shots:
		return
	level.cam.zoom = Vector2(1.4, 1.4)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("C:/tmp/shots/swarm_%s.png" % name)

func check(name: String, ok: bool, info: String = "") -> void:
	print("%s %s %s" % ["PASS" if ok else "FAIL", name, info])

func clear_beasts() -> void:
	for c in level.get_children():
		if c is Critter:
			c.free()

func wait_for(cond: Callable, secs: float) -> bool:
	var n := int(secs * 60.0)
	for i in n:
		await frames(1)
		if cond.call():
			return true
	return false

func any_of(script_class) -> bool:
	for c in level.get_children():
		if is_instance_of(c, script_class):
			return true
	return false

func _run() -> void:
	shots = OS.get_cmdline_user_args().has("shots")
	p = level.player
	await frames(5)
	p.pick_up_stick()
	clear_beasts()
	# 1. four wolves: turns, never more than two at once
	level._move_player(Vector2(1250, 590), 1)
	await frames(10)
	var wolves: Array = []
	for x in [1010.0, 1080.0, 1420.0, 1480.0]:
		var w := NightBeasts.Wolf.new()
		w.left_x = 1000.0
		w.right_x = 1490.0
		w.position = Vector2(x, 600)
		level.add_child(w)
		wolves.append(w)
		w.stompable = false          # (a bitten, tossed Ugu landing on one is a stomp: not what this measures)
	var most := 0
	var leapers := {}
	for i in 600:
		p.global_position.x = 1250.0          # (held in the middle of their ground: knock-back would carry him off it)
		await frames(1)
		var now := 0
		for w in wolves:
			if is_instance_valid(w) and w.state in ["crouch", "lunge"]:
				now += 1
				leapers[w.get_instance_id()] = true
		most = maxi(most, now)
		if i == 300:
			await shot("pack")
	check("wolves take turns", most <= 2 and leapers.size() >= 2, "at most %d at once, %d different wolves attacked" % [most, leapers.size()])
	clear_beasts()
	await frames(10)
	# 2. a skeleton throws its bone from range
	level._move_player(Vector2(1100, 590), 1)
	var sk := Mountain.RisenSkeleton.new()
	sk.left_x = 1000.0
	sk.right_x = 1490.0
	sk.position = Vector2(1400, 600)
	level.add_child(sk)
	sk.state = "walk"
	sk.rise = 1.0
	var bone := await wait_for(func() -> bool: return any_of(Mountain.BoneBoomerang), 8.0)
	await shot("bone")
	check("skeleton throws a bone", bone)
	clear_beasts()
	await frames(10)
	# 3. a bat screeches
	var bat := NightBeasts.Bat.new()
	bat.ground_y = 600.0
	bat.position = Vector2(1350, 540)
	level.add_child(bat)
	var wave := await wait_for(func() -> bool: return any_of(NightBeasts.SonicWave), 10.0)
	await shot("screech")
	check("bat screeches", wave)
	clear_beasts()
	await frames(10)
	# 4. a rat leaps
	level._move_player(Vector2(1100, 590), 1)
	await frames(10)
	var rat := Caves.Rat.new()
	rat.left_x = 1000.0
	rat.right_x = 1490.0
	rat.position = Vector2(1260, 600)
	rat.stompable = false        # (a tossed Ugu landing on it would squash it mid-test)
	level.add_child(rat)
	var leapt := false
	for tries in 5:
		level._move_player(Vector2(rat.position.x - 170.0, 590), 1)
		leapt = await wait_for(func() -> bool: return is_instance_valid(rat) and rat._air, 3.0)
		if leapt:
			break
	check("rat leaps", leapt)
	clear_beasts()
	await frames(10)
	# 5. a snake spits
	level._move_player(Vector2(1100, 590), 1)
	await frames(10)
	var snake := Caves.Snake.new()
	snake.dir = -1
	snake.position = Vector2(1400, 580)
	level.add_child(snake)
	var spat := await wait_for(func() -> bool: return any_of(Caves.VenomGlob), 8.0)
	await shot("spit")
	check("snake spits", spat)
	clear_beasts()
	await frames(10)
	# 6. a hurt wolf howls, and a packmate comes running
	NightBeasts.Wolf._last_howl_ms = -100000      # (a wolf in the pack test may have howled just now)
	level._move_player(Vector2(1100, 590), 1)
	p.give_torch()
	var lone := NightBeasts.Wolf.new()
	lone.left_x = 1000.0
	lone.right_x = 1490.0
	lone.position = Vector2(1400, 600)
	level.add_child(lone)
	lone.hp = 3
	var howled := await wait_for(func() -> bool: return is_instance_valid(lone) and lone.state == "howl", 15.0)
	await frames(80)
	var n := 0
	for c in level.get_children():
		if c is NightBeasts.Wolf:
			n += 1
	check("wolf howls for the pack", howled and n >= 2, "howled %s, wolves now %d" % [howled, n])
	clear_beasts()
	await frames(10)
	# 7. an ambush: the graveyard's skeletons
	var orbs0 := GameState.orbs
	level._move_player(Vector2(15500, 590), 1)
	var came := await wait_for(func() -> bool:
		var k := 0
		for c in level.get_children():
			if c is Mountain.RisenSkeleton:
				k += 1
		return k >= 3, 5.0)
	await shot("ambush")
	check("ambush fires", came)
	p.invuln = 99.0
	for c in level.get_children():
		if c is Mountain.RisenSkeleton:
			c.take_hit(99, 0)
	await frames(180)
	check("ambush cleared, orbs paid", GameState.orbs > orbs0 + 6, "orbs %d -> %d" % [orbs0, GameState.orbs])
	get_tree().quit()
