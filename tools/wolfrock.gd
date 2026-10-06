extends Node
## Test harness (not shipped): the outcrop by the Rattling Cave's mouth, with
## the stretch's own wolves below. He stands on the rock, and hops on it, for
## 8 s: the wolves should leave him be (pace), not run about under him.
var level: Node
var p: CaveMan

func _ready() -> void:
	GameState.reset()
	GameState.seen["level2"] = true
	level = load("res://level2/level2.tscn").instantiate()
	add_child(level)
	_run.call_deferred()

func _run() -> void:
	for i in 5:
		await get_tree().physics_frame
	p = level.player
	p.give_torch()
	for m in level._mouths:
		m._noticed = true
	# the outcrop: the CRAGS row at the far side (the Rattling Cave's mouth is in its far face)
	var rock: Array = []
	for c in level.CRAGS:
		if float(c[0]) > 24300.0 and float(c[0]) < 26300.0:
			rock = c
	var wolves := []
	for c in level.get_children():
		if c is NightBeasts.Wolf and absf(c.global_position.x - float(rock[0])) < 700.0:
			wolves.append(c)
	p.global_position = Vector2(float(rock[0]) + 40.0, float(rock[1]) - 10.0)
	p.velocity = Vector2.ZERO
	p.hp = 50
	var under := 0
	var leaps := 0
	var moved := 0.0
	var was := {}
	var last := {}
	for i in 480:
		if i % 70 == 0:
			p.touch["jump"] = true          # hop on the rock now and then
		if i % 70 == 20:
			p.touch["jump"] = false
		await get_tree().physics_frame
		for c in level.get_children():
			if c is Dialogue:
				c.queue_free()
		p.talking = false
		p.torch_fuel = 1.0
		for w in wolves:
			if not is_instance_valid(w) or w.dying > 0.0:
				continue
			if absf(w.global_position.x - p.global_position.x) < 120.0:
				under += 1
			var lg: bool = w.state in ["crouch", "lunge"]
			if lg and not was.get(w, false):
				leaps += 1
			was[w] = lg
			if last.has(w):
				moved += absf(w.global_position.x - float(last[w]))
			last[w] = w.global_position.x
	print("outcrop at x %.0f, top %.0f; %d wolves near" % [rock[0], rock[1], wolves.size()])
	print("8 s on the rock: %d leaps, %.1f s with a wolf right below him, wolves ran %.0f px in all" % [leaps, under / 60.0, moved])
	get_tree().quit()
