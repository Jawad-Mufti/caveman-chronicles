class_name Bag
extends RefCounted
## UGU'S BAG, Terraria-style: everything he carries, sorted into small boxes
## down the right side of the screen. Hover one: its name, what it is, what
## it's FOR and where to find more. Click the bag (or I / B): the big view,
## every box, by kind, and the CRAFTING list; again: hidden; again: back.
##
## STONES are buried in the rock, a fixed number in each level, hidden where
## their kind belongs (level2_data MT_STONES): clay and flint are common,
## fire-gold and quartz rarer, obsidian very rare. Dig them out (each only once
## per save). Stones and what he makes from them are kept (GameState.bag, saved).
##
## RECIPES turn them into things that DO something: flint tips to throw, a
## salve that heals, a stone wall that holds back big beasts, a ladder, a spark
## kit that lights the torch, and two for good: the obsidian edge (+1 damage on
## every swing) and the lucky charm (hidden stones glint in the rock). Things that are
## used go in the hotbar by themselves; HIT uses them.

static var version := 0          ## bumped on every change: what's drawn redraws only then
static var mode := 1             ## 0 hidden, 1 the strip, 2 the big view (kept between levels)
static var mixer: Mixer = null   ## the mixing slab, while one is out (bag clicks go into it)
static var holding := false      ## the bag paused the world (and will let it go)


## While the big view or a mixing slab is open the world WAITS: thinking out a
## mix with Old One-Eye about is no time to be bitten. A pause someone else
## made (the camp menu, the guide) is theirs, left alone.
static func hold_world(tree: SceneTree) -> void:
	var want := mode == 2 or (mixer != null and is_instance_valid(mixer))
	if want and not holding and not tree.paused:
		holding = true
		tree.paused = true
	elif not want and holding:
		holding = false
		tree.paused = false
## A MIX someone is waiting for (an errand he said yes to): the bag's button
## shows a "!", the big view a banner; clicking it opens the mixing slab. Empty:
## none. {who, title, icon, start: Callable, near: Callable -> bool}
static var job := {}


static func offer_job(who: String, title: String, icon: String, start: Callable, near: Callable) -> void:
	job = {"who": who, "title": title, "icon": icon, "start": start, "near": near}
	version += 1


static func clear_job() -> void:
	job = {}
	version += 1


static func job_near() -> bool:
	return not job.is_empty() and (job["near"] as Callable).call()


## The banner clicked: out comes the mixing slab (if he is close enough).
static func start_job() -> bool:
	if job.is_empty() or not job_near():
		return false
	var start: Callable = job["start"]
	job = {}
	version += 1
	mode = 1                        # the strip stays out to pick from; the big view steps aside
	start.call()
	return true

const CATS := ["GEAR", "STONES", "BUILD", "FOOD", "TREASURE"]
const RARITY := ["COMMON", "UNCOMMON", "RARE", "VERY RARE", "LEGENDARY"]
const RARITY_COL := [Color("e9dcbc"), Color("8fe07a"), Color("6cc4ff"), Color("d08bff"), Color("ffb02e")]

## id -> [name, category, rarity, what it is, what it's for, where to find it]
const ITEMS := {
	"hands": ["FISTS", "GEAR", 0, "Bare hands. Better than nothing!", "HIT punches. Find a good stick!", "Always with you."],
	"club": ["CLUB", "GEAR", 0, "A good heavy stick. BONK!", "HIT swings it. Hold HIT to keep swinging.", "The first stick, in Level 1."],
	"axe": ["FLINT AXE", "GEAR", 2, "A sharp stone tied to a strong handle.", "HIT swings; the 4th hit CLEAVES. Hold J to throw it.", "The Toolmaker."],
	"hammer": ["FIRESTONE HAMMER", "GEAR", 4, "Heavy, hot, and very hard to stop.", "HIT smashes beasts and rock.", "Forged from the Firestone."],
	"shovel": ["SHOVEL", "GEAR", 2, "A flat bone on a stick. Dirt is scared of it.", "Hold it in the hotbar: HIT digs where you aim. Digging finds STONES!", "Found in the Dig."],
	"torch": ["TORCH", "GEAR", 0, "Fire on a stick. Wolves keep away from it.", "It burns down. Sit by a fire, or use a SPARK KIT.", "The first fire."],
	"tips": ["FLINT TIPS", "GEAR", 0, "Sharp flint on a bone. Flies fast, bites hard.", "Hold them in the hotbar: HIT throws one. Twice a rock's hit!", "Make them: CRAFT."],
	"spark": ["SPARK KIT", "GEAR", 1, "Flint and fire-gold. Strike them: SPARKS!", "HIT: the torch burns bright and full again.", "Make it: CRAFT."],
	"edge": ["OBSIDIAN EDGE", "GEAR", 3, "Black glass, sharper than any tooth.", "Always on: every swing does +1 damage.", "Make it: CRAFT."],
	"charm": ["LUCKY CHARM", "GEAR", 2, "Quartz on a cord. Stones like it.", "Always on: stones hidden in the rock glint, so you know where to dig.", "Make it: CRAFT."],
	"trap": ["GLARE TRAP", "GEAR", 2, "A clay pot: a sweet berry inside, quartz all round, fire-gold to strike the spark.", "HIT: set it down in Old One-Eye's hall. It can't resist the smell... FLASH! Its eye is blinded: hit it!", "Work out how to mix it: the job in your bag, once you have met Old One-Eye."],
	"rocks": ["ROCKS", "STONES", 0, "Round and heavy. Just right for throwing.", "Hold them in the hotbar: HIT throws one. Three make a STONE WALL.", "Lying about everywhere."],
	"flint": ["FLINT", "STONES", 0, "A grey stone that breaks into sharp edges.", "Tips, the spark kit, the obsidian edge.", "Common: rock and striped stone chip it off as you dig, every visit."],
	"clay": ["CLAY", "STONES", 0, "Sticky red mud. It holds things together.", "Walls and healing salve.", "Common: it comes up as you dig dirt, every visit. The clay pit is full of it."],
	"pyrite": ["FIRE-GOLD", "STONES", 1, "Shiny like gold, but it isn't. Hit it with flint: SPARKS!", "The spark kit.", "Dig deep rock and striped stone."],
	"quartz": ["QUARTZ", "STONES", 2, "Clear as ice. It catches the light.", "The lucky charm.", "Dig hard grey stone."],
	"obsidian": ["OBSIDIAN", "STONES", 3, "Black glass, from deep under the fire mountain.", "The obsidian edge.", "Very rare. Dig deep into hard stone."],
	"wood": ["WOOD", "BUILD", 0, "Dry dead wood, tied in a bundle.", "Two make a fire. One makes a ladder.", "Hit dead trees."],
	"bones": ["BONES", "BUILD", 0, "Old bones. Strong and light.", "The shelter, flint tips, ladders, the obsidian edge.", "Beasts and old bone piles, every visit."],
	"wall": ["STONE WALL", "BUILD", 0, "Rocks stuck together with clay. Big beasts can't get past.", "HIT: a wall goes up in front of you. It crumbles after 30 seconds.", "Make it: CRAFT."],
	"ladder": ["BONE LADDER", "BUILD", 0, "Bones tied up with wood. Up we go!", "HIT: a ladder stands where you are. Jump up the rungs.", "Make it: CRAFT."],
	"berries": ["BERRIES", "FOOD", 0, "Sweet and juicy.", "Eaten by themselves when you're hurt. Also: healing salve.", "Bushes and vines."],
	"figs": ["ROAST FIGS", "FOOD", 0, "Warm from the fire. Yum.", "H (or HIT in the hotbar): two hearts back.", "Roast them by a fire."],
	"salve": ["HEALING SALVE", "FOOD", 0, "Berries mashed in clay. Smells awful, works great.", "HIT: three hearts back.", "Make it: CRAFT."],
	"shells": ["SHELLS", "TREASURE", 0, "Money! Conches and amber count big.", "Upgrades from the trader and the Toolmaker.", "Everywhere: paths, secret spots, smashed logs."],
	"orbs": ["SPIRIT ORBS", "TREASURE", 1, "The light of the beasts you beat.", "Saved up for upgrades.", "Beat beasts. They come back each visit."],
}

## Things HIT uses from the hotbar (they join it when he has some).
const HOTBAR := ["tips", "salve", "wall", "ladder", "spark", "trap"]
## Made once, kept for good: id -> GameState item
const FOREVER := {"edge": "obsidian_edge", "charm": "lucky_charm"}

## [makes, how many, needs {id: n}]
const RECIPES := [
	["tips", 3, {"flint": 1, "bones": 1}],
	["salve", 1, {"clay": 1, "berries": 1}],
	["wall", 1, {"rocks": 3, "clay": 1}],
	["ladder", 1, {"bones": 4, "wood": 1}],
	["spark", 1, {"flint": 1, "pyrite": 1}],
	["edge", 1, {"obsidian": 2, "flint": 1, "bones": 2}],
	["charm", 1, {"quartz": 2, "bones": 1}],
]



## ------------------------------------------------------------ WHAT HE HAS
static func info(id: String) -> Array:
	if id.begins_with("relic:"):
		var k := id.substr(6)
		var r: Array = Relics.KINDS.get(k, [k.to_upper(), "", Color.WHITE])
		var very := k == "thunder_egg" or k == "golden_horn"
		return [r[0], "TREASURE", 4 if very else 3, r[1], "Kept safe for the shelter.", "Out at the edges of the world."]
	return ITEMS.get(id, [id.to_upper(), "GEAR", 0, "", "", ""])


static func name_of(id: String) -> String:
	return info(id)[0]


static func rarity_col(id: String) -> Color:
	return RARITY_COL[int(info(id)[2])]


## How many he has (p may be null: then only what is kept for good).
static func count(p: CaveMan, id: String) -> int:
	GameState.ensure_loaded()
	if id.begins_with("relic:"):
		return int(GameState.relics.get(id.substr(6), 0))
	match id:
		"hands":
			return 1 if p != null and not p.has_stick else 0
		"club":
			return 1 if p != null and p.has_stick else 0
		"axe", "hammer":
			return 1 if GameState.weapons.has(id) else 0
		"shovel":
			return 1 if GameState.has_item("shovel") else 0
		"torch":
			return 1 if p != null and p.has_torch else 0
		"rocks":
			return p.rocks if p != null else 0
		"wood":
			return p.wood if p != null else 0
		"berries":
			return p.berries if p != null else 0
		"figs":
			return GameState.figs
		"bones":
			return GameState.bones
		"shells":
			return GameState.shells
		"orbs":
			return GameState.orbs
	if FOREVER.has(id):
		return 1 if GameState.has_item(FOREVER[id]) else 0
	return int(GameState.bag.get(id, 0))


## One of a kind: no number on its box.
static func unique(id: String) -> bool:
	return id in ["hands", "club", "axe", "hammer", "shovel", "torch"] or FOREVER.has(id)


## Everything he has, sorted: by kind, then the table's order. `cat` "" = all.
static func listing(p: CaveMan, cat: String = "") -> Array:
	var out: Array = []
	for c in CATS:
		if cat != "" and cat != c:
			continue
		for id in ITEMS:
			if ITEMS[id][1] == c and count(p, id) > 0:
				out.append(id)
		if c == "TREASURE":
			for k in Relics.KINDS:
				if count(p, "relic:" + k) > 0:
					out.append("relic:" + k)
	return out


static func add(id: String, n: int = 1) -> void:
	GameState.bag[id] = int(GameState.bag.get(id, 0)) + n
	version += 1
	GameState.save()


## Which recipes an item goes into (for its tooltip).
static func goes_into(id: String) -> Array:
	var out: Array = []
	for r in RECIPES:
		if (r[2] as Dictionary).has(id) and recipe_open(r[0]):
			out.append(name_of(r[0]))
	return out


## ------------------------------------------------------------ CRAFTING
## Some recipes are secrets until something shows them to him: the GLARE TRAP,
## once he has met Old One-Eye (level2/one_eye.gd).
static func recipe_open(id: String) -> bool:
	return id != "trap" or GameState.mystery("one_eye") != ""


## The recipes he knows, in order.
static func known_recipes() -> Array:
	return RECIPES.filter(func(r: Array) -> bool: return recipe_open(r[0]))


static func recipe(id: String) -> Array:
	for r in RECIPES:
		if r[0] == id:
			return r
	return []


## "" if it can be made now, else what is missing ("2 more CLAY").
static func missing(p: CaveMan, id: String) -> String:
	if FOREVER.has(id) and count(p, id) > 0:
		return "You have it already."
	if not recipe_open(id):
		return "You don't know how to make that yet."
	var r := recipe(id)
	var short: Array = []
	for need in r[2]:
		var lack: int = int(r[2][need]) - count(p, need)
		if lack > 0:
			short.append("%d more %s" % [lack, name_of(need)])
	return "" if short.is_empty() else "Need " + ", ".join(short)


static func craft(p: CaveMan, id: String) -> bool:
	var r := recipe(id)
	if r.is_empty() or p == null or missing(p, id) != "":
		return false
	for need in r[2]:
		_spend(p, need, int(r[2][need]))
	if FOREVER.has(id):
		GameState.give_item(FOREVER[id])
		if id == "edge":
			p.club_bonus += 1
	else:
		GameState.bag[id] = int(GameState.bag.get(id, 0)) + int(r[1])
	version += 1
	GameState.save()
	p._say_word("%s!" % name_of(id), RARITY_COL[int(info(id)[2])])
	FX.burst(p.get_parent(), p.global_position + Vector2(0, -60), "embers")
	return true


static func _spend(p: CaveMan, id: String, n: int) -> void:
	match id:
		"rocks":
			p.rocks -= n
			p.rocks_changed.emit(p.rocks)
		"wood":
			p.wood -= n
			p.wood_changed.emit(p.wood)
		"berries":
			p.berries -= n
			p.berries_changed.emit(p.berries)
		"bones":
			GameState.bones -= n
			var h := p.get_tree().get_first_node_in_group("hud") as Hud
			if h != null:
				h.set_bones(GameState.bones)
		_:
			GameState.bag[id] = int(GameState.bag.get(id, 0)) - n
	version += 1


## ------------------------------------------------------------ USING THINGS
## HIT with one of the HOTBAR things in hand. True if it was used.
static func use(p: CaveMan, id: String) -> bool:
	if p.dead or count(p, id) <= 0:
		return false
	var ok := false
	match id:
		"tips":
			ok = _throw_tip(p)
		"salve":
			if p.hp >= p.max_hp:
				p.said.emit("He isn't hurt. Keep the salve.")
			else:
				p.hp = mini(p.hp + 3, p.max_hp)
				p.hp_changed.emit(p.hp)
				var pop := CaveMan.HeartPop.new()
				pop.position = p.global_position + Vector2(0, -120)
				p.get_parent().add_child(pop)
				ok = true
		"wall":
			ok = _place_wall(p)
		"ladder":
			ok = _place_ladder(p)
		"spark":
			if not p.has_torch:
				p.said.emit("No torch to light.")
			elif p.torch_fuel >= 0.98:
				p.said.emit("The torch is burning fine.")
			else:
				p.torch_fuel = 1.0
				p._say_word("SPARK!", Color("ffd36b"))
				FX.burst(p.get_parent(), p.global_position + Vector2(18 * p.facing, -60), "embers")
				ok = true
		"trap":
			var fy := _floor(p, p.global_position.x + 40.0 * p.facing, p.global_position.y - 30.0)
			if fy == INF or fy - p.global_position.y > 90.0:          # (ground right under him: on bumpy rock is_on_floor flickers)
				p.said.emit("Set the trap down on the ground.")
			else:
				var tr := GlareTrap.new()
				tr.position = Vector2(p.global_position.x + 40.0 * p.facing, fy)
				p.get_parent().add_child(tr)
				p._say_word("TRAP SET!", Color("ffd36b"))
				ok = true
	if ok:
		GameState.bag[id] = int(GameState.bag.get(id, 0)) - 1
		version += 1
		GameState.save()
		if count(p, id) <= 0:
			p.tool = "weapon"            # used the last one: back to the weapon
	return ok


static func _throw_tip(p: CaveMan) -> bool:
	if p.throwing > 0.0:
		return false
	p.throwing = 0.22
	var r := World.ThrownRock.new()
	r.flint = true
	r.dmg = 6
	var a := p.aim()
	r.position = p.global_position + Vector2(20.0 * p.facing, -44) + a * 8.0
	r.thrower = p
	r.vel = Vector2(CaveMan.THROW_SPEED * 1.35 * p.facing, -60.0) if a.y == 0.0 else a * CaveMan.THROW_SPEED * 1.4
	p.get_parent().add_child(r)
	return true


## The floor under x, looking down from y (INF: none near).
static func _floor(p: CaveMan, x: float, y: float) -> float:
	var q := PhysicsRayQueryParameters2D.create(Vector2(x, y), Vector2(x, y + 260.0), 1)
	var hit := p.get_world_2d().direct_space_state.intersect_ray(q)
	return INF if hit.is_empty() else float((hit["position"] as Vector2).y)


static func _place_wall(p: CaveMan) -> bool:
	var x := p.global_position.x + 54.0 * p.facing
	var fy := _floor(p, x, p.global_position.y - 30.0)
	if fy == INF:
		p.said.emit("The wall needs ground to stand on.")
		return false
	# room for it? (not inside rock, not on top of another wall)
	var s := RectangleShape2D.new()
	s.size = StoneWall.SIZE - Vector2(4, 8)
	var q := PhysicsShapeQueryParameters2D.new()
	q.shape = s
	q.transform = Transform2D(0.0, Vector2(x, fy - StoneWall.SIZE.y * 0.5 - 2.0))
	q.collision_mask = 1
	if not p.get_world_2d().direct_space_state.intersect_shape(q, 1).is_empty():
		p.said.emit("No room for a wall there.")
		return false
	var w := StoneWall.new()
	w.position = Vector2(x, fy)
	p.get_parent().add_child(w)
	return true


static func _place_ladder(p: CaveMan) -> bool:
	var x := p.global_position.x + 6.0 * p.facing
	var fy := _floor(p, x, p.global_position.y - 30.0)
	if fy == INF or not p.is_on_floor():
		p.said.emit("Stand on the ground to put up a ladder.")
		return false
	var l := Ladder.new()
	l.position = Vector2(x, fy)
	p.get_parent().add_child(l)
	return true


## ------------------------------------------------------------ DIGGING FINDS
## A stone buried in the rock (a level's MT_STONES / DIG_STONES, ids by place)
## has been dug free: out it pops and flies to him. Each one only once per save.
static func unearth(parent: Node, at: Vector2, id: String, level_id: String, tid: String) -> void:
	if parent == null or GameState.is_taken(level_id, tid):
		return
	GameState.take(level_id, tid, 0)          # (worth no shells: it is not money)
	pop(parent, at, id)


## COMMON stones are easy (docs/inventory_plan.md, R2): as he digs, a broken
## block now and then hands one out, every visit, never "taken once". By the
## stuff dug: [id, chance per broken block]. (Map letters: d dirt, # rock,
## = striped strata; the Dig's blocks by name.) Precious stones (fire-gold,
## quartz, obsidian) are never dropped like this: a fixed few, hidden.
const DIG_DROPS := {"d": ["clay", 1.0 / 6.0], "#": ["flint", 1.0 / 8.0], "=": ["flint", 1.0 / 6.0],
	"dirt": ["clay", 1.0 / 6.0], "clay": ["clay", 0.5], "stone": ["flint", 1.0 / 8.0]}


## A broken block of `what`: maybe a common stone pops out of it.
static var drop_chance := 1.0     ## scales every DIG_DROPS chance (tuning; tests use 0 or 100)


static func dig_drop(parent: Node, at: Vector2, what: String) -> void:
	if not DIG_DROPS.has(what) or parent == null:
		return
	var d: Array = DIG_DROPS[what]
	if randf() < float(d[1]) * drop_chance:
		pop(parent, at, d[0])


## A stone out of the ground, straight into the bag (not remembered: there
## are always more where it came from).
static func pop(parent: Node, at: Vector2, id: String) -> void:
	var f := Find.new()
	f.id = id
	f.position = at
	f.vel = Vector2(randf_range(-90, 90), -380)
	parent.add_child.call_deferred(f)


## A stone popped out of the rock: up, then straight into his bag.
class Find extends Node2D:
	var id := "flint"
	var vel := Vector2.ZERO
	var t := 0.0

	func _ready() -> void:
		z_index = 6
		add_to_group("glow")

	func _process(delta: float) -> void:
		t += delta
		var him := get_tree().get_first_node_in_group("player") as CaveMan
		if t < 0.4 or him == null:
			vel.y += 1300.0 * delta
		else:
			var want := (him.global_position + Vector2(0, -40) - global_position).normalized() * (420.0 + 1500.0 * (t - 0.4))
			vel = vel.lerp(want, minf(1.0, delta * 8.0))
		global_position += vel * delta
		if him == null and t > 1.0 or him != null and t > 0.4 and global_position.distance_to(him.global_position + Vector2(0, -40)) < 26.0 or t > 3.0:
			_land(him)
			return
		queue_redraw()

	func _land(him: CaveMan) -> void:
		var first := not GameState.bag.has(id)
		Bag.add(id)
		var rare := int(Bag.info(id)[2]) >= 2
		var w := CaveMan.WordPop.new()
		w.text = ("NEW! " if first else "+1 ") + Bag.name_of(id)
		w.size = 24 if rare or first else 16
		w.color = Bag.rarity_col(id)
		w.centered = true
		w.tilt = 0.0
		w.life = 1.3 if rare or first else 0.7
		if rare:
			w.star = Color(0.1, 0.05, 0.2, 0.7)
		w.position = global_position + Vector2(0, -30)
		get_parent().add_child(w)
		var burst := Treasure.CollectPop.new()
		burst.tint = Bag.rarity_col(id)
		burst.position = global_position
		get_parent().add_child(burst)
		if first and him != null:
			him.said.emit("%s: %s Hover it in your bag to see what it's for." % [Bag.name_of(id), Bag.info(id)[3]])
		queue_free()

	func _draw() -> void:
		Bag.draw_icon(self, id, Vector2.ZERO, 0.7, t)

	func draw_glow(g) -> void:   # g: the glow layer's Batch
		g.draw_circle(global_position, 16.0, Color(Bag.rarity_col(id), 0.45))


## ------------------------------------------------------------ BUILT THINGS
## A wall of rocks and clay: solid to everything, beasts and him alike. It
## stands 30 seconds, shakes for the last three, and crumbles.
class StoneWall extends StaticBody2D:
	const SIZE := Vector2(44, 124)
	const LIFE := 30.0
	var t := 0.0
	var _shown := -1

	func _ready() -> void:
		collision_layer = 1
		collision_mask = 0
		add_to_group("unsafe_ground")
		var cs := CollisionShape2D.new()
		var s := RectangleShape2D.new()
		s.size = SIZE
		cs.shape = s
		cs.position = Vector2(0, -SIZE.y * 0.5)
		add_child(cs)
		FX.burst(get_parent(), position + Vector2(0, -20), "dust")

	func _process(delta: float) -> void:
		t += delta
		if t >= LIFE:
			for i in 4:
				FX.shards(get_parent(), position + Vector2(0, -20.0 - i * 28.0), Vector2(randf_range(-1, 1), -1), true)
			FX.burst(get_parent(), position + Vector2(0, -40), "dust")
			queue_free()
			return
		# it rises out of the ground, then only redraws while it shakes
		var k := int(minf(t / 0.25, 1.0) * 10.0) if t < 0.3 else (int(t * 20.0) if t > LIFE - 3.0 else 10)
		if k != _shown and LevelBase.near_view(self):
			_shown = k
			queue_redraw()

	func _draw() -> void:
		var b := Batch.new()
		var rise := minf(t / 0.25, 1.0)
		var shake := sin(t * 60.0) * 2.0 if t > LIFE - 3.0 else 0.0
		var h := SIZE.y * rise
		var mortar := Color("8a4a32")
		b.rect(Rect2(Vector2(-SIZE.x * 0.5 + shake, -h), Vector2(SIZE.x, h)), mortar)
		var rows := int(h / 24.0)
		for r in rows:
			var y := -10.0 - r * 24.0
			var off := 0.0 if r % 2 == 0 else 11.0
			for c in 2:
				var cx := -11.0 + c * 22.0 + off * (1.0 if c == 0 else -1.0) * 0.5 + shake
				var tone := Color("8f877c").darkened(0.08 * ((r + c) % 3))
				b.ellipse(Vector2(cx, y), 11.0, 10.5, Color("4a4038"))
				b.ellipse(Vector2(cx, y - 1), 9.5, 9.0, tone)
				b.ellipse(Vector2(cx - 3, y - 4), 3.0, 2.0, Color(1, 1, 1, 0.25))
		b.draw(self)


## A bone ladder: two posts and four rungs he can jump up (one-way, like a
## branch: up through from below, stand on from above). Stays for the level.
class Ladder extends Node2D:
	const RUNG := 96.0
	const RUNGS := 4

	func _ready() -> void:
		z_index = -1
		for i in RUNGS:
			var body := StaticBody2D.new()
			body.collision_layer = 1
			body.collision_mask = 0
			body.add_to_group("unsafe_ground")
			var cs := CollisionShape2D.new()
			var s := RectangleShape2D.new()
			s.size = Vector2(62, 8)
			cs.shape = s
			cs.one_way_collision = true
			body.position = Vector2(0, -RUNG * (i + 1))
			body.add_child(cs)
			add_child(body)
		FX.burst(get_parent(), position + Vector2(0, -20), "dust")

	func _draw() -> void:
		var b := Batch.new()
		var top := -RUNG * RUNGS - 20.0
		var bone := Color("e9dcbc")
		var dark := Color("6d5a3e")
		for sx in [-28.0, 28.0]:
			b.line(Vector2(sx, 4), Vector2(sx, top), dark, 9.0)
			b.line(Vector2(sx, 4), Vector2(sx, top), bone, 6.0)
			b.circle(Vector2(sx, top), 6.0, bone)
		for i in RUNGS:
			var y := -RUNG * (i + 1)
			b.line(Vector2(-31, y), Vector2(31, y), dark, 8.0)
			b.line(Vector2(-31, y - 1), Vector2(31, y - 1), Color("846141"), 5.0)
			for sx in [-28.0, 28.0]:
				b.line(Vector2(sx - 4, y - 5), Vector2(sx + 4, y + 5), Color("5a6b2a"), 2.5)     # the lashing
		b.draw(self)


## The GLARE TRAP, set down: a clay pot with a berry poking out (the smell
## draws Old One-Eye), quartz round its rim and a fire-gold striker. When
## the worm bursts up at it: FLASH! (flash(); 3 in it, then it's spent).
## Whoever hunts by smell finds it in the group "worm_trap".
class GlareTrap extends Node2D:
	var charges := 3
	var _t := 0.0
	var _flash := 0.0              ## > 0: just went off

	func _ready() -> void:
		z_index = 2
		add_to_group("worm_trap")
		add_to_group("glow")
		add_to_group("light")
		FX.burst(get_parent(), position + Vector2(0, -10), "dust")

	func flash() -> void:
		if charges <= 0:
			return
		charges -= 1
		_flash = 0.6
		FX.burst(get_parent(), global_position + Vector2(0, -24), "sparks")
		var w := CaveMan.WordPop.new()
		w.text = "FLASH!"
		w.size = 34
		w.color = Color("fff7c8")
		w.star = Color(1.0, 0.85, 0.3, 0.8)
		w.centered = true
		w.position = global_position + Vector2(0, -90)
		get_parent().add_child(w)

	func light() -> Vector4:
		return Vector4(global_position.x, global_position.y - 20.0, 60.0 + 420.0 * _flash, 1.0)

	func light_strength() -> float:
		return clampf(0.35 + _flash * 1.5, 0.0, 1.0)

	func _process(delta: float) -> void:
		_t += delta
		_flash = maxf(_flash - delta, 0.0)
		if charges <= 0 and _flash <= 0.0:
			FX.shards(get_parent(), global_position + Vector2(0, -14), Vector2.UP, true)
			queue_free()
			return
		if LevelBase.near_view(self):
			queue_redraw()

	func draw_glow(g) -> void:   # g: the glow layer's Batch
		if _flash > 0.0:
			g.draw_circle(global_position + Vector2(0, -20), 40.0 + 260.0 * (0.6 - _flash), Color(1, 0.97, 0.8, _flash * 1.2))
		for i in charges:
			g.draw_circle(global_position + Vector2(-14.0 + i * 14.0, -30), 4.0, Color(0.75, 0.95, 1.0, 0.5 + 0.3 * sin(_t * 5.0 + i)))

	func _draw() -> void:
		var b := Batch.new()
		# the sweet smell rising off it: pink wavy wisps
		for k in 3:
			var q := fmod(_t * 0.5 + k * 0.33, 1.0)
			var x := sin(q * 9.0 + k) * 8.0
			b.circle(Vector2(x - 6 + k * 6, -34.0 - q * 60.0), 3.0 * (1.0 - q) + 1.0, Color(1.0, 0.6, 0.85, 0.5 * (1.0 - q)), 8)
		# the pot
		b.ellipse(Vector2(0, -12), 20.0, 14.0, Color("5a2a1a"))
		b.ellipse(Vector2(0, -13), 18.0, 12.0, Color("b4583a"))
		b.rect(Rect2(-14, -28, 28, 5), Color("8a3c26"))
		b.circle(Vector2(0, -30), 6.0, Color("7b3aa0"), 10)                       # the berry bait
		b.circle(Vector2(-2, -32), 2.0, Color("d9b8ef"), 6)
		# quartz all round the rim, one per flash left
		for i in 3:
			var c := Vector2(-14.0 + i * 14.0, -28)
			var col := Color("bfe8f2") if i < charges else Color(0.4, 0.4, 0.45)
			b.tri(c + Vector2(-4, 0), c + Vector2(0, -12), c + Vector2(4, 0), col)
		b.rect(Rect2(10, -14, 9, 9), Color("d9b43a"))                              # the fire-gold striker
		if _flash > 0.0:
			b.circle(Vector2(0, -20), 30.0 + 120.0 * (0.6 - _flash), Color(1, 1, 0.9, _flash), 24)
		b.draw(self)


## ------------------------------------------------------------ PICTURES
## An item's picture, centred on c; s = 1.0 fills a ~40 px box.
static func draw_icon(ci: CanvasItem, id: String, c: Vector2, s: float, t: float = 0.0) -> void:
	ci.draw_set_transform(c, 0.0, Vector2(s, s))
	if id.begins_with("relic:"):
		var b := Batch.new()
		Relics.draw_icon(b, id.substr(6), Vector2.ZERO, 16.0, t)
		b.draw(ci)
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	match id:
		"club", "axe", "hammer", "shovel", "hands", "rocks":
			Hud.draw_tool(ci, id, Vector2.ZERO, 1.0)
		"figs":
			Hud.draw_fig(ci, Vector2.ZERO, 1.1)
		"shells", "bones":
			var b := Batch.new()
			Treasure.shape_into(b, "shell" if id == "shells" else "bone", Vector2.ZERO)
			b.draw(ci)
		"orbs":
			ci.draw_circle(Vector2.ZERO, 13.0, Color("5fb8ff", 0.3))
			ci.draw_circle(Vector2.ZERO, 8.5, Color("cfeeff"))
			ci.draw_circle(Vector2(-3, -3), 3.0, Color.WHITE)
		"torch":
			ci.draw_line(Vector2(-6, 16), Vector2(2, -4), Color("4a3220"), 6.0)
			ci.draw_line(Vector2(-6, 16), Vector2(2, -4), Color("846141"), 4.0)
			ci.draw_colored_polygon(PackedVector2Array([Vector2(-6, -4), Vector2(4, -20 - sin(t * 9.0) * 2.0), Vector2(10, -2)]), Pal.FLAME)
			ci.draw_colored_polygon(PackedVector2Array([Vector2(-1, -4), Vector2(4, -13), Vector2(7, -3)]), Pal.FLAME_CORE)
		"wood":
			for k in 3:
				var o := Vector2(0, -6 + k * 6)
				ci.draw_line(o + Vector2(-15, 4), o + Vector2(15, -4), Color("4a3220"), 5.0)
				ci.draw_line(o + Vector2(-15, 4), o + Vector2(15, -4), Pal.DEADWOOD.darkened(0.1 * k), 3.5)
			ci.draw_line(Vector2(-2, -12), Vector2(2, 12), Pal.VINE, 3.0)
		"berries":
			ci.draw_line(Vector2(0, -10), Vector2(3, -16), Color("6b4a2a"), 2.5)
			for g in [Vector2(-6, -5), Vector2(0, -7), Vector2(6, -5), Vector2(-3, 1), Vector2(3, 1), Vector2(0, 7)]:
				ci.draw_circle(g, 4.6, Color("3e1a52"))
				ci.draw_circle(g, 3.8, Color("7b3aa0"))
				ci.draw_circle(g + Vector2(-1.2, -1.2), 1.2, Color("d9b8ef"))
		"flint":
			_stone(ci, [Vector2(-13, 6), Vector2(-9, -9), Vector2(3, -13), Vector2(13, -4), Vector2(10, 9), Vector2(-3, 12)], Color("5d5f66"), Color("2a2a30"))
			ci.draw_colored_polygon(PackedVector2Array([Vector2(-9, -9), Vector2(3, -13), Vector2(0, -2), Vector2(-7, 1)]), Color("8a8d96"))
			ci.draw_line(Vector2(3, -13), Vector2(13, -4), Color(1, 1, 1, 0.7), 1.5)
		"clay":
			ci.draw_circle(Vector2(0, 3), 13.0, Color("5a2a1a"))
			ci.draw_circle(Vector2(0, 2), 11.5, Color("b4583a"))
			ci.draw_circle(Vector2(4, -1), 4.0, Color("8a3c26"))
			ci.draw_circle(Vector2(-5, -4), 2.5, Color(1, 0.8, 0.7, 0.5))
		"pyrite":
			for q in [[Vector2(-12, -2), 13.0], [Vector2(0, -10), 11.0], [Vector2(1, 1), 12.0]]:
				var at: Vector2 = q[0]
				var w: float = q[1]
				ci.draw_rect(Rect2(at - Vector2(1, 1), Vector2(w + 2, w + 2)), Color("4a3a10"))
				ci.draw_rect(Rect2(at, Vector2(w, w)), Color("d9b43a"))
				ci.draw_rect(Rect2(at, Vector2(w, w * 0.35)), Color("fff0a0"))
			ci.draw_circle(Vector2(8, -12), 2.0 + sin(t * 6.0), Color(1, 1, 0.85, 0.9))
		"quartz":
			for i in 3:
				var o := Vector2(-8.0 + i * 8.0, 10.0)
				var h := 26.0 if i == 1 else 18.0
				ci.draw_colored_polygon(PackedVector2Array([o + Vector2(-5, 0), o + Vector2(-4, -h + 6), o + Vector2(0, -h), o + Vector2(4, -h + 6), o + Vector2(5, 0)]), Color("bfe8f2") if i == 1 else Color("9cc8d8"))
				ci.draw_line(o + Vector2(-1, -2), o + Vector2(-1, -h + 7), Color(1, 1, 1, 0.8), 1.5)
			ci.draw_rect(Rect2(-14, 9, 28, 5), Color("6b625c"))
		"obsidian":
			_stone(ci, [Vector2(-4, 14), Vector2(-12, 0), Vector2(-3, -15), Vector2(8, -10), Vector2(12, 4)], Color("1a1424"), Color("05030a"))
			ci.draw_colored_polygon(PackedVector2Array([Vector2(-3, -15), Vector2(8, -10), Vector2(1, -2)]), Color("4b3a6a"))
			ci.draw_line(Vector2(-8, 2), Vector2(-2, -10), Color(0.8, 0.7, 1.0, 0.8), 1.5)
		"tips":
			for i in 3:
				var o := Vector2(-8.0 + i * 8.0, 2.0 + absf(i - 1) * 3.0)
				ci.draw_line(o + Vector2(-3, 14), o + Vector2(0, -6), Color("e9dcbc"), 2.5)
				ci.draw_colored_polygon(PackedVector2Array([o + Vector2(-4, -5), o + Vector2(0, -16), o + Vector2(4, -5)]), Color("5d5f66"))
				ci.draw_line(o + Vector2(0, -16), o + Vector2(2, -7), Color(1, 1, 1, 0.6), 1.0)
		"salve":
			ci.draw_colored_polygon(PackedVector2Array([Vector2(-12, -4), Vector2(12, -4), Vector2(9, 12), Vector2(-9, 12)]), Color("8a3c26"))
			ci.draw_rect(Rect2(-13, -7, 26, 5), Color("b4583a"))
			ci.draw_circle(Vector2(0, -8), 8.0, Color("c76aa0"))
			ci.draw_circle(Vector2(-3, -10), 2.5, Color(1, 1, 1, 0.5))
			ci.draw_colored_polygon(PackedVector2Array([Vector2(4, -10), Vector2(16, -18), Vector2(10, -6)]), Color("6fa83a"))
		"wall":
			ci.draw_rect(Rect2(-14, -16, 28, 32), Color("8a4a32"))
			for r in 3:
				for k in 2:
					var cc := Vector2(-7.0 + k * 14.0 + (3.0 if r == 1 else 0.0), 10.0 - r * 11.0)
					ci.draw_circle(cc, 6.5, Color("4a4038"))
					ci.draw_circle(cc + Vector2(0, -0.5), 5.5, Color("8f877c"))
		"ladder":
			for sx in [-9.0, 9.0]:
				ci.draw_line(Vector2(sx, 17), Vector2(sx, -17), Color("6d5a3e"), 5.0)
				ci.draw_line(Vector2(sx, 17), Vector2(sx, -17), Color("e9dcbc"), 3.0)
			for i in 4:
				ci.draw_line(Vector2(-10, 12.0 - i * 8.0), Vector2(10, 12.0 - i * 8.0), Color("846141"), 3.0)
		"spark":
			_stone(ci, [Vector2(-15, 8), Vector2(-12, -4), Vector2(-3, -6), Vector2(0, 6), Vector2(-6, 12)], Color("5d5f66"), Color("2a2a30"))
			ci.draw_rect(Rect2(2, -2, 12, 12), Color("4a3a10"))
			ci.draw_rect(Rect2(3, -1, 10, 10), Color("d9b43a"))
			for i in 4:
				var a := -PI * 0.5 + (i - 1.5) * 0.45 + sin(t * 7.0 + i) * 0.1
				ci.draw_line(Vector2(0, -6) + Vector2.from_angle(a) * 5.0, Vector2(0, -6) + Vector2.from_angle(a) * 14.0, Color("ffd36b"), 2.0)
		"edge":
			ci.draw_line(Vector2(-12, 14), Vector2(-4, 6), Color("846141"), 5.0)
			ci.draw_colored_polygon(PackedVector2Array([Vector2(-6, 8), Vector2(14, -16), Vector2(2, 10)]), Color("1a1424"))
			ci.draw_line(Vector2(-3, 6), Vector2(13, -14), Color(0.8, 0.7, 1.0, 0.9), 1.5)
			ci.draw_circle(Vector2(11, -11), 1.5 + absf(sin(t * 3.0)) * 1.5, Color.WHITE)
		"trap":
			ci.draw_circle(Vector2(0, 6), 12.0, Color("5a2a1a"))
			ci.draw_circle(Vector2(0, 5), 10.5, Color("b4583a"))
			ci.draw_rect(Rect2(-9, -6, 18, 4), Color("8a3c26"))
			ci.draw_circle(Vector2(0, -8), 4.5, Color("7b3aa0"))
			for i in 3:
				var qc := Vector2(-8.0 + i * 8.0, -6)
				ci.draw_colored_polygon(PackedVector2Array([qc + Vector2(-3, 0), qc + Vector2(0, -8), qc + Vector2(3, 0)]), Color("bfe8f2"))
			ci.draw_rect(Rect2(6, 2, 6, 6), Color("d9b43a"))
			var z := 0.5 + 0.5 * sin(t * 6.0)
			ci.draw_line(Vector2(-14, -14), Vector2(-10, -10), Color(1, 1, 0.8, z), 1.5)
			ci.draw_line(Vector2(14, -14), Vector2(10, -10), Color(1, 1, 0.8, 1.0 - z), 1.5)
		"charm":
			ci.draw_arc(Vector2(0, -6), 11.0, PI * 1.05, PI * 1.95, 12, Color("846141"), 2.0)
			ci.draw_line(Vector2(-11, -8), Vector2(-2, 2), Color("846141"), 2.0)
			ci.draw_line(Vector2(11, -8), Vector2(2, 2), Color("846141"), 2.0)
			ci.draw_colored_polygon(PackedVector2Array([Vector2(-5, 4), Vector2(0, -3), Vector2(5, 4), Vector2(0, 17)]), Color("bfe8f2"))
			ci.draw_line(Vector2(-2, 4), Vector2(0, 13), Color(1, 1, 1, 0.8), 1.5)
		_:
			ci.draw_circle(Vector2.ZERO, 10.0, Color.GRAY)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func _stone(ci: CanvasItem, pts: Array, fill: Color, edge: Color) -> void:
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	for p in pts:
		outer.append(p * 1.15)
		inner.append(p)
	ci.draw_colored_polygon(outer, edge)
	ci.draw_colored_polygon(inner, fill)


## ================================================================ THE BAG, ON SCREEN
## One Control over the whole HUD that only takes the mouse where something
## is drawn (_has_point): the bag button, the strip of boxes, the big view.
class View extends Control:
	const BTN := Rect2(1222, 186, 50, 40)
	const STRIP := Vector2(1198, 232)     ## the strip's first box
	const BOX := 34.0
	const STEP := 38.0
	const ROWS := 10
	const PANEL := Rect2(180, 104, 920, 492)
	const GRID := Vector2(16, 92)          ## (in the panel)
	const CELL := 50.0
	const CSTEP := 56.0
	const COLS := 10
	const CROWS := 6
	const CRAFT := Rect2(594, 92, 310, 43) ## first recipe row (in the panel)
	const TABS := ["ALL", "GEAR", "STONES", "BUILD", "FOOD", "TREASURE"]

	var him: CaveMan
	var tab := "ALL"
	var _hover := []              ## [what, id]: "item" / "recipe" / "tab" / "btn" / "close"
	var _hits: Array = []         ## [Rect2, what, id] for what is drawn now
	var _sig := []
	var _mouse := Vector2.ZERO
	var _t := 0.0
	var _tip_box: StyleBoxFlat

	func _ready() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_STOP
		process_mode = Node.PROCESS_MODE_ALWAYS     # it runs while the world waits for it
		mouse_exited.connect(func() -> void: _hover = [])

	func _exit_tree() -> void:
		if Bag.holding:
			Bag.holding = false
			get_tree().paused = false

	func _has_point(at: Vector2) -> bool:
		if BTN.has_point(at):
			return true
		if Bag.mode == 2:
			return PANEL.has_point(at)
		if Bag.mode == 1:
			var n := mini(_strip_ids().size(), 2 * ROWS)
			var rows := ceili(n / 2.0)
			return Rect2(STRIP - Vector2(4, 4), Vector2(2 * STEP + 4, rows * STEP + 4)).has_point(at)
		return false

	func _strip_ids() -> Array:
		# the hotbar first, in its order (1-9), even what has run out; then the rest of the bag
		var out: Array = him.hotbar() if him != null else []
		for id in Bag.listing(him):
			if not out.has(id):
				out.append(id)
		return out

	func toggle() -> void:
		Bag.mode = (Bag.mode + 1) % 3 if Bag.mode != 0 else 1
		if not Bag.job.is_empty() and Bag.mode == 0:
			Bag.mode = 2                 # someone is waiting for a mix: straight to the big view
		# hidden -> strip -> big view -> hidden
		_hover = []
		queue_redraw()

	func _process(delta: float) -> void:
		_t += delta
		if him == null or not is_instance_valid(him):
			him = get_tree().get_first_node_in_group("player") as CaveMan
		# a click (or a held press) on the bag is never a swing too
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and _has_point(get_local_mouse_position()):
			CaveMan.ui_click_until = Time.get_ticks_msec() + 200
		Bag.hold_world(get_tree())
		var sig := [Bag.mode, Bag.holding, tab, _hover, Bag.version, GameState.shells, GameState.orbs, GameState.bones, GameState.figs,
			GameState.weapons.size(), GameState.items.size(), GameState.relics.hash()]
		if him != null:
			sig.append_array([him.rocks, him.wood, him.berries, him.has_stick, him.has_torch, snappedf(him.torch_fuel, 0.05), him.hotbar_selected()])
		if not Bag.job.is_empty():
			sig.append(int(_t * 10.0))     # the "!" on the sack pulses
		if Bag.mode == 2 or not _hover.is_empty():
			sig.append(_mouse)
			if Bag.mode == 2:
				sig.append(int(_t * 8.0))     # the craftable rows glow
		if sig != _sig:
			_sig = sig
			queue_redraw()

	func _input(e: InputEvent) -> void:
		if get_tree().paused and not Bag.holding:
			return                      # the camp menu (or the guide) has the game stopped: not ours
		if e is InputEventKey and e.pressed and not e.echo:
			var k: int = (e as InputEventKey).physical_keycode
			if k == KEY_I or k == KEY_B:
				toggle()
				get_viewport().set_input_as_handled()
			elif k == KEY_ESCAPE and Bag.mode == 2:
				Bag.mode = 1
				get_viewport().set_input_as_handled()

	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseMotion:
			_mouse = e.position
			_hover = _hit_at(_mouse)
		elif e is InputEventMouseButton and e.pressed:
			var mb := e as InputEventMouseButton
			if mb.button_index != MOUSE_BUTTON_LEFT and mb.button_index != MOUSE_BUTTON_RIGHT:
				accept_event()      # (the wheel doesn't flick the hotbar while over the bag)
				return
			CaveMan.ui_click_until = Time.get_ticks_msec() + 250
			_mouse = mb.position
			_click(_hit_at(_mouse), mb.button_index == MOUSE_BUTTON_RIGHT)
			accept_event()
		elif e is InputEventScreenTouch and e.pressed:
			CaveMan.ui_click_until = Time.get_ticks_msec() + 250
			_mouse = e.position
			_hover = _hit_at(_mouse)
			_click(_hover, false)
			accept_event()

	func _hit_at(at: Vector2) -> Array:
		for h in _hits:
			if (h[0] as Rect2).has_point(at):
				return [h[1], h[2]]
		return []

	func _click(h: Array, right: bool) -> void:
		if h.is_empty():
			return
		match h[0]:
			"btn":
				if right:
					Bag.mode = 0 if Bag.mode != 0 else 1
				else:
					toggle()
			"close":
				Bag.mode = 1
			"tab":
				tab = h[1]
			"item":
				if Bag.mixer != null and is_instance_valid(Bag.mixer):
					# the mixing slab is out: into it (right-click: back out of it)
					if right:
						Bag.mixer.take(h[1])
					else:
						Bag.mixer.put(h[1])
				elif him != null:
					# a thing he can hold: into his hand
					var at: int = him.hotbar().find(h[1])
					if at >= 0:
						him.select_slot(at)
			"job":
				if not Bag.start_job() and him != null:
					him.said.emit("Go back to %s to mix it." % str(Bag.job.get("who", "them")).capitalize())
			"recipe":
				if him != null and not Bag.craft(him, h[1]):
					him.said.emit(Bag.missing(him, h[1]))
		_hover = _hit_at(_mouse)
		queue_redraw()

	## ---------------------------------------------------------- drawing
	func _draw() -> void:
		_hits.clear()
		if Bag.holding:
			# the world waits: dimmed behind, and a word saying so
			var vs := get_viewport_rect().size
			draw_rect(Rect2(Vector2.ZERO, vs), Color(0.02, 0.01, 0.03, 0.35))
			var pf := Pal.title_font()
			var pw := pf.get_string_size("PAUSED", HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
			draw_string_outline(pf, Vector2((vs.x - pw) * 0.5, 92), "PAUSED", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, 6, Color(0, 0, 0, 0.7))
			draw_string(pf, Vector2((vs.x - pw) * 0.5, 92), "PAUSED", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color("ffe066"))
		_draw_button()
		if Bag.mode == 1:
			_draw_strip()
		elif Bag.mode == 2:
			_draw_panel()
		_draw_tip()

	func _draw_button() -> void:
		_hits.append([BTN, "btn", ""])
		var on: bool = not _hover.is_empty() and _hover[0] == "btn"
		var c := BTN.get_center() + Vector2(0, 2)
		# a hide sack, tied at the neck
		draw_circle(c + Vector2(0, 4), 15.0, Color("3a2414"))
		draw_circle(c + Vector2(0, 3), 13.5, Color("b0773f") if on else Color("8d5c30"))
		draw_colored_polygon(PackedVector2Array([c + Vector2(-7, -9), c + Vector2(7, -9), c + Vector2(10, -16), c + Vector2(-10, -16)]), Color("8d5c30"))
		draw_line(c + Vector2(-8, -9), c + Vector2(8, -9), Color("5a6b2a"), 3.0)
		draw_circle(c + Vector2(-5, 0), 3.0, Color(1, 1, 1, 0.18))
		var font := ThemeDB.fallback_font
		var label: String = ["SHOW", "BIG", "HIDE"][Bag.mode]
		draw_string(font, BTN.position + Vector2(-34, 26), "I", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(Pal.BONE, 0.55))
		if not Bag.job.is_empty():
			# someone is waiting for a mix: a pulsing "!" on the sack
			var bp := c + Vector2(14, -14)
			var pk := 1.0 + 0.18 * sin(_t * 7.0)
			draw_circle(bp, 10.0 * pk, Color(0.15, 0.06, 0.02))
			draw_circle(bp, 8.5 * pk, Color("ffb02e"))
			draw_string(Pal.title_font(), bp + Vector2(-3.5, 5.5), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.15, 0.06, 0.02))
		if on:
			draw_string_outline(font, BTN.position + Vector2(-46, 46), label, HORIZONTAL_ALIGNMENT_RIGHT, 90, 12, 3, Color(0, 0, 0, 0.8))
			draw_string(font, BTN.position + Vector2(-46, 46), label, HORIZONTAL_ALIGNMENT_RIGHT, 90, 12, Pal.BONE)

	func _box(r: Rect2, id: String, hot: bool, held: bool, small: bool) -> void:
		var rc := Bag.rarity_col(id)
		var n := Bag.count(him, id)
		var empty := n <= 0                      # a hotbar thing he has run out of (rocks, figs): greyed
		draw_rect(r, Color(0.08, 0.06, 0.05, 0.78 if hot else 0.6))
		draw_rect(Rect2(r.position, Vector2(r.size.x, 3)), Color(rc, 0.55))           # its rarity, along the top
		var edge := Color("ffd36b") if held else (Color(rc, 0.95) if hot else Color(Pal.BONE, 0.3))
		draw_rect(r, edge, false, 2.5 if held or hot else 1.2)
		Bag.draw_icon(self, id, r.get_center() + Vector2(0, 1), r.size.x / 46.0, _t)
		if empty:
			draw_rect(r.grow(-2), Color(0.05, 0.04, 0.03, 0.6))
		var font := ThemeDB.fallback_font
		var fs := 11 if small else 13
		# THE HOTBAR: what he can hold has its number (1-9 picks it)
		var slot: int = him.hotbar().find(id) if him != null else -1
		if slot >= 0 and slot < 9:
			var bp := r.position + Vector2(3, 12)
			draw_string_outline(font, bp, str(slot + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 3, Color(0, 0, 0, 0.85))
			draw_string(font, bp, str(slot + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("ffd36b") if held else Color(Pal.BONE, 0.8))
		if id == "torch" and him != null:
			draw_rect(Rect2(r.position + Vector2(4, r.size.y - 6), Vector2((r.size.x - 8) * him.torch_fuel, 3)), Pal.FLAME)
		elif not Bag.unique(id):
			var txt := str(n) if n < 1000 else "%dk" % (n / 1000)
			var at := r.end - Vector2(3, 3)
			draw_string_outline(font, at - Vector2(r.size.x, 0), txt, HORIZONTAL_ALIGNMENT_RIGHT, r.size.x, fs, 3, Color(0, 0, 0, 0.85))
			draw_string(font, at - Vector2(r.size.x, 0), txt, HORIZONTAL_ALIGNMENT_RIGHT, r.size.x, fs, Color(Pal.BONE, 0.45) if empty else Pal.BONE)

	func _draw_strip() -> void:
		var ids := _strip_ids()
		var held: String = him.hotbar_selected() if him != null else ""
		var shown := mini(ids.size(), 2 * ROWS)
		for i in shown:
			var r := Rect2(STRIP + Vector2((i % 2) * STEP, (i / 2) * STEP), Vector2(BOX, BOX))
			if i == 2 * ROWS - 1 and ids.size() > 2 * ROWS:
				# no room for the rest: "+5", and a click opens the big view
				draw_rect(r, Color(0.08, 0.06, 0.05, 0.6))
				draw_rect(r, Color(Pal.BONE, 0.3), false, 1.2)
				draw_string(ThemeDB.fallback_font, r.position + Vector2(0, 22), "+%d" % (ids.size() - i), HORIZONTAL_ALIGNMENT_CENTER, BOX, 13, Pal.BONE)
				_hits.append([r, "btn", ""])
				continue
			var hot: bool = not _hover.is_empty() and _hover[1] == ids[i]
			_box(r, ids[i], hot, ids[i] == held, true)
			_hits.append([r, "item", ids[i]])

	func _draw_panel() -> void:
		var P := PANEL
		var font := ThemeDB.fallback_font
		draw_rect(P.grow(4), Color(0, 0, 0, 0.35))
		draw_rect(P, Color(0.10, 0.075, 0.055, 0.94))
		draw_rect(Rect2(P.position, Vector2(P.size.x, 40)), Color(0.18, 0.12, 0.08, 0.95))
		draw_rect(P, Pal.OCHRE, false, 3.0)
		var all := Bag.listing(him)
		draw_string(Pal.title_font(), P.position + Vector2(18, 28), "UGU'S BAG", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Pal.OCHRE)
		draw_string(font, P.position + Vector2(150, 27), "%d kinds of things" % all.size(), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(Pal.BONE, 0.7))
		# close
		var x := Rect2(P.end.x - 38, P.position.y + 6, 30, 28)
		var xon: bool = not _hover.is_empty() and _hover[0] == "close"
		draw_rect(x, Color("8a3a2a") if xon else Color(0.3, 0.15, 0.1, 0.8))
		draw_line(x.position + Vector2(9, 8), x.end - Vector2(9, 8), Pal.BONE, 3.0)
		draw_line(Vector2(x.end.x - 9, x.position.y + 8), Vector2(x.position.x + 9, x.end.y - 8), Pal.BONE, 3.0)
		_hits.append([x, "close", ""])
		# tabs
		for i in TABS.size():
			var tr := Rect2(P.position + Vector2(16 + i * 94, 50), Vector2(88, 28))
			var on: bool = tab == TABS[i]
			var hov: bool = not _hover.is_empty() and _hover[0] == "tab" and _hover[1] == TABS[i]
			draw_rect(tr, Color(0.30, 0.20, 0.12, 0.95) if on else Color(0.16, 0.11, 0.08, 0.9 if hov else 0.7))
			draw_rect(tr, Color("ffd36b") if on else Color(Pal.BONE, 0.35), false, 2.0 if on else 1.0)
			draw_string(font, tr.position + Vector2(0, 19), TABS[i], HORIZONTAL_ALIGNMENT_CENTER, tr.size.x, 13, Pal.BONE if on or hov else Color(Pal.BONE, 0.7))
			_hits.append([tr, "tab", TABS[i]])
		# the boxes: what he has first, then empty ones, like a real bag
		var ids := Bag.listing(him, "" if tab == "ALL" else tab)
		var held: String = him.hotbar_selected() if him != null else ""
		for i in COLS * CROWS:
			var r := Rect2(P.position + GRID + Vector2((i % COLS) * CSTEP, (i / COLS) * CSTEP), Vector2(CELL, CELL))
			if i < ids.size():
				var hot: bool = not _hover.is_empty() and _hover[0] == "item" and _hover[1] == ids[i]
				_box(r, ids[i], hot, ids[i] == held, false)
				_hits.append([r, "item", ids[i]])
			else:
				draw_rect(r, Color(0.06, 0.045, 0.035, 0.45))
				draw_rect(r, Color(Pal.BONE, 0.12), false, 1.0)
		if ids.is_empty():
			draw_string(font, P.position + GRID + Vector2(0, 150), "Nothing here yet. Go and find some!", HORIZONTAL_ALIGNMENT_CENTER, COLS * CSTEP, 16, Color(Pal.BONE, 0.6))
		# crafting
		draw_string(Pal.title_font(), P.position + Vector2(CRAFT.position.x, 70), "CRAFT", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Pal.OCHRE)
		draw_string(font, P.position + Vector2(CRAFT.position.x + 70, 69), "click to make it", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(Pal.BONE, 0.5))
		var known := Bag.known_recipes()
		for i in known.size():
			var rec: Array = known[i]
			var id: String = rec[0]
			var r := Rect2(P.position + CRAFT.position + Vector2(0, i * (CRAFT.size.y + 4)), CRAFT.size)
			var can := Bag.missing(him, id) == ""
			var owned := Bag.FOREVER.has(id) and Bag.count(him, id) > 0
			var hov: bool = not _hover.is_empty() and _hover[0] == "recipe" and _hover[1] == id
			var glow := 0.5 + 0.5 * sin(_t * 5.0 + i)
			draw_rect(r, Color(0.16, 0.12, 0.07, 0.95) if can else Color(0.08, 0.06, 0.05, 0.7))
			draw_rect(r, Color("ffd36b", 0.6 + 0.4 * glow) if can else Color(Pal.BONE, 0.45 if hov else 0.2), false, 2.0 if can or hov else 1.0)
			Bag.draw_icon(self, id, r.position + Vector2(23, 23), 0.85, _t)
			var a := 1.0 if can or owned else 0.6
			draw_string(font, r.position + Vector2(48, 19), Bag.name_of(id) + ("  x%d" % rec[1] if int(rec[1]) > 1 else ""), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(Bag.rarity_col(id), a))
			if owned:
				draw_string(font, r.position + Vector2(48, 38), "MADE - always on", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("8fe07a"))
			else:
				var ix := 48.0
				for need in rec[2]:
					var have := Bag.count(him, need)
					var want: int = rec[2][need]
					Bag.draw_icon(self, need, r.position + Vector2(ix + 8, 33), 0.36, _t)
					var txt := "%d/%d" % [mini(have, 99), want]
					draw_string(font, r.position + Vector2(ix + 18, 38), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("8fe07a") if have >= want else Color("ff8a6a"))
					ix += 64.0
			_hits.append([r, "recipe", id])
		# someone is waiting for a mix: the job's banner, glowing; click it to start mixing
		if not Bag.job.is_empty():
			var jr := Rect2(P.position + Vector2(16, 434), Vector2(556, 38))
			var near := Bag.job_near()
			var hov: bool = not _hover.is_empty() and _hover[0] == "job"
			var glow := 0.5 + 0.5 * sin(_t * 5.0)
			draw_rect(jr, Color(0.32, 0.2, 0.06, 0.95) if near else Color(0.16, 0.12, 0.08, 0.9))
			draw_rect(jr, Color("ffb02e", 0.55 + 0.45 * glow) if near else Color(Pal.BONE, 0.3), false, 3.0 if hov else 2.0)
			Bag.draw_icon(self, str(Bag.job["icon"]), jr.position + Vector2(22, 19), 0.75, _t)
			draw_string(Pal.title_font(), jr.position + Vector2(46, 26), "MIX " + str(Bag.job["title"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("ffd36b") if near else Color(Pal.BONE, 0.6))
			draw_string(font, jr.position + Vector2(0, 25), "click: start mixing!" if near else "go back to them", HORIZONTAL_ALIGNMENT_RIGHT, jr.size.x - 12.0, 13, Color("8fe07a") if near else Color(Pal.BONE, 0.5))
			_hits.append([jr, "job", ""])
		draw_string(font, P.position + Vector2(18, P.size.y - 12), "Hover: what it is   Click: hold it   Click a recipe: make it   I / B: bag   Right-click the bag: hide",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(Pal.BONE, 0.55))

	## The little card by the mouse: name, kind, what it is, what it's for.
	func _draw_tip() -> void:
		if _hover.is_empty() or (_hover[0] != "item" and _hover[0] != "recipe"):
			return
		var id: String = _hover[1]
		var inf := Bag.info(id)
		var lines: Array = []      # [text, size, colour]
		lines.append([inf[0], 19, Bag.rarity_col(id)])
		lines.append(["%s  ·  %s" % [Bag.RARITY[int(inf[2])], inf[1]], 12, Color(Bag.rarity_col(id), 0.75)])
		if str(inf[3]) != "":
			lines.append([inf[3], 15, Pal.BONE])
		if _hover[0] == "recipe":
			var rec := Bag.recipe(id)
			var parts: Array = []
			for need in rec[2]:
				parts.append("%d %s" % [rec[2][need], Bag.name_of(need)])
			lines.append(["MAKE: " + " + ".join(parts) + ("  ->  %d" % rec[1] if int(rec[1]) > 1 else ""), 14, Color("ffd36b")])
			lines.append(["USE: " + str(inf[4]), 14, Color("cfeeff")])
			var m := Bag.missing(him, id)
			lines.append([m if m != "" else "Click to make it!", 14, Color("ff8a6a") if m != "" else Color("8fe07a")])
		else:
			if str(inf[4]) != "":
				lines.append(["USE: " + str(inf[4]), 14, Color("ffd36b")])
			var into := Bag.goes_into(id)
			if not into.is_empty():
				lines.append(["MAKES: " + ", ".join(into), 14, Color("cfeeff")])
			if str(inf[5]) != "":
				lines.append(["FIND: " + str(inf[5]), 14, Color(Pal.BONE, 0.6)])
			if Bag.mixer != null and is_instance_valid(Bag.mixer):
				lines.append(["Click: put it in the mix   Right-click: take it out", 12, Color("8fe07a")])
			elif him != null and him.hotbar().has(id):
				lines.append(["Click: hold it in your hand", 12, Color("8fe07a")])
		var font := ThemeDB.fallback_font
		var w := 300.0
		var h := 20.0
		var heights: Array = []
		for i in lines.size():
			var l: Array = lines[i]
			var lf: Font = Pal.title_font() if i == 0 else font
			var lh: float = lf.get_multiline_string_size(l[0], HORIZONTAL_ALIGNMENT_LEFT, w - 28.0, l[1]).y
			heights.append(lh)
			h += lh + (8.0 if i == 1 else 3.0)
		var at := _mouse + Vector2(18, 16)
		if Bag.mode == 1:
			at = Vector2(STRIP.x - w - 12.0, _mouse.y - 20.0)        # the strip is at the edge: to its left
		var vs := get_viewport_rect().size
		at.x = clampf(at.x, 4.0, vs.x - w - 4.0)
		at.y = clampf(at.y, 4.0, vs.y - h - 4.0)
		var card := Rect2(at, Vector2(w, h))
		# a rounded card, edged in its rarity's colour, a soft shadow under it
		if _tip_box == null:
			_tip_box = StyleBoxFlat.new()
			_tip_box.bg_color = Color(0.09, 0.065, 0.045, 0.96)
			_tip_box.set_border_width_all(2)
			_tip_box.set_corner_radius_all(12)
			_tip_box.shadow_color = Color(0, 0, 0, 0.45)
			_tip_box.shadow_size = 6
		_tip_box.border_color = Color(Bag.rarity_col(id), 0.85)
		draw_style_box(_tip_box, card)
		var y := at.y + 10.0
		for i in lines.size():
			var l: Array = lines[i]
			var lf: Font = Pal.title_font() if i == 0 else font
			if i == 0:
				draw_multiline_string_outline(lf, Vector2(at.x + 14.0, y + float(l[1])), l[0], HORIZONTAL_ALIGNMENT_LEFT, w - 28.0, l[1], -1, 4, Color(0, 0, 0, 0.7))
			draw_multiline_string(lf, Vector2(at.x + 14.0, y + float(l[1])), l[0], HORIZONTAL_ALIGNMENT_LEFT, w - 28.0, l[1], -1, l[2])
			y += float(heights[i]) + (8.0 if i == 1 else 3.0)
			if i == 1:
				draw_line(Vector2(at.x + 14.0, y - 4.0), Vector2(at.x + w - 14.0, y - 4.0), Color(Bag.rarity_col(id), 0.35), 1.0)


## ================================================================ THE MIXING SLAB
## A flat stone with four hollows, for building something with someone: he
## clicks things in his bag to drop them in (right-click, or click a hollow,
## takes one back out), then MIX!. Whoever opened it checks the mix (`mixed`)
## and answers with `say`: a hint, or `close` and the building starts. Small,
## near the top middle, so the strip of the bag stays in sight beside it.
class Mixer extends Control:
	signal mixed(mix: Dictionary)
	signal closed
	const R := Rect2(452, 132, 376, 214)
	const SLOTS := 4
	var title := "MIX"
	var him: CaveMan
	var mix := {}                 ## id -> how many (in the order they went in)
	var note := "Click wood and stones in your bag to drop them in."
	var note_col := Color("e9dcbc")
	var goal_icon := "wall"       ## what it makes, shown after the "="
	var _shake := 0.0
	var _hover := ""              ## "slot0".."slot3", "mix", "close"
	var _sig := []
	var _t := 0.0
	var _done := false

	func _ready() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_STOP
		Bag.mixer = self
		process_mode = Node.PROCESS_MODE_ALWAYS     # the world waits while he mixes (Bag.hold_world)
		if Bag.mode == 0:
			Bag.mode = 1            # the bag has to be out to pick from it
		mouse_exited.connect(func() -> void: _hover = "")

	func _exit_tree() -> void:
		if Bag.mixer == self:
			Bag.mixer = null

	func _has_point(at: Vector2) -> bool:
		return R.has_point(at)

	func put(id: String) -> void:
		var inf := Bag.info(id)
		if Bag.unique(id):
			say("Build with your %s? Then how would you BONK things?" % Bag.name_of(id), false)
		elif inf[1] == "TREASURE":
			say("Treasure is for keeping, not for walls!", false)
		elif int(mix.get(id, 0)) >= Bag.count(him, id):
			say("That's all the %s you have." % Bag.name_of(id), false)
		elif not mix.has(id) and mix.size() >= SLOTS:
			say("The slab is full. Click a hollow to take something out.", false)
		else:
			mix[id] = int(mix.get(id, 0)) + 1
			note = "In it goes. Anything else? Then: MIX!"
			note_col = Color("e9dcbc")
		Bag.version += 1

	func take(id: String) -> void:
		if not mix.has(id):
			return
		mix[id] = int(mix[id]) - 1
		if int(mix[id]) <= 0:
			mix.erase(id)
		Bag.version += 1

	## A word about the mix (a hint, or a cheer); a wrong one shakes the slab.
	func say(text: String, good: bool) -> void:
		note = text
		note_col = Color("8fe07a") if good else Color("ffb38a")
		if not good:
			_shake = 0.35
		Bag.version += 1

	func close() -> void:
		if _done:
			return
		_done = true
		closed.emit()
		queue_free()

	func _process(delta: float) -> void:
		_t += delta
		_shake = maxf(_shake - delta, 0.0)
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and R.has_point(get_local_mouse_position()):
			CaveMan.ui_click_until = Time.get_ticks_msec() + 200
		var sig := [mix.duplicate(), note, _hover, _shake > 0.0, int(_t * 6.0) if not mix.is_empty() else 0]
		if sig != _sig or _shake > 0.0:
			_sig = sig
			queue_redraw()

	func _input(e: InputEvent) -> void:
		if e is InputEventKey and e.pressed and not e.echo and (e as InputEventKey).physical_keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			close()

	func _slot_rect(i: int) -> Rect2:
		return Rect2(R.position + Vector2(18 + i * 64, 48), Vector2(56, 56))

	func _mix_rect() -> Rect2:
		return Rect2(R.position + Vector2(18, 162), Vector2(150, 38))

	func _close_rect() -> Rect2:
		return Rect2(R.end.x - 34, R.position.y + 6, 28, 26)

	func _what(at: Vector2) -> String:
		for i in SLOTS:
			if _slot_rect(i).has_point(at):
				return "slot%d" % i
		if _mix_rect().has_point(at):
			return "mix"
		if _close_rect().has_point(at):
			return "close"
		return ""

	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseMotion:
			_hover = _what(e.position)
		elif (e is InputEventMouseButton and e.pressed) or (e is InputEventScreenTouch and e.pressed):
			CaveMan.ui_click_until = Time.get_ticks_msec() + 250
			accept_event()
			if e is InputEventMouseButton and (e as InputEventMouseButton).button_index > MOUSE_BUTTON_RIGHT:
				return
			var w := _what(e.position)
			if w == "close":
				close()
			elif w == "mix":
				if mix.is_empty():
					say("The slab is empty! Click things in your bag first.", false)
				else:
					mixed.emit(mix.duplicate())
			elif w.begins_with("slot"):
				var i := int(w.substr(4))
				var keys := mix.keys()
				if i < keys.size():
					take(keys[i])

	func _draw() -> void:
		var font := ThemeDB.fallback_font
		var sh := Vector2(sin(_t * 70.0) * 4.0 * (_shake / 0.35), 0)
		var r := Rect2(R.position + sh, R.size)
		# a flat slab of warm stone, outlined
		draw_rect(r.grow(4), Color(0, 0, 0, 0.35))
		draw_rect(r, Color("5a4a3c"))
		draw_rect(Rect2(r.position, Vector2(r.size.x, 34)), Color("6e5a48"))
		draw_rect(r, Color("2a2018"), false, 3.0)
		for k in 5:
			draw_circle(r.position + Vector2(40 + k * 77, 130 + (k % 2) * 40), 2.0, Color(0, 0, 0, 0.18))   # speckles
		draw_string(Pal.title_font(), r.position + Vector2(14, 24), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Pal.OCHRE)
		var c := _close_rect()
		c.position += sh
		draw_rect(c, Color("8a3a2a") if _hover == "close" else Color(0.3, 0.15, 0.1, 0.8))
		draw_line(c.position + Vector2(8, 7), c.end - Vector2(8, 7), Pal.BONE, 2.5)
		draw_line(Vector2(c.end.x - 8, c.position.y + 7), Vector2(c.position.x + 8, c.end.y - 7), Pal.BONE, 2.5)
		# the four hollows
		var keys := mix.keys()
		for i in SLOTS:
			var s := _slot_rect(i)
			s.position += sh
			draw_rect(s, Color("2e241c"))
			draw_rect(Rect2(s.position, Vector2(s.size.x, 5)), Color(0, 0, 0, 0.35))       # its shadowed lip
			draw_rect(s, Color("ffd36b") if _hover == "slot%d" % i and i < keys.size() else Color(0, 0, 0, 0.5), false, 2.0)
			if i < keys.size():
				var id: String = keys[i]
				var bob := sin(_t * 6.0 + i) * 1.5
				Bag.draw_icon(self, id, s.get_center() + Vector2(0, bob), 1.05, _t)
				var txt := "x%d" % int(mix[id])
				draw_string_outline(font, s.end - Vector2(56, 4), txt, HORIZONTAL_ALIGNMENT_RIGHT, 52, 14, 3, Color(0, 0, 0, 0.9))
				draw_string(font, s.end - Vector2(56, 4), txt, HORIZONTAL_ALIGNMENT_RIGHT, 52, 14, Pal.BONE)
			else:
				draw_string(font, s.position + Vector2(0, 36), "+", HORIZONTAL_ALIGNMENT_CENTER, 56, 22, Color(1, 1, 1, 0.12))
		# = what it makes (a shadow of it, until it's made)
		var g := R.position + sh + Vector2(282, 76)
		draw_string(font, g + Vector2(-26, 8), "=", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(Pal.BONE, 0.6))
		Bag.draw_icon(self, goal_icon, g + Vector2(28, 0), 1.25, _t)
		draw_rect(Rect2(g + Vector2(4, -28), Vector2(48, 56)), Color(0.18, 0.14, 0.1, 0.55))
		draw_string(font, g + Vector2(4, 10), "?", HORIZONTAL_ALIGNMENT_CENTER, 48, 26, Color(Pal.BONE, 0.8))
		# what Shivers (or whoever) says about it
		draw_multiline_string(font, R.position + sh + Vector2(16, 128), note, HORIZONTAL_ALIGNMENT_LEFT, R.size.x - 32, 13, 2, note_col)
		# MIX!
		var m := _mix_rect()
		m.position += sh
		var ready := not mix.is_empty()
		var pulse := 0.5 + 0.5 * sin(_t * 5.0)
		draw_rect(m, Color("b86a2c") if _hover == "mix" else (Color("8d5424") if ready else Color("4a3a2c")))
		draw_rect(m, Color("ffd36b", 0.5 + 0.5 * pulse) if ready else Color(0, 0, 0, 0.5), false, 2.0)
		draw_string(font, m.position + Vector2(0, 26), "MIX!", HORIZONTAL_ALIGNMENT_CENTER, m.size.x, 20, Pal.BONE if ready else Color(Pal.BONE, 0.5))
		draw_string(font, R.position + sh + Vector2(184, 186), "Right-click in bag: take out", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(Pal.BONE, 0.5))
		draw_string(font, R.position + sh + Vector2(184, 200), "Esc: put it away", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(Pal.BONE, 0.5))
