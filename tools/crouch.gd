extends "res://tools/harness.gd"
## THE CROUCH. DOWN on the ground: he crouches low and stays put (he can turn,
## not walk). Crouched + HIT: the LOW SWEEP along the ground in front, when a
## beast is there (or the ground is too hard to dig); else DOWN + HIT still
## digs. Letting go of DOWN: he stands, and walks again.
##   shots - the crouch and the sweep to C:/tmp/shots/crouch_*


func run() -> void:
	shot_prefix = "crouch"
	p.invuln = 99999.0
	p.pick_up_stick()
	for c in level.get_children():
		if c is NightBeasts.Wolf or c is NightBeasts.Bat:
			c.free()
	await put(Vector2(1100, 590))
	await frames(14)

	# 1. DOWN: crouched, low; RIGHT held too: he stays put
	var x0 := p.global_position.x
	p.touch["down"] = true
	p.touch["right"] = true
	await frames(30)
	check("DOWN crouches him", p.crouching and p.crouch_k > 0.95, "crouching %s, k %.2f" % [p.crouching, p.crouch_k])
	check("crouched, he doesn't walk", absf(p.global_position.x - x0) < 12.0, "moved %.0f px" % (p.global_position.x - x0))
	# low: what flies at head height passes over him
	var cap := p._body_cap.shape as CapsuleShape2D
	var head := Area2D.new()
	head.collision_layer = 0
	head.collision_mask = 2
	var hs := CollisionShape2D.new()
	var hr := RectangleShape2D.new()
	hr.size = Vector2(60, 14)
	hs.shape = hr
	head.add_child(hs)
	head.position = p.global_position + Vector2(0, -54)
	level.add_child(head)
	await frames(3)
	var over_low := head.overlaps_body(p)
	check("crouched, his body is low (things fly over)", cap.height < 45.0 and not over_low, "capsule %.0f, head-high thing touches %s" % [cap.height, over_low])
	p.touch["down"] = false
	await frames(10)
	var over_up := head.overlaps_body(p)
	check("standing, the same thing hits him", cap.height > 60.0 and over_up, "capsule %.0f, touches %s" % [cap.height, over_up])
	head.free()
	p.touch["down"] = true
	await frames(20)
	if shots:
		level.cam.zoom = Vector2(2.0, 2.0)
		level.cam.offset = Vector2(0, -90)
		level.cam.force_update_scroll()
		await frames(2)
		await shot("low")

	# 2. crouched + HIT with a beast in front: the low sweep, and it hurts
	var w := pinned_wolf(p.global_position + Vector2(50, -10))
	var hp0 := w.hp
	p.touch["right"] = false
	p.touch["attack"] = true
	var kinds: Array = []
	for i in 30:
		await frames(1)
		if p.attacking > 0.0 and not kinds.has(p._swing_kind):
			kinds.append(p._swing_kind)
		if shots and p.attacking > 0.0 and i % 3 == 0:
			await shot("sweep_%02d" % i)
	p.touch["attack"] = false
	check("crouched + HIT sweeps low", kinds.has("sweep") and not kinds.has("dig"), "kinds %s" % [kinds])
	check("the sweep hits a beast in front", is_instance_valid(w) and w.hp < hp0, "hp %d -> %d" % [hp0, w.hp if is_instance_valid(w) else -1])
	check("still crouched while sweeping", p.crouching, "")
	if is_instance_valid(w):
		w.free()

	# 3. let go of DOWN: he stands and walks again
	release()
	await frames(20)
	x0 = p.global_position.x
	p.touch["right"] = true
	await frames(30)
	release()
	check("up again, he walks", not p.crouching and p.crouch_k < 0.05 and p.global_position.x - x0 > 60.0, "moved %.0f" % (p.global_position.x - x0))
	await frames(20)

	# 4. in the air DOWN + HIT is still the pogo, not a crouch
	p.touch["jump"] = true
	await frames(10)
	p.touch["down"] = true
	p.touch["attack"] = true
	await frames(2)
	var air_kind: String = p._swing_kind
	release()
	check("in the air, DOWN + HIT is still the pogo", air_kind == "spike" and not p.crouching, "kind %s" % air_kind)


func pinned_wolf(at: Vector2) -> Critter:
	var w := NightBeasts.Wolf.new()
	w.left_x = at.x - 1.0
	w.right_x = at.x + 1.0
	w.position = at
	level.add_child(w)
	w.hp = 300
	w.set_physics_process(false)
	return w
