extends Node
## Test harness (not shipped): Toolmaker, shop, forge, shells and the save file.
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
func finish_talk() -> void:
	for d in level.get_children().filter(func(c): return c is Dialogue):
		while is_instance_valid(d) and d._i < d.lines.size():
			d._next()
	await frames(3)
func _run() -> void:
	await frames(5)
	p = level.player
	await finish_talk()
	if phase == 1:
		# pick up the first five shells on the path
		var before := GameState.shells
		p.global_position = Vector2(180, 590)
		p.touch["right"] = true
		await frames(60)
		p.touch["right"] = false
		print("walked the camp path: shells %d -> %d, HUD shows %d" % [before, GameState.shells, level.hud.shells])
		# smash the first log
		p.global_position = Vector2(640, 590)
		p.facing = 1
		for k in 3:
			p.touch["attack"] = true
			await frames(2)
			p.touch["attack"] = false
			await frames(25)
		await frames(60)
		var loot := level.get_children().filter(func(c): return c is Treasure.Pickup and absf(c.global_position.x - 700) < 250)
		for c in loot:
			if is_instance_valid(c):
				p.global_position = c.global_position + Vector2(0, 10)
				await frames(3)
		print("smashed the log: shells now %d" % GameState.shells)
		# pretend he found the gem, bring lots of shells, meet the Toolmaker
		level.gem_found = true
		GameState.gems["level2"] = "found"
		GameState.shells += 300
		level._snuffed = true
		level._panicked = true
		p.global_position = Vector2(30960, 590)
		await frames(20)
		var talk := level.get_children().filter(func(c): return c is Dialogue)
		print("Toolmaker talks: %s (%d lines)" % [talk.size() > 0, talk[0].lines.size() if talk.size() > 0 else 0])
		await finish_talk()
		await frames(5)
		var shop: Shop = null
		for c in level.get_children():
			if c is Shop:
				shop = c
		print("shop opened: %s" % (shop != null))
		for c in shop.get_children():
			pass
		shop._age = 1.0
		for id in ["hammer", "heart", "torch", "pouch", "axe", "bear_cloak", "fig"]:
			print("  buy %-10s -> %s" % [id, shop.buy.call(id)])
		print("after: weapons %s carrying %s, max hp %d, torch burn %.0f s, max wood %d, skin %s, figs %d, shells %d" % [
			GameState.weapons, GameState.weapon, p.max_hp, p.torch_burn, p.max_wood, p.skin, GameState.figs, GameState.shells])
		shop._close()
		await frames(5)
		print("player free again: %s" % (not p.talking))
	else:
		# a fresh start of the level, loading from disk
		print("after restart: shells %d, max hp %d, skin %s, weapon %s (hammer in hand %s), figs %d" % [GameState.shells, p.max_hp, p.skin,
			GameState.weapon, p.hammer, GameState.figs])
	get_tree().quit()
