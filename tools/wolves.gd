extends Node
## Test harness (not shipped): how aggressive are the wolves? With a full torch:
##   notice  - he walks up to a pair: seconds until the first leap, and how far
##             the wolves back away from him first
##   escape  - he runs away from among the pair (1390 to 1010) without swinging: hearts lost
##   stand   - he stands still beside them for 6 s: leaps made, hearts lost
## Each runs 5 times (the wolves are random); averages are reported.
var level: Node
var p: CaveMan

func _ready() -> void:
	GameState.reset()
	GameState.seen["level2"] = true
	level = load("res://level2/level2.tscn").instantiate()
	add_child(level)
	_run.call_deferred()

func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func quiet() -> void:
	for c in level.get_children():
		if c is Dialogue:
			c.queue_free()
	p.talking = false

func pair() -> Array:
	# a fresh pair of wolves on the first stretch (1000-1490), nothing else about
	for c in level.get_children():
		if c is NightBeasts.Wolf or c is NightBeasts.Bat:
			c.free()
	var out := []
	for x in [1330.0, 1450.0]:
		var w := NightBeasts.Wolf.new()
		w.left_x = 1000.0
		w.right_x = 1490.0
		w.position = Vector2(x, 600)
		level.add_child(w)
		out.append(w)
	return out

func reset_him(x: float) -> void:
	p.global_position = Vector2(x, 590)
	p.velocity = Vector2.ZERO
	p.hp = 50
	p.invuln = 0.0
	p.torch_fuel = 1.0
	for k in ["left", "right", "jump", "attack"]:
		p.touch[k] = false

func _run() -> void:
	await frames(5)
	p = level.player
	p.give_torch()
	for m in level._mouths:
		m._noticed = true
	quiet()
	# the bonfire at 520 would shelter him: put it out of the picture
	for c in level.get_children():
		if c is NightWoods.Bonfire:
			c.free()
	var runs := 5
	var first_leap := 0.0
	var backed := 0.0
	var esc_lost := 0.0
	var stand_leaps := 0.0
	var stand_lost := 0.0
	for r in runs:
		# notice: walk in from the left, slowly
		var ws := pair()
		reset_him(780.0)
		await frames(10)
		var x0: float = ws[0].global_position.x
		var max_back := 0.0
		var t := 0
		var leapt := -1.0
		p.touch["right"] = true
		while t < 600 and leapt < 0.0:
			await get_tree().physics_frame
			t += 1
			quiet()
			p.torch_fuel = 1.0
			if p.global_position.x > 1150.0:
				p.touch["right"] = false
			max_back = maxf(max_back, ws[0].global_position.x - x0)
			for w in ws:
				if is_instance_valid(w) and w.state in ["crouch", "lunge"]:
					leapt = t / 60.0
		first_leap += leapt if leapt >= 0.0 else 10.0
		backed += max_back
		# escape: from among them, run for it (away from them), never swinging
		ws = pair()
		reset_him(1390.0)
		await frames(10)
		p.touch["left"] = true
		var hp0 := p.hp
		var te := 0
		while p.global_position.x > 1010.0 and te < 600:
			te += 1
			await get_tree().physics_frame
			quiet()
			p.torch_fuel = 1.0
		p.touch["left"] = false
		esc_lost += hp0 - p.hp
		# stand: still, at the edge of their ground
		ws = pair()
		reset_him(1200.0)
		await frames(10)
		var hp1 := p.hp
		var leaps := 0
		var was := {}
		for i in 360:
			await get_tree().physics_frame
			quiet()
			p.torch_fuel = 1.0
			p.global_position.x = 1200.0
			for w in ws:
				if is_instance_valid(w):
					var now: bool = w.state == "lunge"
					if now and not was.get(w, false):
						leaps += 1
					was[w] = now
		stand_leaps += leaps
		stand_lost += hp1 - p.hp
	# fight: he faces them and swings whenever one comes close
	var fight_lost := 0.0
	var beaten := 0.0
	for r in runs:
		var ws := pair()
		reset_him(1180.0)
		p.facing = 1
		await frames(10)
		var hp2 := p.hp
		var swing := 0
		for i in 600:
			await get_tree().physics_frame
			quiet()
			p.torch_fuel = 1.0
			var near := false
			for w in ws:
				if is_instance_valid(w) and w.dying <= 0.0 and absf(w.global_position.x - p.global_position.x) < 110.0:
					near = true
					p.facing = 1 if w.global_position.x > p.global_position.x else -1
			swing = (swing + 1) % 12
			p.touch["attack"] = near and swing < 6
		p.touch["attack"] = false
		fight_lost += hp2 - p.hp
		for w in ws:
			if not is_instance_valid(w) or w.dying > 0.0:
				beaten += 1
	# above: he stands on a rock 110 up, like the outcrop by the second cave: they should pace, not gather under him
	var above_leaps := 0.0
	var above_under := 0.0
	for r in runs:
		var ws := pair()
		var plat := StaticBody2D.new()
		var cs := CollisionShape2D.new()
		var sh := RectangleShape2D.new()
		sh.size = Vector2(160, 14)
		cs.shape = sh
		plat.add_child(cs)
		plat.position = Vector2(1250, 497)
		level.add_child(plat)
		reset_him(1250.0)
		p.global_position = Vector2(1250, 480)
		await frames(10)
		var under := 0
		var was := {}
		for i in 300:
			await get_tree().physics_frame
			quiet()
			p.torch_fuel = 1.0
			var crowd := 0
			for w in ws:
				if is_instance_valid(w):
					if absf(w.global_position.x - p.global_position.x) < 60.0:
						crowd += 1
					var now: bool = w.state == "lunge"
					if now and not was.get(w, false):
						above_leaps += 1
					was[w] = now
			under += crowd
		above_under += under / 300.0
		plat.queue_free()
	print("notice: first leap after %.1f s; wolves backed away %.0f px first" % [first_leap / runs, backed / runs])
	print("escape: running away from a pair (full torch, no swings): %.1f hearts lost" % (esc_lost / runs))
	print("stand:  6 s beside a pair (full torch): %.1f leaps, %.1f hearts lost" % [stand_leaps / runs, stand_lost / runs])
	print("fight:  10 s facing a pair, swinging: %.1f hearts lost, %.1f of 2 wolves beaten" % [fight_lost / runs, beaten / runs])
	print("above:  5 s on a rock 110 px up, over a pair: %.1f leaps, %.2f wolves right under him on average" % [above_leaps / runs, above_under / runs])
	get_tree().quit()
