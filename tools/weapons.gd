extends Node
## Test harness (not shipped): every weapon's swing and special, against a real wolf.
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
		for c in level.get_children():
			if c is Dialogue: c.queue_free()
		if p != null:
			p.talking = false
func wolf_at(dx: float) -> NightBeasts.Wolf:
	var w := NightBeasts.Wolf.new()
	w.left_x = p.global_position.x + dx - 5.0
	w.right_x = p.global_position.x + dx + 5.0
	w.position = Vector2(p.global_position.x + dx, 600)
	level.add_child(w)
	w.hp = 99
	w.set_physics_process(false)
	return w
func tap(n: int, gap: int) -> Array:
	var kinds := []
	for i in n:
		p.touch["attack"] = true
		await frames(2)
		p.touch["attack"] = false
		await frames(gap)
		kinds.append(p._swing_kind)       # (read after the gap: a buffered tap fires a little later)
	return kinds
func _run() -> void:
	await frames(5)
	p = level.player
	p.invuln = 11699.0
	p.global_position = Vector2(700, 590)
	p.facing = 1
	await frames(10)
	for weapon in ["club", "axe", "hammer"]:
		p.axe = weapon == "axe"
		p.hammer = weapon == "hammer"
		# taps
		var w := wolf_at(60.0)
		var hp0 := w.hp
		var kinds := await tap(4, 22 if weapon != "hammer" else 40)          # the club and the axe chain four
		print("%-6s taps: swings %s, damage to a wolf %d" % [weapon, kinds, hp0 - w.hp])
		w.queue_free()
		await frames(40)
		# the hammer: does the blow land late, after the wind-up?
		if weapon == "hammer":
			var w2 := wolf_at(60.0)
			var first_hit := -1
			p.touch["attack"] = true
			for f in 40:
				await frames(1)
				p.touch["attack"] = f < 2
				if first_hit < 0 and w2.hp < 99:
					first_hit = f
			print("        the smash lands %d frames into the swing (%.2f s)" % [first_hit, first_hit / 60.0])
			w2.queue_free()
			await frames(40)
		# the special: hold, then let go (the axe: hold J; the club and hammer: hold L, SPECIAL)
		var key: String = "attack" if weapon == "axe" else "special"
		var far: float = {"club": 70.0, "axe": 330.0, "hammer": 260.0}[weapon]
		var w3 := wolf_at(far)
		w3.hp = 10 if weapon == "club" else 5
		w3.set_physics_process(true)
		w3.left_x = w3.position.x - 2.0
		w3.right_x = w3.position.x + 2.0
		var x0 := w3.global_position.x
		p.touch[key] = true
		await frames(62)
		var charged := p.slam_charge
		p.touch[key] = false
		await frames(8)
		var what := ""
		if weapon == "club":
			what = "swing %s" % p._swing_kind
		elif weapon == "axe":
			what = "axe out %s" % p.axe_out
		else:
			what = "fire waves %d" % level.get_children().filter(func(c): return c is NightWoods.FireWave).size()
		await frames(50)
		var thrown := 0.0
		if is_instance_valid(w3):
			thrown = absf(w3.global_position.x - x0)
		print("        special: charged %.2f s -> %s; the wolf %s %s" % [charged, what,
			"was beaten, thrown" if (not is_instance_valid(w3) or w3.dying > 0.0) else "still standing,", "%d px" % thrown])
		if weapon == "axe":
			await frames(60)
			print("        the axe came back to his hand: %s" % (not p.axe_out))
		if is_instance_valid(w3):
			w3.queue_free()
		await frames(60)
	get_tree().quit()
