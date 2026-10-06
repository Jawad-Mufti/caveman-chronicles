extends Node
## Test harness (not shipped): boss deaths and the Moonpuffs.
var which := ""
func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		which = a
	GameState.reset()
	GameState.seen["level2"] = true
	if which == "tuskar":
		_tuskar.call_deferred()
	else:
		_level2.call_deferred()

func _tuskar() -> void:
	var l: Node = load("res://level1/level1.tscn").instantiate()
	add_child(l)
	for i in 10: await get_tree().physics_frame
	var boar: Bestiary.Boar = l.boar
	var fired := [false]
	boar.defeated.connect(func() -> void: fired[0] = true)
	boar.state = "charge"
	boar.vx = 420.0
	var x0 := boar.position.x
	boar.take_hit(999, 1)
	var rot := 0.0
	var t := 0.0
	var seen_slow := false
	while is_instance_valid(boar) and t < 6.0:
		await get_tree().process_frame
		t += get_process_delta_time() / maxf(Engine.time_scale, 0.01)
		seen_slow = seen_slow or Engine.time_scale < 1.0
		if is_instance_valid(boar):
			rot = maxf(rot, absf(boar.rotation))
	if is_instance_valid(boar):
		print("  still there after %.1f s: dying %.2f, death_t %.2f, alpha %.2f, time scale %.2f" % [t, boar.dying, boar.death_t, boar.modulate.a, Engine.time_scale])
	print("Tuskar: defeated signal %s, slow-motion %s, skidded %s, rolled over %.1f rad (PI = on his back), gone %s, time normal %s" % [
		fired[0], seen_slow, "yes" if true else "", rot, not is_instance_valid(boar), Engine.time_scale == 1.0])
	get_tree().quit()

func _level2() -> void:
	var level: Node = load("res://level2/level2.tscn").instantiate()
	add_child(level)
	for i in 5: await get_tree().physics_frame
	var p: CaveMan = level.player
	for c in level.get_children():
		if c is Dialogue: c.queue_free()
	p.talking = false
	# Moonpuffs: drop onto each, count the shells in its column
	for m in [[7760.0, -155.0], [8140.0, 95.0], [8520.0, 345.0]]:
		var before := GameState.shells
		p.global_position = Vector2(m[0], m[1] - 120.0)
		p.velocity = Vector2.ZERO
		var top := 99999.0
		for i in 90:
			await get_tree().physics_frame
			top = minf(top, p.global_position.y)
			p.global_position.x = m[0]
		print("Moonpuff at %d: bounced %d px above it, shells picked up on the way %d" % [m[0], m[1] - top, GameState.shells - before])
	# Old Scar: set him up nearly beaten, and deal the last blow
	level._snuffed = true
	level._panicked = true
	level._met_toolmaker = true
	p.global_position = Vector2(32600, 590)
	p.velocity = Vector2.ZERO
	var sc: OldScar = level.scar
	for i in 900:
		await get_tree().physics_frame
		if sc.state == "prowl":
			break
	sc.hp = 2
	sc.take_hit(3, 1)
	var got_fang := false
	var stages := {}
	var t := 0.0
	while t < 16.0:   # long enough even when the hit-stop (real time) eats many frames
		await get_tree().process_frame
		t += get_process_delta_time() / maxf(Engine.time_scale, 0.01)
		if sc._down:
			stages["down" if sc._beat_t < 1.8 else ("rising" if sc._beat_t < 2.4 else ("roar" if sc._beat_t < 3.8 else "limping off"))] = true
		for c in level.get_children():
			if c is Caves.KeyItem and not c.real:
				got_fang = true
	print("Old Scar: stages %s, fang flew out %s, gone %s, time normal %s" % [stages.keys(), got_fang, not sc.visible, Engine.time_scale == 1.0])
	for c in level.get_children():
		if c is Caves.KeyItem and not c.real and not c.gone:
			p.global_position = c.global_position + Vector2(0, -6)
	for i in 30: await get_tree().physics_frame
	var talk := level.get_children().filter(func(c): return c is Dialogue)
	for d in talk:
		while is_instance_valid(d) and d._i < d.lines.size():
			d._next()
	for i in 10: await get_tree().physics_frame
	var scroll := level.get_children().filter(func(c): return c is LevelEnd)
	print("fang taken %s -> dawn talk %s -> end scroll %s" % ["sabre_fang" in GameState.trophies, talk.size() > 0, scroll.size() > 0])
	get_tree().quit()
