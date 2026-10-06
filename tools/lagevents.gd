extends Node
## Test harness (not shipped): does anything that HAPPENS make a frame slow?
## Run with rendering and vsync on. Plays a string of events — twice each, so a
## first-time hitch (a shader prepared on first use) shows up against the
## repeat — and records every frame over 25 ms with what was made that frame.
var level: Node
var p: CaveMan
var _added: Array = []
var _slow: Array = []
var _label := ""

func _ready() -> void:
	GameState.reset()
	GameState.seen["level2"] = true
	level = load("res://level2/level2.tscn").instantiate()
	add_child(level)
	get_tree().node_added.connect(func(n: Node) -> void:
		var s: Script = n.get_script()
		_added.append(s.resource_path.get_file() + ":" + n.get_class() if s != null else n.get_class()))
	_run.call_deferred()

## Watch n frames under the current label.
func watch(n: int) -> void:
	var t := Time.get_ticks_usec()
	for i in n:
		_added.clear()
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		var dt := (now - t) / 1000.0
		t = now
		for c in level.get_children():
			if c is Dialogue and _label.find("talk") < 0:
				c.queue_free()
		if _label.find("talk") < 0:
			p.talking = false
		if dt > 25.0:
			var made := {}
			for a in _added:
				made[a] = int(made.get(a, 0)) + 1
			_slow.append("  %-26s %5.1f ms  time scale %.2f  made %s" % [_label, dt, Engine.time_scale, made])

func event(label: String, f: Callable, frames: int = 90) -> void:
	_label = label
	f.call()
	await watch(frames)

func _run() -> void:
	await get_tree().process_frame
	p = level.player
	p.give_torch()
	p.hp = 999
	for m in level._mouths:
		m._noticed = true
	for c in level.get_children():
		if c is World.Trigger:
			c.queue_free()
	level._move_player(Vector2(1150, 590), 1)
	_label = "settle"
	await watch(60)
	for round in 2:
		var r := " (%s)" % ["first", "again"][round]
		# swinging the club at the air
		await event("club swing" + r, func() -> void: p.touch["attack"] = true, 20)
		p.touch["attack"] = false
		await watch(20)
		# a wolf, beaten: hits, hit-stops, its cartoon death
		var w := NightBeasts.Wolf.new()
		w.left_x = 1000.0
		w.right_x = 1490.0
		w.position = Vector2(1220, 600)
		level.add_child(w)
		_label = "beat a wolf" + r
		for k in 8:
			if is_instance_valid(w) and w.dying <= 0.0:
				w.take_hit(2, 1)
			await watch(12)
		await watch(150)
		# hurt
		p.invuln = 0.0
		await event("he is hit" + r, func() -> void: p.hurt(1, p.global_position.x + 40.0), 90)
		p.hp = 999
		# the fire burst
		p.add_wood(2)
		await event("fire burst" + r, func() -> void: p.start_fire(), 150)
		# a rock throw
		p.add_rock(1)
		await event("rock throw" + r, func() -> void: p.throw_rock(), 60)
		# a talk box
		await event("talk box" + r, func() -> void:
			level._talk([["MOSS", "Ohhh... hello... down... there."], {"choose": [["One", []], ["Two", []]]}]), 40)
		for c in level.get_children():
			if c is Dialogue:
				c.queue_free()
		p.talking = false
		await watch(20)
		# a double jump with the somersault and the yell
		p.invuln = 99999.0
		_label = "double jump" + r
		p.touch["jump"] = true
		await watch(10)
		p.touch["jump"] = false
		await watch(4)
		p.touch["jump"] = true
		await watch(80)
		p.touch["jump"] = false
	print("frames over 25 ms: %d" % _slow.size())
	for s in _slow:
		print(s)
	get_tree().quit()
