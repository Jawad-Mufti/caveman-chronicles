extends RefCounted
## SIDE MISSION: SHIVERS' WINDBREAK. At the foot of the mountain's east slope
## a stranger sits by a sad little fire beside his lean-to, and the wind off
## the steppe blows it sideways. He'd like a wall. Ugu mixes one on the MIXING
## SLAB (Bag.Mixer) from what's in his bag: granny's rhyme says TWO sticks to
## stand it, THREE stones to hold it, ONE clay to glue it. A wrong mix gets a
## hint (and costs nothing); the right one and Ugu builds it, two seconds of
## THUNK, CLACK, SPLAT. The wind goes over it, the fire stands up, Shivers
## warms up (and is Grog again), and gives two pieces of obsidian and a roast
## fig. Kept: GameState.mysteries["windbreak"] (it's in the camp menu too).
## The mud bank by his hut gives clay for a good BONK.

const AT := Vector2(11905, 600)        ## the camp, on the flat at the foot of the slope (ground y 600)
const SHIVERS_X := 100.0
const FIRE_X := 160.0
const WALL_X := 268.0
const STAND_X := 212.0                 ## where Ugu builds from, west of the wall (the steppe ambush starts at 12260)
const MUD_AT := Vector2(11806, 630)
const RIGHT := {"wood": 2, "rocks": 3, "clay": 1}
const BUILD_TIME := 2.0
const WORDS := ["NONE", "ONE", "TWO", "THREE", "FOUR", "FIVE", "SIX"]
const DATA := preload("res://level2/level2_data.gd")


static func build(level: Node) -> Camp:
	var c := Camp.new()
	c.level = level
	c.position = AT
	level.add_child(c)
	var mud := MudBank.new()
	mud.position = MUD_AT
	level.add_child(mud)
	return c


## ================================================================ THE CAMP
## Shivers, his lean-to, his fire, the wind, and (once built) the wall.
## Origin: the ground under the lean-to.
class Camp extends Node2D:
	var level: Node                 ## Level 2 (for _talk, player, hud)
	var speaking := false
	var built := false
	var build_t := -1.0             ## >= 0: Ugu is building it
	var _t := 0.0
	var _met := false
	var _wrong := 0                 ## wrong mixes so far (the rhyme comes back after two)
	var _swing := 0.0
	var _said := 0                  ## build words said so far

	func _ready() -> void:
		z_index = -1
		built = GameState.mystery("windbreak") == "solved"
		_met = GameState.mystery("windbreak") != ""
		add_to_group("light")
		add_to_group("glow")

	func light() -> Vector4:
		return Vector4(global_position.x + FIRE_X, global_position.y - 30.0, 240.0 if built else 150.0, 1.0)

	func light_strength() -> float:
		return 1.0 if built else 0.75 + 0.15 * sin(_t * 9.0)

	func draw_glow(g) -> void:   # g: the glow layer's Batch
		var f := global_position + Vector2(FIRE_X, -18)
		g.draw_circle(f, 30.0 if built else 18.0, Color(1.0, 0.6, 0.25, 0.35))
		_wind(g, global_position)

	func _process(delta: float) -> void:
		_t += delta
		if build_t >= 0.0:
			_build_step(delta)
		if LevelBase.near_view(self):
			queue_redraw()

	## ---------------------------------------------------------- talking
	func meet() -> void:
		var p: CaveMan = level.player
		if built:
			level._again(["GROG:  \"Toasty! Toasty toasty toasty.\"", "GROG:  \"Best wall in the whole Stone Age.\"",
				"GROG:  \"I named the wall. It's called WALLY.\"", "GROG:  \"My toes stopped telling jokes. I kind of miss them.\""])
			return
		if not _met:
			_met = true
			GameState.open_mystery("windbreak")
			level._talk([
				["SHIVERS", "B-b-b-BRRR! H-hello! Don't mind me. I'm j-just... v-vibrating."],
				{"choose": [
					["You cold?", [["SHIVERS", "C-cold? My toes froze so hard they t-tell jokes now. B-bad ones."]]],
					["Nice hut.", [["SHIVERS", "Th-thanks! Built it myself. The w-wind likes it too. It keeps trying to TAKE it."]]],
					["Who are you?", [["SHIVERS", "I'm SHIVERS. W-well, I was Grog. Then the wind came. Now I'm Shivers."]]],
				]},
				["SHIVERS", "The wind comes off the steppe and blows my fire SIDEWAYS. Fire isn't s-supposed to go sideways!"],
				["SHIVERS", "If only someone b-built a WALL. Right there. Between me and the w-wind..."],
				["", "He looks at Ugu. He looks at the empty spot. He looks at Ugu again. VERY hard."],
				["SHIVERS", "My granny's rhyme: TWO sticks to STAND it, THREE stones to HOLD it, ONE clay to GLUE it!"],
				["SHIVERS", "Clay? My m-mud bank, by the hut. Give it a good BONK."],
				_ask_build(),
			])
			return
		level._talk([
			["SHIVERS", ["Back! B-b-brilliant!", "Still here. Still v-vibrating.", "My nose is blue. Is that a f-fashion?"][randi() % 3]],
			_ask_build(),
		])

	## "Shall we?" Building opens the mixing slab when the talk is over.
	func _ask_build() -> Dictionary:
		return {"choose": [
			["Let's build it!", [["SHIVERS", "YES! Get mixing! Ooh, I'm so excited my t-teeth are clapping.", _open_later]]],
			["Not yet.", [["SHIVERS", "I'll j-just... keep vibrating, then."]]],
		]}

	func _open_later() -> void:
		var d := level.get_tree().get_first_node_in_group("dialogue")
		if d != null and d.has_signal("finished"):
			d.finished.connect(open_mixer, CONNECT_ONE_SHOT)
		else:
			open_mixer.call_deferred()

	## ---------------------------------------------------------- the mixing slab
	func open_mixer() -> void:
		var p: CaveMan = level.player
		if p == null or p.dead or Bag.mixer != null:
			return
		var m := Bag.Mixer.new()
		m.title = "MIX: A WINDBREAK"
		m.him = p
		m.goal_icon = "wall"
		m.note = "Click wood, rocks and clay in your bag. Remember granny's rhyme!"
		if _wrong >= 2:
			m.note = "Granny: TWO sticks to stand it, THREE stones to hold it, ONE clay to glue it!"
		m.mixed.connect(func(mix: Dictionary) -> void: _on_mix(m, mix))
		m.closed.connect(func() -> void:
			if build_t < 0.0:
				p.talking = false)
		p.talking = true            # he stands at the slab: still, and safe
		level.hud.add_child(m)

	## What Shivers says about a mix: "" if it's right.
	static func judge(mix: Dictionary) -> String:
		for id in mix:
			if not RIGHT.has(id):
				match id:
					"bones":
						return "Bones? I want a WALL, not a skeleton friend!"
					"berries", "figs", "salve":
						return "Food?! ...I'll eat that later. But not IN the wall."
					"flint", "tips":
						return "Flint is for cutting. Walls don't need to cut anything!"
					"pyrite", "quartz", "obsidian":
						return "Too shiny for a wall! Keep that treasure."
					_:
						return "%s? That's not in granny's rhyme." % Bag.name_of(id)
		if not mix.has("wood"):
			return "No sticks? What's going to STAND it up?"
		if not mix.has("rocks"):
			return "No stones?! The wind will blow it to the next valley!"
		if not mix.has("clay"):
			return "Nothing to GLUE it! Clay, from my mud bank. BONK it!"
		for id in RIGHT:
			var have := int(mix[id])
			var want: int = RIGHT[id]
			if have < want:
				if id == "wood":
					return "Just %s stick%s? It'll wobble like my knees!" % [WORDS[have].to_lower(), "" if have == 1 else "s"]
				return "Not enough %s! Granny said %s." % [Bag.name_of(id), WORDS[want]]
			if have > want:
				return "Too much %s! It'll fall on my head! Granny said %s." % [Bag.name_of(id), WORDS[want]]
		return ""

	func _on_mix(m: Bag.Mixer, mix: Dictionary) -> void:
		var hint := judge(mix)
		if hint != "":
			_wrong += 1
			if _wrong == 2:
				hint += "  (Granny: TWO, THREE, ONE!)"
			m.say("SHIVERS: " + hint, false)
			return
		m.say("SHIVERS: THAT'S IT! Granny would cry!", true)
		var p: CaveMan = level.player
		for id in mix:
			Bag._spend(p, id, int(mix[id]))
		Bag.version += 1
		GameState.save()
		build_t = 0.0                  # (before close: the slab closing doesn't let him go)
		m.close()
		_start_build(p)

	## ---------------------------------------------------------- building it
	func _start_build(p: CaveMan) -> void:
		p.talking = true
		_swing = 0.0
		_said = 0
		var stand := global_position.x + STAND_X
		var tw := create_tween()
		tw.tween_property(p, "global_position:x", stand, clampf(absf(p.global_position.x - stand) / 330.0, 0.05, 0.4))
		p.facing = 1

	func _build_step(delta: float) -> void:
		var p: CaveMan = level.player
		build_t += delta
		_swing -= delta
		if _swing <= 0.0 and build_t < BUILD_TIME - 0.15:
			_swing = 0.34
			p.facing = 1
			p._start_swing("club")         # (while he's "talking" a swing hits nothing: just the hammering)
		var at := global_position + Vector2(WALL_X, 0)
		var beats := [[0.15, "THUNK!", -22.0], [0.45, "THUNK!", 22.0], [0.8, "CLACK!", -60.0], [1.05, "CLACK!", -90.0], [1.3, "CLACK!", -120.0], [1.65, "SPLAT!", -70.0]]
		while _said < beats.size() and build_t >= float(beats[_said][0]):
			var b: Array = beats[_said]
			var w := CaveMan.WordPop.new()
			w.text = b[1]
			w.size = 22
			w.color = Color("ffd36b") if b[1] != "SPLAT!" else Color("e07a5f")
			w.centered = true
			w.position = at + Vector2(randf_range(-30, 30), float(b[2]) - 40.0)
			level.add_child(w)
			FX.burst(level, at + Vector2(0, float(b[2]) if b[1] != "THUNK!" else 0.0), "dust")
			_said += 1
		if build_t >= BUILD_TIME:
			build_t = -1.0
			built = true
			GameState.solve_mystery("windbreak")
			for i in 3:
				FX.shards(level, at + Vector2(0, -40.0 - i * 30.0), Vector2(randf_range(-1, 1), -1), false)
			var w := CaveMan.WordPop.new()
			w.text = "WINDBREAK!"
			w.size = 32
			w.color = Color("ffd36b")
			w.star = Color(0.35, 0.18, 0.05, 0.8)
			w.centered = true
			w.life = 1.4
			w.position = at + Vector2(-40, -170)
			level.add_child(w)
			p.talking = false
			_thanks()

	func _thanks() -> void:
		level._talk([
			["SHIVERS", "...Wait. My teeth stopped. Hello, teeth! I can hear myself THINK!"],
			["SHIVERS", "Look at my fire! It goes UP! Like a PROPER fire!"],
			{"choose": [
				["You're welcome!", [["SHIVERS", "I'm changing my name back to GROG. Shivers was a silly name."]]],
				["Warm now?", [["SHIVERS", "Warm as a bear's armpit. ...That's a GOOD thing."]]],
			]},
			["SHIVERS", "Here. Black glass from deep in the mountain. I kept it for a rainy day... but it's a WARM day!", _reward],
			["SHIVERS", "And a roast fig, hot from MY fire. My fire that goes UP."],
		])

	func _reward() -> void:
		var from := global_position + Vector2(SHIVERS_X, -70)
		for i in 2:
			var f := Bag.Find.new()
			f.id = "obsidian"
			f.position = from
			f.vel = Vector2(randf_range(-60, 60), -340.0 - i * 60.0)
			level.add_child(f)
		if GameState.figs < GameState.fig_max():
			GameState.figs += 1
			GameState.save()
			level.hud.set_figs(GameState.figs)

	## ---------------------------------------------------------- the picture
	func _draw() -> void:
		var b := Batch.new()
		_lean_to(b)
		_draw_wall(b)
		_fire(b)
		_shivers(b)
		b.draw(self)
		if not built and not speaking and fmod(_t, 3.2) < 1.1:
			var q := fmod(_t, 3.2) / 1.1
			draw_string(ThemeDB.fallback_font, Vector2(SHIVERS_X + 18 + q * 14.0, -118 - q * 16.0), "brrr", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.75, 0.9, 1.0, 1.0 - q))

	## A humble lean-to: two forked poles, sticks laid slanting down, a patchy hide, a grass bed.
	func _lean_to(b: Batch) -> void:
		var stick := Color("6b4a2e")
		var dark := Color("3a2616")
		b.line(Vector2(34, 0), Vector2(30, -98), dark, 7.0)
		b.line(Vector2(34, 0), Vector2(30, -98), stick, 4.5)
		b.line(Vector2(-6, 0), Vector2(-4, -60), stick, 4.0)
		b.line(Vector2(30, -98), Vector2(22, -112), stick, 3.0)       # the fork
		b.line(Vector2(30, -98), Vector2(40, -110), stick, 3.0)
		for i in 7:
			var top := Vector2(30.0 - i * 2.0, -98.0 + i * 1.5)
			b.line(top, Vector2(-58.0 + i * 4.0, 2), dark if i % 2 == 0 else stick, 3.5)
		# a hide over part of it, a corner flapping in the wind
		var flap := 0.0 if built else sin(_t * 9.0) * 5.0
		b.quad(Vector2(24, -90), Vector2(-40, -22), Vector2(-22, -10), Vector2(30, -70 + flap), Color("8a6440"))
		b.tri(Vector2(30, -70 + flap), Vector2(42, -64 + flap * 1.6), Vector2(26, -80), Color("7a5636"))
		b.circle(Vector2(-6, -40), 3.0, Color("5a3e26"))                # a patch
		b.ellipse(Vector2(-14, -4), 40.0, 6.0, Color("8a8a3a"))         # the grass bed
		for k in 6:
			b.line(Vector2(-46 + k * 13, -2), Vector2(-49 + k * 13, -12 - (k % 2) * 4), Color("a3a14a"), 2.0)

	func _fire(b: Batch) -> void:
		var f := Vector2(FIRE_X, 0)
		for k in 5:
			b.ellipse(f + Vector2(-18 + k * 9, -3), 6.0, 4.5, Color("6b625c"))
		b.line(f + Vector2(-14, -4), f + Vector2(14, -10), Color("4a3220"), 5.0)
		b.line(f + Vector2(-14, -10), f + Vector2(14, -4), Color("5a3a22"), 5.0)
		var flick := sin(_t * 13.0) * 3.0 + sin(_t * 7.3) * 2.0
		var h := (44.0 if built else 20.0) + flick
		var lean := 0.0 if built else -(16.0 + sin(_t * 3.0) * 6.0)   # the wind pushes it west
		b.tri(f + Vector2(-13, -6), f + Vector2(lean, -6 - h), f + Vector2(13, -6), Pal.FLAME)
		b.tri(f + Vector2(-7, -6), f + Vector2(lean * 0.6, -6 - h * 0.6), f + Vector2(7, -6), Pal.FLAME_CORE)
		if built:
			for k in 3:
				var q := fmod(_t * 1.4 + k * 0.33, 1.0)
				b.circle(f + Vector2(sin(_t * 3.0 + k) * 6.0, -30.0 - q * 50.0), 2.0 * (1.0 - q), Color(1, 0.7, 0.3, 1.0 - q))

	## Two stakes, three big stones, clay between: as much of it as is built so far.
	func _draw_wall(b: Batch) -> void:
		var bt := 99.0 if built else build_t
		if bt < 0.0:
			# where it should go: a faint outline, once he knows
			if _met:
				var a := 0.18 + 0.1 * sin(_t * 4.0)
				b.line(Vector2(WALL_X - 26, 0), Vector2(WALL_X - 26, -116), Color(1, 1, 1, a), 2.0)
				b.line(Vector2(WALL_X + 26, 0), Vector2(WALL_X + 26, -116), Color(1, 1, 1, a), 2.0)
				b.line(Vector2(WALL_X - 26, -116), Vector2(WALL_X + 26, -116), Color(1, 1, 1, a), 2.0)
			return
		var w := Vector2(WALL_X, 0)
		for s in 2:
			var t0 := 0.15 + s * 0.3
			if bt >= t0:
				var drop := maxf(0.0, 1.0 - (bt - t0) / 0.12) * 60.0
				var x := -24.0 if s == 0 else 24.0
				b.line(w + Vector2(x, 4), w + Vector2(x, -128 - drop), Color("3a2616"), 8.0)
				b.line(w + Vector2(x, 4), w + Vector2(x, -128 - drop), Color("846141"), 5.0)
				b.tri(w + Vector2(x - 4, -128 - drop), w + Vector2(x, -138 - drop), w + Vector2(x + 4, -128 - drop), Color("846141"))
		var stones := [[0.8, -20.0, 26.0], [1.05, -56.0, 24.0], [1.3, -92.0, 22.0]]
		for k in stones.size():
			var st: Array = stones[k]
			if bt >= float(st[0]):
				var drop := maxf(0.0, 1.0 - (bt - float(st[0])) / 0.1) * 50.0
				var c := w + Vector2(0, float(st[1]) - drop)
				var r: float = st[2]
				b.ellipse(c, r + 2.0, r * 0.75 + 2.0, Color("3e3630"))
				b.ellipse(c + Vector2(0, -1), r, r * 0.75, Color("8f877c").darkened(0.06 * k))
				b.ellipse(c + Vector2(-r * 0.35, -r * 0.3), r * 0.3, r * 0.18, Color(1, 1, 1, 0.22))
		if bt >= 1.65:
			var a := clampf((bt - 1.65) / 0.25, 0.0, 1.0)
			for y in [-38.0, -74.0]:
				b.ellipse(w + Vector2(0, y), 22.0, 6.0, Color(0.63, 0.33, 0.22, a))
				b.ellipse(w + Vector2(-6, y - 1), 6.0, 2.0, Color(0.85, 0.5, 0.35, a * 0.7))
		# vine lashings at the top
		if bt >= 1.65:
			b.line(w + Vector2(-26, -108), w + Vector2(26, -102), Color("5a6b2a"), 3.0)

	## Shivers, sitting on a log facing his fire: hunched and shaking, arms
	## hugged in, blue nose; once warm, hands out to the fire and a big smile.
	func _shivers(b: Batch) -> void:
		var shake := Vector2(sin(_t * 47.0) * 1.6, 0) if not built else Vector2.ZERO
		var o := Vector2(SHIVERS_X, 0) + shake
		var skin := Color("b89a86") if not built else Color("d39a6a")
		var hide := Color("7a5636")
		# the log
		b.ellipse(Vector2(SHIVERS_X - 4, -9), 22.0, 9.0, Color("4a3220"))
		b.ellipse(Vector2(SHIVERS_X + 16, -9), 5.0, 8.0, Color("8a6440"))
		# legs: knees up toward the fire
		b.line(o + Vector2(-4, -22), o + Vector2(14, -30), skin.darkened(0.15), 8.0)
		b.line(o + Vector2(14, -30), o + Vector2(18, -2), skin.darkened(0.15), 7.0)
		b.ellipse(o + Vector2(22, -2), 7.0, 3.5, Color("4a3426"))
		# the body, hunched (warm: sitting up)
		var hunch := 0.0 if built else 6.0
		var neck := o + Vector2(2 + hunch, -64 + hunch)
		b.ellipse(o + Vector2(0, -42), 17.0, 22.0, skin)
		b.quad(o + Vector2(-16, -52), o + Vector2(14, -58), o + Vector2(18, -22), o + Vector2(-18, -20), hide)
		b.tri(o + Vector2(-18, -20), o + Vector2(-8, -20), o + Vector2(-14, -12), hide.darkened(0.15))   # a ragged edge
		b.tri(o + Vector2(4, -20), o + Vector2(14, -21), o + Vector2(9, -13), hide.darkened(0.15))
		# arms
		if built:
			b.line(o + Vector2(6, -54), o + Vector2(26, -44), skin, 7.0)        # hands out to the fire
			b.circle(o + Vector2(28, -44), 4.5, skin)
		else:
			b.line(o + Vector2(-12, -52), o + Vector2(12, -40), skin.darkened(0.08), 7.0)   # hugging himself
			b.line(o + Vector2(10, -54), o + Vector2(-10, -40), skin, 7.0)
			b.circle(o + Vector2(-11, -40), 4.0, skin)
			b.circle(o + Vector2(13, -40), 4.0, skin.darkened(0.08))
		# the head
		var h := neck + Vector2(2, -18)
		b.circle(h, 16.0, skin, 18)
		# wild grey-black hair and a scruffy beard
		for k in 7:
			var a := PI + 0.2 + k * 0.42
			var tip := h + Vector2.from_angle(a) * (22.0 + (k % 2) * 4.0) + Vector2(0, -2)
			b.tri(h + Vector2.from_angle(a - 0.3) * 13.0, tip, h + Vector2.from_angle(a + 0.3) * 13.0, Color("3d3a38"))
		b.ellipse(h + Vector2(3, 11), 11.0, 8.0, Color("4a4542"))
		# eyes (warm: happy closed arcs)
		for s in [-1.0, 1.0]:
			var e := h + Vector2(5.0 + s * 5.0, -3)
			if built:
				b.line(e + Vector2(-3, 1), e + Vector2(0, -1.5), Color("1a120c"), 2.0)
				b.line(e + Vector2(0, -1.5), e + Vector2(3, 1), Color("1a120c"), 2.0)
			else:
				b.circle(e, 2.6, Color.WHITE, 8)
				b.circle(e + Vector2(0.8, 0), 1.5, Color("1a120c"), 6)
		# the big nose (blue at the tip with cold) and the mouth
		b.ellipse(h + Vector2(14, 2), 5.5, 4.5, skin.darkened(0.12))
		b.circle(h + Vector2(17, 2), 2.8, Color("8fb8e0") if not built else Color("e8907a"), 8)
		var m := h + Vector2(9, 9)
		if speaking:
			b.ellipse(m, 3.5, 2.0 + (0.5 + 0.5 * sin(_t * 18.0)) * 2.5, Color("3a1a12"))
		elif built:
			b.line(m + Vector2(-4, -1), m + Vector2(0, 2), Color("3a1a12"), 2.0)
			b.line(m + Vector2(0, 2), m + Vector2(4, -1), Color("3a1a12"), 2.0)
			b.circle(h + Vector2(4, 5), 3.0, Color(0.95, 0.5, 0.45, 0.5))   # rosy cheek
		else:
			# chattering teeth
			var chat := 1.0 + absf(sin(_t * 30.0)) * 2.0
			b.rect(Rect2(m + Vector2(-4, -chat * 0.5 - 1.0), Vector2(8, 2)), Color("f2ead8"))
			b.rect(Rect2(m + Vector2(-4, chat * 0.5 - 1.0), Vector2(8, 2)), Color("f2ead8"))

	## The wind off the steppe: streaks blowing west. Once the wall stands
	## they're thrown up and over it, and the camp is still.
	func _wind(g, o: Vector2) -> void:   # g: the glow layer (over the dark), o: where the camp is
		var gust := 0.6 + 0.4 * sin(_t * 1.3)
		for i in 18:
			var sd := float(i) * 37.13
			var y := -18.0 - fmod(sd * 7.7, 150.0)
			var span := 820.0
			var x := 540.0 - fmod(_t * (380.0 + fmod(sd, 120.0)) + sd * 13.0, span)
			var ln := 26.0 + fmod(sd, 30.0) * gust
			var a := 0.45 * gust
			if built and x < WALL_X + 60.0:
				# over the wall and away: lifted, thinning out
				var past := WALL_X + 60.0 - x
				y -= past * 1.1 + 20.0
				a *= clampf(1.0 - past / 160.0, 0.0, 1.0)
			if a <= 0.01:
				continue
			g.draw_line(o + Vector2(x, y), o + Vector2(x + ln, y + 2.0), Color(0.8, 0.9, 1.0, a * 0.6), 2.0)
		# a few leaves, tumbling along
		for i in 4:
			var q := fmod(_t * 0.35 + i * 0.25, 1.0)
			var x := 420.0 - q * 680.0
			var y := -30.0 - sin(q * 9.0 + i) * 30.0 - i * 18.0
			if built and x < WALL_X + 40.0:
				y -= (WALL_X + 40.0 - x) * 1.2
			g.draw_circle(o + Vector2(x, y), 2.5, Color(0.75, 0.6, 0.3, 0.7))


## ================================================================ THE MUD BANK
## Red clay by Shivers' hut (it's what holds his hut up). A good BONK knocks
## a lump loose, every second blow, until its MUD_LUMPS are gone (once per save).
class MudBank extends Area2D:
	var _cd := 0.0
	var _wob := 0.0
	var _hits := 0
	var _told := false

	func _ready() -> void:
		collision_layer = 4
		collision_mask = 0
		monitoring = false
		z_index = -1
		var cs := CollisionShape2D.new()
		var c := CircleShape2D.new()
		c.radius = 30.0
		cs.shape = c
		cs.position = Vector2(0, -18)
		add_child(cs)

	func take_hit(_dmg: int, _from_dir: int) -> void:
		if _cd > 0.0:
			return
		_cd = 0.18
		_wob = 0.3
		FX.burst(get_parent(), global_position + Vector2(0, -26), "dust")
		_hits += 1
		if _hits % 2 == 1:
			return                      # every second good BONK knocks a lump loose
		var lumps: int = DATA.MUD_LUMPS
		for i in lumps:
			if not GameState.is_taken("level2", "mud%d" % i):
				Bag.unearth(get_parent(), global_position + Vector2(0, -30), "clay", "level2", "mud%d" % i)
				return
		if not _told:
			_told = true
			var w := Treasure.FloatText.new()
			w.text = "All dug out."
			w.position = global_position + Vector2(-40, -60)
			get_parent().add_child(w)

	func _process(delta: float) -> void:
		_cd = maxf(_cd - delta, 0.0)
		if _wob > 0.0:
			_wob = maxf(_wob - delta, 0.0)
			queue_redraw()

	func _draw() -> void:
		var b := Batch.new()
		var s := 1.0 + sin(_wob * 40.0) * 0.04 * (_wob / 0.3)
		b.ellipse(Vector2(0, -12), 46.0 * s, 24.0 / s, Color("4a2418"))
		b.ellipse(Vector2(0, -14), 42.0 * s, 21.0 / s, Color("a2553a"))
		b.ellipse(Vector2(-10, -22), 16.0, 8.0, Color("b86848"))
		b.ellipse(Vector2(14, -10), 8.0, 4.0, Color("8a3c26"))
		for k in 3:
			b.ellipse(Vector2(-22 + k * 20, -28 + (k % 2) * 6), 3.0, 1.6, Color(1, 0.85, 0.75, 0.45))   # wet glints
		b.draw(self)
