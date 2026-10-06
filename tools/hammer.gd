extends Node
## Test harness (not shipped): the forging, the slam, and the Three Fires.
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
func finish_talk() -> void:
	for d in level.get_children().filter(func(c): return c is Dialogue):
		while is_instance_valid(d) and d._i < d.lines.size():
			d._next()
	await frames(3)
func slam_at(x: float) -> void:
	p.global_position = Vector2(x, 590)
	p.velocity = Vector2.ZERO
	await frames(8)
	p.touch["attack"] = true
	await frames(60)
	p.touch["attack"] = false
	await frames(50)
func _run() -> void:
	await frames(5)
	p = level.player
	await finish_talk()
	p.give_torch()
	p.invuln = 999.0
	level._snuffed = true
	level._panicked = true
	for m in level._mouths:
		m._noticed = true
	# the forging: gem in hand, meet the Toolmaker, pick the forge
	level.gem_found = true
	GameState.gems["level2"] = "found"
	p.global_position = Vector2(30960, 590)
	await frames(20)
	await finish_talk()
	await frames(5)
	var shop: Shop = null
	for c in level.get_children():
		if c is Shop: shop = c
	shop._age = 1.0
	var hw: Dictionary = shop.list_items.call().filter(func(w): return w["id"] == "hammer")[0]
	print("shop's hammer card: ", hw["name"], " / ", hw["note"])
	print("buy: ", shop.buy.call("hammer"))
	await frames(5)
	var story := level.get_children().filter(func(c): return c is Dialogue).size() > 0
	await finish_talk()
	await frames(10)
	var cards := level.get_children().filter(func(c): return c is ItemGet)
	print("ceremony talk %s -> item card %s ('%s') -> hammer in hand %s, held up high %s" % [story, cards.size() > 0,
		cards[0].title if cards.size() > 0 else "", p.hammer, p.showing_off > 0.0])
	cards[0]._age = 2.0
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_SPACE
	ev.pressed = true
	cards[0]._input(ev)
	await frames(5)
	await finish_talk()
	p.talking = false
	# the Three Fires: smash the boulder, slam at the bowls
	var rock: Node = level.get_children().filter(func(c): return c is NightWoods.CrackedRock)[0]
	p.global_position = Vector2(31380, 590)
	p.facing = 1
	for k in 3:
		p.touch["attack"] = true
		await frames(3)
		p.touch["attack"] = false
		await frames(22)
	await frames(20)
	print("boulder: smashed by the hammer %s" % (not is_instance_valid(rock) or rock.hp <= 0))
	var wolves_before := level.get_children().filter(func(c): return c is NightBeasts.Wolf and c.left_x == 31560.0 and c.dying <= 0.0).size()
	await slam_at(31700)
	print("slam near the first bowl: bowls lit %d, trial wolves %d -> %d" % [level._trial_lit, wolves_before,
		level.get_children().filter(func(c): return c is NightBeasts.Wolf and c.left_x == 31560.0 and c.dying <= 0.0).size()])
	p.global_position = Vector2(31850, 470)
	await frames(20)
	await slam_at(32060)
	await frames(10)
	print("bowls lit %d / 3, gate burning %s" % [level._trial_lit, level._trial_gate.burning >= 0.0])
	await frames(120)
	p.global_position = Vector2(32180, 590)
	p.touch["right"] = true
	await frames(40)
	p.touch["right"] = false
	print("walked through where the gate was: x %.0f (gate at 32250)" % p.global_position.x)
	get_tree().quit()
