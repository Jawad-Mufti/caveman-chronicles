extends Node
## Test harness (not shipped): plays the whole key quest for one key location.
var level: Node
var p: CaveMan
var variant := 0

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("variant="):
			variant = int(a.split("=")[1])
	level = load("res://level2/level2.tscn").instantiate()
	level.key_cave = variant
	GameState.reset()
	GameState.seen["level2"] = true
	add_child(level)
	_run.call_deferred()

func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func talk_now() -> String:
	var said := []
	# talking is his choice now: press TALK (as a player presses E)
	if not level.get_children().any(func(c): return is_instance_valid(c) and c is Dialogue):
		p.touch["talk"] = true
		await frames(2)
		p.touch["talk"] = false
		await frames(3)
	for c in level.get_children():
		if c is Dialogue:
			while is_instance_valid(c) and c._i < c.lines.size():
				said.append(c._name.text + ": " + c._text.text)
				c._next()
	await frames(2)
	return " | ".join(said)

func stand(at: Vector2, facing: int) -> void:
	p.global_position = at
	p.velocity = Vector2.ZERO
	p.facing = facing
	p.hp = 5
	p.invuln = 1.0

func _run() -> void:
	await frames(5)
	p = level.player
	await talk_now()
	p.give_torch()
	print("== key in the %s" % ["Weeping Cave (spiders)", "Rattling Cave (snakes)"][variant])
	# meet Bongo
	stand(Vector2(23500, -418), 1)
	await frames(20)
	var intro: String = await talk_now()
	print("Bongo's clue: ", intro.substr(intro.find("and then"), 90))
	print("quest now: %s   HUD: %s" % [level.quest, level.hud._quest.text])
	# read both doors, go into the right cave
	var doors := [Vector2(22930, 590), Vector2(25570, 590)]
	for w in [0, 1]:
		stand(doors[w], -1)
		await frames(12)
		var hint: String = await talk_now()
		print("door %d hint: %s" % [w, hint.substr(0, 150)])
	stand(doors[variant], -1)
	p.touch["left"] = true
	await frames(40)
	p.touch["left"] = false
	await frames(30)
	print("went in: region %d at x %.0f, moon %.0f" % [level._region, p.global_position.x, level.night.moon_r])
	# open both hiding spots (the other one gives the decoy)
	var spot: Node = null
	var other: Node = null
	for c in level.get_children():
		if c is Caves.Cocoon:
			if variant == 0: spot = c
			else: other = c
		if c is Caves.Nest:
			if variant == 1: spot = c
			else: other = c
	for s in [other, spot]:
		for k in 2:
			s.take_hit(3, 1)
		await frames(90)
		for c in level.get_children():
			if c is Caves.KeyItem and not c.gone:
				stand(c.global_position + Vector2(0, -4), 1)
				await frames(6)
		print("opened %s: has_key = %s   HUD: %s" % [s.get_class() if false else ("cocoon" if s is Caves.Cocoon else "nest"), level.has_key, level.hud._msg.text.substr(0, 70)])
	# back out, and up to Bongo
	var exit_at := Vector2((34700 if variant == 0 else 38500) + 20, 590)
	stand(exit_at, -1)
	p.touch["left"] = true
	var exit_node: Node = null
	for c in level.get_children():
		if c is Caves.CaveExit and absf(c.global_position.x - exit_at.x) < 200.0:
			exit_node = c
	for i in 40:
		await get_tree().physics_frame
		if i % 8 == 0:
			print("  f%d x %.0f y %.1f vel %s knock %.2f floor %s facing %d overlap %s hold %.2f talking %s" % [i, p.global_position.x, p.global_position.y, p.velocity.round(), p.knock, p.is_on_floor(), p.facing, exit_node.overlaps_body(p), exit_node._hold, p.talking])
	p.touch["left"] = false
	await frames(30)
	print("came out: region %d at x %.0f" % [level._region, p.global_position.x])
	level._near_elder = false
	stand(Vector2(23500, -418), 1)
	await frames(20)
	var end: String = await talk_now()
	await frames(20)
	print("turn-in said: %s..." % end.substr(0, 60))
	print("quest %s, gem_found %s, box open %s, bananas left for him %d" % [level.quest, level.gem_found, level.elder.box_open,
		level.get_children().filter(func(c): return c is NightBeasts.BananaPickup).size()])
	get_tree().quit()
