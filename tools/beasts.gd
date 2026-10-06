extends Node
## Test harness (not shipped): cave animals, webs, and the killable troop.
var level: Node
var p: CaveMan
func _ready() -> void:
	level = load("res://level2/level2.tscn").instantiate()
	add_child(level)
	_run.call_deferred()
func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
func all(cls) -> Array:
	return level.get_children().filter(func(c): return is_instance_of(c, cls))
func quiet() -> void:
	for c in all(Dialogue):
		c.queue_free()
	p.talking = false
	for m in level._mouths:
		m._noticed = true
func stand(at: Vector2) -> void:
	p.global_position = at
	p.velocity = Vector2.ZERO
	p.hp = 5
	p.invuln = 0.0
func _run() -> void:
	await frames(5)
	p = level.player
	quiet()
	p.give_torch()
	# spider: walk under it
	var sp: Caves.Spider = all(Caves.Spider)[0]
	stand(Vector2(29060, 690))
	var states := {}
	for i in 240:
		p.torch_fuel = 1.0
		await get_tree().physics_frame
		states[sp.state] = true
	print("spider: %s, hp 5 -> %d" % [states.keys(), p.hp])
	# snake, alone: stand in front of its hole, then jump its strike
	for r in all(Caves.Rat):
		r.queue_free()
	await frames(2)
	var sn: Caves.Snake = all(Caves.Snake)[0]
	stand(Vector2(31210, 590))
	for i in 300:
		await get_tree().physics_frame
	print("snake, standing in front 5 s: hp 5 -> %d (%s)" % [p.hp, sn.state])
	stand(Vector2(31210, 590))
	while sn.state != "rear":
		p.global_position.x = 31210
		p.hp = 5
		await get_tree().physics_frame
	p.touch["jump"] = true
	for i in 30:
		await get_tree().physics_frame
	p.touch["jump"] = false
	await frames(30)
	print("snake, jumped when it hissed: hp 5 -> %d" % p.hp)
	# webs: torch out blocks, torch lit burns
	var web: Caves.Web = all(Caves.Web)[0]
	stand(Vector2(28760, 590))
	p.torch_fuel = 0.0
	p.touch["right"] = true
	await frames(60)
	print("web, torch out: stopped at x %.0f (web at %.0f), msg: %s" % [p.global_position.x, web.global_position.x, level.hud._msg.text.substr(0, 40)])
	p.torch_fuel = 1.0
	await frames(90)
	p.touch["right"] = false
	print("web, torch lit: now at x %.0f, web gone: %s" % [p.global_position.x, not is_instance_valid(web)])
	# monkeys: three hits
	var m: NightBeasts.Monkey = all(NightBeasts.Monkey)[0]
	for k in 3:
		m.take_hit(3, 1)
		await frames(5)
	await frames(90)
	print("monkey hit 3 times: freed %s, kills counted %d, banana left behind %d" % [not is_instance_valid(m), level.monkey_kills, all(NightBeasts.BananaPickup).size()])
	get_tree().quit()
