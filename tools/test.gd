extends Node
## Test harness (not shipped): drives Level 2 through scripted scenarios.
var level: Node
var p: CaveMan

func _ready() -> void:
	level = load("res://level2/level2.tscn").instantiate()
	add_child(level)
	_run.call_deferred()

func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func wolves() -> Array:
	var out := []
	for c in get_tree().get_nodes_in_group("critters"):
		if c is NightBeasts.Wolf and c.dying <= 0.0:
			out.append(c)
	return out

func place(x: float, y: float, fuel: float) -> void:
	if p.dead:
		p.revive(Vector2(x, y))       # the dark may have killed him in the step before
	p.global_position = Vector2(x, y)
	p.velocity = Vector2.ZERO
	p.torch_fuel = fuel
	p.hp = 5
	p.invuln = 0.0
	p.knock = 0.0

## Watch the wolves near him for n frames, holding the torch at a fixed fuel.
func watch(n: int, fuel: float, label: String) -> void:
	var seen := {}
	var hp0 := p.hp
	var min_d := 25999.0
	for i in n:
		p.torch_fuel = fuel
		await get_tree().physics_frame
		for w in wolves():
			if absf(w.global_position.x - p.global_position.x) < 700.0 and absf(w.floor_y - p.global_position.y) < 60.0:
				seen[w.state] = seen.get(w.state, 0) + 1
				if w.state == "stalk":
					min_d = minf(min_d, absf(w.global_position.x - p.global_position.x))
	print("%s: fuel=%.2f  hp %d -> %d  closest stalking wolf %.0f px  states=%s" % [label, fuel, hp0, p.hp, min_d, seen])

func _run() -> void:
	await frames(5)
	p = level.player
	for c in level.get_children():
		if c is Dialogue:
			c.queue_free()
	p.talking = false
	for m in level._mouths:
		m._noticed = true
	p.give_torch()

	# 1. strong torch in the first wolves' ground: lunges should break on the light
	place(1150, 590, 1.0)
	await watch(600, 1.0, "full torch ")
	# 2. weak torch: lunges land
	place(1150, 590, 0.3)
	await watch(600, 0.3, "weak torch ")
	# 3. no torch: the pack hunts
	place(1150, 590, 0.0)
	await watch(400, 0.0, "torch out  ")

	# 4. fire: three wood, a fresh pack around him in the dark, press F
	for w in wolves():
		w.queue_free()
	await frames(2)
	for x in [1060.0, 1180.0, 1390.0, 1640.0]:
		var nw := NightBeasts.Wolf.new()
		nw.left_x = 1000.0
		nw.right_x = 1490.0 if x < 1500.0 else 2590.0
		if x > 1500.0:
			nw.left_x = 1640.0
		nw.position = Vector2(x, 600)
		level.add_child(nw)
	place(1250, 590, 0.0)
	p.wood = 3
	await frames(40)
	var before := wolves().size()
	print("  at the press: dead %s, hp %d, fury %.2f, fire_prev %s, knock %.2f, talking %s, wood %d" % [p.dead, p.hp, p.fury, p._fire_prev, p.knock, p.talking, p.wood])
	p.touch["fire"] = true
	await frames(2)
	p.touch["fire"] = false
	var inv_ok := true
	for i in 30:
		p.invuln = 0.0
		var hp := p.hp
		p.hurt(1, p.global_position.x + 10)
		if p.hp != hp:
			inv_ok = false
		await get_tree().physics_frame
	await frames(40)
	print("fire: wolves %d -> %d, wood left %d, torch relit to %.2f, untouchable during wind-up: %s" % [before, wolves().size(), p.wood, p.torch_fuel, inv_ok])

	# 5. dead tree: club it twice, collect the wood
	p.wood = 0
	place(1215, 590, 1.0)
	p.facing = 1
	for k in 3:
		p.touch["attack"] = true
		await frames(2)
		p.touch["attack"] = false
		await frames(30)
	var drops := 0
	for c in level.get_children():
		if c is NightWoods.WoodPickup:
			drops += 1
	await frames(60)
	for c in level.get_children():
		if c is NightWoods.WoodPickup:
			p.global_position = c.global_position + Vector2(0, -5)
			await frames(4)
	print("dead tree: %d bundles dropped, he now carries %d wood" % [drops, p.wood])

	# 6. bonfire 2 catches, becomes the checkpoint; death wakes him there
	place(1720, 590, 0.2)
	await frames(10)
	var fire2: NightWoods.Bonfire = null
	for c in level.get_children():
		if c is NightWoods.Bonfire and absf(c.global_position.x - 1720) < 5:
			fire2 = c
	print("bonfire 2 lit: %s  torch refilled: %.2f  checkpoint: %s" % [fire2.lit, p.torch_fuel, level.checkpoint])
	place(1900, 590, 0.0)
	p.invuln = 0.0
	p.hurt(9, 1950)
	print("dead: %s" % p.dead)
	await get_tree().create_timer(2.6).timeout
	print("revived: dead=%s hp=%d at x=%.0f torch=%.2f" % [p.dead, p.hp, p.global_position.x, p.torch_fuel])
	get_tree().quit()
