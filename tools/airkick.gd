extends "res://tools/harness.gd"
## The AIR KICKS. In the air, UP + HIT (no side) is a snap kick, then the
## FLASH KICK (a backflip); held, they chain. UP + a side + HIT is still the
## club, aimed. Kicks hit what is above him, need no weapon, and only the
## first two of a jump lift him.
##   shots - a paused frame sequence of the kicks to C:/tmp/shots/kick_*


func run() -> void:
	shot_prefix = "kick"
	p.invuln = 99999.0
	p.pick_up_stick()
	for c in level.get_children():
		if c is NightBeasts.Wolf or c is NightBeasts.Bat:
			c.free()
	await put(Vector2(1100, 590))
	await frames(14)

	# 1. UP + HIT in the air: the snap kick, then held, the FLASH KICK
	var kinds: Array = []
	await jump_and(true, "")
	var vy0: float = p.velocity.y
	for i in 40:
		if p.attacking > 0.0 and not kinds.has(p._swing_kind):
			kinds.append(p._swing_kind)
		if shots and p.attacking > 0.0 and i % 2 == 0:
			level.cam.zoom = Vector2(3.0, 3.0)
			await shot("%02d_%s_%d" % [i, p._swing_kind, int(100.0 * (1.0 - p.attacking / p._swing_time))])
		await frames(1)
	check("UP + HIT in the air kicks, held: snap then FLASH KICK", kinds.slice(0, 2) == ["kick1", "kick2"], "kinds %s, vy at the kick %.0f" % [kinds, vy0])
	release()
	await frames(60)

	# 2. UP + RIGHT + HIT in the air: the club, as ever
	await jump_and(true, "right")
	var kind2: String = p._swing_kind
	release()
	check("UP + RIGHT + HIT in the air swings the club", kind2.begins_with("club") and p._swing_kind != "kick1", "kind %s" % kind2)
	await frames(60)

	# 3. the kicks hit a beast above him
	await put(Vector2(1100, 590))
	await frames(24)
	var w := pinned_wolf(p.global_position + Vector2(20, -150))
	var hp0 := w.hp
	await jump_and(true, "")
	await frames(30)
	release()
	check("a kick hits a beast above him", is_instance_valid(w) and w.hp < hp0, "hp %d -> %d" % [hp0, w.hp if is_instance_valid(w) else -1])
	if is_instance_valid(w):
		w.free()
	await frames(60)

	# 4. only the first two of a jump lift him
	await jump_and(true, "")
	var most := 0
	var landed := -1
	for i in 180:
		await frames(1)
		most = maxi(most, p._air_kicks)
		if p.is_on_floor() and i > 5:
			landed = i
			break
	release()
	check("held kicks don't keep him up: he lands", most >= 3 and landed > 0 and landed < 150, "kicks in the air %d, landed after %d frames" % [most, landed])
	await frames(60)

	# 5. no weapon: still kicks
	p.has_stick = false
	await jump_and(true, "")
	var kind5: String = p._swing_kind
	var kicking: bool = p._kicking()
	release()
	check("bare-handed, UP + HIT in the air still kicks", kind5 == "kick1" and kicking, "kind %s" % kind5)
	p.has_stick = true


func pinned_wolf(at: Vector2) -> Critter:
	var w := NightBeasts.Wolf.new()
	w.left_x = at.x - 1.0
	w.right_x = at.x + 1.0
	w.position = at
	level.add_child(w)
	w.hp = 300
	w.set_physics_process(false)
	return w


## Jump, and at the top of the rise press UP (+ side) and HIT.
func jump_and(up: bool, side: String) -> void:
	release()
	await frames(20)
	p.touch["jump"] = true
	await frames(8)
	p.touch["up"] = up
	if side != "":
		p.touch[side] = true
	p.touch["attack"] = true
	await frames(1)
