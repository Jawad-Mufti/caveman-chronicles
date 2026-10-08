extends RefCounted
## SIDE MISSIONS (errands): folk along the way with a problem that something
## from the bag can fix. Each one: talk (E), then the MIXING SLAB (Bag.Mixer)
## opens beside the bag; a wrong mix gets a funny hint and costs nothing; the
## right one and Ugu works at it for 2 seconds; then thanks and a reward.
## Kept in GameState.mysteries (the camp menu lists them).
##   PIP   a kid; her baby goat ran up a tall rock from the wolves:  a BONE LADDER
##   TAKA  a hunter who tripped over a snail, foot swollen:          a HEALING SALVE
##   OOMA  an old woman in the Long Dark, her fire blown out:        a SPARK KIT
## (Shivers' windbreak, the first of these, is level2/windbreak.gd.)

const BUILD_TIME := 2.0
const WORDS := ["NONE", "ONE", "TWO", "THREE", "FOUR", "FIVE", "SIX"]
const PIP_AT := Vector2(24700, 600)     ## far side, left of the wolves' beat (24890-25300)
const TAKA_AT := Vector2(14440, 600)    ## the Steppe, between the river and the Dig
const OOMA_AT := Vector2(30060, 600)    ## the Long Dark, on the floor 30000-30250
const BERRY_HINT := "See the GRAPE VINE right here by the river? Its grapes grow back. Pick them when you're NOT hurt, or you'll gobble them up!"
const CLAY_HINT := "Clay? Dig the dirt in the mountain, or BONK Shivers' mud bank, back at the foot of the mountain."


static func build(level: Node) -> Array:
	var out: Array = []
	for e in [Pip.new(), Taka.new(), Ooma.new()]:
		e.level = level
		level.add_child(e)
		out.append(e)
	return out


## ================================================================ AN ERRAND
class Errand extends Node2D:
	var level: Node
	var id := ""
	var who := ""
	var recipe := {}
	var title := "MIX"
	var goal_icon := "wall"
	var stand_x := 60.0             ## where Ugu works from (from the origin)
	var work_face := 1              ## which way he faces while he works
	var beats: Array = []           ## [time, word, offset from the origin, colour]
	var speaking := false
	var done := false
	var build_t := -1.0
	var _t := 0.0
	var _met := false
	var _wrong := 0
	var _said := 0
	var _swing := 0.0

	func _ready() -> void:
		z_index = -1
		_met = GameState.mystery(id) != ""
		done = GameState.mystery(id) == "solved"

	func _process(delta: float) -> void:
		_t += delta
		if build_t >= 0.0:
			_build_step(delta)
		if LevelBase.near_view(self):
			queue_redraw()

	func _draw() -> void:
		var b := Batch.new()
		_paint(b)
		b.draw(self)

	## ------------------------------------------ (each errand fills these in)
	func _paint(_b: Batch) -> void:
		pass

	func intro() -> Array:
		return []

	func nag() -> String:
		return "Back already?"

	func wait_line() -> String:
		return "I'll wait."

	func odd(_item: String) -> String:
		return ""

	func short(_item: String) -> String:
		return ""

	func again() -> Array:
		return ["..."]

	func finish() -> void:
		pass

	## ------------------------------------------ talking
	func meet() -> void:
		if done:
			level._again(again())
			return
		if not _met:
			_met = true
			GameState.open_mystery(id)
			var lines := intro()
			lines.append(_ask())
			level._talk(lines)
			return
		level._talk([[who, nag()], _ask()])

	func _ask() -> Dictionary:
		return {"choose": [
			["Let's do it!", [[who, "YES! Get mixing!", _open_later]]],
			["Not yet.", [[who, wait_line()]]],
		]}

	func _open_later() -> void:
		var d := level.get_tree().get_first_node_in_group("dialogue")
		if d != null and d.has_signal("finished"):
			d.finished.connect(offer, CONNECT_ONE_SHOT)
		else:
			offer.call_deferred()

	## A yes: the job goes in his BAG (a "!" on it); he opens the bag and clicks
	## it to start mixing (Bag.start_job), here with them.
	func offer() -> void:
		if done or build_t >= 0.0:
			return
		Bag.offer_job(who, "FOR %s: %s" % [who, title.replace("MIX: ", "")], goal_icon, open_mixer, func() -> bool:
			return level.player.global_position.distance_to(global_position + Vector2(stand_x, 0)) < 450.0)
		level.hud.say("Open your BAG (I) and click the job to start mixing!", 3.5)

	## ------------------------------------------ the mixing slab
	func open_mixer() -> void:
		var p: CaveMan = level.player
		if p == null or p.dead or Bag.mixer != null:
			return
		var m := Bag.Mixer.new()
		m.title = title
		m.him = p
		m.goal_icon = goal_icon
		m.note = "Click things in your bag to drop them in. What did %s say?" % who.capitalize()
		if _wrong >= 2:
			m.note = "%s: %s" % [who, _recipe_words()]
		m.mixed.connect(func(mix: Dictionary) -> void: _on_mix(m, mix))
		m.closed.connect(func() -> void:
			if build_t < 0.0:
				p.talking = false
				offer())              # not made yet: the job waits in the bag again
		p.talking = true
		level.hud.add_child(m)

	func _recipe_words() -> String:
		var parts: Array = []
		for k in recipe:
			parts.append("%s %s" % [WORDS[int(recipe[k])], Bag.name_of(k)])
		return " + ".join(parts) + "!"

	## What the errand's owner says about a mix: "" if it's right.
	func judge(mix: Dictionary) -> String:
		for k in mix:
			if not recipe.has(k):
				var o := odd(k)
				return o if o != "" else "%s? That's not what we need." % Bag.name_of(k)
		for k in recipe:
			if not mix.has(k):
				var s := short(k)
				return s if s != "" else "We need some %s!" % Bag.name_of(k)
		for k in recipe:
			var have := int(mix[k])
			var want: int = recipe[k]
			if have < want:
				return "Not enough %s! %s, it needs." % [Bag.name_of(k), WORDS[want]]
			if have > want:
				return "Too much %s! Just %s." % [Bag.name_of(k), WORDS[want]]
		return ""

	func _on_mix(m: Bag.Mixer, mix: Dictionary) -> void:
		var hint := judge(mix)
		if hint != "":
			_wrong += 1
			if _wrong == 2:
				hint += "  (" + _recipe_words() + ")"
			m.say("%s: %s" % [who, hint], false)
			return
		var p: CaveMan = level.player
		for k in mix:
			Bag._spend(p, k, int(mix[k]))
		Bag.version += 1
		GameState.save()
		build_t = 0.0
		m.close()
		p.talking = true
		_swing = 0.0
		_said = 0
		var stand := global_position.x + stand_x
		var tw := create_tween()
		tw.tween_property(p, "global_position:x", stand, clampf(absf(p.global_position.x - stand) / 330.0, 0.05, 0.4))
		p.facing = work_face

	func _build_step(delta: float) -> void:
		var p: CaveMan = level.player
		build_t += delta
		_swing -= delta
		if _swing <= 0.0 and build_t < BUILD_TIME - 0.15:
			_swing = 0.34
			p.facing = work_face
			p._start_swing("club")         # (while he's "talking" a swing hits nothing: the work, acted out)
		while _said < beats.size() and build_t >= float(beats[_said][0]):
			var bt: Array = beats[_said]
			var w := CaveMan.WordPop.new()
			w.text = bt[1]
			w.size = 22
			w.color = bt[3]
			w.centered = true
			w.position = global_position + (bt[2] as Vector2) + Vector2(randf_range(-16, 16), -30)
			level.add_child(w)
			FX.burst(level, global_position + (bt[2] as Vector2), "dust" if bt[1] != "SPARK!" and bt[1] != "FWOOSH!" else "embers")
			_said += 1
		if build_t >= BUILD_TIME:
			build_t = -1.0
			p.talking = false
			finish()

	func _solve() -> void:
		done = true
		GameState.solve_mystery(id)

	func _gift(item: String, n: int, from: Vector2) -> void:
		for i in n:
			var f := Bag.Find.new()
			f.id = item
			f.position = global_position + from
			f.vel = Vector2(randf_range(-70, 70), -340.0 - i * 50.0)
			level.add_child(f)

	func _figs(n: int) -> void:
		var room := GameState.fig_max() - GameState.figs
		GameState.figs += mini(n, maxi(room, 0))
		GameState.save()
		level.hud.set_figs(GameState.figs)


## ================================================================ PIP AND BAA
## A kid at the foot of a tall rock; her baby goat ran up it from the wolves
## and won't come down. A BONE LADDER (4 bones + 1 wood) goes up against the
## rock; Ugu climbs it, and Baa hops down into Pip's arms. Baa found shiny
## stones up there: two quartz (enough for a LUCKY CHARM).
class Pip extends Errand:
	const ROCK := Rect2(95, -310, 90, 310)    ## from the origin
	const LADDER_X := 60.0
	var rescued := false
	var _hop := -1.0                          ## >= 0: Baa is jumping down
	var _ladder: Node2D

	func _init() -> void:
		id = "pip"
		who = "PIP"
		recipe = {"bones": 4, "wood": 1}
		title = "MIX: A BONE LADDER"
		goal_icon = "ladder"
		stand_x = 34.0
		position = PIP_AT
		beats = [[0.2, "CLONK!", Vector2(LADDER_X, -40), Color("f3ead2")], [0.6, "CLONK!", Vector2(LADDER_X, -140), Color("f3ead2")],
			[1.1, "TWIST!", Vector2(LADDER_X, -240), Color("8fe07a")], [1.6, "TIE!", Vector2(LADDER_X, -330), Color("8fe07a")]]

	func _ready() -> void:
		super()
		var rock := NightWoods.Crag.new(Rect2(global_position + ROCK.position, ROCK.size))
		level.add_child.call_deferred(rock)
		var st := GameState.mystery(id)
		rescued = st == "solved"
		if st == "built" or st == "solved":
			_put_ladder()

	func _put_ladder() -> void:
		if _ladder != null:
			return
		_ladder = Bag.Ladder.new()
		_ladder.position = global_position + Vector2(LADDER_X, 0)
		level.add_child.call_deferred(_ladder)

	func _goat_at() -> Vector2:
		if rescued and _hop < 0.0:
			return Vector2(-74, -2)
		var top := Vector2(ROCK.position.x + 50.0, ROCK.position.y - 2.0)
		if _hop >= 0.0:
			var q := clampf(_hop / 0.7, 0.0, 1.0)
			return top.lerp(Vector2(-74, -2), q) + Vector2(0, -sin(q * PI) * 120.0)
		return top

	func _process(delta: float) -> void:
		super(delta)
		var p: CaveMan = level.player
		if not rescued and _ladder != null and p != null and not p.dead:
			if p.global_position.distance_to(global_position + _goat_at() + Vector2(0, -20)) < 70.0:
				rescued = true
				_hop = 0.0
				var w := CaveMan.WordPop.new()
				w.text = "MEHHH!"
				w.size = 26
				w.color = Color("fff4d6")
				w.centered = true
				w.position = global_position + _goat_at() + Vector2(0, -50)
				level.add_child(w)
		if _hop >= 0.0:
			_hop += delta
			if _hop >= 0.7:
				_hop = -1.0
				_thanks()

	func meet() -> void:
		if _ladder != null and not rescued:
			level._talk([["PIP", ["Up the ladder! Get Baa!", "Climb! CLIMB! She's right at the top!"][randi() % 2]]])
			return
		super()

	func intro() -> Array:
		return [
			["PIP", "Mister! MISTER! Baa ran up the big rock to get away from the wolves!"],
			["", "Way up on top of the rock, a tiny goat:  \"MEHHH.\""],
			{"choose": [
				["Jump down, goat!", [["PIP", "She won't! She's a BABY! Babies don't jump. They just go... MEHHH."]]],
				["Why up there?", [["PIP", "Goats LOVE going up. Coming down? Not so much."]]],
			]},
			["PIP", "My grandpa makes LADDERS. FOUR bones for the sides and the steps, and ONE stick of wood to tie it all!"],
		]

	func nag() -> String:
		return ["Baa is still up there! Listen: MEHHH.", "Four bones and one wood! I counted on my fingers!", "Hurry, before she eats the whole rock!"][randi() % 3]

	func wait_line() -> String:
		return "Okay... Baa and me will just... MEHHH."

	func odd(item: String) -> String:
		match item:
			"rocks":
				return "Rocks? We want to go UP, not make a pile!"
			"clay":
				return "Clay is sticky. Baa would get stuck AGAIN."
			"berries", "figs", "salve":
				return "Baa eats grass, not snacks. ...Can I have it?"
			"flint", "tips":
				return "Sharp! Baa doesn't need a haircut!"
			"pyrite", "quartz", "obsidian":
				return "Ooh, shiny! But that's not ladder stuff."
		return ""

	func short(item: String) -> String:
		return "No bones? What would you STAND on?" if item == "bones" else "Nothing to tie it! It'll fall apart. ONE stick of wood!"

	func finish() -> void:
		_put_ladder()
		GameState.mysteries[id] = "built"
		GameState.save()
		level._talk([["PIP", "A LADDER! A real one! Go up, go up! Get Baa!"]])

	func _thanks() -> void:
		_solve()
		level._talk([
			["", "Baa leaps off the rock and lands right in Pip's arms.  \"MEHHH!\""],
			["PIP", "BAA! You silly, silly goat! Don't EVER do that again!"],
			["PIP", "Look! She had shiny stones in her mouth. Goats eat EVERYTHING. You keep them!", func() -> void: _gift("quartz", 2, Vector2(-44, -60))],
		])

	func again() -> Array:
		return ["PIP:  \"Baa says MEHHH. That means THANK YOU.\"", "PIP:  \"We're never going near that rock again. Probably.\"",
			"PIP:  \"When I grow up I'm going to build ladders. BIG ones.\""]

	func _paint(b: Batch) -> void:
		var happy := rescued and _hop < 0.0
		# the ladder going up while Ugu builds it (then the real one stands there)
		if build_t >= 0.0:
			var h := 400.0 * clampf(build_t / 1.8, 0.0, 1.0)
			for sx in [-28.0, 28.0]:
				b.line(Vector2(LADDER_X + sx, 0), Vector2(LADDER_X + sx, -h), Color("e9dcbc"), 6.0)
		Folk.draw(b, Vector2(-44, 0), {"skin": Color("c98e5e"), "hair": Color("c0662a"), "hide": Color("9a6a3e"), "k": 0.72, "long": true},
			"happy" if happy else "sad", _t, speaking, 1)
		# Baa, a little white goat kid
		var g := _goat_at()
		var bob := 0.0 if _hop >= 0.0 else absf(sin(_t * 3.0)) * 2.0
		var c := g + Vector2(0, -16 - bob)
		for lx in [-8.0, -3.0, 4.0, 9.0]:
			b.line(c + Vector2(lx, 6), c + Vector2(lx, 16), Color("6b5a48"), 3.0)
		b.ellipse(c, 14.0, 9.0, Color("f2ece0"))
		b.ellipse(c + Vector2(13, -9), 7.0, 6.0, Color("f2ece0"))
		b.tri(c + Vector2(10, -14), c + Vector2(8, -21), c + Vector2(13, -15), Color("c9b89a"))      # little horns
		b.tri(c + Vector2(15, -14), c + Vector2(16, -21), c + Vector2(18, -14), Color("c9b89a"))
		b.circle(c + Vector2(16, -10), 1.6, Color("1a120c"), 6)
		b.ellipse(c + Vector2(7, -9), 4.0, 2.0, Color("e8c8b0"), 0.6)                             # floppy ear
		if not rescued and fmod(_t, 2.6) < 0.8:
			b.ellipse(c + Vector2(20, -6), 2.0, 1.5 + absf(sin(_t * 20.0)), Color("6b3a3a"))       # MEHHH


## ================================================================ TAKA
## A big hunter sitting in the grass, holding his swollen foot ("I tripped
## over a SNAIL"). HEALING SALVE (1 clay + 1 berry), mashed and smeared on;
## up he hops. He gives three flint tips (and a hunter's tip about bats).
class Taka extends Errand:
	var healed := false

	func _init() -> void:
		id = "taka"
		who = "TAKA"
		recipe = {"clay": 1, "berries": 1}
		title = "MIX: A HEALING SALVE"
		goal_icon = "salve"
		stand_x = 62.0
		work_face = -1
		position = TAKA_AT
		beats = [[0.25, "MASH!", Vector2(40, -20), Color("c76aa0")], [0.7, "MASH!", Vector2(40, -20), Color("c76aa0")],
			[1.15, "SQUISH!", Vector2(36, -16), Color("e07a5f")], [1.65, "SLAP!", Vector2(30, -14), Color("ffd36b")]]

	func _ready() -> void:
		super()
		healed = done

	func intro() -> Array:
		return [
			["TAKA", "OW. Ow ow ow. Don't look! A big hunter like me... tripped over a SNAIL."],
			{"choose": [
				["A snail?", [["TAKA", "A very FAST snail. ...Okay. A normal snail. It was just sitting there."]]],
				["Can you walk?", [["TAKA", "Walk? I can't even wiggle my toes. Look. ...See? Nothing."]]],
			]},
			["TAKA", "My mother's healing salve would fix it: ONE clay to hold it on, and ONE berry to make it work. Mash them up!"],
			["TAKA", BERRY_HINT],
			["TAKA", CLAY_HINT],
		]

	func nag() -> String:
		# what he is still missing, first (a hint where to find it); then just grumbling
		var p: CaveMan = level.player
		if p != null and p.berries <= 0:
			return BERRY_HINT
		if Bag.count(p, "clay") <= 0:
			return CLAY_HINT
		return ["Still sitting. Still sore. Still embarrassed.", "The snail came back. It LAUGHED at me.", "One clay, one berry. Please!"][randi() % 3]

	func wait_line() -> String:
		return "I'll be here. Not like I can go anywhere."

	func odd(item: String) -> String:
		match item:
			"rocks":
				return "Rocks? On a SORE FOOT?! NO!"
			"bones":
				return "Bones? I've got bones. In my foot. HURTING."
			"wood":
				return "Wood? I don't want a peg leg!"
			"flint", "tips":
				return "Sharp things! On a sore foot! Are you MAD?"
			"figs":
				return "A fig! ...Yum. But it's the BERRY that heals."
			"pyrite", "quartz", "obsidian":
				return "Pretty. Doesn't heal though."
		return ""

	func short(item: String) -> String:
		return "No clay! Dig mountain dirt, or BONK Shivers' mud bank." if item == "clay" else "No berry! The grape vine right here: pick it when you're NOT hurt."

	func finish() -> void:
		healed = true
		_solve()
		level._talk([
			["TAKA", "Ooh, that's cold. And SMELLY. And... wait. I can WIGGLE! Look! Wiggle wiggle!"],
			["TAKA", "Take my hunting tips. ...Flint tips. Not advice.", func() -> void: _gift("tips", 3, Vector2(0, -60))],
			["TAKA", "Okay, ONE piece of advice: throw them at bats. POP!"],
		])

	func again() -> Array:
		return ["TAKA:  \"Wiggle wiggle. Best foot in the Stone Age.\"", "TAKA:  \"If you see that snail, tell him I'm BACK.\"",
			"TAKA:  \"My mother says thank you. I told her about you. Not about the snail.\""]

	func _paint(b: Batch) -> void:
		var look := {"skin": Color("b5784a"), "hair": Color("2a1f1a"), "hide": Color("6e4a2a"), "k": 1.08, "beard": true}
		if healed:
			Folk.draw(b, Vector2.ZERO, look, "happy", _t, speaking, 1)
			return
		Folk.draw(b, Vector2.ZERO, look, "hurt", _t, speaking, 1)
		# the swollen foot, red and sore, and a smug little snail
		var foot := Vector2(34, -6)
		b.ellipse(foot, 11.0, 8.0, Color("d0705a"))
		b.ellipse(foot + Vector2(-3, -3), 4.0, 2.0, Color(1, 0.8, 0.7, 0.5))
		if fmod(_t, 1.6) < 0.8:
			b.line(foot + Vector2(-6, -14), foot + Vector2(-4, -20), Color("ff6a4a"), 2.0)       # throb lines
			b.line(foot + Vector2(4, -14), foot + Vector2(7, -20), Color("ff6a4a"), 2.0)
		var s := Vector2(78 + sin(_t * 0.3) * 6.0, -4)
		b.ellipse(s + Vector2(-4, 2), 9.0, 3.0, Color("8a7a5a"))
		b.circle(s + Vector2(0, -4), 6.0, Color("9a6a3e"), 12)
		b.circle(s + Vector2(0, -4), 3.0, Color("6e4a2a"), 10)
		b.line(s + Vector2(-10, 0), s + Vector2(-13, -7), Color("8a7a5a"), 1.5)


## ================================================================ OOMA
## An old woman in the Long Dark, by a fire pit the wind blew out; her eyes
## are too old to find her fire stones in the dark. A SPARK KIT (1 flint + 1
## fire-gold): SKRITCH, SKRITCH, SPARK, FWOOSH. Her fire lights the dark
## around her for good. Two roast figs and a piece of obsidian.
class Ooma extends Errand:
	const PIT_X := 56.0
	var lit := false

	func _init() -> void:
		id = "ooma"
		who = "OOMA"
		recipe = {"flint": 1, "pyrite": 1}
		title = "MIX: A SPARK KIT"
		goal_icon = "spark"
		stand_x = 96.0
		work_face = -1
		position = OOMA_AT
		beats = [[0.3, "SKRITCH!", Vector2(PIT_X, -20), Color("dfeaf2")], [0.8, "SKRITCH!", Vector2(PIT_X, -20), Color("dfeaf2")],
			[1.3, "SPARK!", Vector2(PIT_X, -24), Color("ffd36b")], [1.75, "FWOOSH!", Vector2(PIT_X, -40), Color("ff8a3a")]]

	func _ready() -> void:
		super()
		lit = done
		add_to_group("light")
		add_to_group("glow")

	func light() -> Vector4:
		if not lit:
			return Vector4.ZERO
		return Vector4(global_position.x + PIT_X, global_position.y - 30.0, 260.0, 1.0)

	func light_strength() -> float:
		return 1.0 if lit else 0.0

	func draw_glow(g) -> void:   # g: the glow layer's Batch
		if lit:
			g.draw_circle(global_position + Vector2(PIT_X, -20), 34.0, Color(1.0, 0.6, 0.25, 0.35))
		elif build_t >= 0.0:
			g.draw_circle(global_position + Vector2(PIT_X, -10), 10.0 + randf() * 8.0, Color(1.0, 0.9, 0.5, 0.5))

	func intro() -> Array:
		return [
			["OOMA", "Who's there? If you're a wolf, go away. If you're NOT a wolf... hello, dearie!"],
			{"choose": [
				["Not a wolf.", [["OOMA", "Oh, good. Wolves never bring me anything."]]],
				["Woof?", [["OOMA", "...Very funny. I've got a stick, you know."]]],
			]},
			["OOMA", "The wind blew out my fire, and my old eyes can't find my fire stones in this dark."],
			["OOMA", "Grey FLINT and shiny FIRE-GOLD. Strike them together: SPARKS! Then my fire will catch."],
		]

	func nag() -> String:
		return ["Still dark, dearie. Still cold.", "Flint and fire-gold! One of each!", "I can hear you breathing. Is that you? Good."][randi() % 3]

	func wait_line() -> String:
		return "I'll sit here in the dark. Like a mushroom."

	func odd(item: String) -> String:
		match item:
			"wood":
				return "Wood I have! It's the SPARK I need."
			"clay":
				return "Clay doesn't spark, dearie. It goes SPLAT."
			"rocks":
				return "Plain rocks? CLONK. No sparks."
			"bones":
				return "Bones? Dearie, I'm old. I'm not a dog."
			"quartz", "obsidian":
				return "Ooh, lovely. But it won't spark."
			"berries", "figs", "salve":
				return "Snacks later! Sparks first!"
		return ""

	func short(item: String) -> String:
		return "Fire-gold alone won't spark. It needs FLINT to hit it!" if item == "flint" else "Flint on its own? A tiny spark. FIRE-GOLD makes the big ones!"

	func finish() -> void:
		lit = true
		_solve()
		level._talk([
			["OOMA", "Oh! OH! Light! And there you are. ...You're much hairier than I thought."],
			["OOMA", "Warm figs, roasted in MY fire. And this black glass I found when I could still see.", func() -> void:
				_figs(2)
				_gift("obsidian", 1, Vector2(0, -70))],
		])

	func again() -> Array:
		return ["OOMA:  \"Sit, dearie. Warm your toes.\"", "OOMA:  \"I can see my feet again! They're older than I remembered.\"",
			"OOMA:  \"If a wolf comes, I'll show him the fire. And my stick.\""]

	func _paint(b: Batch) -> void:
		var f := Vector2(PIT_X, 0)
		for k in 6:
			b.ellipse(f + Vector2(-20 + k * 8, -3), 5.0, 4.0, Color("5a524c"))
		b.line(f + Vector2(-14, -4), f + Vector2(14, -10), Color("3a2616"), 5.0)
		b.line(f + Vector2(-14, -10), f + Vector2(14, -4), Color("4a3220"), 5.0)
		if lit:
			var h := 40.0 + sin(_t * 13.0) * 3.0 + sin(_t * 7.3) * 2.0
			b.tri(f + Vector2(-13, -6), f + Vector2(sin(_t * 4.0) * 3.0, -6 - h), f + Vector2(13, -6), Pal.FLAME)
			b.tri(f + Vector2(-7, -6), f + Vector2(0, -6 - h * 0.6), f + Vector2(7, -6), Pal.FLAME_CORE)
		else:
			b.circle(f + Vector2(-2, -8), 3.0, Color("6b625c"), 8)          # cold ash
			for k in 2:
				var q := fmod(_t * 0.4 + k * 0.5, 1.0)
				b.circle(f + Vector2(sin(q * 6.0 + k) * 6.0, -14.0 - q * 40.0), 3.0 + q * 3.0, Color(0.6, 0.6, 0.65, 0.35 * (1.0 - q)), 8)
		Folk.draw(b, Vector2.ZERO, {"skin": Color("c39a7a"), "hair": Color("d8d4cc"), "hide": Color("7a5a8a"), "k": 0.9, "long": true, "bun": true},
			"happy" if lit else "sad", _t, speaking, 1)


## ================================================================ FOLK
## A stranger, code-drawn like everything else: standing (or, "hurt", sitting
## in the grass), feet at `at`, facing `face`. look: skin, hair, hide, k
## (size), beard, long (hair), bun. mood: "sad" (arms in, brows up), "happy"
## (an arm waving, a grin), "hurt" (sitting, holding a foot, wincing).
class Folk extends RefCounted:
	static func draw(b: Batch, at: Vector2, look: Dictionary, mood: String, t: float, speaking: bool, face: int) -> void:
		var k: float = look.get("k", 1.0)
		var skin: Color = look["skin"]
		var hair: Color = look["hair"]
		var hide: Color = look["hide"]
		var f := float(face)
		var bob := sin(t * 2.2) * 1.2
		if mood == "hurt":
			# sitting: legs out toward the foot, leaning over it
			b.line(at + Vector2(-6, -8) * k, at + Vector2(30 * f, -6) * k, skin.darkened(0.12), 9.0 * k)
			b.ellipse(at + Vector2(-2, -32) * k, 17.0 * k, 22.0 * k, skin)
			b.quad(at + Vector2(-17, -40) * k, at + Vector2(15, -46) * k, at + Vector2(19, -12) * k, at + Vector2(-19, -10) * k, hide)
			b.line(at + Vector2(8 * f, -40) * k, at + Vector2(30 * f, -14) * k, skin, 7.0 * k)       # a hand on the sore foot
			_head(b, at + Vector2(10 * f, -66) * k, k, skin, hair, look, "hurt", t, speaking, f)
			return
		var wave := sin(t * 9.0) * 0.5 if mood == "happy" else 0.0
		# legs
		b.line(at + Vector2(-6, -30) * k, at + Vector2(-8, 0) * k, skin.darkened(0.15), 8.0 * k)
		b.line(at + Vector2(6, -30) * k, at + Vector2(8, 0) * k, skin.darkened(0.15), 8.0 * k)
		b.ellipse(at + Vector2(-8 + 3 * f, 0) * k, 7.0 * k, 3.0 * k, Color("4a3426"))
		b.ellipse(at + Vector2(8 + 3 * f, 0) * k, 7.0 * k, 3.0 * k, Color("4a3426"))
		# the body and the hide
		var c := at + Vector2(0, -50 + bob) * k
		b.ellipse(c, 17.0 * k, 24.0 * k, skin)
		b.quad(c + Vector2(-17, -10) * k, c + Vector2(15, -16) * k, c + Vector2(18, 22) * k, c + Vector2(-18, 24) * k, hide)
		b.tri(c + Vector2(-18, 24) * k, c + Vector2(-8, 24) * k, c + Vector2(-14, 32) * k, hide.darkened(0.15))
		b.tri(c + Vector2(4, 23) * k, c + Vector2(14, 22) * k, c + Vector2(9, 30) * k, hide.darkened(0.15))
		# arms
		if mood == "happy":
			var up := c + Vector2(18 * f, -16) * k
			b.line(c + Vector2(10 * f, -14) * k, up + Vector2.from_angle(-PI * 0.5 + wave * f) * 20.0 * k, skin, 7.0 * k)
			b.line(c + Vector2(-10 * f, -12) * k, c + Vector2(-16 * f, 10) * k, skin, 7.0 * k)
		else:
			b.line(c + Vector2(-10, -12) * k, c + Vector2(-12, 12) * k, skin.darkened(0.06), 7.0 * k)
			b.line(c + Vector2(10, -12) * k, c + Vector2(12, 12) * k, skin, 7.0 * k)
		_head(b, c + Vector2(2 * f, -38) * k, k, skin, hair, look, mood, t, speaking, f)


	static func _head(b: Batch, h: Vector2, k: float, skin: Color, hair: Color, look: Dictionary, mood: String, t: float, speaking: bool, f: float) -> void:
		if look.get("long", false):
			b.ellipse(h + Vector2(-6 * f, 10) * k, 15.0 * k, 20.0 * k, hair)         # hair down the back
		b.circle(h, 15.0 * k, skin, 18)
		# hair on top: shaggy spikes (a bun for Ooma)
		for i in 6:
			var a := PI + 0.25 + i * 0.5
			var tip := h + Vector2.from_angle(a) * (20.0 + (i % 2) * 3.0) * k
			b.tri(h + Vector2.from_angle(a - 0.32) * 12.0 * k, tip, h + Vector2.from_angle(a + 0.32) * 12.0 * k, hair)
		if look.get("bun", false):
			b.circle(h + Vector2(-4 * f, -18) * k, 7.0 * k, hair, 12)
			b.line(h + Vector2(-12 * f, -22) * k, h + Vector2(4 * f, -14) * k, Color("e9dcbc"), 2.0 * k)    # a bone pin
		if look.get("beard", false):
			b.ellipse(h + Vector2(4 * f, 11) * k, 11.0 * k, 8.0 * k, hair)
		# brows and eyes
		var ink := Color("1a120c")
		for s in [-1.0, 1.0]:
			var e := h + Vector2((5.0 + s * 5.0) * f, -2) * k
			if mood == "happy":
				b.line(e + Vector2(-3, 1) * k, e + Vector2(0, -1.5) * k, ink, 2.0 * k)
				b.line(e + Vector2(0, -1.5) * k, e + Vector2(3, 1) * k, ink, 2.0 * k)
			elif mood == "hurt":
				b.line(e + Vector2(-3, -1) * k, e + Vector2(3, 1) * k, ink, 2.0 * k)        # squeezed shut
			else:
				b.circle(e, 2.4 * k, Color.WHITE, 8)
				b.circle(e + Vector2(0.6 * f, 0.4) * k, 1.4 * k, ink, 6)
			var inner: float = -s * f                       # sad brows tilt up in the middle
			var lift := 2.0 if mood == "sad" else 0.0
			b.line(e + Vector2(-4, -5 - lift * (1.0 if inner > 0 else 0.0)) * k, e + Vector2(4, -5 - lift * (1.0 if inner < 0 else 0.0)) * k, hair.darkened(0.3), 2.0 * k)
		# nose and mouth
		b.ellipse(h + Vector2(13 * f, 2) * k, 4.5 * k, 3.8 * k, skin.darkened(0.12))
		var m := h + Vector2(8 * f, 9) * k
		if speaking:
			b.ellipse(m, 3.2 * k, (1.5 + (0.5 + 0.5 * sin(t * 18.0)) * 2.5) * k, Color("3a1a12"))
		elif mood == "happy":
			b.line(m + Vector2(-4, -1) * k, m + Vector2(0, 2) * k, Color("3a1a12"), 2.0 * k)
			b.line(m + Vector2(0, 2) * k, m + Vector2(4, -1) * k, Color("3a1a12"), 2.0 * k)
			b.circle(h + Vector2(3 * f, 5) * k, 3.0 * k, Color(0.95, 0.5, 0.45, 0.45), 8)
		else:
			b.line(m + Vector2(-4, 1.5) * k, m + Vector2(0, -0.5) * k, Color("3a1a12"), 2.0 * k)
			b.line(m + Vector2(0, -0.5) * k, m + Vector2(4, 1.5) * k, Color("3a1a12"), 2.0 * k)
