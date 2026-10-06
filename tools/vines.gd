extends Node
## Test harness (not shipped): the Long Dark crossings, played by a simple policy.
var level: Node
var p: CaveMan
func _ready() -> void:
	level = load("res://level2/level2.tscn").instantiate()
	add_child(level)
	_run.call_deferred()
func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
func quiet() -> void:
	for c in level.get_children():
		if c is Dialogue or c is Shop:
			c.queue_free()
	p.talking = false
## run right from `start`, jump at the lip, grab, and let go near the top of the forward swing
## release_a: how high in the forward swing he lets go (a good player: late, ~0.95 rad);
## he pumps the swing up first, pushing with it. expect_miss: a run that should fall short.
func cross(label: String, start: Vector2, lip: float, land_x0: float, land_y: float, max_frames: int = 400, release_a: float = 0.95, expect_miss: bool = false) -> void:
	p.global_position = start
	p.velocity = Vector2.ZERO
	p.hp = 9
	p.invuln = 999.0
	await frames(5)
	quiet()
	p.touch["right"] = true
	var grabbed := 0
	var jumped := false
	var hold := 0
	var was_on := false
	var amp := 0.0          ## how high the swing has gone since he caught the vine
	for i in max_frames:
		await get_tree().physics_frame
		quiet()
		hold -= 1
		p.touch["jump"] = hold > 0
		if p.is_on_floor() and hold <= 0:
			# like a player: jump at the lip of a gap
			var q := PhysicsRayQueryParameters2D.create(p.global_position + Vector2(34, -10), p.global_position + Vector2(34, 40), 1)
			if p.get_world_2d().direct_space_state.intersect_ray(q).is_empty():
				jumped = true
				hold = 16
				p.touch["jump"] = true
		# on a vine: pump with the swing (jump released), and let go high on the forward swing
		if p.vine != null:
			if not was_on:
				hold = 0
				p.touch["jump"] = false
				amp = 0.0
			amp = maxf(amp, absf(p._vine_a))
			p.touch["right"] = p._vine_w >= 0.0
			p.touch["left"] = p._vine_w < 0.0
			if p._vine_w > 0.0 and p._vine_a > release_a and amp >= minf(1.15, release_a + 0.3):
				hold = 14
				p.touch["jump"] = true
				p.touch["right"] = true
				p.touch["left"] = false
				grabbed += 1
		elif was_on:
			p.touch["right"] = true
			p.touch["left"] = false
		was_on = p.vine != null
		if p.is_on_floor() and p.global_position.x > land_x0 and absf(p.global_position.y - land_y) < 3.0:
			break
		if p.global_position.y > 900.0:
			break
	p.touch["right"] = false
	p.touch["jump"] = false
	await frames(5)
	var ok := p.is_on_floor() and p.global_position.x > land_x0 and absf(p.global_position.y - land_y) < 3.0
	if expect_miss:
		ok = not ok
	p.touch["left"] = false
	print("%-34s %s  ended at (%.0f, %.0f), let go of %d vine(s)" % [label, "OK  " if ok else "MISS", p.global_position.x, p.global_position.y, grabbed])
func _run() -> void:
	await frames(5)
	p = level.player
	quiet()
	level._snuffed = true
	level._panicked = true
	await cross("gorge: three swings, let go late", Vector2(3900, 590), 4060, 5420, 600, 1200)
	await cross("gorge: let go early: falls short", Vector2(3900, 590), 4060, 5420, 600, 1200, 0.2, true)
	await cross("pit 1 by the first vine", Vector2(28760, 590), 28900, 29300, 600)
	await cross("crumbling bridge", Vector2(29500, 590), 29600, 30000, 600)
	await cross("pit 2 by two vines", Vector2(30120, 590), 30250, 30700, 600, 600)
	get_tree().quit()
