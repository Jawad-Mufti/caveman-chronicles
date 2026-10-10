extends "res://shelter/system.gd"
## COMING HOME (the home, shelter/home.gd): things that make a visit worth it.
## - THE WELCOME CARD: as he arrives, a card slides down: "WELCOME HOME!" and
##   what's new and what's waiting: the pup has dug something up, relics brought
##   home since last time, a build he can pay for now (or how many bones the
##   next one wants), a wish ready on Star Rock, the mirror to make.
## - THE PUP'S FIND: between visits (every PUP_EVERY seconds, real time) the pup
##   digs up something by the fire: a mound with a bone sticking out; E: dig it
##   up (shells mostly; sometimes a stone, bones, fire-gold, a rare quartz).

const Builds := preload("res://shelter/builds.gd")
const Nature := preload("res://shelter/nature.gd")
const PUP_EVERY := 30.0 * 60.0                      ## a find every half an hour away
const MOUND := Vector3(-3.4, 0, 3.0)                ## (from the cave's middle) by the pup

var _mound: Node3D
var _card: CanvasLayer
var _rng := RandomNumberGenerator.new()


func movers() -> Array:
	return [_mound] if _mound != null else []


func build() -> void:
	_rng.randomize()
	if now() - float(saved("pup", 0.0)) >= PUP_EVERY:
		_make_mound()
	if not OS.get_cmdline_user_args().has("shot") and not OS.get_cmdline_user_args().has("nocard"):
		_welcome.call_deferred()


## ------------------------------------------------------------------ the pup's find
func _make_mound() -> void:
	var at: Vector3 = home.CAVE + MOUND
	_mound = pivot(at)
	shape(ball(0.55, 8), home.EARTH, Vector3(0, 0.05, 0), Vector3.ZERO, Vector3(1.0, 0.45, 0.85), _mound)
	for k in 6:
		var a := k * TAU / 6.0
		shape(ball(0.13, 5), home.EARTH.darkened(0.15), Vector3(cos(a) * 0.65, 0.05, sin(a) * 0.55), Vector3.ZERO, Vector3.ONE, _mound)
	shape(cyl(0.05, 0.5, 5), home.BONE, Vector3(0.1, 0.35, 0), Vector3(0, 0, -30), Vector3.ONE, _mound)
	shape(ball(0.08, 5), home.BONE, Vector3(0.24, 0.58, 0), Vector3.ZERO, Vector3.ONE, _mound)
	var sp: CPUParticles3D = home._particles(10, 1.0, Color("fff2a0"), 0.03, 0.06, true)
	sp.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	sp.emission_sphere_radius = 0.5
	sp.gravity = Vector3(0, 0.5, 0)
	sp.spread = 180.0
	sp.initial_velocity_min = 0.1
	sp.initial_velocity_max = 0.4
	sp.position = Vector3(0, 0.4, 0)
	_mound.add_child(sp)
	home._spot("dig", at, "THE PUP'S FIND", "E: dig it up!")


func use(id: String) -> bool:
	if id != "dig" or _mound == null:
		return false
	var at := _mound.global_position
	puff(at + Vector3(0, 0.3, 0), Color(0.55, 0.4, 0.25, 0.9), 30, 3.5)
	_mound.queue_free()
	_mound = null
	home._unspot("dig")
	save_key("pup", now())
	var got := _find()
	pop_word(got, at + Vector3(0, 1.4, 0), Color("ffe066"), 80)
	home.say("The pup dug up %s! Good pup." % got)
	home._pup_hop = 1.2
	if home._hearts != null:
		home._hearts.restart()
	home._model.cheer(1.0)
	return true


## What the pup dug up.
func _find() -> String:
	var r := _rng.randf()
	if r < 0.5:
		var n := _rng.randi_range(6, 14)
		GameState.shells += n
		GameState.save()
		return "%d SHELLS" % n
	if r < 0.72:
		var id := "clay" if _rng.randf() < 0.5 else "flint"
		Bag.add(id)
		return "a lump of %s" % Bag.name_of(id)
	if r < 0.9:
		var b := _rng.randi_range(4, 9)
		GameState.bones += b
		GameState.save()
		return "%d BONES" % b
	if r < 0.98:
		Bag.add("pyrite")
		return "a bit of FIRE-GOLD"
	Bag.add("quartz")
	return "a QUARTZ!"


## ------------------------------------------------------------------ the welcome card
## What's new and what's waiting, for the card.
func news() -> Array:
	var out: Array = []
	var first := not GameState.shelter.has("visits")
	GameState.shelter["visits"] = int(GameState.shelter.get("visits", 0)) + 1
	GameState.save()
	if first:
		out.append("Your cave! The BONES you bring home BUILD things here: find the signs.")
	if _mound != null:
		out.append("The pup has dug something up, by the fire!")
	for s in home._systems:
		if s.has_method("new_ones"):
			var nw: Array = s.new_ones()
			if not nw.is_empty():
				var names: Array = nw.slice(0, 2).map(func(k: String) -> String: return Relics.name_of(k))
				if nw.size() > 2:
					names.append("%d more" % (nw.size() - 2))
				out.append("Brought home: %s. Find where they went!" % ", ".join(names))
	var next := []
	for b in Builds.BUILDS:
		if not Builds.is_built(b[0]):
			next = b
			break
	if not next.is_empty():
		if GameState.bones >= int(next[2]):
			out.append("You have %d bones: you can BUILD %s! (the workshop, or its sign)" % [GameState.bones, next[1]])
		else:
			out.append("Next to build: %s, %d more bones." % [next[1], int(next[2]) - GameState.bones])
	if Builds.is_built("bridge") and float(GameState.shelter.get("wish", 0.0)) + Nature.WISH_EVERY <= now():
		out.append("The WISHING STONE on Star Rock is awake. Make a wish!")
	for r in Bag.HOME_RECIPES:                               # what the workshop can make now
		if Bag.missing(home._rig, r[0]) == "":
			out.append("You have all it takes to make the %s (the workshop)!" % Bag.name_of(r[0]))
			break
	return out.slice(0, 4)


func _welcome() -> void:
	var lines := news()
	_card = CanvasLayer.new()
	_card.layer = 4
	var c := WelcomeCard.new()
	c.lines = lines
	_card.add_child(c)
	home.add_child(_card)


## The card: a hide with a bone at the top and bottom, the words on it; it
## slides down, stays a while, goes back up (a click: at once).
class WelcomeCard extends Control:
	var lines: Array = []
	var t := 0.0
	const W := 760.0
	const STAY := 7.5

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_PASS
		set_anchors_preset(Control.PRESET_FULL_RECT)

	func _process(delta: float) -> void:
		t += delta
		if t > STAY + 1.0:
			get_parent().queue_free()
			return
		queue_redraw()

	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and (e as InputEventMouseButton).pressed and _rect().has_point((e as InputEventMouseButton).position):
			t = maxf(t, STAY)

	func _rect() -> Rect2:
		var h := 92.0 + lines.size() * 30.0
		var k := smoothstep(0.0, 0.6, t) * (1.0 - smoothstep(STAY, STAY + 0.7, t))
		var vw := get_viewport_rect().size.x
		return Rect2((vw - W) * 0.5, lerpf(-h - 20.0, 92.0, k), W, h)

	func _draw() -> void:
		var r := _rect()
		if r.end.y < 0.0:
			return
		draw_rect(Rect2(r.position + Vector2(6, 8), r.size), Color(0, 0, 0, 0.35))
		draw_rect(r, Color("ecd8b0"))
		draw_rect(r.grow(-6), Color("d9bf90"), false, 2.0)
		for y in [r.position.y, r.end.y]:                    # a bone across top and bottom
			draw_line(Vector2(r.position.x - 14, y), Vector2(r.end.x + 14, y), Color("efe4c8"), 9.0)
			for x in [r.position.x - 14, r.end.x + 14]:
				draw_circle(Vector2(x, y - 4), 7.0, Color("efe4c8"))
				draw_circle(Vector2(x, y + 4), 7.0, Color("efe4c8"))
		var tf := Pal.title_font()
		var f := Pal.text_font()
		draw_string_outline(tf, r.position + Vector2(0, 50), "WELCOME HOME, UGU!", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 34, 8, Color("3b2a22"))
		draw_string(tf, r.position + Vector2(0, 50), "WELCOME HOME, UGU!", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 34, Color("ffcf40"))
		for i in lines.size():
			var y2 := r.position.y + 88 + i * 30
			draw_circle(Vector2(r.position.x + 28, y2 - 6), 5.0 + sin(t * 4.0 + i) * 0.8, Color("c8553d"))
			draw_string(f, Vector2(r.position.x + 44, y2), str(lines[i]), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 60, 17, Color("3b2a22"))
