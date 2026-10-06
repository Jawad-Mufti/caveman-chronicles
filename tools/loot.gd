extends Node
## Test harness (not shipped): boxes pay on every hit; stash, totem, hare; fresh hunt each visit.
var level: Node
var p: CaveMan
var phase := 1
func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("phase="):
			phase = int(a.split("=")[1])
	if phase == 1:
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
		if c is Dialogue: c.queue_free()
	p.talking = false
func pickups_near(x: float, r: float) -> Array:
	return level.get_children().filter(func(c): return c is Treasure.Pickup and absf(c.global_position.x - x) < r)
func sweep(x: float, r: float) -> void:
	for c in pickups_near(x, r):
		if is_instance_valid(c) and c.vel == Vector2.ZERO:
			p.global_position = c.global_position + Vector2(0, 8)
			await frames(3)
func smash(obj: Node2D, times: int) -> Array:
	var after := []
	for k in times:
		var before := pickups_near(obj.global_position.x, 400.0).size()
		if is_instance_valid(obj):
			obj.take_hit(3, 1)
		await frames(40)
		after.append(pickups_near(obj.global_position.x if is_instance_valid(obj) else 0.0, 400.0).size() - before)
	return after
func _run() -> void:
	await frames(5)
	p = level.player
	quiet()
	p.invuln = 999.0
	level._snuffed = true
	level._panicked = true
	for m in level._mouths:
		m._noticed = true
	print("level treasure in all: %d (shells)" % level._treasure_total)
	if phase == 2:
		var first := level.get_children().filter(func(c): return c is Treasure.Pickup and c.id == "s0")
		print("after a restart, the first shell is back: %s" % (first.size() > 0))
		get_tree().quit()
		return
	var log: Node2D = level.get_children().filter(func(c): return c is Treasure.Breakable and c.kind == "log")[0]
	p.global_position = log.global_position + Vector2(-80, -10)
	var at := log.global_position.x
	print("log, items out per hit: %s" % [await smash(log, 2)])
	var mound: Node2D = level.get_children().filter(func(c): return c is Treasure.Breakable and c.kind == "mound")[0]
	p.global_position = mound.global_position + Vector2(-80, -10)
	print("mound, items out per hit: %s" % [await smash(mound, 3)])
	var pot: Node2D = level.get_children().filter(func(c): return c is Treasure.Breakable and c.kind == "pot")[0]
	p.global_position = pot.global_position + Vector2(-80, -10)
	print("pot, items out: %s" % [await smash(pot, 1)])
	var stash: Node2D = level.get_children().filter(func(c): return c is Treasure.Breakable and c.kind == "stash")[0]
	p.global_position = stash.global_position + Vector2(-200, -10)
	var sx := stash.global_position.x
	var got := await smash(stash, 2)
	var spread := 0.0
	for c in pickups_near(sx, 400.0):
		spread = maxf(spread, absf(c.global_position.x - sx))
	print("stash, items out per hit: %s, fountain spread %d px" % [got, spread])
	var totem: Node2D = level.get_children().filter(func(c): return c is Treasure.ShellTotem)[0]
	p.global_position = totem.global_position + Vector2(-80, -10)
	print("totem, items out per hit: %s" % [await smash(totem, 7)])
	# chase a hare: it runs, and is caught at the end of its ground
	var hare: Critter = level.get_children().filter(func(c): return c is Treasure.GoldenHare)[0]
	var h0 := hare.global_position.x
	p.global_position = Vector2(hare.global_position.x - 200.0, 590)
	var before := GameState.shells
	p.touch["right"] = true
	await frames(240)
	p.touch["right"] = false
	await frames(30)
	var caught := not is_instance_valid(hare) or hare.dying > 0.0 or not hare.visible
	print("hare: ran from %d, caught %s" % [h0, caught])
	await sweep(hare.global_position.x if is_instance_valid(hare) else h0, 500.0)
	print("pouch after the chase: +%d" % (GameState.shells - before))
	GameState.save()
	get_tree().quit()
