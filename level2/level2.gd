extends "res://level2/level2_data.gd"
## Level 2: Discovery of Fire. Night falls as he walks. The torch is his sight
## and his defence at once, and it burns down; bonfires feed it.
##   Dusk camp (0-900)          the torch, and the first eyes in the trees
##   Firelit woods (900-3980)   wolves, bats, dead trees, fire, the pack in the hollow
##   The Hanging Gorge (3980-5680) a ravine crossed by a chain of vines hanging from a
##                              fallen giant; a resting ledge; crumbling stepping stones
##   The Mountain (5680-8750)   a hard climb in the wind; a crevice stash; a lookout
##   (12050-12750)               open ground between the mountain and the great tree
##   The Great Tree (16050-14120) climb it, cross the chasm on its bough, mind the monkeys.
##                              At the very top: Old Bongo, the monkey king, who talks.
##   Far side (17420-16200)      last bonfire, a dead snag to climb back up, wolves running scared
##   The Boulder Run (19500-18200) a boulder breaks loose and rolls after him: run!
##   The Long Dark (21600-20400) the roar that snuffs his torch; fireflies; vines; crumbling rock
##   The Toolmaker (23700-21080) his home under a rock overhang: the forge
##                              (Firestone -> the Firestone Hammer) and his shop
##   The Three Fires (24380-22000) a trial: a cracked boulder, wolves, and three
##                              stone bowls to light; they burn the gate down
##   Old Scar's clearing (25300-23300) the boss
##
## The story: Old Bongo has lost the key to his banana box in one of two
## caves, and he'll trade the gem for it. Which cave is decided fresh each
## time the level starts. His memory of what chased him, and what lies at each
## cave's door, are the clues. The caves are built off to the right of the
## level (x > 24,000); their doorways fade him there and back.
##   The Weeping Cave  (mouth in the mountain's foot)  spiders, webs; a cocoon in the roof
##   The Rattling Cave (mouth in the far-side outcrop) rats, snakes; the rats' hoard
## Beaten, Old Scar flees and dawn comes up; the end-of-level scroll counts
## what was found.

var night: Night
var mountain: Terrain
var sky: NightWoods.NightSky
var _sky_layer: CanvasLayer
var _bands: ParallaxBackground
var elder: NightBeasts.Elder
var _told_wood := false
var _told_out := 0.0
var _told_monkeys := false

## The quest. key_cave: 0 = the Weeping Cave, 1 = the Rattling Cave; -1 = pick at random.
var key_cave := -1
var quest := "none"          ## none, asked, done
var has_key := false
var monkey_kills := 0
var _near_elder := false
var _callouts := 0
var _callout_t := 0.0
var _region := 0             ## 0 the woods (and the underground below it), 1 the Weeping Cave, 2 the Rattling Cave, 3 the fight
var _moving := false
var _mouths: Array = []

## The end of the level.
var scar: OldScar
var toolmaker: NightBeasts.Toolmaker
var arena_bongo: NightBeasts.Elder
var _gate: StaticBody2D
var _fight := false
var _scar_beaten := false
var _met_toolmaker := false
var moss: Friends.Moss
const AMBUSH := preload("res://level2/ambush.gd")
const WINDBREAK := preload("res://level2/windbreak.gd")
const ERRANDS := preload("res://level2/errands.gd")
var nutmeg: Friends.Nutmeg
var shivers: WINDBREAK.Camp   ## the side mission at the foot of the mountain (level2/windbreak.gd)
var errands: Array = []         ## Pip, Taka, Ooma: more side missions (level2/errands.gd)
var _met_nutmeg := false     ## heard about the stolen stone: Old Bongo gets asked about it
var _near_toolmaker := false
var _bongo_helps := 0
var _bongo_cd := 0.0
var _snuffed := false
var _panicked := false
var _time := 0.0
var _secrets := {}
var _treasure_total := 0


func _ready() -> void:
	level_w = LEVEL_W
	fall_y = FALL_Y
	cam_top = -900
	title = "LEVEL 2   DISCOVERY OF FIRE"
	if key_cave < 0:
		key_cave = randi() % 2
	_build_background()
	_build_world()
	_build_player(Vector2(140, GROUND_Y))
	# he keeps the club from Level 1, and he has his first hide
	player.pick_up_stick()
	player.costume = 2
	_build_critters()
	_build_tree_life()
	_build_caves()
	_build_cave_trials()
	_build_sky_lanes()
	_build_sky_lanes_2()
	_build_under()
	_build_windy()
	_build_mountain_inside()
	_build_gorge()
	_build_steppe()
	_build_tar_pits()
	_build_canyon()
	_build_friends()
	_build_boulder_run()
	_build_long_dark()
	_build_the_end()
	_build_treasure()
	_build_talkers()
	night = Night.new()
	night.table = DARKNESS
	night.player = player
	add_child(night)
	night.caves.append(mountain)      # dark as underground inside its tunnels
	var wind := NightWoods.Wind.new()
	wind.x0 = WIND_ZONE[0]
	wind.x1 = WIND_ZONE[1]
	wind.shelter = mountain           # no wind inside its tunnels
	wind.player = player
	add_child(wind)
	_build_hud()
	_wire_player()
	wind.first_gust.connect(func() -> void:
		hud.say("WIND! Lean into it — or hide behind a rock.", 5.0))
	# the guide first (once per save), then the story begins
	if not GameState.seen.has("level2"):
		var guide := Guide.new()
		guide.pages = GUIDE
		guide.player = player
		guide.done.connect(func() -> void:
			GameState.seen["level2"] = true
			GameState.save()
			_opening())
		add_child(guide)
	else:
		_opening()


func _opening() -> void:
	_talk([
		["", "The sun is going down, and he is far from the cave he knows."],
		["", "Night is coming. Something out there is hungry. He will need fire."],
		["", "(Space, J or a tap to go on.)"],
	])


## The guide at the start of the level: what to collect and why, the boss,
## and the secrets. Every page can be skipped.
const GUIDE := [
	{"title": "TREASURE OF THE WILD", "tag": "What to pick up, and why", "accent": Color("f0b44a"), "items": [
		["shells", "SHELLS, CONCHES & AMBER", "The treasure everyone trades with. Each one can be found only ONCE — so look high, look hidden, smash every box. Spend them at the Toolmaker's."],
		["bones", "MAMMOTH BONES", "For BUILDING! Grab all you can — they come back every time you play. One day you'll build your very own home with them."],
		["health", "GRAPES & ROAST FIGS", "Grapes heal you all by themselves. Roast figs are for emergencies: press H (or tap the fig)."],
	]},
	{"title": "BEWARE: OLD SCAR", "tag": "The terror of the Long Dark", "accent": Color("e0663a"), "items": [
		["scar", "A GIANT SABRE-TOOTH", "Deep in the dark lives Old Scar — huge, clever, and he LEARNS. Beat him to finish the level."],
		["torch", "HE FEARS FIRE", "When he crouches and wiggles, he's about to pounce: hold your torch toward him and he'll cower. Now hit him!"],
		["tricks", "WATCH FOR HIS TRICKS", "Two pairs of eyes in the dark... a shadow growing under you... And a rock thrown into his roaring jaws works wonders."],
	]},
	{"title": "GEMS & SECRET WEAPONS", "tag": "Legends of the forge", "accent": Color("b95ad6"), "items": [
		["gem", "THE FIRESTONE", "Somewhere a red gem glows. Help old Bongo the monkey find what he lost, and he might give it to you..."],
		["hammer", "THE FIRESTONE HAMMER", "Take it to the Toolmaker (with shells for his work) and he'll forge a legend. Hold attack, let go — FIRE SLAM! A wave of fire!"],
		["weapons", "EVERY WEAPON HAS A SECRET", "Hold attack with any weapon to find its special move: HOME RUN with the club, a boomerang AXE THROW..."],
	]},
]


func _build_background() -> void:
	_sky_layer = CanvasLayer.new()
	_sky_layer.layer = -120
	add_child(_sky_layer)
	sky = NightWoods.NightSky.new()
	_sky_layer.add_child(sky)

	var pb := ParallaxBackground.new()
	pb.scroll_ignore_camera_zoom = true     # the far scenery keeps its size; the view pulls back over it
	pb.layer = -100
	add_child(pb)
	_bands = pb
	var ridges := NightWoods.NightRidges.new()
	ridges.seedn = 5
	_pano(pb, ridges, Vector2(0.10, 0.06))
	var pines := NightWoods.PineBand.new()
	pines.seedn = 6
	_pano(pb, pines, Vector2(0.24, 0.12))
	var woods := NightWoods.WoodsBand.new()
	woods.seedn = 7
	_pano(pb, woods, Vector2(0.45, 0.22))
	var under := World.Undergrowth.new()
	under.seedn = 8
	_pano(pb, under, Vector2(0.62, 0.34))
	_pal_bands = [ridges, pines, woods, under]


## THE COLOUR SCRIPT: the region's palette at x (PALETTE, lerped between the two
## entries round it), blended toward PALETTE_UNDER by depth inside UNDER.
## Returns [sky_high, sky_low, ridge, pine, woods, under, accent].
var _pal_bands: Array = []
## Each band is drawn once in its own colours; it is recoloured by `modulate`
## (target / the colour it was drawn in): per-vertex, free, no redraw.
const PAL_BASE := [Pal.NIGHT_FAR, Pal.PINE, Pal.NIGHT_NEAR, Pal.FROND]
var accent := Color("e08a3c")        ## the region's accent (its light, its glows, its highlights)

func palette_at(at: Vector2) -> Array:
	var i := 0
	while i < PALETTE.size() - 2 and at.x > float(PALETTE[i + 1][0]):
		i += 1
	var a: Array = PALETTE[i]
	var b: Array = PALETTE[i + 1]
	var t := clampf((at.x - float(a[0])) / maxf(float(b[0]) - float(a[0]), 1.0), 0.0, 1.0)
	var out: Array = []
	for k in range(1, 8):
		out.append((a[k] as Color).lerp(b[k], t))
	if at.x > UNDER.position.x and at.x < UNDER.end.x:
		var deep := clampf((at.y - Night.UNDER_Y) / 500.0, 0.0, 1.0)
		if deep > 0.0:
			for k in 7:
				out[k] = (out[k] as Color).lerp(PALETTE_UNDER[k], deep)
	return out


func _update_palette() -> void:
	if player == null or _pal_bands.is_empty():
		return
	if player.global_position.x > LEVEL_W + 400.0:
		return                                     # the caves keep their own colours
	var p := palette_at(player.global_position)
	sky.night_high = p[0]
	sky.night_low = p[1]
	sky.accent = p[6]
	accent = p[6]
	for k in 4:
		var target: Color = p[2 + k]
		var base: Color = PAL_BASE[k]
		(_pal_bands[k] as CanvasItem).modulate = Color(target.r / base.r, target.g / base.g, target.b / base.b)


func _build_world() -> void:
	# the mountain: painted rock with tunnels and caves inside (common/terrain.gd)
	mountain = Terrain.new()
	mountain.map = MOUNTAIN_MAP
	mountain.position = MOUNTAIN_AT
	add_child(mountain)
	var tree := NightWoods.GreatTree.new()
	tree.position = Vector2(TREE_X, GROUND_Y)
	add_child(tree)
	var snag := NightWoods.Snag.new()
	snag.position = Vector2(SNAG_X, GROUND_Y)
	add_child(snag)

	for seg in FLOORS:
		add_child(Turf.Ground.new(Rect2(seg[0], GROUND_Y, seg[1] - seg[0], 240)))     # living turf
	add_child(Turf.Ground.new(Rect2(HOLLOW[0], HOLLOW[1], HOLLOW[2], 140)))
	for l in LEDGES:
		add_child(World.Slab.new(Rect2(l[0], l[1], l[2], 22)))
	for c in CRAGS:
		add_child(NightWoods.Crag.new(Rect2(c[0], c[1], c[2], c[3])))
	for m in MOONPUFFS:
		var puff := NightWoods.MoonPuff.new()
		var py: float = mountain.ground_y(m[0], m[1] - 70.0)
		puff.position = Vector2(m[0], py if absf(py - m[1]) < 60.0 else m[1])   # on the mountain: right on its rock
		add_child(puff)
	for b in BOULDERS:
		var rock := NightWoods.Boulder.new()
		rock.position = Vector2(b[0], b[1])
		add_child(rock)
	for br in BRANCHES:
		add_child(NightWoods.Branch.new(Rect2(br[0], br[1], br[2], 14), br[3]))
	add_child(World.Slab.new(Rect2(-80, -1000, 80, 2200)))
	add_child(World.Slab.new(Rect2(LEVEL_W, -1000, 300, 2200)))

	for b in BONFIRES:
		var fire := NightWoods.Bonfire.new()
		fire.position = Vector2(b[0], b[1])
		fire.lit = b[2]
		fire.visited.connect(_on_bonfire.bind(fire))
		fire.kindled.connect(func() -> void:
			hud.say("The embers catch. If he falls now, he wakes here.", 3.5))
		add_child(fire)

	for tr in DEAD_TREES:
		var dead := NightWoods.DeadTree.new()
		dead.position = Vector2(tr[0], tr[1])
		dead.wood = tr[2]
		add_child(dead)
	for w in WOOD:
		var bundle := NightWoods.WoodPickup.new()
		bundle.position = Vector2(w[0], w[1])
		bundle.ground_y = w[1]
		add_child(bundle)
	for r in ROCK_PILES:
		var rock := World.RockPickup.new()
		rock.position = Vector2(r[0], r[1])
		add_child(rock)
	for v in PATH_VINES:
		var vine := World.BerryBush.new()
		vine.position = Vector2(v[0], v[1])
		vine.regrow = VINE_REGROW
		add_child(vine)
	for b in BERRIES:
		var bush := World.BerryBush.new()
		bush.position = Vector2(b[0], b[1])
		add_child(bush)



func _build_critters() -> void:
	for w in WOLVES:
		var wolf := NightBeasts.Wolf.new()
		wolf.left_x = w[0]
		wolf.right_x = w[1]
		wolf.position = Vector2(w[2], w[3])
		add_child(wolf)
	for b in BATS:
		var bat := NightBeasts.Bat.new()
		bat.ground_y = b[1]
		bat.position = Vector2(b[0], b[1] - BAT_HOVER)
		if b.size() > 2:
			bat.roam_x = b[2]
		add_child(bat)
	for a in AMBUSHES:
		var amb := AMBUSH.new()
		amb.x0 = a[0]
		amb.x1 = a[1]
		amb.floor_y = a[2]
		amb.kinds = a[3]
		amb.line = a[4]
		amb.tier = AMBUSH.tier_at(float(a[0]), LEVEL_W)       # deeper in, harder
		if float(a[0]) > MOUNTAIN_AT.x and float(a[1]) < 12080.0:
			amb.terrain = mountain              # inside the mountain: on its floors
		add_child(amb)

	_note(980,"Eyes in the dark. Bright fire keeps them back.", 4.5)
	_note(1170, "Dead tree. Dry as a bone. Bonk it for wood!", 3.5)
	_note(2700, "Three wolves down there. Time for FIRE.", 4.0)
	_note(3800, "Vines over a gorge! Swing high — let go at the TOP.", 5.0)
	_note(5500, "Only one way now: UP.", 3.0)
	_spot(Rect2(5860, 620, 240, 110), "A crack in the rock — and someone's stash in it.", "crevice")
	_spot(Rect2(7170, -480, 80, 90), "From up here, the whole valley. And something glints, high in the great tree.", "lookout")
	_note(23240, "Monkeys! Leave them alone, they leave YOU alone.", 4.5)
	_note(24480, "A dead snag: a ladder back up to the bough.", 4.5)


func _build_tree_life() -> void:
	for m in MONKEYS:
		var monkey := NightBeasts.Monkey.new()
		monkey.position = Vector2(m[0], m[1])
		monkey.habit = m[2]
		monkey.hanging = m[3]
		monkey.player = player
		monkey.shrieked.connect(_on_shriek)
		monkey.died.connect(func() -> void: monkey_kills += 1)
		add_child(monkey)
	elder = NightBeasts.Elder.new()
	elder.position = ELDER_AT
	elder.player = player
	elder.poked.connect(func() -> void: hud.say("OLD BONGO:  \"Ow! Rude.\"", 2.0))
	add_child(elder)


func _on_shriek() -> void:
	if not _told_monkeys:
		_told_monkeys = true
		hud.say("Now he's done it. Bananas that miss him are food, at least.", 4.0)


## ---------------------------------------------------------------- caves
func _build_caves() -> void:
	_build_cave(CAVE_A, CAVE_A_ROCK, CAVE_A_IN, CAVE_A_DOOR, 0)
	_build_cave(CAVE_B, CAVE_B_ROCK, CAVE_B_IN, CAVE_B_DOOR, 1)
	for w in CAVE_A_WEBS:
		var web := Caves.Web.new()
		web.position = Vector2(w[0], w[1])
		web.h = w[2]
		web.player = player
		web.blocked.connect(func() -> void:
			hud.say("The web holds. It wants fire: a lit torch, or a fire burst.", 4.0))
		add_child(web)
	for sp in SPIDERS:
		var spider := Caves.Spider.new()
		spider.roof_y = sp[1]
		spider.left_x = sp[3]
		spider.right_x = sp[4]
		spider.position = Vector2(sp[0], sp[2])
		add_child(spider)
	var cocoon := Caves.Cocoon.new()
	cocoon.position = Vector2(COCOON[0], COCOON[1] + 100.0)
	cocoon.roof_y = COCOON[1]
	cocoon.floor_y = COCOON[2]
	cocoon.holds_key = key_cave == 0
	cocoon.revealed.connect(_on_revealed)
	add_child(cocoon)
	for r in RATS:
		var rat := Caves.Rat.new()
		rat.left_x = r[0]
		rat.right_x = r[1]
		rat.position = Vector2(r[2], r[3])
		add_child(rat)
	for sn in SNAKES:
		var snake := Caves.Snake.new()
		snake.dir = sn[2]
		snake.position = Vector2(sn[0], sn[1])
		add_child(snake)
	var nest := Caves.Nest.new()
	nest.position = Vector2(NEST[0], NEST[1])
	nest.holds_key = key_cave == 1
	nest.revealed.connect(_on_revealed)
	add_child(nest)


## The longer caves: what lies between the old rooms. See the tables above.
func _build_cave_trials() -> void:
	for c in CRYSTALS:
		var crystal := CaveTrials.Crystals.new()
		crystal.position = Vector2(c[0], c[1])
		crystal.hanging = c[2]
		crystal.tint = TINTS[c[3]]
		crystal.n = 3 + (int(c[0]) / 7) % 3
		add_child(crystal)
	# the Weeping Hall
	for i in HALL_STALACTITES.size():
		var h: Array = HALL_STALACTITES[i]
		var st := CaveTrials.Stalactite.new()
		st.position = Vector2(h[0], h[1])
		st.len = h[2]
		st.floor_y = 700.0
		st.warn = 0.72 + 0.09 * (i % 3)
		add_child(st)
	# the nursery
	for sc in EGG_SACS:
		var sac := CaveTrials.EggSac.new()
		sac.position = Vector2(sc[0], sc[1])
		sac.left_x = NURSERY[0]
		sac.right_x = NURSERY[1]
		sac.popped.connect(_on_sac_popped)
		add_child(sac)
		_count_treasure("shell")
	# the Glowcap Chasm
	for g in GLOWCAPS:
		var cap := CaveTrials.GlowCap.new()
		cap.position = Vector2(g[0], g[1])
		cap.tint = TINTS[g[2]]
		add_child(cap)
	for sh in CAVE_SHELVES:
		var shelf := CaveTrials.Shelf.new()
		shelf.position = Vector2(sh[0], sh[1])
		shelf.w = sh[2]
		add_child(shelf)
	# the Stampede Alley
	var mound := CaveTrials.RatMound.new()
	mound.position = Vector2(STAMPEDE[0], STAMPEDE[1])
	mound.zone_x0 = STAMPEDE_ZONE[0]
	mound.kill_x = STAMPEDE_ZONE[1]
	mound.rumbled.connect(func(_wave: int) -> void:
		hud.say("Skritch-skritch-skritch — here they come!", 2.0))
	add_child(mound)
	# the Rattle Pit
	for bs in BONE_SLABS:
		var slab := CaveTrials.BoneSlab.new()
		slab.position = Vector2(bs[0], bs[1])
		slab.w = bs[2]
		slab.player = player
		add_child(slab)
	# the Rockfall Run
	var fall := CaveTrials.Rockfall.new()
	fall.xs = ROCKFALL_XS
	fall.floor_y = 600.0
	fall.start_y = 222.0
	fall.lead = 380.0
	fall.delay = 0.7
	fall.rattled.connect(func() -> void:
		hud.say("Dust trickles down. The roof is letting go — watch the floor: shadows come first.", 4.0))
	add_child(fall)
	_note(36015, "Dripping rocks above. Don't stand still!", 4.5)
	_note(36405, "Wriggly silk sacs. Pop them from far away.", 4.5)
	_note(36715, "A glowing mushroom. Jump on it. WHEEE!", 4.0)
	_note(39410, "Scritch... scratch... scritch... LOTS of somethings.", 3.5)
	_note(39765, "A bridge of old ribs. It creaks. Something hisses.", 4.5)
	_note(40135, "The roof is rattling. RUN!", 3.0)


## The sky lanes: see SKY_LANES. Loot is added with the rest of the treasure.
func _build_sky_lanes() -> void:
	for li in SKY_LANES.size():
		var lane: Dictionary = SKY_LANES[li]
		var pad: Array = lane["pad"]
		var bloom := NightWoods.MoonPuff.new()
		bloom.position = Vector2(pad[0], pad[1])
		add_child(bloom)
		var beacon := SkyLanes.Beacon.new()
		beacon.position = Vector2(pad[0], pad[1])
		add_child(beacon)
		var rocks: Array = lane["rocks"]
		for r in rocks:
			var rock := SkyLanes.SkyRock.new()
			rock.position = Vector2(r[0], r[1])
			rock.w = r[2]
			rock.lamp = (int(r[3]) & 2) != 0
			add_child(rock)
			if (int(r[3]) & 1) != 0:
				var b2 := NightWoods.MoonPuff.new()
				b2.position = Vector2(float(r[0]) + float(r[2]) * 0.5, r[1])
				add_child(b2)
		for mx in lane["motes"]:
			var motes := SkyLanes.StarMotes.new()
			motes.position = Vector2(mx, 200.0)
			add_child(motes)
		var c: Array = lane["cache"]
		var cr: Array = rocks[c[0]]
		var cache := SkyLanes.SkyCache.new()
		cache.contents = c[1]
		cache.level_id = "level2"
		cache.id = "sc%d" % li
		cache.position = Vector2(float(cr[0]) + float(cr[2]) * 0.5, cr[1])
		add_child(cache)
		for kind in cache.contents:
			_count_treasure(kind)
		if lane.has("bat"):
			var at: Array = lane["bat"]
			var bat := NightBeasts.Bat.new()
			bat.ground_y = float(at[1]) + 260.0
			bat.position = Vector2(at[0], at[1])
			bat.roam_x = 170.0
			bat.roam_y = 70.0
			add_child(bat)
		var n: Array = lane["note"]
		_note(n[0], n[1], n[2])


## A sac popped from afar: one shell, and no spiderlings.
func _on_sac_popped(sac: CaveTrials.EggSac) -> void:
	var id := "sac%d" % int(sac.position.x)
	if GameState.is_taken("level2", id):
		return
	var p := Treasure.Pickup.new()
	p.kind = "shell"
	p.level_id = "level2"
	p.id = id
	p.position = sac.global_position + Vector2(0, -30)
	p.vel = Vector2(randf_range(-70.0, 70.0), randf_range(-420.0, -330.0))
	p.floor_y = sac.global_position.y
	_on_treasure_popped(p)
	call_deferred("add_child", p)


func _build_cave(bounds: Rect2, rock: Array, entry: Vector2, door: Array, which: int) -> void:
	var back := Caves.CaveBackdrop.new()
	back.rect = bounds
	add_child(back)
	for r in rock:
		add_child(Caves.CaveRock.new(Rect2(r[0], r[1], r[2], r[3]), r[4]))
	var out := Caves.CaveExit.new()
	out.position = Vector2(bounds.position.x + 100.0, entry.y)
	out.side = -1
	out.player = player
	out.left.connect(_leave_cave.bind(which))
	add_child(out)
	var mouth := Caves.CaveMouth.new()
	mouth.position = Vector2(door[0], door[1])
	mouth.side = door[2]
	mouth.kind = door[3]
	mouth.monkey_went_in = key_cave == which
	mouth.player = player
	mouth.noticed.connect(_on_mouth_noticed.bind(which))
	mouth.entered.connect(_enter_cave.bind(which))
	add_child(mouth)
	_mouths.append(mouth)


## The mystery at each door. Which one a monkey went into is the answer.
func _door_lines(which: int) -> Array:
	var here := key_cave == which
	if which == 0:
		var lines := [["", "A cave in the rock by the great tree. Cold air breathes out of it."]]
		if here:
			lines.append(["", "Webs hang across the mouth — but they are torn, and a half-eaten banana is stuck in one."])
			lines.append(["", "Small hand-prints go in. None come out."])
		else:
			lines.append(["", "Thick webs hang across the mouth, whole and dusty. Nothing has pushed through them in a long time."])
		lines.append(["CAVEMAN", "Hmm."])
		return lines
	var lines := [["", "A cave in the rock. Something rattles and scratches, deep inside."]]
	if here:
		lines.append(["", "A shed snake skin lies at the mouth. On it, a banana peel — and the print of a small hand."])
	else:
		lines.append(["", "A shed snake skin lies at the mouth, and it smells of rats. Nothing with hands has come this way."])
	lines.append(["CAVEMAN", "Hnn."])
	return lines


func _on_mouth_noticed(which: int) -> void:
	_talk(_door_lines(which))


func _enter_cave(which: int) -> void:
	if _moving:
		return
	_moving = true
	var entry := CAVE_A_IN if which == 0 else CAVE_B_IN
	hud.through_black(func() -> void:
		_move_player(entry, 1)
		_secrets["weeping" if which == 0 else "rattling"] = true
		hud.say("The Weeping Cave." if which == 0 else "The Rattling Cave.", 2.5)
	)


func _leave_cave(which: int) -> void:
	if _moving:
		return
	_moving = true
	var door: Array = CAVE_A_DOOR if which == 0 else CAVE_B_DOOR
	# back out in front of the doorway, facing away from it
	var side := int(door[2])
	hud.through_black(func() -> void:
		_move_player(Vector2(door[0] - side * 60.0, door[1]), -side)
	)


func _move_player(at: Vector2, facing: int) -> void:
	player.global_position = at
	player.velocity = Vector2.ZERO
	player.facing = facing
	last_safe = at
	_apply_region(_region_at(at.x))
	_moving = false


func _region_at(x: float) -> int:
	if x >= CAVE_B.position.x:
		return 2
	if x >= CAVE_A.position.x:
		return 1
	return 0


## Point the camera at the woods or at one cave, and put the moon away underground.
func _apply_region(r: int) -> void:
	_region = r
	var rect := Rect2(0, cam_top, LEVEL_W, 1200 - cam_top)
	if r == 1:
		rect = CAVE_A
	elif r == 2:
		rect = CAVE_B
	elif r == 3:
		rect = Rect2(ARENA.position.x, cam_top, ARENA.size.x, 1200 - cam_top)
	cam.limit_left = int(rect.position.x)
	cam.limit_right = int(rect.end.x)
	cam.limit_top = int(rect.position.y)
	cam.limit_bottom = int(rect.end.y)
	apply_view(rect)          # a cave is only so tall: never show past it
	var outdoors := r == 0 or r == 3
	night.moon_r = 70.0 if outdoors else 0.0
	night.sky_lift = 1.0 if outdoors else 0.0
	# underground, the sky and the woods are behind solid rock: don't draw them
	_sky_layer.visible = outdoors
	_bands.visible = outdoors
	cam.global_position = player.global_position + Vector2(0, -150)
	cam.reset_smoothing()


## ---------------------------------------------------------------- the quest
func _on_revealed(item: Caves.KeyItem) -> void:
	item.taken.connect(_on_key_taken)


func _on_key_taken(real: bool) -> void:
	if not real:
		if quest == "asked":
			hud.say("A bone. Shaped like a key... but just a bone. Bongo's key must be in the other cave.", 5.0)
		else:
			hud.say("A bone, shaped a bit like a key. Just a bone.", 4.0)
		return
	has_key = true
	if quest == "asked":
		hud.say("Old Bongo's key! Back up the great tree with it.", 4.5)
		hud.set_quest("Bring the key to Old Bongo — top of the great tree")
	else:
		hud.say("A key carved from bone, with a banana for a handle. Someone must be missing this.", 5.0)
		hud.set_quest("A strange key... whose is it?")


func _bongo(text: String, action: Callable = Callable()) -> Array:
	if action.is_valid():
		return ["OLD BONGO", text, action]
	return ["OLD BONGO", text]


func _clue() -> String:
	if key_cave == 0:
		return "something dropped on me from the ceiling — so many legs! Eight, at least!"
	return "something slid out of the wall at me — no legs at all! None!"


func _meet_elder() -> void:
	if quest == "done":
		_again(["OLD BONGO:  \"Go well, hairless one. Mind the big one.\"", "OLD BONGO:  \"A king never forgets a favour. Or a smell.\"",
			"OLD BONGO:  \"Banana? ...No. Mine.\""])
		return
	var lines: Array = []
	if quest == "none" and not has_key:
		lines = [_bongo("HALT! Who climbs the royal tree? ...Oh. A hairless one. With a tiny sun.")]
		if monkey_kills > 0:
			lines.append(_bongo("You've been hitting my family. I'm keeping a list."))
		var answers := [
			["Ugh. Deal.", [_bongo("Few words. I like you already.")]],
			["...Banana?", [_bongo("A WHOLE box of them. Locked. It's a royal tragedy.")]],
		]
		if _met_nutmeg:
			answers.append(["That's beaver's stone!", [_bongo("Beaver? Never heard of her. ...Moving on!")]])
		lines += [
			_bongo("I lost the key to my banana box in a cave. Fetch it, and this shiny stone is yours."),
			{"choose": answers},
			_bongo("It was dark, I was eating a banana, and then " + _clue()),
			_bongo("Two caves: one in the rock by my tree, one past the chasm. Their doors give clues. GO!"),
		]
		_talk(lines, func() -> void:
			quest = "asked"
			hud.set_quest("Find Old Bongo's key — in one of the two caves"))
	elif not has_key:
		var short := "so many legs" if key_cave == 0 else "no legs at all"
		_talk([_bongo("No key yet? It's in the cave where the thing with " + short + " lives. Shoo!")])
	else:
		if quest == "none":
			lines = [_bongo("HALT! Who — wait. Is that MY KEY? I didn't even ask yet!")]
		else:
			lines = [_bongo("Is that... MY KEY! Hairless one, you smell terrible and I love you.")]
		lines.append(_bongo("BANANAS FOR EVERYONE!", _open_box))
		if _met_nutmeg:
			# the beaver's stone: Bongo would rather not talk about it
			lines.append({"choose": [
				["Ugh. Thank you.", [_bongo("Manners! Here — the shiny stone, as promised.", _give_gem)]],
				["Beaver's stone!", [_bongo("...My nephew BORROWED it. Take it! Shh!", _give_gem)]],
			]})
		else:
			lines.append(_bongo("And the shiny stone. A king keeps his word.", _give_gem))
		lines.append(_bongo("Now go. Something big is awake tonight. Bigger than me. Hard to believe."))
		_talk(lines, func() -> void:
			quest = "done"
			has_key = false
			hud.set_quest(""))


func _open_box() -> void:
	elder.open_box()
	for i in 3:
		var b := NightBeasts.BananaPickup.new()
		b.position = ELDER_AT + Vector2(-120.0 + i * 36.0, 0)
		add_child(b)


func _give_gem() -> void:
	elder.has_gem = false
	var g := World.Gem.new()
	g.position = player.global_position
	g.found.connect(_on_gem)
	add_child(g)


func _talk(lines: Array, after: Callable = Callable(), _speaker: Node = null) -> void:
	var d := Dialogue.new()
	d.lines = lines
	d.player = player
	var who_is := {"OLD BONGO": elder, "TOOLMAKER": toolmaker, "MOSS": moss, "NUTMEG": nutmeg, "SHIVERS": shivers}
	for e in errands:
		who_is[e.who] = e
	d.line_started.connect(func(who: String) -> void:
		for nm in who_is:
			if who_is[nm] != null:
				who_is[nm].speaking = who == nm)
	d.finished.connect(func() -> void:
		for nm in who_is:
			if who_is[nm] != null:
				who_is[nm].speaking = false
		if after.is_valid():
			after.call())
	add_child(d)


func _update_elder(delta: float) -> void:
	if player.dead or player.talking or player.fury >= 0.0:
		return
	# (talking to him is his choice now: see _update_talkers)
	# from the bough, a voice from above
	_callout_t -= delta
	var on_bough := absf(player.global_position.y - 42.0) < 12.0 and player.global_position.x > 23700.0
	if quest == "none" and on_bough and _callouts < 3 and _callout_t <= 0.0:
		_callouts += 1
		_callout_t = 10.0
		hud.say("A voice from above:  \"Psst! Hairless one! Up here!\"", 3.0)


## ---------------------------------------------------------------- the Long Dark
## ---------------------------------------------------------------- the Boulder Run
var _boulder: NightWoods.RollingBoulder
var _run_logs: Array = []
var _run_on := false
var _run_done := false


func _build_boulder_run() -> void:
	var ledge := NightWoods.BoulderLedge.new()
	ledge.position = RUN_LEDGE
	add_child(ledge)
	_boulder = NightWoods.RollingBoulder.new()
	_boulder.position = Vector2(RUN_LEDGE.x + 10.0, RUN_LEDGE.y - 80.0 - NightWoods.RollingBoulder.R)
	_boulder.road_y = GROUND_Y
	_boulder.ravine_x = RUN_RAVINE[0]
	_boulder.crashed.connect(_on_boulder_crashed)
	add_child(_boulder)
	for k in RUN_STASH:
		_count_treasure(k)
	for x in RUN_LOGS:
		var log := NightWoods.FallenLog.new()
		log.position = Vector2(x, GROUND_Y)
		add_child(log)
		_run_logs.append(log)


func _update_boulder_run(_delta: float) -> void:
	if _run_done or _boulder == null:
		return
	var p := player.global_position
	if not _run_on:
		if p.x > RUN_TRIGGER and p.x < RUN_RAVINE[1] and not player.dead:
			_run_on = true
			_boulder.release()
			shake(10.0, 0.5)
			hud.say("CRACK! A BOULDER! RUN — if it catches you, you're flat!", 3.5)
		return
	if player.dead:
		_reset_run(false)
		return
	var bx := _boulder.position.x
	# the logs it reaches are smashed to splinters
	for log in _run_logs:
		if not log.smashed and bx + NightWoods.RollingBoulder.R > log.position.x - 40.0:
			log.smash()
			shake(6.0, 0.2)
	# the ground rumbles, harder the closer it gets
	var gap := p.x - bx
	if _boulder.state in ["drop", "roll"]:
		shake(clampf(1.0 - gap / 700.0, 0.0, 1.0) * 6.0 + 1.0, 0.08)
		# caught!
		if absf(gap) < NightWoods.RollingBoulder.R + 12.0 and p.y > _boulder.position.y - NightWoods.RollingBoulder.R - 50.0:
			_flattened()
			return
	# fell into one of the gaps
	if p.y > GROUND_Y + 90.0 and p.x > RUN_START and p.x < RUN_RAVINE[0]:
		_reset_run(true)


## Caught by the boulder: no second chances — it rolls right over him. He
## wakes by the last fire (the one before the pass, if he lit it).
func _flattened() -> void:
	shake(16.0, 0.6)
	var pop := Treasure.FloatText.new()
	pop.text = "SQUASH!!"
	pop.position = player.global_position + Vector2(-40, -120)
	add_child(pop)
	player.invuln = 0.0
	player.fury = -1.0
	if player.sun_t > 0.0:
		player.end_sunfire()          # not even the sun stops a boulder
	player.hurt(player.hp, _boulder.position.x)
	_run_on = false
	_boulder.reset()
	for log in _run_logs:
		log.restore()


## Fallen into a gap: back to the start of the pass, boulder back on its ledge.
func _reset_run(hurt: bool) -> void:
	_run_on = false
	_boulder.reset()
	for log in _run_logs:
		log.restore()
	if hurt:
		player.hurt(1, player.global_position.x - 40.0)
		if not player.dead:
			player.respawn_at(Vector2(RUN_START, GROUND_Y - 10.0))
			player.facing = 1
			hud.say("FLATTENED! Back you go — and this time, don't stop running!", 3.0)


func _on_boulder_crashed() -> void:
	_run_on = false
	_run_done = true
	shake(14.0, 0.8)
	hud.say("It plunges into the ravine — CRASH!! Something shakes loose from the cliff...", 4.0)
	var box := Treasure.Breakable.new()
	box.kind = "stash"
	box.contents = RUN_STASH
	box.level_id = "level2"
	box.id = "rstash"
	box.position = Vector2(RUN_RAVINE[1] + 110.0, GROUND_Y)
	add_child(box)


## The Hanging Gorge: the fallen giant, its vines, the ledge, the crumbling stones.
## The Mammoth Steppe: the split rock, the herd, the river and its ferry, the graveyard.
func _build_steppe() -> void:
	add_child(Steppe.KickWall.new(Rect2(CHIMNEY[0], CHIMNEY[1], CHIMNEY[2], CHIMNEY[3])))
	add_child(Steppe.KickWall.new(Rect2(CLIFF[0], CLIFF[1], CLIFF[2], GROUND_Y + 240.0 - CLIFF[1]), true))
	for s in CLIFF_STEPS:
		add_child(NightWoods.Crag.new(Rect2(s[0], s[1], s[2], GROUND_Y + 240.0 - float(s[1]))))
	for h in HERD:
		var m := Steppe.Mammoth.new()
		m.x0 = h[0]
		m.x1 = h[1]
		m.position = Vector2(h[2], GROUND_Y)
		m.speed = h[3]
		m.size = h[4]
		add_child(m)
	var river := Steppe.River.new()
	river.position = Vector2(RIVER[0], 0)
	river.w = RIVER[1] - RIVER[0]
	river.swept.connect(_on_swept)
	add_child(river)
	var bull := Steppe.Mammoth.new()
	bull.x0 = FERRY[0]
	bull.x1 = FERRY[1]
	bull.position = Vector2(FERRY[0], FERRY[2])
	bull.speed = FERRY[3]
	bull.rest = 2.2
	add_child(bull)
	for g in GRAVEYARD:
		var bones := Steppe.Skeleton.new()
		bones.position = Vector2(g[0], GROUND_Y)
		bones.size = g[1]
		add_child(bones)
	_note(12300, "Two walls, close together. Bounce wall to wall — up, up, UP!", 5.5)
	_note(13140, "Mammoths! Mind the feet. Ride the backs.", 5.0)
	_note(13720, "Too deep to swim. The old bull wades across — hop on!", 5.0)
	_note(14550, "A mammoth graveyard. Bones as big as huts. Spooky.", 5.0)


## The Tar Pits: pools of tar, logs that sink under him, a boulder stuck fast.
func _build_tar_pits() -> void:
	for tp in TAR_POOLS:
		var pool := TarPits.Pool.new()
		pool.position = Vector2(tp[0], 0)
		pool.w = tp[1] - tp[0]
		var bank: float = tp[0]
		pool.stuck.connect(func() -> void: _on_tar(bank))
		add_child(pool)
	for lg in TAR_LOGS:
		var lgn := TarPits.Log.new()
		lgn.position = Vector2(lg[0], GROUND_Y)
		lgn.w = lg[1]
		add_child(lgn)
	for r in TAR_ROCKS:
		add_child(NightWoods.Crag.new(Rect2(r[0], r[1], r[2], 140)))
	for i in TAR_LOOT.size():
		var l: Array = TAR_LOOT[i]
		_treasure(l[2], "t%d" % i, Vector2(l[0], l[1]))
	for gy in TAR_GEYSERS:
		var g := TarPits.Geyser.new()
		g.position = Vector2(gy[0], 0)
		g.offset = gy[1]
		add_child(g)
	var snap := TarPits.Snapper.new()
	snap.x0 = TAR_SNAPPER[0]
	snap.x1 = TAR_SNAPPER[1]
	add_child(snap)
	_note(15940, "Tar pits! Logs sink, tar spouts — keep hopping!", 5.0)
	_note(16900, "Yellow eyes in the tar... don't stand still!", 4.0)


## Thunder Canyon: the Sky Stones with their vines, the rest ledge, the
## floating rocks with the bats above them, and the outcrop with the cave.
func _build_canyon() -> void:
	# Stone k is at its nearest-left at t = k * beat/2 and its farthest-right
	# half a beat later — just as stone k+1 comes nearest-left: a wave.
	for k in SKY_STONES.size():
		var s: Array = SKY_STONES[k]
		var stone := Canyon.SkyStone.new()
		stone.kind = s[0]
		stone.position = Vector2(s[1], s[2])
		stone.amp = s[3]
		stone.vine_len = s[4]
		stone.look = s[5]
		stone.period = STONE_BEAT
		match stone.kind:
			"drift":
				stone.beat = -PI * 0.5 - k * PI
			"orbit":
				stone.beat = PI - k * PI
			_:
				stone.beat = -k * PI
		add_child(stone)
	var rocks: Array = []
	for r in FLOAT_ROCKS:
		var rock := Canyon.FloatRock.new()
		rock.position = Vector2(r[0], r[1])
		rock.w = r[2]
		rock.bob = r[3]
		add_child(rock)
		rocks.append(rock)
	var sky := Canyon.BatSky.new()
	sky.x0 = BAT_SKY[0]
	sky.x1 = BAT_SKY[1]
	sky.every = BAT_SKY[2]
	sky.rocks = rocks
	sky.player = player
	sky.level = self
	add_child(sky)
	add_child(NightWoods.Crag.new(Rect2(CANYON_OUTCROP[0], CANYON_OUTCROP[1], CANYON_OUTCROP[2], GROUND_Y + 240.0 - float(CANYON_OUTCROP[1]))))
	for i in CANYON_LOOT.size():
		var l: Array = CANYON_LOOT[i]
		_treasure(l[2], "n%d" % i, Vector2(l[0], l[1]))
	_note(17920, "Flying rocks! Ride their vines — they keep a rhythm.", 4.5)
	_note(20220, "Phew. A fire. Rest.", 3.0)
	_note(20500, "Floating rocks! Hop across — and watch the sky.", 4.0)
	_note(22620, "The great tree! At last.", 3.5)


## The bats start on him over the floating rocks.
func _bats_begin() -> void:
	hud.say("BATS! When one screeches, jump its swoop — or bonk it!", 3.5)


## In the tar: stuck fast, then hauled out on the near bank.
func _on_tar(bank: float) -> void:
	player.respawn_at(Vector2(bank - 40.0, GROUND_Y - 10.0))
	hud.say("Stuck in the tar! Out he comes — sticky and grumpy.", 3.0)


## The animals who talk: Moss over the gorge, Nutmeg by her creek past the tar pits.
## Nobody starts talking on their own: a bubble shows over them when he's
## close, and E (or TALK) starts it.
func _build_friends() -> void:
	var creek := Friends.Creek.new()
	creek.position = Vector2(CREEK[0], 0)
	creek.w = CREEK[1]
	add_child(creek)
	moss = Friends.Moss.new()
	moss.position = MOSS_AT
	add_child(moss)
	nutmeg = Friends.Nutmeg.new()
	nutmeg.position = NUTMEG_AT
	add_child(nutmeg)
	shivers = WINDBREAK.build(self)       # SIDE MISSION: a windbreak for a freezing stranger
	errands = ERRANDS.build(self)          # and Pip's goat, Taka's foot, Ooma's fire


var _moss_met := false
var _moss_clue := false          ## she told him where the shovel went
var _shovel_hint := 0            ## how many times the clay has CLANGed (SHOVEL_HINTS)
var _talk_again := 0           ## cycles the "again" lines


## A sloth, in no hurry. Short — she'd never manage a long one.
func _meet_moss() -> void:
	if GameState.mystery("shovel") == "open" and not _moss_clue:
		# she saw where it went — if he wakes her up
		_moss_clue = true
		_moss_met = true
		moss.asleep = false
		_talk([
			["MOSS", "...Mm? A digging stone? ...On a stick?"],
			["MOSS", "A big bird... dropped one. Into the THORNS. Way up... where the wind howls... past the moon rocks."],
			{"choose": [
				["Up there?!", [["MOSS", "...Higher than... I have ever bothered... to go."]]],
				["Thorns? Ow.", [["MOSS", "Wet thorns. They won't burn... for just any fire. ...Zzz."]]],
			]},
			["MOSS", "...Bring the sun. ...Zzz.", func() -> void: moss.asleep = true],
		])
		return
	if _moss_met:
		_again(["Moss, asleep:  \"Zzz... Tuesday... zzz\"", "Moss, asleep:  \"Mmm... five more minutes... or years...\"",
			"Moss snores like a very small volcano."])
		return
	_moss_met = true
	_talk([
		["MOSS", "...Oh. A visitor. I'll say hello... tomorrow."],
		{"choose": [
			["Hello?", [["MOSS", "...Too fast. My ears are still... on \"Hel\"."]]],
			["What you doing?", [["MOSS", "Hanging. It's a full-time job. No... breaks."]]],
			["(poke her)", [["MOSS", "...Ow. I'll feel that... next week."]]],
		]},
		["MOSS", "Tip: vines... let go at the TOP. ...Zzz.", func() -> void: moss.asleep = true],
	])


## A beaver, furious: a monkey stole the red stone from her dam.
func _meet_nutmeg() -> void:
	if _met_nutmeg:
		_again(["NUTMEG:  \"Still cross. VERY cross.\"", "NUTMEG:  \"See that monkey? Give him a look. A HARD one.\"",
			"NUTMEG:  \"My dam. My rules. No monkeys.\""])
		return
	_talk([
		["NUTMEG", "A MONKEY stole my glowing red stone! Out of MY dam! Then rode off on a mammoth — LAUGHING!"],
		{"choose": [
			["Bad monkey.", [["NUTMEG", "The WORST. I'm making up a song about how bad he is."]]],
			["Heh. Funny.", [["NUTMEG", "NOT funny! ...Okay. On a mammoth. A bit funny."]]],
			["Where he go?", [["NUTMEG", "Up the great tree. Monkeys take every shiny thing to their king."]]],
		]},
		["NUTMEG", "Find my stone? Keep it. Anyone's better than a monkey.", func() -> void: nutmeg.calm = true],
	], func() -> void: _met_nutmeg = true)


## A short line for talking to someone again — a different one each time.
func _again(lines: Array) -> void:
	hud.say(lines[_talk_again % lines.size()], 3.0)
	_talk_again += 1


## In the river: the current throws him back out on the near bank.
func _on_swept() -> void:
	player.respawn_at(Vector2(RIVER[0] - 40.0, GROUND_Y - 10.0))
	hud.say("Brr! Too deep — the river spits him back out.", 3.0)


func _build_gorge() -> void:
	var giant := NightWoods.FallenGiant.new()
	giant.position = Vector2(GORGE_TRUNK[0], GORGE_TRUNK[2])
	giant.w = GORGE_TRUNK[1] - GORGE_TRUNK[0]
	add_child(giant)
	giant.stomped_on.connect(_on_giant_stomped)
	for v in GORGE_VINES:
		var vine := NightWoods.Vine.new()
		vine.position = Vector2(v[0], v[1])
		vine.length = v[2]
		add_child(vine)
	add_child(NightWoods.Crag.new(Rect2(GORGE_LEDGE[0], GORGE_LEDGE[1], GORGE_LEDGE[2], 18)))
	for c in GORGE_CRUMBLES:
		var rock := NightWoods.CrumbleRock.new()
		rock.position = Vector2(c[0], c[1])
		rock.w = c[2]
		rock.player = player
		add_child(rock)


## A METEOR STOMP on the fallen giant: Moss clings on in terror, and what was
## tucked in its bark shakes loose and flies straight to him.
var _gw_out := {}
var _moss_shaken := 0
func _on_giant_stomped(level: int, at: Vector2) -> void:
	moss.scare(3.5 if level == 1 else 5.0)
	var eek := CaveMan.WordPop.new()
	eek.text = "EEEK!"
	eek.size = 24
	eek.color = Color("ffe7b0")
	eek.centered = true
	eek.position = moss.global_position + Vector2(48, 120)
	add_child(eek)
	hud.say(MOSS_SHAKEN[_moss_shaken % MOSS_SHAKEN.size()], 3.5)
	_moss_shaken += 1
	var n := 3 if level == 1 else 5
	var shaken := 0
	for i in GORGE_WOOD_LOOT.size():
		if n <= 0:
			break
		var id := "gw%d" % i
		if GameState.is_taken("level2", id) or _gw_out.has(id):
			continue
		_gw_out[id] = true
		n -= 1
		var p := Treasure.Pickup.new()
		p.kind = GORGE_WOOD_LOOT[i]
		p.level_id = "level2"
		p.id = id
		p.position = Vector2(at.x + randf_range(-200.0, 200.0), at.y + 20.0)
		p.vel = Vector2(randf_range(-200.0, 200.0), randf_range(-760.0, -600.0))     # high out of the bark, then to him
		p.homing = player
		_on_treasure_popped(p)
		add_child(p)
		shaken += 1
	if shaken > 0:
		var w := CaveMan.WordPop.new()
		w.text = "SHAKEN LOOSE! x%d" % shaken
		w.size = 26
		w.color = Color("ffe066")
		w.star = Color("e8823a", 0.85)
		w.centered = true
		w.life = 1.3
		w.position = at + Vector2(0, -190)
		add_child(w)


func _build_long_dark() -> void:
	for v in VINES:
		var vine := NightWoods.Vine.new()
		vine.position = Vector2(v[0], v[1])
		vine.length = v[2]
		add_child(vine)
	for c in CRUMBLES:
		var rock := NightWoods.CrumbleRock.new()
		rock.position = Vector2(c[0], c[1])
		rock.w = c[2]
		rock.player = player
		add_child(rock)
	for f in FIREFLIES:
		var ff := NightWoods.FireflySwarm.new()
		ff.position = Vector2(f[0], f[1])
		add_child(ff)
	for w in WATCHERS:
		var eyes := NightWoods.Watcher.new()
		eyes.position = Vector2(w[0], w[1])
		eyes.player = player
		add_child(eyes)
	for c in CLAW_MARKS:
		var marks := NightWoods.ClawMarks.new()
		marks.position = Vector2(c[0], c[1])
		add_child(marks)


## The wolves run past him (from something), then the roar puts his torch out.
func _update_long_dark() -> void:
	var x := player.global_position.x
	if not _panicked and x > PANIC_AT and x < LEVEL_W:
		_panicked = true
		for i in 3:
			var wolf := NightBeasts.Wolf.new()
			wolf.panic = true
			wolf.panic_end = 25660.0
			wolf.left_x = 25000.0
			wolf.right_x = 29000.0
			wolf.position = Vector2(x + 720.0 + i * 70.0, GROUND_Y)
			add_child(wolf)
		hud.say("The wolves come running — straight past him. They're running FROM something.", 4.5)
	if not _snuffed and x > SNUFF_AT and x < LEVEL_W:
		_snuffed = true
		cam.offset = Vector2(0, 0)
		if player.has_torch:
			player.torch_fuel = 0.0
		_talk([
			["", "A roar rolls through the trees, so deep he feels it in his chest."],
			["", "A gust tears the flame off his torch. The dark is total."],
			["", "Only the fireflies move. Follow them."],
		])


## ---------------------------------------------------------------- the end
func _build_the_end() -> void:
	# the Toolmaker's home, and the man himself
	var camp := NightWoods.ToolmakerCamp.new()
	camp.position = CAMP_AT
	add_child(camp)
	toolmaker = NightBeasts.Toolmaker.new()
	toolmaker.position = TOOLMAKER_AT
	toolmaker.player = player
	add_child(toolmaker)
	# the clearing: two stone bowls, two ledges, a gate that shuts behind him
	_build_trial()
	var arena_bowls: Array = []
	for b in BRAZIERS:
		var bowl := NightWoods.Brazier.new()
		bowl.position = Vector2(b[0], b[1])
		add_child(bowl)
		arena_bowls.append(bowl)
	for l in ARENA_LEDGES:
		add_child(NightWoods.Crag.new(Rect2(l[0], l[1], l[2], 18)))
	var lair := NightWoods.Lair.new()
	lair.position = Vector2(LAIR_X, GROUND_Y)
	add_child(lair)
	var snag := NightWoods.Snag.new()
	snag.position = Vector2(BONGO_PERCH.x - 20.0, GROUND_Y)
	snag.height = 330.0
	add_child(snag)
	add_child(NightWoods.Branch.new(Rect2(BONGO_PERCH.x - 70.0, BONGO_PERCH.y, 140, 14), true))
	_gate = StaticBody2D.new()
	var cs := CollisionShape2D.new()
	var sh := RectangleShape2D.new()
	sh.size = Vector2(30, 1400)
	cs.shape = sh
	cs.position = Vector2(ARENA.position.x - 15.0, 0)
	cs.disabled = true
	_gate.add_child(cs)
	add_child(_gate)
	scar = OldScar.new()
	scar.position = Vector2(LEVEL_W + 300.0, GROUND_Y)
	scar.arena_l = ARENA.position.x
	scar.arena_r = ARENA.end.x
	scar.lair_x = LAIR_X
	scar.ledges = []
	for l in ARENA_LEDGES:
		scar.ledges.append([l[0], l[0] + l[2], l[1]])
	scar.braziers = arena_bowls
	scar.siege_wave.connect(_on_siege_wave)
	scar.rock_in_teeth.connect(func() -> void:
		hud.say("A rock right in the teeth! He's reeling — hit him!", 3.0))
	scar.roared.connect(_on_scar_roar)
	scar.phase_changed.connect(_on_scar_phase)
	scar.beaten.connect(_on_scar_beaten)
	scar.fang_out.connect(_on_fang_out)
	add_child(scar)
	arena_bongo = NightBeasts.Elder.new()
	arena_bongo.position = BONGO_PERCH
	arena_bongo.show_box = false
	arena_bongo.has_gem = false
	arena_bongo.player = player
	arena_bongo.visible = false
	add_child(arena_bongo)
	player.died.connect(_on_died_in_fight)
	_note(30200, "Firelight under the rocks. Someone lives here.", 3.0)


## ---------------------------------------------------------------- the Three Fires
var _trial_lit := 0
var _trial_gate: NightWoods.PalisadeGate


func _build_trial() -> void:
	var rock := NightWoods.CrackedRock.new()
	rock.position = TRIAL_ROCK
	rock.broken.connect(func() -> void: hud.say("The boulder bursts apart!", 2.0))
	add_child(rock)
	add_child(NightWoods.Crag.new(Rect2(TRIAL_LEDGE[0], TRIAL_LEDGE[1], TRIAL_LEDGE[2], 18)))
	for b in TRIAL_BOWLS:
		var bowl := NightWoods.Brazier.new()
		bowl.position = Vector2(b[0], b[1])
		bowl.kindled.connect(_on_trial_fire)
		add_child(bowl)
	for w in TRIAL_WOLVES:
		var wolf := NightBeasts.Wolf.new()
		wolf.left_x = w[0]
		wolf.right_x = w[1]
		wolf.position = Vector2(w[2], GROUND_Y)
		add_child(wolf)
	_trial_gate = NightWoods.PalisadeGate.new()
	_trial_gate.position = Vector2(TRIAL_GATE_X, GROUND_Y)
	add_child(_trial_gate)
	_note(TRIAL_ROCK.x - 140.0, "A cracked boulder. Something heavy could smash it.", 3.5)


func _on_trial_fire() -> void:
	_trial_lit += 1
	if _trial_lit < TRIAL_BOWLS.size():
		hud.say("A bowl of fire! %d of %d." % [_trial_lit, TRIAL_BOWLS.size()], 2.5)
		return
	hud.say("The third fire! The old stakes across the path catch light...", 4.0)
	hud.set_quest("Face Old Scar")
	_trial_gate.burn()


func _update_toolmaker() -> void:
	pass       # (talking to him is his choice now: see _update_talkers)


## The Toolmaker: short and gruff, then his shop. After that, just the shop.
func _meet_toolmaker() -> void:
	if _met_toolmaker:
		hud.say("TOOLMAKER:  \"Back again? Let's see your shells.\"", 2.0)
		_open_shop()
		return
	_met_toolmaker = true
	var lines := [
		["TOOLMAKER", "A live one! Most who walk the Long Dark end up as Old Scar's supper."],
		{"choose": [
			["Ugh. Not supper.", [["TOOLMAKER", "Ha! Good. Supper never talks back."]]],
			["Old Scar?", [["TOOLMAKER", "The sabre-tooth. He took my arm. I took his tooth. We're even-ish."]]],
		]},
		["TOOLMAKER", "He hates fire in his face: hold your torch at him when he leaps. Light the three bowls past my fire and the way opens."],
	]
	if gem_found and GameState.gems.get("level2", "") == "found":
		lines.append(["TOOLMAKER", "Wait — a FIRESTONE?! Forty winters I've waited. Pick it from my wares. Free."])
	else:
		lines.append(["TOOLMAKER", "Bring me a Firestone and I'll make you something HE'S scared of. Now — shells?"])
	_talk(lines, _open_shop, toolmaker)


## ---------------------------------------------------------------- talking
## Nobody starts talking on their own: when he's close to someone he can
## talk to, a bubble with an "E" bobs over them, and E (or TALK on a touch
## screen) starts the talk. [node, reach x, reach y, bubble offset, start]
var _talkers: Array = []
var _prompt: Friends.TalkPrompt
var _talk_key := false


func _build_talkers() -> void:
	_prompt = Friends.TalkPrompt.new()
	add_child(_prompt)
	_talkers = [
		[moss, 190.0, 420.0, Vector2(-34, 120), _meet_moss],
		[nutmeg, 150.0, 60.0, Vector2(-10, -122), _meet_nutmeg],
		[elder, 190.0, 30.0, Vector2(0, -118), _meet_elder],
		[toolmaker, 150.0, 40.0, Vector2(0, -150), _meet_toolmaker],
		[shivers, 260.0, 70.0, Vector2(WINDBREAK.SHIVERS_X, -150), func() -> void: shivers.meet()],
		[errands[0], 130.0, 70.0, Vector2(-44, -110), func() -> void: errands[0].meet()],
		[errands[1], 170.0, 70.0, Vector2(0, -130), func() -> void: errands[1].meet()],
		[errands[2], 170.0, 70.0, Vector2(0, -140), func() -> void: errands[2].meet()],
	]


func _update_talkers() -> void:
	var press: bool = Input.is_physical_key_pressed(KEY_E) or player.touch.get("talk", false)
	var fresh := press and not _talk_key
	_talk_key = press
	_prompt.shown = false
	if player.dead or player.talking or player.fury >= 0.0 or _fight or not player.is_on_floor():
		return
	var best: Array = []
	var best_d := INF
	for t in _talkers:
		var n: Node2D = t[0]
		if n == null or not is_instance_valid(n):
			continue
		var d := player.global_position - n.global_position
		if absf(d.x) < float(t[1]) and absf(d.y) < float(t[2]) and absf(d.x) < best_d:
			best = t
			best_d = absf(d.x)
	if best.is_empty():
		return
	_prompt.shown = true
	_prompt.global_position = (best[0] as Node2D).global_position + (best[3] as Vector2)
	if fresh:
		(best[4] as Callable).call()


## ---------------------------------------------------------------- the shop
## ---------------------------------------------------------------- the shop
## [id, tab, name, what it is]
const WARES := [
	["club", "weapons", "Wooden Club", "A quick overhead BONK. Hold attack and let go: HOME RUN! A huge swing that sends small beasts flying."],
	["axe", "weapons", "Flint Axe", "Fast slashes: tap three times for slash, back-slash, CHOP! Hold attack and let go: it spins out through everything, and flies back to his hand."],
	["hammer", "weapons", "Firestone Hammer", "Heaved up and SMASHED down: slow, heavy, the ground shakes. Hold attack and let go: FIRE SLAM! A wave of fire rolls along the ground."],
	["plain", "costumes", "Plain Hide", "His everyday hide. Nothing wrong with it."],
	["wolf_hood", "costumes", "Wolf Hood", "A wolf's head worn as a hood, its grey pelt down his back. Let the pack wonder whose side he's on."],
	["ember_paint", "costumes", "Ember Paint", "Charcoal and ochre painted like flames rising up his chest, and a black band across the eyes: the mark of those who tamed fire."],
	["bear_cloak", "costumes", "Bear Cloak", "A heavy cloak of bear fur, round ears on the hood, fastened with two bear claws. Warm on the longest night."],
	["firekeeper", "costumes", "Firekeeper", "A leather headband with a glowing ember charm, feathers, ash stripes — and a pouch of live embers at his belt."],
	["fig", "supplies", "Roast Fig", "Figs roasted in the embers. Eat one (press H, or tap it) for two hearts back."],
	["heart", "supplies", "Extra Heart", "Bitter roots, chewed long: one more heart, for good. (Up to two.)"],
	["torch", "supplies", "Long-burning Torch", "Resin-soaked wrappings: his torch burns 40% longer."],
	["pouch", "supplies", "Bigger Pouch", "More room: wood, rocks, berries — and one more roast fig."],
]
const LEGACY_SKINS := {"wolf_pelt": "Wolf Pelt", "war_paint": "War Paint", "bone_necklace": "Bone Necklace"}


## What something costs here, from the level's treasure.
func price_of(id: String) -> int:
	var f: float = ECONOMY.get(id, 0.0)
	if id == "heart" and int(GameState.upgrades["heart"]) >= 1:
		f *= 1.5
	return int(round(_treasure_total * f / 5.0)) * 5


func _open_shop() -> void:
	var shop := Shop.new()
	shop.player = player
	shop.list_items = _shop_items
	shop.buy = _shop_buy
	add_child(shop)


func _shop_items() -> Array:
	var out: Array = []
	var wares: Array = WARES.duplicate()
	for id in LEGACY_SKINS:
		if GameState.skins.has(id):
			wares.append([id, "costumes", LEGACY_SKINS[id], "One of his older looks."])
	for w in wares:
		var id: String = w[0]
		var tab: String = w[1]
		var item := {"id": id, "tab": tab, "name": w[2], "desc": w[3], "icon": id, "price": price_of(id),
			"status": "buy", "can": false, "note": "", "skin": "", "weapon": ""}
		match tab:
			"weapons":
				item["weapon"] = id
				if GameState.weapons.has(id):
					item["status"] = "on" if GameState.weapon == id else "equip"
					item["note"] = "CARRYING"
					item["can"] = true
				elif id == "hammer":
					# forging is the Toolmaker's work: the Firestone AND shells
					var gem: String = GameState.gems.get("level2", "")
					if gem == "found":
						item["note"] = "THE FIRESTONE + SHELLS"
						item["can"] = GameState.shells >= item["price"]
					else:
						item["status"] = "locked"
						item["note"] = "NEEDS A FIRESTONE"
				else:
					item["can"] = GameState.shells >= item["price"]
			"costumes":
				item["skin"] = id
				if id in LEGACY_SKINS:
					item["icon"] = "plain"
				if GameState.skins.has(id) or id == "plain":
					item["status"] = "on" if GameState.skin == id else "equip"
					item["note"] = "WEARING"
					item["can"] = true
				else:
					item["can"] = GameState.shells >= item["price"]
			"supplies":
				if id == "fig":
					if GameState.figs >= GameState.fig_max():
						item["status"] = "maxed"
						item["note"] = "POUCH FULL (%d)" % GameState.figs
					else:
						item["name"] = "Roast Fig  (%d/%d)" % [GameState.figs, GameState.fig_max()]
						item["can"] = GameState.shells >= item["price"]
				else:
					var have: int = GameState.upgrades[id]
					if have >= int(GameState.UPGRADE_MAX[id]):
						item["status"] = "maxed"
						item["note"] = "HAVE IT"
					else:
						item["can"] = GameState.shells >= item["price"]
		out.append(item)
	return out


## Buying, or putting on something he already has. Everything is saved at once.
func _shop_buy(id: String) -> String:
	var said := ""
	if id in ["club", "axe", "hammer"]:
		if GameState.weapons.has(id):
			GameState.weapon = id
			said = "He takes up the %s." % _ware_name(id)
		elif id == "hammer":
			var cost := price_of("hammer")
			if GameState.shells < cost:
				return "Forging takes the Firestone AND %d shells." % cost
			GameState.shells -= cost
			hud.set_shells(GameState.shells)
			GameState.gems["level2"] = "forged"
			GameState.weapons.append("hammer")
			GameState.weapon = "hammer"
			GameState.save()
			call_deferred("_forge_ceremony")
			return "The Toolmaker takes the Firestone..."
		else:
			var price := price_of(id)
			if GameState.shells < price:
				return "Not enough shells."
			GameState.shells -= price
			GameState.weapons.append(id)
			GameState.weapon = id
			said = "The %s! Tap to slash, three times fast for a CHOP. Hold, then let go, to throw it." % _ware_name(id)
		player.axe = GameState.weapon == "axe"
		player.hammer = GameState.weapon == "hammer"
	elif id == "fig":
		var price := price_of(id)
		if GameState.shells < price:
			return "Not enough shells."
		GameState.shells -= price
		GameState.figs += 1
		hud.set_figs(GameState.figs)
		said = "A roast fig, wrapped in a leaf. (Press H to eat one.)"
	elif id in GameState.upgrades:
		var price := price_of(id)
		if GameState.shells < price:
			return "Not enough shells."
		GameState.shells -= price
		GameState.upgrades[id] = int(GameState.upgrades[id]) + 1
		_apply_upgrade(id)
		said = "Done. The Toolmaker grunts, pleased."
	else:
		# a costume: bought once, then worn any time
		if not GameState.skins.has(id) and id != "plain":
			var price := price_of(id)
			if GameState.shells < price:
				return "Not enough shells."
			GameState.shells -= price
			GameState.skins.append(id)
		GameState.skin = id
		player.skin = id
		said = "He puts on the %s. Very fine." % _ware_name(id)
	GameState.save()
	hud.set_shells(GameState.shells)
	return said


func _ware_name(id: String) -> String:
	for w in WARES:
		if w[0] == id:
			return w[2]
	return LEGACY_SKINS.get(id, id)


## The forging: the story of the hammer, the hammering, and then the moment he
## holds it up — the Firestone Hammer.
func _forge_ceremony() -> void:
	for c in get_children():
		if c is Shop:
			c._age = 1.0
			c._close()
	_talk([
		["TOOLMAKER", "Forty winters ago, the night Old Scar took my arm... I hit him with this. Broke his fang clean off."],
		["TOOLMAKER", "Now hold still. Let's put the Firestone where it belongs.", func() -> void: toolmaker.forging = 2.2],
		["", "Clang. Clang. CLANG. Sparks fly into the dark. The stone in the hammer begins to glow."],
	], _hammer_reveal, toolmaker)


func _hammer_reveal() -> void:
	player.hammer = true
	player.axe = false
	shake(6.0, 0.4)
	var card := ItemGet.new()
	card.title = "FIRESTONE HAMMER"
	card.line = "Hold ATTACK to raise it overhead... let go to SLAM! A wave of fire rolls along the ground: it burns, it lights fires from afar, and it trips anything charging at you."
	card.icon = _hammer_icon
	card.player = player
	card.done.connect(func() -> void:
		_talk([["TOOLMAKER", "Ha! Now it burns like the stone. Go on — show me on those three bowls. And give Old Scar my regards."]]))
	add_child(card)


## The hammer, big, for the item card.
func _hammer_icon(c: Control) -> void:
	# the haft: pale wood, outlined, bound with sinew
	c.draw_line(Vector2(-78, 92), Vector2(26, -24), Color("3a2a18"), 20.0, true)
	c.draw_line(Vector2(-78, 92), Vector2(26, -24), Color("c49a64"), 13.0, true)
	for k in 3:
		var q := Vector2(-70, 83).lerp(Vector2(26, -24), 0.08 + k * 0.08)
		c.draw_line(q + Vector2(-10, -9), q + Vector2(10, 9), Color("6b4a2a"), 5.0, true)
	# the head: a heavy stone block, outlined, with the Firestone set in it
	var head := PackedVector2Array([Vector2(-10, -104), Vector2(96, -22), Vector2(62, 18), Vector2(-42, -64)])
	c.draw_colored_polygon(head, Color("8a8378"))
	c.draw_colored_polygon(PackedVector2Array([Vector2(-6, -98), Vector2(88, -24), Vector2(76, -10), Vector2(-20, -84)]), Color("a39b8f"))
	c.draw_polyline(PackedVector2Array([head[0], head[1], head[2], head[3], head[0]]), Color("3d3831"), 5.0, true)
	c.draw_circle(Vector2(28, -43), 34.0, Color(Pal.EMBER_GLOW, 0.45))
	c.draw_colored_polygon(PackedVector2Array([Vector2(28, -68), Vector2(52, -43), Vector2(28, -18), Vector2(4, -43)]), Pal.GEM)
	c.draw_colored_polygon(PackedVector2Array([Vector2(28, -68), Vector2(52, -43), Vector2(28, -43)]), Pal.GEM_LIGHT)
	c.draw_polyline(PackedVector2Array([Vector2(28, -68), Vector2(52, -43), Vector2(28, -18), Vector2(4, -43), Vector2(28, -68)]), Color("5a1016"), 3.0, true)


func _apply_upgrade(id: String) -> void:
	match id:
		"heart":
			player.max_hp += 1
			player.hp += 1
			hud.max_hp = player.max_hp
			player.hp_changed.emit(player.hp)
		"torch":
			player.torch_burn = CaveMan.TORCH_BURN * (1.0 + 0.4 * int(GameState.upgrades["torch"]))
		"pouch":
			player.max_wood += 1
			player.max_rocks += 2
			player.max_berries += 1
			hud.set_figs(GameState.figs)
		"club":
			player.club_bonus = int(GameState.upgrades["club"])


## ---------------------------------------------------------------- the fight
func _update_fight(delta: float) -> void:
	if _scar_beaten or player.dead:
		return
	if not _fight:
		if player.global_position.x > ARENA.position.x + 160.0 and player.global_position.x < LEVEL_W and not player.talking:
			_start_fight()
		return
	hud.set_boss(scar.ratio())
	_update_siege(delta)
	# Old Bongo, in the treetops: helps only if the troop was spared
	_bongo_cd -= delta
	if monkey_kills == 0 and _bongo_helps < 2 and _bongo_cd <= 0.0 and player.hp <= 2:
		_bongo_helps += 1
		_bongo_cd = 8.0
		var gift := NightBeasts.GiftBanana.new()
		gift.setup(arena_bongo.global_position + Vector2(10, -40), player.global_position)
		add_child(gift)
		scar.distract(arena_bongo.global_position)
		hud.say("OLD BONGO:  \"Here! Catch! Hey, you big ugly cat — look at ME!\"", 3.0)


func _start_fight() -> void:
	_fight = true
	_gate.get_child(0).set_deferred("disabled", false)
	_apply_region(3)
	scar.start()
	arena_bongo.visible = true
	hud.set_boss(1.0)
	hud.say("Something moves in the dark at the far end of the clearing...", 2.5)
	var line := "OLD BONGO (from the treetops):  \"Hairless one! Keep your little sun in his face — he hates it!\""
	if monkey_kills > 0:
		line = "OLD BONGO (from the treetops):  \"You hit my family. Good luck, hairless one.\""
	get_tree().create_timer(6.5).timeout.connect(func() -> void: hud.say(line, 4.0))


func _on_scar_roar() -> void:
	if not _fight:
		return
	if scar.state == "intro":
		# his entrance: the name card, and the torch shudders
		hud.title_card("OLD SCAR", "Terror of the Long Dark")
		return
	if player.hammer:
		hud.say("He roars — but the Firestone keeps the flame alive. The torch burns on.", 3.0)
	elif player.has_torch and player.torch_fuel > 0.0:
		player.torch_fuel = 0.0
		hud.say("His roar snuffs the torch! Relight it at a stone bowl.", 3.0)
	for i in 4:
		var rock := NightWoods.FallingRock.new()
		rock.floor_y = GROUND_Y
		rock.position = Vector2(clampf(player.global_position.x + randf_range(-260.0, 260.0), ARENA.position.x + 60.0, ARENA.end.x - 60.0), 0)
		rock.delay = 0.7 + i * 0.25
		add_child(rock)


## ---------------------------------------------------------------- the siege
## At half his health Old Scar leaps onto his lair rock and howls, and the
## night answers in three waves — 2 wolves, then 3, then 4 bats out of his
## cave. The wolves he calls are in a frenzy: the torch won't hold them off.
var _wave: Array = []            ## what's still alive of the current wave
var _wave_n := 0
var _wave_clear := -1.0          ## counting down to the next wave, once one is beaten


func _on_siege_wave(n: int) -> void:
	_wave_n = n
	_wave_clear = -1.0
	_wave.clear()
	match n:
		1:
			hud.say("Old Scar leaps onto his rock and HOWLS — and the pack answers! TWO WOLVES!", 4.0)
			_wave_wolf(ARENA.position.x + 70.0)
			_wave_wolf(LAIR_X - 160.0)
		2:
			hud.say("He howls again — THREE WOLVES this time!", 3.5)
			_wave_wolf(ARENA.position.x + 70.0)
			_wave_wolf((ARENA.position.x + ARENA.end.x) * 0.5)
			_wave_wolf(LAIR_X - 160.0)
		3:
			hud.say("BATS! They pour out of his lair!", 3.5)
			for i in 4:
				var bat := NightBeasts.Bat.new()
				bat.ground_y = GROUND_Y
				bat.position = Vector2(LAIR_X - 60.0 - i * 26.0, GROUND_Y - 110.0 - (i % 2) * 34.0)
				bat.roam_x = 1100.0
				bat.roam_y = 240.0
				add_child(bat)
				_wave.append(bat)


func _wave_wolf(x: float) -> void:
	var wolf := NightBeasts.Wolf.new()
	wolf.left_x = ARENA.position.x + 60.0
	wolf.right_x = ARENA.end.x - 60.0
	wolf.position = Vector2(x, GROUND_Y)
	wolf.frenzy = true
	add_child(wolf)
	# the pack he calls: many of them, each a little lighter than a wolf of the woods
	wolf.hp = 5
	wolf.lunge_cd = randf_range(0.6, 1.6)
	wolf.state = "hunt"
	_wave.append(wolf)


func _update_siege(delta: float) -> void:
	if _wave_n == 0 or _wave_n > 3:
		return
	if _wave_clear < 0.0:
		var alive := _wave.filter(func(c): return is_instance_valid(c) and c.dying <= 0.0)
		if alive.is_empty():
			_wave_clear = 1.6
			if _wave_n == 3:
				hud.say("The last of them falls... Old Scar crouches on his rock — HE'S COMING DOWN!", 3.5)
			else:
				hud.say("Beaten back! But he's drawing breath to howl again...", 2.5)
		return
	_wave_clear -= delta
	if _wave_clear <= 0.0:
		_wave_clear = -1.0
		if _wave_n == 3:
			_wave_n = 4
		scar.next_wave()


func _clear_siege() -> void:
	for c in _wave:
		if is_instance_valid(c):
			c.queue_free()
	_wave.clear()
	_wave_n = 0
	_wave_clear = -1.0


func _on_scar_phase(ph: int) -> void:
	if ph == 2:
		hud.say("OLD BONGO:  \"He's calling the others! Beat them, and he'll have to come down to you!\"", 4.0)
	elif ph == 3:
		hud.say("OLD BONGO:  \"He's charging blind! Step aside — let him hit the rocks!\"", 4.0)


func _on_died_in_fight() -> void:
	if not _fight:
		return
	# back to the Toolmaker's fire; the beast goes back into the dark. A
	# checkpoint: once the siege has been beaten, he comes back at half his
	# health with it behind him, rather than all of it to do again.
	_fight = false
	var siege_beaten := scar._siege >= 4
	_clear_siege()
	scar.reset_fight()
	if siege_beaten:
		scar.hp = OldScar.MAX_HP / 2
		scar.phase = 2
		scar._siege = 4
		hud.say("Old Scar still bears his wounds — and the pack he called is gone.", 3.5)
	arena_bongo.visible = false
	_gate.get_child(0).set_deferred("disabled", true)
	hud.set_boss(-1.0)


func _on_scar_beaten() -> void:
	_fight = false
	_scar_beaten = true
	hud.set_boss(-1.0)
	shake(12.0, 0.9)
	_gate.get_child(0).set_deferred("disabled", true)


## Thrown down, his broken fang flies out of his jaw.
func _on_fang_out(at: Vector2) -> void:
	var fang := Caves.KeyItem.new()
	fang.real = false
	fang.position = Vector2(clampf(at.x, ARENA.position.x + 60.0, ARENA.end.x - 60.0), GROUND_Y)
	fang.taken.connect(func(_r: bool) -> void: _on_fang())
	add_child(fang)
	hud.say("His broken fang flies from his jaw! Old Scar staggers up... and limps away into the dark.", 5.0)


func _on_fang() -> void:
	if not ("sabre_fang" in GameState.trophies):
		GameState.trophies.append("sabre_fang")
	GameState.save()
	finished = true
	_dawn()


## ---------------------------------------------------------------- dawn, and the scroll
func _dawn() -> void:
	var tw := create_tween()
	tw.tween_property(night, "extra", -0.62, 5.0)
	tw.parallel().tween_property(sky, "dusk", 1.0, 5.0)
	_talk([
		["", "Old Scar's broken fang. Sharp as a spearhead, and longer than his hand."],
		["", "The sky is going grey in the east. The long night is over."],
		["", "He carries the fire home. Tonight, for the first time, his people will sit around a hearth of their own."],
	], _show_scroll)


func _show_scroll() -> void:
	var gem := "missed"
	match GameState.gems.get("level2", ""):
		"forged":
			gem = "Firestone Hammer"
		"found":
			gem = "found"
	var found := 0
	for s in SECRETS:
		if _secrets.has(s):
			found += 1
	var scroll := LevelEnd.new()
	scroll.title = "LEVEL 2   DISCOVERY OF FIRE"
	scroll.lines = [
		["Shells", "%d / %d" % [_treasure_found(), _treasure_total]],
		["Bones", "%d" % _run_bones],
		["Gem", gem],
		["Secrets", "%d / %d" % [found, SECRETS.size()]],
		["Troop spared", "%d / %d" % [MONKEYS.size() - monkey_kills, MONKEYS.size()]],
		["Old Scar", "driven off"],
		["Time", "%d:%02d" % [int(_time) / 60, int(_time) % 60]],
	]
	scroll.done.connect(func() -> void:
		scroll.queue_free()
		hud.say("To be continued: Level 3 — the fang becomes a spear.", 999.0))
	add_child(scroll)


## ---------------------------------------------------------------- treasure
func _build_treasure() -> void:
	# shells are remembered once found (per save); bones come back every visit
	GameState.ensure_loaded()
	var n := 0
	for r in SHELL_ROWS:
		var count: int = r[3]
		for i in count:
			var x := lerpf(r[0], r[1], (i + 0.5) / count)
			_treasure("shell" if i % 2 == 1 else "bone", "s%d" % n, Vector2(x, float(r[2]) - 24.0))
			n += 1
	for p in SHELL_POINTS:
		_treasure(p[2] if p.size() > 2 else ("shell" if n % 3 == 1 else "bone"), "s%d" % n, Vector2(p[0], p[1]))
		n += 1
	for i in CONCHES.size():
		_treasure("conch", "c%d" % i, Vector2(CONCHES[i][0], CONCHES[i][1]))
	for i in AMBERS.size():
		_treasure("amber", "a%d" % i, Vector2(AMBERS[i][0], AMBERS[i][1]))
	for i in BREAKABLES.size():
		var b: Array = BREAKABLES[i]
		var box := Treasure.Breakable.new()
		box.kind = b[2]
		box.contents = b[3]
		box.level_id = "level2"
		box.id = "b%d" % i
		box.position = Vector2(b[0], b[1])
		add_child(box)
		for k in b[3]:
			_count_treasure(k)
	for i in POTS.size():
		var pt: Array = POTS[i]
		var count: int = pt[2]
		for k in count:
			var pot := Treasure.Breakable.new()
			pot.kind = "pot"
			# a bone and a shell or two in each
			pot.contents = ["shell", "bone", "shell"] if (i + k) % 2 == 0 else ["bone", "shell", "bone"]
			pot.level_id = "level2"
			pot.id = "p%d_%d" % [i, k]
			pot.position = Vector2(float(pt[0]) + (k - (count - 1) * 0.5) * 38.0, pt[1])
			add_child(pot)
			for c in pot.contents:
				_count_treasure(c)
	for i in STOMP_SPOTS.size():
		var sp := Stomp.Spot.new()
		sp.kind = STOMP_SPOTS[i][1]
		sp.contents = STOMP_SEAL if sp.kind == "seal" else STOMP_CRACK
		sp.level_id = "level2"
		sp.id = "g%d" % i
		sp.position = Vector2(STOMP_SPOTS[i][0], GROUND_Y)
		add_child(sp)
		for c in sp.contents:
			_count_treasure(c)
	_note(STOMP_SPOTS[0][0] - 160.0, "A cracked slab in the ground... Jump, then press T to STOMP it!", 5.0)
	_note(STOMP_SPOTS[2][0] - 180.0, "A gold rune seal! Only a MEGA STOMP breaks it: double-jump, THEN T.", 5.0)
	for row in HOARDS:
		var id: String = row[0]
		var stuff: Array = STASH if id.begins_with("x") else HOARD
		var ground := Vector2(row[1], row[2])
		var land := Vector2(row[8], row[2])
		var rope: float = row[3]
		var box := Treasure.Breakable.new()
		box.kind = "hoard"
		box.contents = stuff
		box.level_id = "level2"
		box.id = id
		box.land = land
		box.position = ground + Vector2(0, -HOARD_RISE)
		add_child(box)
		var h := Hoards.Hoard.new()
		h.level = self
		h.box = box
		h.rope = rope
		h.period = 2.6 * sqrt(rope / 200.0)
		h.swing = deg_to_rad(row[4])
		h.guards = row[5]
		h.prop = row[6]
		h.drift = row[7]
		h.root_y = TarPits.SURFACE
		h.position = ground + Vector2(0, -HOARD_RISE - rope - 50.0)
		add_child(h)
		for c in stuff:
			_count_treasure(c)
	for i in TOTEMS.size():
		var totem := Treasure.ShellTotem.new()
		totem.level_id = "level2"
		totem.id = "t%d" % i
		totem.position = Vector2(TOTEMS[i][0], TOTEMS[i][1])
		add_child(totem)
		_bones_total += 11
		_treasure_total += 5
	for i in HARES.size():
		var h: Array = HARES[i]
		var hare := Treasure.GoldenHare.new()
		hare.left_x = h[0]
		hare.right_x = h[1]
		hare.position = Vector2(h[2], h[3])
		hare.level_id = "level2"
		hare.id = "h%d" % i
		add_child(hare)
		_bones_total += 8
		_treasure_total += 5
	_build_extension_loot()


## The treasure of the longer caves, and of the sky lanes.
func _build_extension_loot() -> void:
	for i in CAVE_LOOT.size():
		var l: Array = CAVE_LOOT[i]
		_treasure(l[2], "v%d" % i, Vector2(l[0], l[1]))
	for i in STEPPE_LOOT.size():
		var m: Array = STEPPE_LOOT[i]
		_treasure(m[2], "m%d" % i, Vector2(m[0], m[1]))
	# the sky lanes: their shells are worked out from the rocks, ids "k0", "k1"...
	var sky_n := 0
	for lane in SKY_LANES:
		for sl in SkyLanes.loot_for(lane["pad"], lane["rocks"]):
			_treasure(sl[2], "k%d" % sky_n, Vector2(sl[0], sl[1]))
			sky_n += 1
	for c in POTS_LATE:
		for k in int(c[2]):
			var pot := Treasure.Breakable.new()
			pot.kind = "pot"
			pot.contents = ["shell", "bone", "shell"] if k % 2 == 0 else ["bone", "shell", "bone"]
			pot.level_id = "level2"
			pot.id = "q%d_%d" % [int(c[0]), k]
			pot.position = Vector2(float(c[0]) + (k - (int(c[2]) - 1) * 0.5) * 38.0, c[1])
			add_child(pot)
			for kind in pot.contents:
				_count_treasure(kind)


## Counts what the level holds: shells by value (the economy is worked out
## from this), bones by number.
var _bones_total := 0


func _count_treasure(kind: String) -> void:
	if Treasure.is_bone(kind):
		_bones_total += int(Treasure.VALUE[kind])
	else:
		_treasure_total += int(Treasure.VALUE[kind])


func _treasure(kind: String, id: String, at: Vector2) -> void:
	_count_treasure(kind)
	var t := Treasure.Pickup.new()
	t.kind = kind
	t.level_id = "level2"
	t.id = id
	t.position = at
	t.collected.connect(_on_treasure)
	add_child(t)


## A Breakable passes on what pops out of it.
func _on_treasure_popped(p: Treasure.Pickup) -> void:
	p.collected.connect(_on_treasure)


var _run_value := 0          ## shells picked up this visit, by value
var _run_bones := 0          ## bones picked up this visit


func _on_treasure(kind: String, value: int) -> void:
	if Treasure.is_bone(kind):
		_run_bones += value
		hud.set_bones(GameState.bones)
	else:
		_run_value += value
		hud.set_shells(GameState.shells)


## How much of this level's treasure has been taken, by value.
func _treasure_found() -> int:
	return GameState.found_value("level2")


## A note that trips only inside a small area (a secret spot), not on passing an x.
func _spot(r: Rect2, text: String, secret: String = "") -> void:
	var t := World.Trigger.new(r)
	t.tripped.connect(func() -> void:
		hud.say(text, 4.0)
		if secret != "":
			_secrets[secret] = true)
	add_child(t)


func _on_gem() -> void:
	gem_found = true
	hud.set_gem(true)
	if not GameState.gems.has("level2"):
		GameState.gems["level2"] = "found"
	GameState.save()
	hud.say("The hidden gem — a king's reward.", 4.0)


func _wire_player() -> void:
	player.wood_changed.connect(func(v: int) -> void:
		if v > 0 and not _told_wood:
			_told_wood = true
			hud.say("Dry wood. Two bundles make a fire: F — he has to get angry first.", 4.5)
	)
	player.torch_out.connect(func() -> void:
		if _told_out <= 0.0:
			hud.say("The torch is out. Now they come.", 3.0)
			_told_out = 8.0
	)


func _on_bonfire(fire: NightWoods.Bonfire) -> void:
	set_checkpoint(fire.global_position + Vector2(56, 0))
	GameState.save()
	if not player.has_torch:
		player.give_torch()
		hud.say("He pulls a burning branch from the fire. Bonfires feed it — keep it lit.", 5.0)


func _process(delta: float) -> void:
	_update_talkers()
	_update_under()
	_update_mountain()
	super._process(delta)
	_told_out = maxf(_told_out - delta, 0.0)
	hud.set_torch(player.has_torch, player.torch_fuel)
	sky.dusk = clampf(1.0 - player.global_position.x / 1500.0, 0.0, 1.0)
	_update_palette()
	# the camera stays on the clearing through the fight and through his defeat,
	# until he has limped away into the dark
	var r := 3 if (_fight or (_scar_beaten and scar.visible)) else _region_at(player.global_position.x)
	if r != _region:
		_apply_region(r)
	_update_elder(delta)
	if not finished:
		_time += delta
	_update_long_dark()
	_update_toolmaker()
	_update_boulder_run(delta)
	_update_fight(delta)


## The first cold fire he lights himself: the flame leaps into HIM. SUNFIRE
## is his for good, and the sun starts full so he can try it at once.
func _learn_sunfire() -> void:
	if not GameState.learn("sunfire"):
		return
	player.sun_charge = 1.0
	var card := ItemGet.new()
	card.title = "SUNFIRE"
	card.line = "The Sun Stone's fire leaps into him! It is one of his two ABILITIES now — its circle is at the bottom of the screen. When it shines, press Q (or tap it): 30 seconds of fire in both fists — faster, stronger, burning blows, and THROW hurls fireballs (hold it for a stream). Fill the sun by hitting beasts, grabbing shells and sitting by fires."
	card.icon = func(c: Control) -> void:
		var b := Batch.new()
		Abilities.draw_symbol(b, "sunfire", Vector2.ZERO, 70.0, Abilities.GOLD, Time.get_ticks_msec() / 1000.0)
		b.draw(c)
	card.player = player
	add_child(card)


## ---------------------------------------------------------------- exploring
## The higher sky lanes (SKY_LANES_2): rocks, jellies, rays, a cache, shells
## along the way ("k2_%d") and a rare find at the top.
func _build_sky_lanes_2() -> void:
	var shell_n := 0
	for li in SKY_LANES_2.size():
		var lane: Dictionary = SKY_LANES_2[li]
		if lane.has("pad"):
			var pad: Array = lane["pad"]
			var bloom := NightWoods.MoonPuff.new()
			bloom.position = Vector2(pad[0], pad[1])
			add_child(bloom)
			var beacon := SkyLanes.Beacon.new()
			beacon.position = Vector2(pad[0], pad[1])
			add_child(beacon)
		var rocks: Array = lane["rocks"]
		for r in rocks:
			var rock := SkyLanes.SkyRock.new()
			rock.position = Vector2(r[0], r[1])
			rock.w = r[2]
			rock.lamp = (int(r[3]) & 2) != 0
			add_child(rock)
		for j in lane["jellies"]:
			var jelly := SkyCreatures.DriftJelly.new()
			jelly.position = Vector2(j[0], j[1])
			jelly.look = j[2]
			jelly.drift = j[3]
			add_child(jelly)
		for ry in lane["rays"]:
			var ray := SkyCreatures.SkyRay.new()
			ray.x0 = ry[0]
			ray.x1 = ry[1]
			ray.position = Vector2(ry[0], ry[2])
			ray.crossing = ry[3]
			add_child(ray)
		var c: Array = lane["cache"]
		var cr: Array = rocks[c[0]]
		var cache := SkyLanes.SkyCache.new()
		cache.contents = c[1]
		cache.level_id = "level2"
		cache.id = "sc2_%d" % li
		cache.position = Vector2(float(cr[0]) + float(cr[2]) * 0.3, cr[1])
		add_child(cache)
		for kind in cache.contents:
			_count_treasure(kind)
		var loot := SkyLanes.loot_for(lane["start"], rocks)
		if not lane.has("pad"):
			loot = loot.slice(3)      # the first three hang over a bloom: there is none here
		for sl in loot:
			_treasure(sl[2], "k2_%d" % shell_n, Vector2(sl[0], sl[1]))
			shell_n += 1
		_relic(lane["relic"])
		var n: Array = lane["note"]
		_note(n[0], n[1], n[2])


## A rare find lying in the world.
func _relic(r: Array) -> void:
	var relic := Relics.Relic.new()
	relic.position = Vector2(r[0], r[1])
	relic.kind = r[2]
	relic.level_id = "level2"
	relic.id = r[3]
	add_child(relic)


## The windy heights over the Moon Garden, and the bramble with the shovel.
func _build_windy() -> void:
	for r in WINDY_ROCKS:
		var rock := SkyLanes.SkyRock.new()
		rock.position = Vector2(r[0], r[1])
		rock.w = r[2]
		rock.lamp = (int(r[3]) & 2) != 0
		add_child(rock)
	var jelly := SkyCreatures.DriftJelly.new()
	jelly.position = Vector2(WINDY_JELLY[0], WINDY_JELLY[1])
	jelly.look = WINDY_JELLY[2]
	jelly.drift = WINDY_JELLY[3]
	add_child(jelly)
	var gusts := NightWoods.Wind.new()
	gusts.x0 = WINDY_WIND[0]
	gusts.x1 = WINDY_WIND[1]
	gusts.y0 = WINDY_WIND[2]
	gusts.y1 = WINDY_WIND[3]
	gusts.strength = WINDY_WIND[4]
	gusts.player = player
	add_child(gusts)
	var shovel_here := not GameState.has_item("shovel")
	if not GameState.is_taken("level2", "bramble0"):
		var bramble := Dig.Bramble.new()
		bramble.position = BRAMBLE_AT
		bramble.tried.connect(func() -> void:
			hud.say("Wet thorns, dripping with cloud-dew. Only a fire as hot as the SUN could burn them.", 4.5))
		bramble.burned.connect(func() -> void:
			GameState.take("level2", "bramble0", 0)
			if not GameState.has_item("shovel"):
				_place_shovel())
		add_child(bramble)
	elif shovel_here:
		_place_shovel()


func _place_shovel() -> void:
	var sh := Dig.ShovelPickup.new()
	sh.position = BRAMBLE_AT
	sh.picked.connect(_got_shovel)
	add_child.call_deferred(sh)


func _got_shovel() -> void:
	GameState.give_item("shovel")
	GameState.solve_mystery("shovel")
	var card := ItemGet.new()
	card.title = "STONE SHOVEL"
	card.line = "A flat stone lashed to a stick. Packed clay is nothing to it now. The Dig (the mound in the graveyard) goes on down..."
	card.icon = func(c: Control) -> void:
		var b := Batch.new()
		Dig.draw_shovel(b, Vector2.ZERO, 2.2)
		b.draw(c)
	card.player = player
	add_child(card)


## ---------------------------------------------------------------- underground
## The Dig, the Gulper's den, the Root Hollows and the two updrafts — all in
## the world, under the graveyard and the Tar Pits (see the UNDER tables).
var _burrow: Underground.Burrow
var _grid: Dig.DigGrid
var _gulper: Dig.Gulper
var _seal: Dig.DenSeal


func _build_under() -> void:
	var back := Caves.CaveBackdrop.new()
	back.rect = UNDER
	back.margin = 0.0          # (right under the surface: no dark border over the sky)
	add_child(back)
	for r in UNDER_ROCK:
		add_child(Caves.CaveRock.new(Rect2(r[0], r[1], r[2], r[3]), r[4]))
	# the shaft: crust, dirt, stones, the Sun Stone's hollow, packed clay
	var cols: int = DIG_GRID[2]
	var rows: int = DIG_GRID[3]
	_grid = Dig.DigGrid.new()
	_grid.cols = cols
	_grid.rows = rows
	_grid.position = Vector2(DIG_GRID[0], DIG_GRID[1])
	var crust_open := GameState.is_taken("level2", "burrow0")
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var cells := PackedInt32Array()
	cells.resize(cols * rows)
	var free_dirt: Array = []
	for y in rows:
		for x in cols:
			var kind := Dig.DIRT
			if y == 0:
				kind = Dig.AIR if crust_open and x >= 2 and x <= 5 else Dig.CRUST
			elif y >= DIG_CLAY[0] and y <= DIG_CLAY[1]:
				kind = Dig.CLAY
			elif y >= DIG_POCKET[0] and y <= DIG_POCKET[1] and x >= DIG_POCKET[2] and x <= DIG_POCKET[3]:
				kind = Dig.AIR
			elif y >= 2 and rng.randf() < 0.18:
				kind = Dig.STONE
			cells[y * cols + x] = kind
			if kind == Dig.DIRT and y >= 2 and y < DIG_CLAY[0] - 1:
				free_dirt.append(y * cols + x)
	_grid.cells = cells
	for i in DIG_LOOT.size():
		var at: int = free_dirt[(i * 37 + 11) % free_dirt.size()]
		while _grid.loot.has(at):
			at = free_dirt[(free_dirt.find(at) + 1) % free_dirt.size()]
		_grid.loot[at] = [DIG_LOOT[i], "dg%d" % i]
		_count_treasure(DIG_LOOT[i])
	# stones for the bag, hidden in the dirt (where: this save's own roll)
	var srng := RandomNumberGenerator.new()
	srng.seed = 77 + GameState.seed_of_world()
	for i in DIG_STONES.size():
		for tries in 20:
			var at2: int = free_dirt[srng.randi() % free_dirt.size()]
			if not _grid.loot.has(at2):
				_grid.loot[at2] = ["stone:" + DIG_STONES[i], "sd%d" % i]
				break
	_grid.clay_needs_shovel.connect(func() -> void:
		if not GameState.has_item("shovel"):
			GameState.open_mystery("shovel")
		hud.say(SHOVEL_HINTS[mini(_shovel_hint, SHOVEL_HINTS.size() - 1)], 5.5)
		_shovel_hint += 1)
	add_child(_grid)
	# the mound on the crust: a MEGA STOMP opens the shaft
	_burrow = Underground.Burrow.new()
	_burrow.position = Vector2(float(DIG_GRID[0]) + cols * Dig.TILE * 0.5, GROUND_Y)
	_burrow.open = crust_open
	_burrow.opened.connect(func() -> void:
		GameState.take("level2", "burrow0", 0)
		_grid.open_crust(2, 5)
		hud.say("The crust breaks! Earth all the way down: hold DOWN and HIT to dig.", 4.5))
	add_child(_burrow)
	var hint := World.Trigger.new(Rect2(_burrow.position.x - 260.0, 100, 60, 900))
	hint.tripped.connect(func() -> void:
		if not _burrow.open:
			hud.say("Eyes blink inside that mound... it would take a MEGA STOMP to break.", 4.5))
	add_child(hint)
	# the Sun Stone, in its hollow
	var stone := Dig.SunStone.new()
	stone.position = Vector2(float(DIG_GRID[0]) + (DIG_POCKET[2] + DIG_POCKET[3] + 1) * Dig.TILE * 0.5, float(DIG_GRID[1]) + (DIG_POCKET[1] + 1) * Dig.TILE)
	stone.spent = GameState.abilities.has("sunfire")
	stone.taken.connect(_learn_sunfire)
	add_child(stone)
	# the painting by the clay, on the shaft's right wall: where the shovel went
	var painting := Dig.Painting.new()
	painting.position = Vector2(float(DIG_GRID[0]) + cols * Dig.TILE + 150.0, float(DIG_GRID[1]) + DIG_CLAY[0] * Dig.TILE - 120.0)
	add_child(painting)
	# the den, off the shaft: claw marks show where; a short dig sideways
	var marks := Dig.ClawMarks.new()
	marks.position = Vector2(float(DIG_GRID[0]) + cols * Dig.TILE - 30.0, DEN_PASSAGE[1] + 30.0)
	add_child(marks)
	var passage := Dig.DigGrid.new()
	passage.cols = DEN_PASSAGE[2]
	passage.rows = DEN_PASSAGE[3]
	passage.position = Vector2(DEN_PASSAGE[0], DEN_PASSAGE[1])
	var pc := PackedInt32Array()
	pc.resize(passage.cols * passage.rows)
	pc.fill(Dig.DIRT)
	passage.cells = pc
	add_child(passage)
	var den_back := Caves.CaveBackdrop.new()
	den_back.rect = DEN
	den_back.margin = 0.0
	add_child(den_back)
	_seal = Dig.DenSeal.new()
	_seal.position = Vector2(DEN.position.x - 10.0, DEN_PASSAGE[1])
	add_child(_seal)
	if not GameState.has_item("gulper_teeth"):
		_gulper = Dig.Gulper.new()
		_gulper.position = Vector2(DEN.get_center().x, DEN.end.y)   # near_view needs it in the den
		_gulper.floor_y = DEN.end.y
		_gulper.x0 = DEN.position.x + 30.0
		_gulper.x1 = DEN.end.x - 30.0
		_gulper.defeated.connect(_on_gulper_beaten)
		add_child(_gulper)
	# the updrafts, and the root mats over their mouths
	for u in UPDRAFTS:
		var up := Underground.Updraft.new()
		up.x0 = u[0]
		up.x1 = u[1]
		up.top = u[2]
		up.bottom = u[3]
		add_child(up)
	for l in LIDS:
		var lid := Underground.Lid.new()
		lid.position = Vector2(l[0], GROUND_Y)
		lid.w = l[1]
		add_child(lid)
	# the Root Hollows
	for w in DEEP_WORMS:
		var worms := Underground.GlowWorms.new()
		worms.position = Vector2(w[0], w[1])
		worms.width = w[2]
		worms.reach = w[3]
		add_child(worms)
	var angler := Underground.Angler.new()
	angler.position = Vector2(DEEP_ANGLER[0], DEEP_ANGLER[1])
	angler.drop = DEEP_ANGLER[2]
	add_child(angler)
	var snail := Underground.CrystalSnail.new()
	snail.x0 = DEEP_SNAIL[0]
	snail.x1 = DEEP_SNAIL[1]
	snail.position = Vector2((DEEP_SNAIL[0] + DEEP_SNAIL[1]) * 0.5, DEEP_SNAIL[2])
	snail.holding = not GameState.is_taken("level2", "r3")
	snail.cracked.connect(func(at: Vector2) -> void:
		_relic.call_deferred([at.x, at.y, "glow_crystal", "r3"]))
	add_child(snail)
	for r in DEEP_RELICS:
		_relic(r)
	for i in DEEP_LOOT.size():
		var l2: Array = DEEP_LOOT[i]
		_treasure(l2[2], "u%d" % i, Vector2(l2[0], l2[1]))


## Every frame: under the ground the camera may go deep and there is no
## "fell" (it is a long way down on purpose); and the den's trap.
func _update_under() -> void:
	if player == null or _region != 0:
		return
	var p := player.global_position
	var under := p.x > UNDER.position.x and p.x < UNDER.end.x
	cam.limit_bottom = int(UNDER.end.y) if under else 1200
	fall_y = UNDER.end.y + 200.0 if under else FALL_Y
	if _gulper == null or not is_instance_valid(_gulper) or _gulper.state == "dead":
		return
	var inside := DEN.grow(-20.0).has_point(p + Vector2(0, -20)) and not player.dead
	if inside and _gulper.state == "sleep":
		# the trap: rocks crash down behind him, and it wakes
		_seal.set_shut(true)
		_gulper.wake()
		shake(12.0, 0.6)
		hud.title_card("THE GULPER", "it swims in the earth — hit it when it's stuck!")
		hud.say("CRASH! The way out is blocked...", 3.0)
	elif player.dead or not DEN.grow(60.0).has_point(p):
		if _seal.shut:
			_seal.set_shut(false)
			_gulper.reset()
			hud.set_boss(-1.0)
	if _seal.shut:
		hud.set_boss(float(_gulper.hp) / Dig.Gulper.HP)


func _on_gulper_beaten(at: Vector2) -> void:
	_seal.set_shut(false)
	hud.set_boss(-1.0)
	hud.say("The rocks shift... the way out is open.", 3.0)
	var teeth := Dig.TeethPickup.new()
	teeth.position = at + Vector2(0, -6)
	teeth.picked.connect(_got_teeth)
	add_child.call_deferred(teeth)


func _got_teeth() -> void:
	GameState.give_item("gulper_teeth")
	if _gulper != null and is_instance_valid(_gulper):
		_gulper.queue_free()
	var card := ItemGet.new()
	card.title = "GULPER TEETH"
	card.line = "Sharper than flint, harder than stone. A toolmaker could make something FIERCE out of these."
	card.icon = func(c: Control) -> void:
		var b := Batch.new()
		Dig.draw_teeth(b, Vector2.ZERO, 2.4)
		b.draw(c)
	card.player = player
	add_child(card)


## ------------------------------------------------------------ inside the mountain
## The mountain is a Terrain (built in _build_world); here its tunnels and caves
## are furnished. Everything is set on the floor (or hung from the roof) that the
## terrain itself reports, so the map can be reshaped without moving these.
var _mt_seen := {}

func _mt_floor(x: float, near_y: float) -> float:
	var y := mountain.ground_y(x, near_y - 70.0)
	return y if y < INF else near_y


func _mt_roof(x: float, near_y: float) -> float:
	var y := mountain.roof_y(x, near_y + 70.0)
	return y if y > -INF else near_y


func _build_mountain_inside() -> void:
	# root mats over the mouths on the path: he walks over them; from below he jumps up through
	for m in MT_LIDS:
		var lid := Underground.Lid.new()
		lid.position = Vector2(m[0], m[1])
		lid.w = m[2]
		add_child(lid)
	# the two chimneys' walls: kick walls
	for ch in [MT_CHIMNEY, MT_CHIMNEY2]:
		for s in [[ch[0], 1.0], [ch[1], -1.0]]:
			var face := Mountain.KickFace.new()
			face.position = Vector2(s[0], 0)
			face.top = ch[2]
			face.bottom = ch[3]
			face.side = s[1]
			add_child(face)
	for g in MT_CAPS:
		var cap := CaveTrials.GlowCap.new()
		cap.position = Vector2(g[0], _mt_floor(g[0], g[1]))
		cap.tint = TINTS[g[2]]
		add_child(cap)
	_bury_finds()
	for c in MT_CRYSTALS:
		var crystal := CaveTrials.Crystals.new()
		crystal.hanging = c[2]
		crystal.position = Vector2(c[0], _mt_roof(c[0], c[1]) if c[2] else _mt_floor(c[0], c[1]))
		crystal.tint = TINTS[c[3]]
		crystal.n = 3 + (int(c[0]) / 7) % 3
		add_child(crystal)
	var bones := Steppe.Skeleton.new()
	bones.position = Vector2(MT_SKELETON[0], _mt_floor(MT_SKELETON[0], MT_SKELETON[1]))
	bones.size = MT_SKELETON[2]
	add_child(bones)
	var paint := Mountain.CavePaint.new()
	paint.position = Vector2(MT_PAINT[0], _mt_floor(MT_PAINT[0], MT_PAINT[1]) - 6.0)
	add_child(paint)
	for w in MT_WORMS:
		var worms := Underground.GlowWorms.new()
		worms.position = Vector2(w[0], _mt_roof(w[0], w[1]))
		worms.width = w[2]
		worms.reach = w[3]
		add_child(worms)
	for w in MT_CAVEWORMS:
		var worm := Mountain.CaveWorm.new()
		worm.terrain = mountain
		worm.left_x = w[2]
		worm.right_x = w[3]
		worm.position = Vector2(w[0], _mt_floor(w[0], w[1]))
		add_child(worm)
	for s in MT_SKELETONS:
		var risen := Mountain.RisenSkeleton.new()
		risen.terrain = mountain
		risen.left_x = s[2]
		risen.right_x = s[3]
		risen.position = Vector2(s[0], _mt_floor(s[0], s[1]))
		add_child(risen)
	for r in MT_RELICS:
		_relic([r[0], _mt_floor(r[0], r[1]) - 30.0, r[2], r[3]])
	for ch in MT_CHESTS:
		var chest := Treasure.Breakable.new()
		chest.kind = "chest"
		chest.contents = ch[2]
		chest.level_id = "level2"
		chest.id = ch[3]
		chest.position = Vector2(ch[0], _mt_floor(ch[0], ch[1]))
		add_child(chest)
	for i in MT_LOOT.size():
		var l: Array = MT_LOOT[i]
		var at := Vector2(l[0], l[1])
		if l[3]:
			at.y = _mt_floor(l[0], l[1]) - 30.0
		_treasure(l[2], "mt%d" % i, at)
	_note(5860, "A slot in the rock... and the dark goes on, INTO the mountain.", 4.5)
	_note(9900, "The HIGH PEAK. Down there... the rock is full of glints. DOWN + HIT to dig!", 5.0)


## Every frame: the first time he steps into each room, its name.
func _update_mountain() -> void:
	if player == null or _region != 0:
		return
	# over the mountain he may dig all the way down: the camera follows, and it's no "fall"
	var mb := mountain.bounds()
	if player.global_position.x > mb.position.x and player.global_position.x < mb.end.x:
		cam.limit_bottom = int(mb.end.y)
		fall_y = mb.end.y + 200.0
	var at := player.global_position + Vector2(0, -30)
	for i in MT_ROOMS.size():
		var room: Array = MT_ROOMS[i]
		if not _mt_seen.has(i) and (room[0] as Rect2).has_point(at) and mountain.is_inside(at):
			_mt_seen[i] = true
			hud.title_card(room[1], room[2])


## Finds buried in the mountain's rock (MT_BURIED, MT_BURIED_RARE, MT_STONES): a roll
## seeded from the save (every save digs its own mountain) over its solid samples,
## at least two in from any open air; the rare ones deep in the strata, each stone
## where its kind belongs (MT_STONE_HOME). Treasure glints through the rock; the
## stones hide. (Ids follow the order: "mb%d", "st%d".)
func _bury_finds() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2611 + GameState.seed_of_world()
	var spots := []
	var by_code := {}                       # map letter code -> its buried spots
	for r in range(2, mountain._h - 3):
		for c in range(3, mountain._w - 3):
			var code := mountain._code(c, r)
			if not mountain._is_solid_code(code):
				continue
			var buried := true
			for d in [Vector2i(-2, 0), Vector2i(2, 0), Vector2i(0, -2), Vector2i(0, 2), Vector2i(-1, -1), Vector2i(1, -1)]:
				if not mountain._is_solid_code(mountain._code(c + d.x, r + d.y)):
					buried = false
			if not buried:
				continue
			spots.append(r * mountain._w + c)
			if not by_code.has(code):
				by_code[code] = []
			(by_code[code] as Array).append(r * mountain._w + c)
	var take := func(pool: Array) -> int:
		while not pool.is_empty():
			var i: int = pool.pop_at(rng.randi() % pool.size())
			if not mountain.loot.has(i):
				return i
		return -1
	var n := 0
	for kind in MT_BURIED:
		for i in int(MT_BURIED[kind]):
			var idx: int = take.call(spots)
			if idx >= 0:
				mountain.loot[idx] = [kind, "mb%d" % n]
			n += 1
	for rare in MT_BURIED_RARE:
		var idx2: int = take.call(by_code.get(61, []))          # '=': the deep strata
		if idx2 >= 0:
			mountain.loot[idx2] = ["relic:" + rare[0], rare[1]]
	n = 0
	for kind in MT_STONES:
		for i in int(MT_STONES[kind]):
			var idx3 := -1
			for code in MT_STONE_HOME[kind]:
				idx3 = take.call(by_code.get(code, []))
				if idx3 >= 0:
					break
			if idx3 < 0:
				idx3 = take.call(spots)
			if idx3 >= 0:
				mountain.loot[idx3] = ["stone:" + kind, "st%d" % n]
			n += 1
