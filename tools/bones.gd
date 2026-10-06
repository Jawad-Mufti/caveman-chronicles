extends Node
## Test harness (not shipped): shells once, bones every visit; grapes heal by themselves.
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
		for c in level.get_children():
			if c is Dialogue: c.queue_free()
		if p != null:
			p.talking = false
func count(kind_is_bone: bool) -> int:
	return level.get_children().filter(func(c): return c is Treasure.Pickup and Treasure.is_bone(c.kind) == kind_is_bone).size()
func _run() -> void:
	await get_tree().physics_frame
	p = level.player
	p.invuln = 11699.0
	await frames(5)
	print("visit %d: level holds %d shells' worth (one-time) and %d bones; lying about now: %d shell pickups, %d bones" % [
		phase, level._treasure_total, level._bones_total, count(false), count(true)])
	if phase == 1:
		print("prices: axe %d, costumes %d..%d, fig %d, heart %d" % [level.price_of("axe"), level.price_of("wolf_hood"), level.price_of("bear_cloak"), level.price_of("fig"), level.price_of("heart")])
		# pick up everything lying in the first stretch (shells and bones)
		var s0 := GameState.shells
		var b0 := GameState.bones
		for c in level.get_children().filter(func(c): return c is Treasure.Pickup and c.global_position.x < 8700.0):
			if is_instance_valid(c):
				p.global_position = c.global_position + Vector2(0, 8)
				await frames(2)
		print("picked up the first stretch: +%d shells, +%d bones; HUD shows %d shells, %d bones" % [GameState.shells - s0, GameState.bones - b0, level.hud.shells, level.hud.bones])
		# grapes: hurt -> eaten at once; full -> kept, then eaten when hurt
		p.global_position = Vector2(700, 590)
		await frames(5)
		p.hp = p.max_hp - 3
		var hp0 := p.hp
		p.add_berry()
		print("grapes while hurt: hearts %d -> %d at once, pouch %d" % [hp0, p.hp, p.berries])
		p.hp = p.max_hp
		p.add_berry()
		print("grapes at full health: kept in the pouch (%d)" % p.berries)
		p.invuln = 0.0
		p.hurt(1, p.global_position.x + 50.0)
		var after_hit := p.hp
		await frames(40)
		print("hurt with grapes in the pouch: %d hearts after the hit -> %d a moment later, pouch %d" % [after_hit, p.hp, p.berries])
		GameState.save()
	get_tree().quit()
