extends "res://tools/harness.gd"
## FROM THE ROOF: the mountain's ambushes bring beasts down from above too.
## Into the Crystal Grotto: the roof cracks (a tell first), a skeleton falls as
## a heap of bones and rattles up, a spider drops on its silk; beaten, the
## ambush clears. The Bone Hall's fires too.
##   shots - the tell, the fall, the landing to C:/tmp/shots/roofdrop_*


func run() -> void:
	shot_prefix = "roofdrop"
	p.invuln = 99999.0
	p.pick_up_stick()
	p.give_torch()
	var amb: Node = null
	for c in level.get_children():
		if "kinds" in c and (c.kinds as Array).has("skel_drop") and float(c.x0) < 6400.0:
			amb = c
	check("the Crystal Grotto has a roof ambush", amb != null)
	if amb == null:
		return
	await put(Vector2(6480, 860))
	# 1. the tell: a crack in the roof before anything comes down
	var drop: Node2D = null
	var tell_seen := 0.0
	for i in 120:
		await frames(1)
		for c in level.get_children():
			if c.get_class() == "Node2D" and "kind" in c and "roof" in c and is_instance_valid(c):
				drop = c
		if drop != null and is_instance_valid(drop) and not drop._burst:
			tell_seen = maxf(tell_seen, drop.t)
			if shots and absf(drop.t - 0.6) < 0.02:
				level.cam.zoom = Vector2(1.6, 1.6)
				await shot("tell")
		if drop != null and is_instance_valid(drop) and drop._burst:
			break
	check("the ambush fires inside the mountain", bool(amb._fired))
	check("the roof cracks first (a tell before the drop)", tell_seen >= 0.7 and drop != null, "tell %.2f s" % tell_seen)
	if drop != null and is_instance_valid(drop):
		check("it comes from ABOVE him", drop.roof < drop.ground - 100.0, "roof %.0f, floor %.0f" % [drop.roof, drop.ground])
	# 2. let them all come down
	var kinds_seen := {}
	var shot_fall := false
	for i in 360:
		await frames(1)
		for c in amb._spawned:
			if is_instance_valid(c):
				kinds_seen[c.get_script().get_global_name() if c.get_script().get_global_name() != "" else str(c.get_class())] = true
				if c is Mountain.RisenSkeleton:
					kinds_seen["skeleton"] = true
				if c is Caves.Spider:
					kinds_seen["spider"] = true
		if shots and not shot_fall:
			for c in level.get_children():
				if "kind" in c and "roof" in c and is_instance_valid(c) and c._burst and c.kind == "skel_drop" and c._y > c.roof + 50.0:
					shot_fall = true
					await shot("fall")
					break
		if amb._queue.is_empty() and amb._pending == 0 and i > 120:
			break
	check("a skeleton dropped and rose", kinds_seen.has("skeleton"), str(kinds_seen.keys()))
	check("a spider dropped from the roof", kinds_seen.has("spider"), str(kinds_seen.keys()))
	if shots:
		await shot("down")
	# 3. beat them: the ambush clears
	for k in 20:
		for c in amb._spawned:
			if is_instance_valid(c) and (c as Critter).dying <= 0.0:
				c.take_hit(99, 1)
		await frames(10)
		if amb._done:
			break
	check("all beaten: AMBUSH CLEARED", bool(amb._done), "pending %d" % amb._pending)

	# 4. the Bone Hall fires too, with drops
	var hall: Node = null
	for c in level.get_children():
		if "kinds" in c and float(c.x0) > 6800.0 and float(c.x0) < 6900.0:
			hall = c
	await put(Vector2(7000, 630))
	await frames(90)
	check("the Bone Hall's ambush fires", hall != null and bool(hall._fired), "")
