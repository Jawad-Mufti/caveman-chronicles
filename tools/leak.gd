extends Node
## Test harness (not shipped): does anything pile up? 40 s of everything at
## once — running, stomping, Sunfire with a stream of fireballs, fire rings —
## then the node count (and object count) should come back to where it began.
var level: Node
var p: CaveMan

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

func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
		quiet()

func kinds() -> Dictionary:
	var d := {}
	for n in level.get_children():
		var k: String = n.get_class()
		for pair in [[Treasure.Pickup, "Pickup"], [Treasure.FloatText, "FloatText"], [Critter.DeathPop, "DeathPop"], [Sunfire.Impact, "Impact"], [Sunfire.Fireball, "Fireball"], [Stomp.Blast, "Blast"], [Stomp.Trail, "Trail"], [Critter, "Critter"], [CPUParticles2D, "Particles"]]:
			if is_instance_of(n, pair[0]):
				k = pair[1]
				break
		d[k] = int(d.get(k, 0)) + 1
	return d

func count() -> int:
	return get_tree().get_node_count()

func _run() -> void:
	p = level.player
	await frames(10)
	p.give_torch()
	p.invuln = 99999.0
	level._move_player(Vector2(24600, 590), 1)
	await frames(60)
	var n0 := count()
	var kinds0 := kinds()
	var o0 := Performance.get_monitor(Performance.OBJECT_COUNT)
	for round in 4:
		p.sun_charge = 1.0
		p.start_sunfire()
		p.wood = 4
		for i in 600:
			await frames(1)
			p.hp = 5
			p.torch_fuel = 1.0
			# back and forth along the flat ground
			var dir := 1 if (i / 120) % 2 == 0 else -1
			p.touch["right"] = dir > 0
			p.touch["left"] = dir < 0
			p.touch["throw"] = i % 6 < 3
			p.touch["jump"] = i % 50 < 14
			p.touch["stomp"] = i % 50 == 20
			p.touch["fire"] = i % 200 == 100
		for k in ["right", "left", "throw", "jump", "stomp", "fire"]:
			p.touch[k] = false
		p.end_sunfire()
		await frames(180)          # let every effect run out
		var k1 := kinds()
		for k in k1:
			if int(k1[k]) != int(kinds0.get(k, 0)):
				print("   %s: %d -> %d" % [k, int(kinds0.get(k, 0)), int(k1[k])])
		print("round %d: nodes %d (start %d), objects %d (start %d)" % [round, count(), n0, Performance.get_monitor(Performance.OBJECT_COUNT), o0])
	get_tree().quit()
