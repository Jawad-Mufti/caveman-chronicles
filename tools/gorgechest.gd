extends Node
## Test harness (not shipped): the fallen giant over the Hanging Gorge can be
## walked along (and climbed onto from the camp side), and the two hidden
## mountain chests each open in 3 blows with loot and a very rare relic.
## One PASS/FAIL line each.
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
		for c in level.get_children():
			if c is Dialogue:
				c.queue_free()
		p.talking = false
		p.invuln = 0.5

func check(name: String, ok: bool, info: String = "") -> void:
	print("%s %s %s" % ["PASS" if ok else "FAIL", name, info])

func _run() -> void:
	p = level.player
	await frames(5)
	# 1. walk along the trunk, from the root end to past the second vine
	level._move_player(Vector2(4040, 180), 1)
	await frames(30)
	var on := p.is_on_floor() and p.global_position.y < 260.0
	p.touch["right"] = true
	await frames(110)
	p.touch["right"] = false
	await frames(10)
	check("trunk walk", on and p.is_on_floor() and p.global_position.x > 4600.0 and p.global_position.y < 280.0,
		"x %.0f y %.0f" % [p.global_position.x, p.global_position.y])
	# 2. from the sky lanes: the Moon Garden's last island is right over the trunk; step off it
	level._move_player(Vector2(4150, 100), 1)
	await frames(30)
	var on_rock := p.is_on_floor() and p.global_position.y < 120.0
	p.touch["right"] = true
	await frames(30)
	p.touch["right"] = false
	await frames(40)
	check("lane to trunk", on_rock and p.is_on_floor() and p.global_position.y > 200.0 and p.global_position.y < 260.0,
		"x %.0f y %.0f" % [p.global_position.x, p.global_position.y])
	# 3. a METEOR STOMP on the trunk: Moss wakes in a fright, loot flies to him
	level._move_player(Vector2(4400, 200), 1)
	await frames(30)
	var before := GameState.found_value("level2")
	p.touch["jump"] = true
	await frames(14)
	p.touch["stomp"] = true
	await frames(3)
	p.touch["stomp"] = false
	p.touch["jump"] = false
	var scared := false
	var shots := OS.get_cmdline_user_args().has("shots")
	for i in 60:
		await frames(1)
		scared = scared or level.moss.scared > 0.0
		if shots and i % 8 == 0:
			level.cam.zoom = Vector2(1.6, 1.6)
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("C:/tmp/shots/gstomp_%02d.png" % i)
	var low := p.global_position.y
	for i in 150:
		await frames(1)
		low = maxf(low, p.global_position.y)
	var got := 0
	for i in 3:
		if GameState.is_taken("level2", "gw%d" % i):
			got += 1
	check("stomp the trunk", scared and got == 3 and low < 260.0, "moss scared %s, %d of 3 flew to him, value +%d, lowest y %.0f (stays on the trunk)" % [scared, got, GameState.found_value("level2") - before, low])
	# a MEGA stomp (double jump first): 5 more
	await frames(120)
	p.touch["jump"] = true
	await frames(10)
	p.touch["jump"] = false
	await frames(4)
	p.touch["jump"] = true
	await frames(8)
	p.touch["stomp"] = true
	await frames(3)
	p.touch["stomp"] = false
	p.touch["jump"] = false
	low = p.global_position.y
	for i in 220:
		await frames(1)
		low = maxf(low, p.global_position.y)
	got = 0
	for i in range(3, 8):
		if GameState.is_taken("level2", "gw%d" % i):
			got += 1
	check("mega stomp the trunk", got == 5 and low < 260.0, "%d of 5, lowest y %.0f" % [got, low])
	# 3. the chests
	var chests := []
	for c in level.get_children():
		if c is Treasure.Breakable and c.kind == "chest":
			chests.append(c)
	check("two chests", chests.size() == 2, "found %d" % chests.size())
	for ch in chests:
		var at: Vector2 = ch.global_position
		var id: String = ch.id
		var relic_id: String = (ch.contents[ch.contents.size() - 1] as String).split(":")[2]
		var on_floor: bool = level.mountain.ground_y(at.x, at.y - 30.0) <= at.y + 2.0
		for i in 3:
			ch.take_hit(1, 1)
			await frames(4)
		await frames(10)
		var relic: Node = null
		var loot := 0
		for c in level.get_children():
			if c is Relics.Relic and c.id == relic_id:
				relic = c
			if c is Treasure.Pickup and (c.id as String).begins_with(id + "_"):
				loot += 1
		check("chest %s" % id, on_floor and relic != null and loot >= 8, "at %s, %d pickups, relic %s" % [at, loot, relic_id])
		if relic != null:
			level._move_player(relic.global_position + Vector2(0, 30), 1)
			await frames(20)
			check("relic %s" % relic_id, GameState.is_taken("level2", relic_id))
	get_tree().quit()
