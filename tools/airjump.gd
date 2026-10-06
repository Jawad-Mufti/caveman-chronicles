extends Node
## Test harness (not shipped): the Hercules double jump. A running jump, then
## the second jump at the top: he somersaults, and the fall after it is slower
## and capped. Reports height, distance, top fall speed and air time.
var level: Node
var p: CaveMan

func _ready() -> void:
	level = load("res://level2/level2.tscn").instantiate()
	add_child(level)
	_run.call_deferred()

func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func report(label: String, ok: bool, info: String) -> void:
	print("%-34s %s  %s" % [label, "PASS" if ok else "FAIL", info])

## second: frame of the second press (-1 = none). Returns [up, across, top fall speed, air s, flipped].
func leap(start_x: float, second: int) -> Array:
	p.global_position = Vector2(start_x, 590)
	p.velocity = Vector2.ZERO
	await frames(10)
	p.talking = false
	var y0 := p.global_position.y
	var x0 := p.global_position.x
	p.touch["right"] = true
	await frames(20)                     # get up to speed
	x0 = p.global_position.x
	p.touch["jump"] = true
	var top := y0
	var fall := 0.0
	var flipped := false
	var t := 0
	for i in 200:
		if i == second - 1:
			p.touch["jump"] = false      # a fresh press for the second jump
		if i == second:
			p.touch["jump"] = true
		await get_tree().physics_frame
		t += 1
		top = minf(top, p.global_position.y)
		fall = maxf(fall, p.velocity.y)
		if p.flip_t > 0.0:
			flipped = true
		if i > 5 and p.is_on_floor():
			break
	p.touch["jump"] = false
	p.touch["right"] = false
	return [y0 - top, p.global_position.x - x0, fall, t / 60.0, flipped]

func _run() -> void:
	await frames(5)
	p = level.player
	for c in level.get_children():
		if c is Critter or c is NightBeasts.Monkey or c is Dialogue:
			c.queue_free()
	p.talking = false
	for m in level._mouths:
		m._noticed = true
	await frames(3)
	var one: Array = await leap(25750.0, -1)
	print("single jump: up %.0f  across %.0f  top fall %.0f  air %.2f s" % [one[0], one[1], one[2], one[3]])
	var two: Array = await leap(25750.0, 24)
	print("double jump: up %.0f  across %.0f  top fall %.0f  air %.2f s" % [two[0], two[1], two[2], two[3]])
	report("single jump: no flip", not one[4], "")
	report("double jump: somersault", two[4], "")
	report("double jump: fall capped", float(two[2]) <= CaveMan.GLIDE_FALL + 1.0, "top fall %.0f px/s" % two[2])
	report("double jump: higher than single", float(two[0]) > float(one[0]) + 60.0, "%.0f vs %.0f" % [two[0], one[0]])
	get_tree().quit()
