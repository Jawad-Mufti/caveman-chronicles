extends Node2D
## AMBUSHES: stretches of the level where, the moment he walks in, beasts burst
## out at him — wolves running in from the trees, skeletons rattling up out of
## the ground, rats pouring from holes, bats dropping from the dark. They come
## in a staggered rush (and then take TURNS: Critter.may_attack), and when the
## last is beaten: "AMBUSH CLEARED!" and a burst of Spirit Orbs. Every visit.
## Placed from AMBUSHES in level2_data.gd. Loaded with preload (no class_name).

var x0 := 0.0
var x1 := 0.0
var floor_y := 600.0
var kinds: Array = []
var line := ""
var terrain: Terrain = null        ## inside the mountain: snap to its floors
## ESCALATION: the further into the level, the harder (1..5, from how far along
## it is: `tier_at`). Higher tiers bring more beasts, more WAVES, and ELITES.
var tier := 1
var _fired := false
var _spawned: Array = []
var _queue: Array = []
var _waves: Array = []
var _wave := 0
var _next := 0.0
var _done := false


static func tier_at(x: float, level_w: float) -> int:
	return clampi(1 + int(x / level_w * 5.0), 1, 5)


## The waves for this tier: the first is the table's beasts (one more from
## tier 2); a second wave from tier 3, bigger again at 4; a third at 5.
func _plan() -> Array:
	var out: Array = []
	var w1: Array = kinds.duplicate()
	if tier >= 2:
		w1.append(kinds[0])
	out.append(w1)
	if tier >= 3:
		var w2: Array = kinds.duplicate()
		w2.append(kinds[randi() % kinds.size()])
		if tier >= 4:
			w2.append(kinds[0])
		out.append(w2)
	if tier >= 5:
		var w3: Array = kinds.duplicate()
		w3.append_array(kinds.slice(0, 2))
		out.append(w3)
	return out


func _elite_chance() -> float:
	return [0.0, 0.0, 0.15, 0.3, 0.5][tier - 1]


func _process(delta: float) -> void:
	if _done:
		return
	var p := get_tree().get_first_node_in_group("player") as CaveMan
	if p == null or p.dead:
		return
	if not _fired:
		var at := p.global_position
		if at.x > x0 and at.x < x1 and absf(at.y - floor_y) < 150.0 and not p.talking:
			_fire(p)
		return
	# the rush comes in one after another, not all in the same instant
	if not _queue.is_empty():
		_next -= delta
		if _next <= 0.0:
			_next = maxf(0.3, 0.6 - tier * 0.06)
			_spawn(_queue.pop_front(), p)
		return
	for c in _spawned:
		if is_instance_valid(c) and (c as Critter).dying <= 0.0:
			return
	if _wave + 1 < _waves.size():
		# the next wave, after a breath
		_wave += 1
		_queue = (_waves[_wave] as Array).duplicate()
		_next = 1.4
		_pop("WAVE %d!" % (_wave + 1), Color("ff9a3a"), p, 34)
		return
	_cleared(p)


func _pop(text: String, col: Color, p: CaveMan, size: int) -> void:
	var w := CaveMan.WordPop.new()
	w.text = text
	w.size = size
	w.color = col
	w.star = Color("2a0a0a", 0.85)
	w.centered = true
	w.life = 1.2
	w.position = p.global_position + Vector2(0, -170)
	get_parent().add_child(w)


func _fire(p: CaveMan) -> void:
	_fired = true
	_waves = _plan()
	_wave = 0
	_queue = (_waves[0] as Array).duplicate()
	_next = 0.6
	if tier >= 3:
		line += "   (DANGER %d: %d waves)" % [tier, _waves.size()]
	var w := CaveMan.WordPop.new()
	w.text = "AMBUSH!" if tier < 4 else ("BIG AMBUSH!" if tier == 4 else "HUGE AMBUSH!!")
	w.size = 40
	w.color = Color("ff6a3a")
	w.star = Color("2a0a0a", 0.85)
	w.centered = true
	w.life = 1.2
	w.position = p.global_position + Vector2(0, -170)
	get_parent().add_child(w)
	var lvl := get_parent()
	if line != "" and "hud" in lvl and lvl.hud != null:
		lvl.hud.say(line, 3.5)
	if lvl.has_method("shake"):
		lvl.shake(5.0, 0.3)


func _floor_at(x: float) -> float:
	if terrain != null:
		var g := terrain.ground_y(x, floor_y - 80.0)
		if g < INF:
			return g
	return floor_y


## Each one arrives its own way.
func _spawn(kind: String, p: CaveMan) -> void:
	var side := -1.0 if _spawned.size() % 2 == 0 else 1.0
	var view := LevelBase.view_half(self).x
	var c: Critter = null
	match kind:
		"wolf":
			# running in from the trees, off the edge of the view
			var wolf := NightBeasts.Wolf.new()
			wolf.left_x = x0 - 60.0
			wolf.right_x = x1 + 60.0
			var x := clampf(p.global_position.x + side * (view + 40.0), wolf.left_x, wolf.right_x)
			wolf.position = Vector2(x, _floor_at(x))
			wolf.state = "stalk"
			c = wolf
		"skeleton":
			# rattling up out of the ground, not far from him
			var sk := Mountain.RisenSkeleton.new()
			sk.terrain = terrain
			sk.left_x = x0 - 100.0
			sk.right_x = x1 + 100.0
			var xs := clampf(p.global_position.x + side * randf_range(170.0, 260.0), sk.left_x, sk.right_x)
			sk.position = Vector2(xs, _floor_at(xs))
			c = sk
		"rat":
			# out of a hole in the ground beside him
			var rat := Caves.Rat.new()
			rat.left_x = x0
			rat.right_x = x1
			var xr := clampf(p.global_position.x + side * randf_range(200.0, 320.0), x0, x1)
			rat.position = Vector2(xr, _floor_at(xr))
			FX.burst(get_parent(), rat.position, "dust", -side)
			c = rat
		"bat":
			# dropping out of the dark above
			var bat := NightBeasts.Bat.new()
			var xb := p.global_position.x + side * randf_range(140.0, 240.0)
			bat.ground_y = _floor_at(xb)
			bat.position = Vector2(xb, bat.ground_y - 260.0)
			c = bat
	if c == null:
		return
	get_parent().add_child(c)
	_spawned.append(c)
	if randf() < _elite_chance():
		c.make_elite()
		c.tell("ELITE!", Color("ff5a3a"))


func _cleared(p: CaveMan) -> void:
	_done = true
	if _spawned.is_empty():
		return
	var w := CaveMan.WordPop.new()
	w.text = "AMBUSH CLEARED!"
	w.size = 32
	w.color = Color("ffe066")
	w.star = Color("c0392b", 0.85)
	w.centered = true
	w.life = 1.4
	w.position = p.global_position + Vector2(0, -170)
	get_parent().add_child(w)
	# a reward: a big burst of Spirit Orbs streaming in
	var orbs := Critter.ORBS.new()
	orbs.count = 6 + 3 * _spawned.size() + 5 * tier         # deeper, bigger: a bigger reward
	orbs.target = p
	orbs.origin = p.global_position + Vector2(0, -140)
	get_parent().add_child(orbs)
