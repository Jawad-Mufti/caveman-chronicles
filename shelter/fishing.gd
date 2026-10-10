extends "res://shelter/system.gd"
## FISHING, at the end of the pier (the home, shelter/home.gd), with the
## FISHING STICK (Bag "fishing_stick", made at the workshop: a bone pole, a
## flint hook, a clay sinker). Without it Ugu tries his hands: SPLASH. Nothing.
## With it, E at the pier and he holds the stick in both fists:
## 1. CAST: a meter swings NEAR .. FAR; E lets fly. Far out: bigger fish, and the
##    rare ones (some only at night).
## 2. WAIT: the bobber bobs. NIBBLES (little dips) are tricks: strike at one and
##    the fish swims off. The BITE: the bobber goes UNDER, a splash, "!": E, quick!
## 3. FIGHT: HOLD E (or Space) to reel; the line's TENSION climbs. Too tight: SNAP.
##    Too slack too long: it slips the hook. Let go and it runs. Big fish pull
##    hard, wild ones DART and leap out of the water; the stick bends, the line
##    goes taut or sags; it tires.
## 4. CATCH: the fish flies up into his hands: a card with its picture, its
##    size, NEW! (first of its kind) and RECORD! (his biggest). It goes to cook
##    (the fire) and onto the drying rack; a golden carp pays shells, a glow eel
##    spirit orbs, OLD BONEJAW (the legend, far out at night) goes on the trophy
##    totem. Sometimes it's not a fish at all.
## THE FISH LOG at the pier: every kind he has caught (how many, the biggest),
## the rest "???" with a hint of where they are. GameState.shelter["fish"].
## Esc or a step (while not fighting): put the stick down.

## [id, name, rarity, body, belly, size cm [min, max], strength, wildness, when, far, what it is]
const SPECIES := [
	["perch", "PEBBLE PERCH", 0, Color("8fa86a"), Color("e8d890"), [14, 26], 0.32, 0.2, "any", 0.0, "Small, round, and very sure of itself."],
	["snapper", "STRIPED SNAPPER", 0, Color("d0703a"), Color("f3d0a0"), [22, 40], 0.45, 0.35, "day", 0.0, "It snaps at anything shiny. Toes included."],
	["gilly", "BLUE GILLY", 1, Color("4a90d0"), Color("bfe3ff"), [18, 34], 0.42, 0.75, "day", 0.25, "Quick and twisty: it zigzags all over the place."],
	["whiskers", "MUD WHISKERS", 1, Color("6a5a40"), Color("c9b48a"), [40, 80], 0.78, 0.15, "any", 0.4, "A big lazy catfish. Lazy until it's hooked."],
	["glow_eel", "GLOW EEL", 2, Color("2a6a6a"), Color("6dffd8"), [50, 95], 0.6, 0.8, "night", 0.35, "It glows in the dark water. And it wriggles. A LOT."],
	["golden_carp", "GOLDEN CARP", 3, Color("ffcf40"), Color("fff2a0"), [35, 60], 0.66, 0.7, "any", 0.6, "Scales like shell-gold. Kekko would faint."],
	["bonejaw", "OLD BONEJAW", 4, Color("5a5a68"), Color("d8d0c0"), [180, 320], 0.95, 0.5, "night", 0.82, "An armoured giant with a jaw of bone, older than the mammoths. They say he can't be caught."],
]
## Not a fish at all: [id, name, what he gets]
const JUNK := [
	["sandal", "A SOGGY BARK SANDAL", "Ugu tries it on. It fits! It squelches."],
	["clam", "A GIANT CLAM", "+8 SHELLS inside!"],
	["tooth", "A MAMMOTH TOOTH", "+6 BONES: it was a big mammoth."],
]
const RARE_WEIGHT := [55.0, 26.0, 12.0, 5.0, 1.5]
const STAND := Vector2(0.0, 10.7)                  ## from the pier's start: where he fishes
const DECK := 0.66
const MAX_OUT := 25.0                              ## more line out than this: it's gone
const BITE_WINDOW := 0.85

var reel_hold := false                             ## (tests) as if E were held
var state := ""                                    ## "", "aim", "fly", "wait", "bite", "fight", "catch", "lost"
var power := 0.0
var caught := {}                                    ## the last catch, for the card: species row (or junk), size, new, record, reward
var lost_word := ""
var _pt := 0.0
var _st := 0.0                                     ## time in this state
var _wait := 0.0
var _nibble_at: Array = []
var _nibbling := 0.0
var _fish: Array = []                              ## the species on the line
var _size := 0.0
var _junk: Array = []
var _dist := 0.0
var tension := 0.0
var stamina := 1.0
var _slack := 0.0
var _burst := 0.0
var _burst_in := 2.0
var _phase := 0.0
var _leap := -1.0
var _leap_in := 3.0
var _spray_in := 0.0
var _hook := Vector3.ZERO
var _fly_from := Vector3.ZERO
var _rod: Node3D
var _segs: Array = []
var _tip: Node3D
var _line_a: MeshInstance3D
var _line_b: MeshInstance3D
var _bobber: Node3D
var _fishy: Node3D
var _hud: CanvasLayer
var _rng := RandomNumberGenerator.new()


func build() -> void:
	_rng.randomize()
	var line_mat := StandardMaterial3D.new()
	line_mat.albedo_color = Color(0.95, 0.93, 0.85)
	line_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for k in 2:
		var l := MeshInstance3D.new()
		l.mesh = cyl(0.012, 1.0, 4)
		l.material_override = line_mat
		l.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		l.visible = false
		add_child(l)
		if k == 0:
			_line_a = l
		else:
			_line_b = l
	# the bobber: red over white, a little stick on top
	_bobber = pivot(Vector3(0, -5, 0))
	shape(ball(0.12, 10), Color("e04848"), Vector3(0, 0.04, 0), Vector3.ZERO, Vector3(1, 0.8, 1), _bobber)
	shape(ball(0.12, 10), Color("f3f0e6"), Vector3(0, -0.04, 0), Vector3.ZERO, Vector3(1, 0.8, 1), _bobber)
	shape(cyl(0.015, 0.16, 4), Color("3b2a22"), Vector3(0, 0.16, 0), Vector3.ZERO, Vector3.ONE, _bobber)
	_bobber.visible = false
	_log_board()
	_pier_line()


func movers() -> Array:
	return [_bobber, _line_a, _line_b]


func has_stick() -> bool:
	return GameState.has_item("fishing_stick")


## The workshop made something: the stick? Then the pier says so.
func made(id: String) -> void:
	if id == "fishing_stick":
		_pier_line()


## The pier's line on screen says what E does there.
func _pier_line() -> void:
	home._titles["pier"] = ["THE PIER", "E: fish with your FISHING STICK" if has_stick() else "E: fish... with what? (the workshop makes a FISHING STICK)"]


func where() -> Vector3:
	return Vector3(home.PIER.x + STAND.x, DECK, home.PIER.y + STAND.y)


## ------------------------------------------------------------------ the fish log
func _log_board() -> void:
	var p := Vector3(home.PIER.x - 2.0, 0, home.PIER.y - 0.6)
	p.y = ground(p.x, p.z)
	var n := pivot(p)
	for s: float in [-0.6, 0.6]:
		shape(cyl(0.06, 1.7, 6), home.WOOD, Vector3(s, 0.85, 0), Vector3.ZERO, Vector3.ONE, n)
	shape(BoxMesh.new(), Color("e2c49a"), Vector3(0, 1.35, 0.03), Vector3.ZERO, Vector3(1.5, 0.9, 0.05), n)
	for k in 3:                                              # fish painted on it
		var y := 1.6 - k * 0.27
		var col: Color = [home.OCHRE, Color("4a6a8a"), Color("6a5a40")][k]
		shape(ball(0.1, 6), col, Vector3(-0.15 + k * 0.08, y, 0.07), Vector3.ZERO, Vector3(2.6, 0.9, 0.2), n)
		shape(cone(0.08, 0.14, 3), col, Vector3(0.18 + k * 0.08, y, 0.07), Vector3(0, 0, 90), Vector3(1, 1, 0.2), n)
	home._blocks.append([Vector2(p.x, p.z), 0.6])
	home._spot("fishlog", p + Vector3(0, 0, 1.2), "THE FISH LOG", "E: every fish he has caught")


func _log() -> Dictionary:
	return GameState.shelter.get("fish", {})


func _log_rows() -> Array:
	var rows: Array = []
	var lg := _log()
	for s in SPECIES:
		var id: String = s[0]
		if lg.has(id):
			var e: Array = lg[id]
			rows.append([str(s[1]), "x%d, best %d cm" % [int(e[0]), int(e[1])], false, null])
		else:
			var hint := "anywhere"
			if str(s[8]) == "night":
				hint = "at NIGHT"
			elif str(s[8]) == "day":
				hint = "by day"
			if float(s[9]) > 0.3:
				hint += ", cast FAR"
			rows.append(["???  (%s)" % hint, "", false, null])
	return rows


## ------------------------------------------------------------------ E at the pier
func use(id: String) -> bool:
	match id:
		"fishlog":
			var lg := _log()
			home._open_menu("THE FISH LOG", "%d of %d kinds caught. The sea is full of surprises." % [lg.size(), SPECIES.size()], Color("5ab0ff"), _log_rows)
			return true
		"pier":
			if not has_stick():
				_hands()
			else:
				_start()
			return true
	return false


## No stick: he tries with his hands. SPLASH.
func _hands() -> void:
	puff(where() + Vector3(0, -0.4, 0.8), Color(0.8, 0.92, 1.0, 0.85), 26, 3.5)
	pop_word("SPLASH!", where() + Vector3(0, 1.8, 0.8), Color("bfe3ff"))
	home._model.emote("sad", 1.4)
	home.say("SPLASH! Nothing. Fish are FAST. A FISHING STICK would do it: the WORKSHOP makes one (6 bones, 1 flint, 1 clay).")


func _start() -> void:
	home._holder = self
	home._focus = 0.0
	home._model.show_weapon(false)
	_make_rod()
	_to("aim")
	if _hud == null:
		_hud = CanvasLayer.new()
		_hud.layer = 3
		var h := FishHud.new()
		h.f = self
		_hud.add_child(h)
		home.add_child(_hud)
	home.say("")


## Puts the stick down: back to walking about.
func release() -> void:
	state = ""
	home._holder = null
	home._model.rod_pose = -1.0
	home._model.show_weapon(true)
	home._model.emote("happy", 0.4)                         # (no fight face left on)
	if _rod != null:
		_rod.queue_free()
		_rod = null
	_bobber.visible = false
	_line_a.visible = false
	_line_b.visible = false
	if _fishy != null:
		_fishy.queue_free()
		_fishy = null
	if _hud != null:
		_hud.queue_free()
		_hud = null


## E while he holds the stick.
func held_use() -> void:
	match state:
		"aim":
			cast(power)
		"wait":
			if _nibbling > 0.0:
				_lose("Too early! It was only a NIBBLE... the fish swims off.")
			else:
				home.say("Nothing yet. Wait till the bobber goes right UNDER!")
				_wait += 0.6
		"bite":
			hook()
		"catch", "lost":
			if _st > 0.35:
				_to("aim")


func _input(e: InputEvent) -> void:
	if state == "" or not (e is InputEventKey and e.pressed) or e.is_echo():
		return
	var k := (e as InputEventKey).physical_keycode
	if k == KEY_ESCAPE or k == KEY_Q:
		release()
		get_viewport().set_input_as_handled()
	elif k in [KEY_W, KEY_S, KEY_A, KEY_D, KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT] and state in ["aim", "wait", "catch", "lost"]:
		release()


func _to(s: String) -> void:
	state = s
	_st = 0.0


## ------------------------------------------------------------------ the stick
## A long bone pole, bound with cord at every joint, a leather grip, a spool of
## line, a red tassel at the tip; in segments that bend with the line's pull.
func _make_rod() -> void:
	if _rod != null:
		return
	var hand: Node3D = home._model.hand()
	_rod = Node3D.new()
	if hand != null:
		hand.add_child(_rod)
		_rod.rotation.x = 2.05                               # (out over the water, not up at the sky)
	else:
		home._model.add_child(_rod)
		_rod.position = Vector3(0.3, 1.2, 0.3)
		_rod.rotation.x = 1.0
	shape(cyl(0.045, 0.32, 8), Color("6a4a30"), Vector3(0, 0.0, 0), Vector3.ZERO, Vector3.ONE, _rod)        # the grip
	shape(cyl(0.07, 0.1, 10), Color("8a6a46"), Vector3(0, 0.22, 0.05), Vector3(90, 0, 0), Vector3.ONE, _rod) # the spool
	_segs.clear()
	var parent: Node3D = _rod
	var seg_len := 0.42
	for k in 6:
		var s := pivot(Vector3(0, 0.15 if k == 0 else seg_len, 0), parent)
		var r0 := lerpf(0.032, 0.012, k / 6.0)
		var r1 := lerpf(0.032, 0.012, (k + 1) / 6.0)
		shape(cyl(r0, seg_len, 7, r1), home.BONE.darkened(0.04 * (k % 2)), Vector3(0, seg_len * 0.5, 0), Vector3.ZERO, Vector3.ONE, s)
		shape(cyl(r0 + 0.008, 0.05, 7), Color("5a3a22"), Vector3(0, 0.02, 0), Vector3.ZERO, Vector3.ONE, s)   # a cord binding
		_segs.append(s)
		parent = s
	_tip = pivot(Vector3(0, seg_len, 0), parent)
	shape(cone(0.04, 0.12, 5), Color("e04848"), Vector3(0, -0.02, 0), Vector3(180, 0, 0), Vector3.ONE, _tip)    # the tassel
	for m in _rod.find_children("*", "MeshInstance3D", true, false):
		(m as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _bend(k: float) -> void:
	for i in _segs.size():
		(_segs[i] as Node3D).rotation.x = k * (0.05 + i * 0.035)


## ------------------------------------------------------------------ cast, wait, bite
func cast(p: float) -> void:
	power = clampf(p, 0.0, 1.0)
	var d := lerpf(5.0, 19.0, power)
	_hook = where() + Vector3(_rng.randf_range(-1.6, 1.6), 0, d)
	_hook.y = 0.02
	_fly_from = _tip.global_position if _tip != null else where() + Vector3(0, 2, 0)
	_to("fly")
	pop_word("WHOOSH!", where() + Vector3(0, 2.6, 0.6), Color("fff2c0"), 60)


func _wait_start() -> void:
	_to("wait")
	_wait = _rng.randf_range(2.2, 5.5) + power * 1.5
	_nibble_at.clear()
	for k in _rng.randi_range(0, 3):
		_nibble_at.append(_rng.randf_range(0.6, _wait - 0.5))
	_nibbling = 0.0
	puff(_hook, Color(0.85, 0.95, 1.0, 0.85), 16, 2.5)
	_ripple(_hook)


## What bites: by the time of day and how far out he cast.
func _pick() -> void:
	_junk = []
	_fish = []
	if _rng.randf() < 0.08:
		_junk = JUNK[_rng.randi() % JUNK.size()]
		return
	var night := night() > 0.55
	var pool: Array = []
	var total := 0.0
	for s in SPECIES:
		var when: String = s[8]
		if when == "night" and not night or when == "day" and night:
			continue
		if float(s[9]) > power + 0.05:
			continue
		var w: float = RARE_WEIGHT[int(s[2])] * (1.0 + power * float(s[2]) * 0.6)
		pool.append([s, w])
		total += w
	var r := _rng.randf() * total
	for e in pool:
		r -= float(e[1])
		if r <= 0.0:
			_fish = e[0]
			break
	if _fish.is_empty():
		_fish = SPECIES[0]
	var sz: Array = _fish[5]
	_size = lerpf(float(sz[0]), float(sz[1]), pow(_rng.randf(), 1.5 - power * 0.7))


func _bite() -> void:
	_pick()
	_to("bite")
	puff(_hook, Color(0.85, 0.95, 1.0, 0.9), 22, 3.5)
	pop_word("!", _hook + Vector3(0, 1.2, 0), Color("ffe066"), 140)
	home._model.emote("ooh", 0.6)


## E on the bite: hooked! The fight begins.
func hook() -> void:
	if state != "bite":
		return
	if not _junk.is_empty():
		_land()                                              # junk doesn't fight
		return
	_to("fight")
	_dist = Vector2(_hook.x, _hook.z).distance_to(Vector2(where().x, where().z))
	tension = 0.35
	stamina = 1.0
	_slack = 0.0
	_burst = 0.0
	_burst_in = _rng.randf_range(1.0, 2.5)
	_leap_in = _rng.randf_range(1.5, 3.5)
	_phase = _rng.randf() * TAU
	pop_word("HOOKED!", where() + Vector3(0, 2.8, 1.0), Color("ff9a3a"), 90)
	home._model.emote("effort", 999.0)


func _lose(why: String) -> void:
	lost_word = why
	_to("lost")
	_bobber.visible = false
	home._model.emote("angry" if why.begins_with("SNAP") else "sad", 1.6)
	home._model.rod_pose = 0.0


## ------------------------------------------------------------------ held: every frame
func hold_step(delta: float) -> void:
	_st += delta
	var m: Node3D = home._model
	home._pos = where()
	m.rotation = Vector3(0, 0, 0)                            # facing out to sea (+z)
	m.look_at_point = _hook if state in ["wait", "bite", "fight"] else Vector3.INF
	var stretch := 0.0
	match state:
		"aim":
			_pt += delta
			power = 0.5 - 0.5 * cos(_pt * 2.4)
			m.rod_pose = 0.15 + 0.1 * sin(_pt * 2.4)
			_bobber.visible = false
			_line_a.visible = false
			_line_b.visible = false
		"fly":
			var k := clampf(_st / 0.7, 0.0, 1.0)
			var p := _fly_from.lerp(_hook, k) + Vector3(0, sin(k * PI) * 3.0, 0)
			_bobber.visible = true
			_bobber.global_position = p
			m.rod_pose = 0.0
			_lines(p, 0.0)
			if k >= 1.0:
				_wait_start()
		"wait":
			_wait -= delta
			_nibbling = maxf(_nibbling - delta, 0.0)
			for i in range(_nibble_at.size() - 1, -1, -1):
				if _st >= float(_nibble_at[i]):
					_nibble_at.remove_at(i)
					_nibbling = 0.45
					puff(_hook, Color(0.85, 0.95, 1.0, 0.6), 6, 1.2)
			var dip := -0.12 * sin(clampf(_nibbling / 0.45, 0.0, 1.0) * PI * 3.0) if _nibbling > 0.0 else 0.0
			_bobber.global_position = _hook + Vector3(0, 0.06 + sin(home._t * 2.6) * 0.035 + dip, 0)
			m.rod_pose = 0.1
			_lines(_bobber.global_position, 0.5)
			if _wait <= 0.0:
				_bite()
		"bite":
			_bobber.global_position = _hook + Vector3(0, -0.22 + sin(home._t * 40.0) * 0.06, 0)
			_lines(_bobber.global_position, 0.15)
			m.rod_pose = 0.3
			if _st > BITE_WINDOW:
				_lose("Too slow! It stole the bait.")
		"fight":
			stretch = _fight(delta)
		"catch", "lost":
			m.rod_pose = 0.0
			_line_a.visible = false
			_line_b.visible = false
			_bobber.visible = false
			if _fishy != null and state == "catch":
				_hold_up()
	_bend(stretch)


## The fight: the line's tension, the fish's pull, how much line is out.
func _fight(delta: float) -> float:
	var strength: float = float(_fish[6]) * (0.85 + 0.3 * _size_k())
	var wild: float = _fish[7]
	_burst_in -= delta
	if _burst_in <= 0.0 and wild > 0.3:
		_burst = 0.5 * wild
		_burst_in = _rng.randf_range(1.0, 3.0) / wild
		_phase += _rng.randf_range(1.0, 3.0)
		pop_word("IT DARTS!", _hook + Vector3(0, 1.4, 0), Color("ff9a3a"), 56)
		puff(_hook, Color(0.85, 0.95, 1.0, 0.9), 18, 3.0)
	_burst = maxf(_burst - delta, 0.0)
	var pull := strength * (0.35 + 0.65 * stamina) * (0.75 + 0.25 * sin(_st * 3.1 + _phase)) + _burst
	var reeling := reel_hold or Input.is_physical_key_pressed(KEY_E) or Input.is_physical_key_pressed(KEY_SPACE) or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	if reeling:
		tension += (0.32 + pull * 0.8) * delta
		_dist -= 2.5 * (1.0 - 0.55 * pull) * delta
		stamina = maxf(0.0, stamina - 0.1 * delta * (0.5 + tension))
	else:
		tension -= 0.7 * delta
		_dist += pull * 1.5 * delta
		stamina = maxf(0.0, stamina - 0.03 * delta)
	tension = clampf(tension, 0.0, 1.05)
	if tension < 0.08:
		_slack += delta
	else:
		_slack = maxf(0.0, _slack - delta)
	# where the fish is: in from where he cast, side to side as it swims
	var out := (_hook - where()) * Vector3(1, 0, 1)
	var dir := out.normalized() if out.length() > 0.01 else Vector3.BACK
	var side := Vector3(dir.z, 0, -dir.x)
	_hook = where() * Vector3(1, 0, 1) + dir * _dist + side * sin(_st * (0.8 + wild * 2.5) + _phase) * wild * 0.06
	_hook.y = 0.0
	_bobber.visible = true
	_bobber.global_position = _hook + Vector3(0, 0.02 + sin(_st * 14.0) * 0.04 * tension, 0)
	_lines(_bobber.global_position, 1.0 - tension)
	home._model.rod_pose = tension
	# spray where it thrashes; now and then it leaps right out
	_spray_in -= delta
	if _spray_in <= 0.0:
		_spray_in = 0.35
		puff(_hook, Color(0.85, 0.95, 1.0, 0.7), 5 + int(strength * 8.0), 1.5 + strength * 1.5)
	_leap_in -= delta
	if _leap < 0.0 and _leap_in <= 0.0 and tension > 0.45 and (float(_fish[6]) > 0.55 or int(_fish[2]) >= 2):
		_leap = 0.0
		_leap_in = _rng.randf_range(2.5, 5.0)
		_make_fishy()
		pop_word("WHOA!", _hook + Vector3(0, 2.5, 0), Color("fff2c0"), 64)
	if _leap >= 0.0:
		_leap += delta / 0.8
		if _fishy != null:
			_fishy.global_position = _hook + Vector3(0, sin(clampf(_leap, 0.0, 1.0) * PI) * (1.2 + _size_k() * 1.4), 0)
			_fishy.rotation = Vector3(-cos(_leap * PI) * 1.1, atan2(dir.x, dir.z), 0)
		if _leap >= 1.0:
			_leap = -1.0
			puff(_hook, Color(0.85, 0.95, 1.0, 0.9), 26, 3.5)
			if _fishy != null:
				_fishy.queue_free()
				_fishy = null
	# how it ends
	if tension >= 1.0:
		_lose("SNAP! The line broke: too tight!")
	elif _slack > 2.2:
		_lose("Too slack! It slipped the hook.")
	elif _dist >= MAX_OUT:
		_lose("It ran off into the deep...")
	elif _dist <= 1.3:
		_land()
	return tension


## 0 .. 1: how big this one is for its kind.
func _size_k() -> float:
	if _fish.is_empty():
		return 0.5
	var sz: Array = _fish[5]
	return clampf((_size - float(sz[0])) / maxf(float(sz[1]) - float(sz[0]), 1.0), 0.0, 1.0)


## The line: rod tip to the hook, in two pieces, sagging when slack.
func _lines(to: Vector3, sag: float) -> void:
	if _tip == null:
		return
	var a := _tip.global_position
	var mid := (a + to) * 0.5 + Vector3(0, -clampf(sag, 0.0, 1.0) * minf(1.2, a.distance_to(to) * 0.12), 0)
	_line_piece(_line_a, a, mid)
	_line_piece(_line_b, mid, to)


func _line_piece(l: MeshInstance3D, a: Vector3, b: Vector3) -> void:
	l.visible = true
	var y := (b - a)
	var len := y.length()
	if len < 0.001:
		l.visible = false
		return
	var yn := y / len
	var x := (Vector3.UP if absf(yn.y) < 0.9 else Vector3.RIGHT).cross(yn).normalized()
	l.global_transform = Transform3D(Basis(x, yn * len, x.cross(yn)), (a + b) * 0.5)


func _ripple(at: Vector3) -> void:
	var r := glowing(cyl(0.5, 0.02, 24), Color(0.9, 0.97, 1.0), 0.6, at + Vector3(0, 0.03, 0))
	var mt := r.material_override as StandardMaterial3D
	mt.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var tw := r.create_tween().set_parallel(true)
	tw.tween_property(r, "scale", Vector3(4, 1, 4), 1.2)
	tw.tween_property(mt, "albedo_color:a", 0.0, 1.2)
	tw.chain().tween_callback(r.queue_free)


## ------------------------------------------------------------------ the catch
## A fish to see: its body, belly, tail, fins, eyes; the kind's own marks.
func _make_fishy() -> void:
	if _fishy != null:
		_fishy.queue_free()
	_fishy = pivot(_hook)
	var body: Color = _fish[3] if not _fish.is_empty() else Color("8a8a8a")
	var belly: Color = _fish[4] if not _fish.is_empty() else Color("cccccc")
	var id: String = _fish[0] if not _fish.is_empty() else ""
	var l := clampf(_size / 100.0, 0.25, 2.4) * (1.0 if id != "bonejaw" else 0.85)
	var thin := 0.2 if id == "glow_eel" else 0.36
	var n := pivot(Vector3.ZERO, _fishy)
	shape(ball(0.5, 12), body, Vector3.ZERO, Vector3.ZERO, Vector3(l * thin * 0.8, l * thin, l), n)
	shape(ball(0.5, 10), belly, Vector3(0, -l * thin * 0.18, 0.02 * l), Vector3.ZERO, Vector3(l * thin * 0.7, l * thin * 0.7, l * 0.8), n)
	shape(cone(l * 0.2, l * 0.32, 4), body.darkened(0.15), Vector3(0, 0, -l * 0.6), Vector3(-90, 0, 0), Vector3(1, 1, 0.25), n)
	shape(cone(l * 0.08, l * 0.22, 4), body.darkened(0.2), Vector3(0, l * thin * 0.55, -l * 0.05), Vector3(0, 0, 0), Vector3(0.25, 1, 1.4), n)
	for s: float in [-1.0, 1.0]:
		shape(ball(l * 0.045, 6), Color.WHITE, Vector3(s * l * thin * 0.3, l * thin * 0.12, l * 0.36), Vector3.ZERO, Vector3.ONE, n)
		shape(ball(l * 0.025, 6), Color("1a120c"), Vector3(s * l * thin * 0.34, l * thin * 0.12, l * 0.38), Vector3.ZERO, Vector3.ONE, n)
	match id:
		"snapper":
			for k in 3:
				shape(cyl(l * thin * 0.42, l * 0.04, 10), body.darkened(0.35), Vector3(0, 0, l * (0.15 - k * 0.15)), Vector3(90, 0, 0), Vector3(0.8, 1, 1.05), n)
		"whiskers":
			for s2: float in [-1.0, 1.0]:
				shape(cyl(0.008, l * 0.35, 4), Color("3b2a22"), Vector3(s2 * l * 0.08, -l * 0.04, l * 0.5), Vector3(70, s2 * 30.0, 0), Vector3.ONE, n)
		"glow_eel":
			glowing(ball(0.5, 10), Color("6dffd8"), 1.6, Vector3(0, l * 0.06, 0), Vector3.ZERO, Vector3(l * 0.05, l * 0.05, l * 0.9), n)
		"golden_carp":
			for k in 6:
				glowing(ball(l * 0.03, 5), Color("fff2a0"), 1.2, Vector3((k % 2 - 0.5) * l * 0.2, l * 0.04 * (k % 3), l * (0.25 - k * 0.08)), Vector3.ZERO, Vector3.ONE, n)
		"bonejaw":
			for k in 4:
				shape(BoxMesh.new(), Color("8a8a96"), Vector3(0, l * 0.1, l * (0.3 - k * 0.12)), Vector3(10, 0, 0), Vector3(l * 0.3, l * 0.08, l * 0.1), n)
			for k in 7:
				shape(cone(l * 0.015, l * 0.06, 4), home.BONE, Vector3((k - 3) * l * 0.025, -l * 0.04, l * 0.47), Vector3(180, 0, 0), Vector3.ONE, n)
	for m in _fishy.find_children("*", "MeshInstance3D", true, false):
		(m as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## It's his: out of the water, up into his hands; the card, the log, the rewards.
func _land() -> void:
	_to("catch")
	_bobber.visible = false
	puff(_hook, Color(0.85, 0.95, 1.0, 0.95), 30, 4.0)
	caught = {}
	if not _junk.is_empty():
		caught = {"junk": _junk, "reward": _junk[2]}
		match str(_junk[0]):
			"clam":
				GameState.shells += 8
			"tooth":
				GameState.bones += 6
		GameState.save()
		home._model.emote("curious", 1.6)
		pop_word(str(_junk[1]), where() + Vector3(0, 3.0, 0.5), Color("e2c49a"), 56)
		return
	_make_fishy()
	_fishy.global_position = _hook
	_fly_from = _hook
	var id: String = _fish[0]
	var cm := int(round(_size))
	var lg: Dictionary = _log()
	var fresh := not lg.has(id)
	var best := 0 if fresh else int(lg[id][1])
	var record := not fresh and cm > best
	lg[id] = [(0 if fresh else int(lg[id][0])) + 1, maxi(best, cm)]
	save_key("fish", lg)
	var reward := ""
	match id:
		"golden_carp":
			GameState.shells += 15
			reward = "+15 SHELLS: Kekko paid just to look at it."
		"glow_eel":
			GameState.orbs += 3
			reward = "+3 SPIRIT ORBS: it glows like spirit light."
		"bonejaw":
			if not GameState.trophies.has("bonejaw"):
				GameState.trophies.append("bonejaw")
			GameState.bones += 25
			reward = "THE LEGEND! His jaw goes on the TROPHY TOTEM. +25 BONES."
	GameState.save()
	home.hang_fish(_fish[3], 0.7 + _size_k() * 0.8)
	caught = {"fish": _fish, "cm": cm, "new": fresh, "record": record, "reward": reward}
	var big := int(_fish[2]) >= 2 or _size_k() > 0.75
	home._model.emote("whee" if big else "happy", 2.2)
	home._model.cheer(1.2)
	pop_word("NEW FISH!" if fresh else ("RECORD!" if record else "CAUGHT!"), where() + Vector3(0, 3.2, 0.5), Color("ffe066"), 90)


## The catch flies up and he holds it high.
func _hold_up() -> void:
	var k := clampf(_st / 0.8, 0.0, 1.0)
	var top := where() + Vector3(0, 2.6, 0.5)
	_fishy.global_position = _fly_from.lerp(top, k) + Vector3(0, sin(k * PI) * 2.0, 0)
	_fishy.rotation = Vector3(0, PI * 0.5 + sin(home._t * 6.0) * 0.25 * (1.0 - k * 0.5), sin(home._t * 9.0) * 0.15)
	home._model.rod_pose = 0.8 * k


## Everything a fishing visit needs to tell (tests read it too).
func busy() -> bool:
	return state != ""


## ------------------------------------------------------------------ the camera: out over the sea
func studio_camera() -> Array:
	var me := where()
	var look := me + Vector3(0, 0.6, 8.0)
	if state in ["wait", "bite", "fight"]:
		look = me.lerp(_hook, 0.6) + Vector3(0, 0.4, 0)
	elif state == "catch":
		look = me + Vector3(0, 2.2, 1.0)
	return [me + Vector3(-2.6, 3.3, -4.8), look, 50.0]


## ------------------------------------------------------------------ the screen: the meter, the bite, the tension, the card
class FishHud extends Control:
	var f: Node
	var t := 0.0
	const GOLD := Color("ffcf40")
	const INK := Color("3b2a22")

	func _ready() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		t += delta
		queue_redraw()

	func _draw() -> void:
		var vs := get_viewport_rect().size
		var tf := Pal.title_font()
		var tx := Pal.text_font()
		var cx := vs.x * 0.5
		match str(f.state):
			"aim":
				_meter(Vector2(cx, vs.y - 120), float(f.power))
				_say(tx, Vector2(cx, vs.y - 30), "E: CAST!   (far out: bigger fish)      Esc / a step: put the stick down", 17)
			"fly", "wait":
				var nib: bool = float(f._nibbling) > 0.0
				_say(tf if nib else tx, Vector2(cx, vs.y - 60), "...nibble..." if nib else "Watch the bobber... strike when it goes UNDER!", 28 if nib else 19, Color("bfe3ff") if nib else Color("f3e3c3"))
			"bite":
				var pulse := 1.0 + 0.12 * sin(t * 30.0)
				draw_set_transform(Vector2(cx, vs.y * 0.32), 0.0, Vector2(pulse, pulse))
				draw_circle(Vector2.ZERO, 58.0, Color("e04848"))
				draw_circle(Vector2.ZERO, 50.0, Color("ffe066"))
				draw_string(tf, Vector2(-60, 30), "!", HORIZONTAL_ALIGNMENT_CENTER, 120, 92, INK)
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
				_say(tf, Vector2(cx, vs.y * 0.32 + 104), "E NOW!", 46, Color("ffe066"))
			"fight":
				_tension(Vector2(cx, vs.y - 92), float(f.tension), float(f._dist), float(f.stamina))
			"catch":
				_card(Vector2(vs.x * 0.71, vs.y * 0.45))             # (to one side: the fish he holds up stays in view)
			"lost":
				_say(tf, Vector2(cx, vs.y * 0.36), str(f.lost_word), 40, Color("ffb08a"))
				_say(tx, Vector2(cx, vs.y * 0.36 + 44), "E: cast again", 18)

	func _say(font: Font, at: Vector2, s: String, size: int, col := Color("f3e3c3")) -> void:
		draw_string_outline(font, at - Vector2(450, 0), s, HORIZONTAL_ALIGNMENT_CENTER, 900, size, 8, Color(0.1, 0.06, 0.03, 0.9))
		draw_string(font, at - Vector2(450, 0), s, HORIZONTAL_ALIGNMENT_CENTER, 900, size, col)

	## The cast meter: a bow of colour NEAR (blue) to FAR (gold), a needle swinging.
	func _meter(c: Vector2, p: float) -> void:
		var r := 92.0
		draw_arc(c, r + 10.0, PI, TAU, 40, Color(0.1, 0.06, 0.03, 0.8), 34.0)
		for k in 30:
			var a0 := PI + PI * k / 30.0
			var a1 := PI + PI * (k + 1) / 30.0
			draw_arc(c, r + 10.0, a0, a1, 3, Color("5ab0ff").lerp(GOLD, k / 29.0), 24.0)
		var a := PI + PI * p
		draw_line(c, c + Vector2(cos(a), sin(a)) * (r + 26.0), Color.WHITE, 5.0)
		draw_circle(c, 9.0, INK)
		draw_circle(c, 6.0, Color.WHITE)
		var tf := Pal.title_font()
		draw_string(tf, c + Vector2(-r - 70, 8), "NEAR", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("bfe3ff"))
		draw_string(tf, c + Vector2(r + 26, 8), "FAR", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, GOLD)

	## The fight: the tension bar (slack, good, danger), how much line is out, how tired it is.
	func _tension(c: Vector2, ten: float, dist: float, st: float) -> void:
		var w := 460.0
		var r := Rect2(c.x - w * 0.5, c.y, w, 30)
		draw_rect(r.grow(5), Color(0.1, 0.06, 0.03, 0.85))
		draw_rect(Rect2(r.position, Vector2(w * 0.15, r.size.y)), Color("8a8a8a"))
		draw_rect(Rect2(r.position + Vector2(w * 0.15, 0), Vector2(w * 0.65, r.size.y)), Color("5f9e3a"))
		draw_rect(Rect2(r.position + Vector2(w * 0.8, 0), Vector2(w * 0.2, r.size.y)), Color("c0503a"))
		var x := r.position.x + w * clampf(ten, 0.0, 1.0)
		var danger := ten > 0.8
		draw_rect(Rect2(x - 5, r.position.y - 9, 10, r.size.y + 18), Color.WHITE if not danger or fmod(t, 0.2) < 0.1 else Color("ffe066"))
		var tf := Pal.title_font()
		var tx := Pal.text_font()
		draw_string(tf, r.position + Vector2(4, -12), "SLACK", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("d8d8d8"))
		draw_string(tf, r.position + Vector2(w * 0.4, -12), "REEL!", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("9be15d"))
		draw_string(tf, r.position + Vector2(w * 0.83, -12), "SNAP!", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("ff8a6a"))
		# line out and the fish's strength
		var big: bool = float(f._fish[6]) > 0.7 if not f._fish.is_empty() else false
		_say(tf, Vector2(c.x, c.y - 52), "Something BIG!" if big else "A fish on the line!", 26, GOLD)
		draw_string(tx, Vector2(r.position.x, r.end.y + 26), "Line out: %d m" % int(dist), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("f3e3c3"))
		var sw := 150.0
		draw_rect(Rect2(r.end.x - sw, r.end.y + 12, sw, 12), Color(0.1, 0.06, 0.03, 0.8))
		draw_rect(Rect2(r.end.x - sw, r.end.y + 12, sw * st, 12), Color("ffb347"))
		draw_string(tx, Vector2(r.end.x - sw - 70, r.end.y + 23), "its fight", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("f3e3c3"))
		_say(tx, Vector2(c.x, r.end.y + 62), "HOLD E (or Space): reel     let go: let it run", 17)

	## The catch: a hide card, the fish drawn, its name, size, NEW! / RECORD!.
	func _card(c: Vector2) -> void:
		var k := smoothstep(0.0, 0.35, float(f._st))
		var cd: Dictionary = f.caught
		if cd.is_empty():
			return
		var w := 520.0
		var h := 300.0
		draw_set_transform(c, 0.0, Vector2(k, k))
		var r := Rect2(-w * 0.5, -h * 0.5, w, h)
		draw_rect(Rect2(r.position + Vector2(6, 8), r.size), Color(0, 0, 0, 0.35))
		draw_rect(r, Color("ecd8b0"))
		draw_rect(r.grow(-6), Color("c9a074"), false, 3.0)
		var tf := Pal.title_font()
		var tx := Pal.text_font()
		if cd.has("junk"):
			var j: Array = cd["junk"]
			draw_string(tf, Vector2(r.position.x, -60), "NOT A FISH...", HORIZONTAL_ALIGNMENT_CENTER, w, 30, Color("8a6a3c"))
			draw_string(tf, Vector2(r.position.x, -10), str(j[1]), HORIZONTAL_ALIGNMENT_CENTER, w, 32, INK)
			draw_string(tx, Vector2(r.position.x, 40), str(j[2]), HORIZONTAL_ALIGNMENT_CENTER, w, 19, INK)
		else:
			var fish: Array = cd["fish"]
			var rk: int = fish[2]
			var rc: Color = Bag.RARITY_COL[rk]
			_draw_fish(Vector2(-120, -10), fish, int(cd["cm"]))
			draw_string(tf, Vector2(0, -86), str(fish[1]), HORIZONTAL_ALIGNMENT_LEFT, 250, 26, INK)
			draw_string(tf, Vector2(0, -58), Bag.RARITY[rk], HORIZONTAL_ALIGNMENT_LEFT, 250, 16, rc.darkened(0.3))
			draw_string(tf, Vector2(0, -12), "%d cm" % int(cd["cm"]), HORIZONTAL_ALIGNMENT_LEFT, 250, 40, INK)
			draw_multiline_string(tx, Vector2(0, 20), str(fish[10]), HORIZONTAL_ALIGNMENT_LEFT, 240, 15, 3, INK.lightened(0.2))
			if str(cd["reward"]) != "":
				draw_multiline_string(tf, Vector2(r.position.x + 24, 100), str(cd["reward"]), HORIZONTAL_ALIGNMENT_CENTER, w - 48, 17, 2, Color("5f9e3a"))
			if bool(cd["new"]) or bool(cd["record"]):
				draw_set_transform(c + Vector2(w * 0.5 - 70, -h * 0.5 + 24) * k, 0.25, Vector2(k, k))
				var st := Rect2(-70, -22, 140, 44)
				draw_rect(st, Color(1, 1, 1, 0.0))
				draw_rect(st, Color("e04848"), false, 4.0)
				draw_string(tf, Vector2(-70, 12), "NEW!" if bool(cd["new"]) else "RECORD!", HORIZONTAL_ALIGNMENT_CENTER, 140, 26, Color("e04848"))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		draw_string_outline(tx, Vector2(c.x - 300, c.y + h * 0.5 * k + 32), "E: cast again      Esc / a step: put the stick down", HORIZONTAL_ALIGNMENT_CENTER, 600, 17, 6, Color(0.1, 0.06, 0.03, 0.9))
		draw_string(tx, Vector2(c.x - 300, c.y + h * 0.5 * k + 32), "E: cast again      Esc / a step: put the stick down", HORIZONTAL_ALIGNMENT_CENTER, 600, 17, Color("f3e3c3"))

	## A fish drawn flat: its body and belly, tail, fin, eye; each kind's marks.
	func _draw_fish(c: Vector2, fish: Array, cm: int) -> void:
		var body: Color = fish[3]
		var belly: Color = fish[4]
		var id: String = fish[0]
		var l := 190.0
		var hh := l * (0.18 if id == "glow_eel" else 0.32)
		if id == "glow_eel":
			draw_circle(c, l * 0.55, Color(0.43, 1.0, 0.85, 0.12 + 0.06 * sin(t * 3.0)))
		var top := PackedVector2Array()
		var bot := PackedVector2Array()
		for k in 17:
			var q := k / 16.0
			var x := lerpf(-l * 0.5, l * 0.5, q)
			var y := sin(q * PI) * hh * (1.0 - 0.25 * q)
			top.append(c + Vector2(x, -y))
			bot.append(c + Vector2(x, y * 0.85))
		var tail := PackedVector2Array([c + Vector2(-l * 0.46, 0), c + Vector2(-l * 0.72, -hh * 0.8), c + Vector2(-l * 0.62, 0), c + Vector2(-l * 0.72, hh * 0.8)])
		draw_colored_polygon(tail, body.darkened(0.2))
		var outline := top.duplicate()
		var rev := bot.duplicate()
		rev.reverse()
		outline.append_array(rev)
		draw_colored_polygon(outline, body)
		var low := PackedVector2Array([c + Vector2(-l * 0.45, 0)])
		for k in range(1, 16):
			low.append((bot[k] as Vector2) + Vector2(0, 0))
		low.append(c + Vector2(l * 0.45, 0))
		draw_colored_polygon(low, belly)
		draw_colored_polygon(PackedVector2Array([c + Vector2(-l * 0.1, -hh * 0.9), c + Vector2(l * 0.1, -hh * 1.35), c + Vector2(l * 0.16, -hh * 0.85)]), body.darkened(0.25))
		draw_polyline(outline + PackedVector2Array([outline[0]]), body.darkened(0.45), 3.0)
		match id:
			"snapper":
				for k in 3:
					var x2 := -l * 0.2 + k * l * 0.15
					draw_line(c + Vector2(x2, -hh * 0.75), c + Vector2(x2 - 8, hh * 0.6), body.darkened(0.4), 7.0)
			"whiskers":
				for s in [-1.0, 1.0]:
					draw_line(c + Vector2(l * 0.45, 4), c + Vector2(l * 0.62, 4 + s * 22), INK, 2.5)
			"golden_carp":
				for k in 7:
					draw_circle(c + Vector2(-l * 0.25 + k * l * 0.08, (k % 2 - 0.5) * hh * 0.6), 5.0, Color("fff2a0"))
			"glow_eel":
				draw_line(c + Vector2(-l * 0.4, -2), c + Vector2(l * 0.4, -2), Color("6dffd8"), 4.0)
			"bonejaw":
				for k in 4:
					draw_rect(Rect2(c + Vector2(-l * 0.25 + k * l * 0.12, -hh * 0.8), Vector2(l * 0.1, hh * 0.5)), Color("8a8a96"))
				for k in 6:
					draw_colored_polygon(PackedVector2Array([c + Vector2(l * 0.3 + k * 6, 4), c + Vector2(l * 0.3 + k * 6 + 3, 14), c + Vector2(l * 0.3 + k * 6 + 6, 4)]), Color("efe4c8"))
		draw_circle(c + Vector2(l * 0.32, -hh * 0.25), 9.0, Color.WHITE)
		draw_circle(c + Vector2(l * 0.34, -hh * 0.25), 5.0, Color("1a120c"))
		draw_circle(c + Vector2(l * 0.35, -hh * 0.28), 1.8, Color.WHITE)
		# a size bar: how big for its kind
		var sz: Array = fish[5]
		var kk := clampf((cm - float(sz[0])) / maxf(float(sz[1]) - float(sz[0]), 1.0), 0.0, 1.0)
		draw_rect(Rect2(c + Vector2(-l * 0.5, hh + 26), Vector2(l, 8)), Color(0, 0, 0, 0.2))
		draw_rect(Rect2(c + Vector2(-l * 0.5, hh + 26), Vector2(l * kk, 8)), Color("ffb347"))
