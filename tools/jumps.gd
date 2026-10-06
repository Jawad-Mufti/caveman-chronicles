extends Node
## Test harness (not shipped): tries every climbing jump with a simple
## "hold toward it, jump, let go over it" policy and reports where he lands.
var level: Node
var p: CaveMan

func _ready() -> void:
	level = load("res://level2/level2.tscn").instantiate()
	add_child(level)
	_run.call_deferred()

func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

## start: where he stands; dir: -1/0/1; rect: [x0, x1, top] of the target
func attempt(label: String, start: Vector2, dir: int, x0: float, x1: float, top: float) -> void:
	p.global_position = start
	p.velocity = Vector2.ZERO
	p.hp = 5
	await frames(8)
	var k := "right" if dir > 0 else "left"
	p.touch["jump"] = true
	if dir != 0:
		p.touch[k] = true
	var landed := false
	for i in 90:
		await get_tree().physics_frame
		if i == 16:
			p.touch["jump"] = true
		var x := p.global_position.x
		if dir != 0 and ((dir > 0 and x > x0 + 25.0) or (dir < 0 and x < x1 - 25.0)):
			p.touch[k] = false
		if i > 10 and p.is_on_floor():
			landed = true
			break
	p.touch["jump"] = false
	p.touch["left"] = false
	p.touch["right"] = false
	await frames(10)
	var g := p.global_position
	var ok := absf(g.y - top) < 3.0 and g.x >= x0 - 12.0 and g.x <= x1 + 12.0
	print("%-26s %s  landed at (%.0f, %.0f)" % [label, "OK  " if ok else "MISS", g.x, g.y])

func _run() -> void:
	await frames(5)
	p = level.player
	p.give_torch()
	# a clean run: no wind, no critters, no monkeys
	for c in level.get_children():
		if c is Critter or c is NightBeasts.Monkey or c is NightWoods.Wind:
			c.queue_free()
	await frames(3)
	# no dialogue in the way
	for c in level.get_children():
		if c is Dialogue:
			c.queue_free()
	p.talking = false
	for m in level._mouths:
		m._noticed = true
	for c in level.get_children():
		if c is Caves.Web:
			c.queue_free()
	await frames(3)
	await attempt("A: step down to A2", Vector2(35180, 590), 1, 35200, 35550, 700)
	await attempt("A: across the pit", Vector2(35540, 690), 1, 35720, 36000, 700)
	await attempt("A: floor -> ledge 1", Vector2(37340, 690), 1, 37370, 37470, 590)
	await attempt("A: ledge 1 -> ledge 2", Vector2(37462, 580), 1, 37520, 37620, 480)
	await attempt("A: ledge 2 -> chamber", Vector2(37612, 470), 1, 37650, 37870, 380)
	await attempt("B: floor -> pillar", Vector2(38850, 590), 1, 38900, 38990, 510)
	await attempt("B: floor -> shelf 1", Vector2(40830, 590), 1, 40860, 40970, 490)
	await attempt("B: shelf 1 -> shelf 2", Vector2(40962, 480), 1, 41000, 41140, 380)
	await attempt("far: ground -> snag 1", Vector2(24570, 590), 1, 24600, 24710, 490)
	await attempt("far: snag 1 -> snag 2", Vector2(24702, 480), 1, 24730, 24840, 378)
	await attempt("far: snag 2 -> snag 3", Vector2(24738, 368), -1, 24600, 24710, 266)
	await attempt("far: snag 3 -> snag 4", Vector2(24702, 256), 1, 24730, 24840, 154)
	await attempt("far: snag 4 -> snag 5", Vector2(24738, 144), -1, 24520, 24710, 42)
	await attempt("far: snag 5 -> bough", Vector2(24530, 32), -1, 23560, 24460, 42)
	await attempt("far: ground -> outcrop", Vector2(25320, 590), 1, 25350, 25600, 490)
	get_tree().quit()
