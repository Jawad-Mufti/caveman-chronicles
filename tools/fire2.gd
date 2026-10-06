extends Node
## Test harness (not shipped): cost of fire situations, with and without the darkness overlay.
var level: Node
var p: CaveMan
func _ready() -> void:
	level = load("res://level2/level2.tscn").instantiate()
	add_child(level)
	_run.call_deferred()
func quiet() -> void:
	for c in level.get_children():
		if c is Dialogue:
			c.queue_free()
	p.talking = false
	for m in level._mouths:
		m._noticed = true
func measure(n: int) -> Array:
	var f := 0.0
	var sc := 0.0
	var last := Time.get_ticks_usec()
	for i in n:
		await get_tree().process_frame
		quiet()
		var now := Time.get_ticks_usec()
		f += (now - last) / 1000.0
		last = now
		sc += (Performance.get_monitor(Performance.TIME_PROCESS) + Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)) * 1000.0
	return [f / n, sc / n]
func overlay(on: bool) -> void:
	for c in level.night.get_children():
		if c is CanvasLayer and c.layer == 3:
			c.visible = on
func phase(label: String, at: Vector2, setup: Callable = Callable()) -> void:
	p.global_position = at
	p.velocity = Vector2.ZERO
	p.invuln = 999.0
	p.torch_fuel = 1.0
	for i in 30:
		await get_tree().process_frame
		quiet()
	if setup.is_valid():
		setup.call()
	var a: Array = await measure(20)
	overlay(false)
	if setup.is_valid():
		setup.call()
	var b: Array = await measure(20)
	overlay(true)
	print("%-28s frame %5.1f ms (darkness off: %5.1f)   scripts %4.2f ms   lights on screen %d" % [label, a[0], b[0], a[1], level.night._l.size()])
func _run() -> void:
	await get_tree().process_frame
	p = level.player
	quiet()
	p.give_torch()
	await phase("woods, torch only", Vector2(1100, 590))
	await phase("standing in the camp fire", Vector2(520, 590))
	await phase("at lit bonfire 2 + wolves", Vector2(1760, 590))
	await phase("fire burst", Vector2(2300, 590), func() -> void:
		p.wood = 2
		p.fury = -1.0
		p.touch["fire"] = true
		await get_tree().process_frame
		p.touch["fire"] = false)
	await phase("summit fire", Vector2(7410, -288))
	get_tree().quit()
