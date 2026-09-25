extends LevelBase
## Level 2: Discovery of Fire. Night falls as he walks. The torch is his sight
## and his defence at once, and it burns down; bonfires feed it.
##   Dusk camp (0-900)          the torch, and the first eyes in the trees
##   Firelit woods (900-3980)   wolves, bats, dead trees, fire, the pack in the hollow
##   The Mountain (3980-7050)   a hard climb in the wind; a crevice stash; a lookout
##   The Great Tree (7050-8420) climb it, cross the chasm on its bough, mind the monkeys.
##                              At the very top: Old Bongo, the monkey king, who talks.
##   Far side (8420-10000)       last bonfire, a dead snag to climb back up, last wolves
##
## The story: Old Bongo has lost the key to his banana box in one of two
## caves, and he'll trade the gem for it. Which cave is decided fresh each
## time the level starts. His memory of what chased him, and what lies at each
## cave's door, are the clues. The caves are built off to the right of the
## woods (x > 10,000); their doorways fade him there and back.
##   The Weeping Cave  (mouth in the mountain's foot)  spiders, webs; a cocoon in the roof
##   The Rattling Cave (mouth in the far-side outcrop) rats, snakes; the rats' hoard
## Still to come: the Long Dark and the sabre-tooth arena.

const GROUND_Y := 600.0
const LEVEL_W := 10000.0
const FALL_Y := 1020.0

## Reachability budget: a jump climbs ~133 px and carries ~227 px. Every step
## here asks for 100-125 up; the mountain's are the ones near the top of that.
## Ground runs: [x0, x1] at GROUND_Y.
const FLOORS := [[0.0, 1500.0], [1640.0, 2600.0], [2760.0, 2900.0], [3350.0, 3980.0], [7050.0, 7700.0], [8420.0, LEVEL_W]]
## The hollow where the pack waits: [x, floor y, width].
const HOLLOW := [2900.0, 700.0, 450.0]
const LEDGES := [
	[880.0, 500.0, 170.0],
	[2080.0, 490.0, 150.0],
	[2290.0, 400.0, 150.0],
]
## The mountain. Rects [x, top, width, height]: tall ones are the rock steps,
## thin ones are ledges sticking out of the face. A missed jump off the thin
## ones is a fall; missing the first one drops him into the crevice (a stash).
const CRAGS := [
	[3980.0, 490.0, 180.0, 710.0],     # first step up from the base camp
	[4160.0, 720.0, 240.0, 480.0],     # crevice floor
	[4180.0, 610.0, 60.0, 16.0],       # the way back out of the crevice
	[4230.0, 385.0, 100.0, 18.0],
	[4400.0, 285.0, 200.0, 915.0],
	[4690.0, 172.0, 90.0, 18.0],       # narrow, and a bat waits here
	[4870.0, 60.0, 100.0, 18.0],
	[5060.0, -52.0, 260.0, 1252.0],    # a broad shelf: dead tree, rocks, a boulder
	[5410.0, -165.0, 90.0, 18.0],      # narrow, second bat
	[5590.0, -278.0, 420.0, 1478.0],   # the summit
	[5470.0, -398.0, 80.0, 18.0],      # the lookout, above and behind the summit
	# the way down, in steps
	[6010.0, -155.0, 190.0, 1355.0], [6200.0, -30.0, 190.0, 1230.0], [6390.0, 95.0, 190.0, 1105.0],
	[6580.0, 220.0, 190.0, 980.0], [6770.0, 345.0, 190.0, 855.0], [6960.0, 470.0, 90.0, 730.0],
	[9350.0, 490.0, 250.0, 710.0],     # the far-side outcrop: the Rattling Cave's mouth is in its far face
]
## Boulders to shelter behind, [x, surface y]. The wind blows down the climb
## (from the right), so the lee is the left side.
const BOULDERS := [[4565.0, 285.0], [5290.0, -52.0]]
const WIND_ZONE := [4170.0, 5590.0]
## The mountain's silhouette, drawn behind the climb.
const MOUNTAIN := [[3930, 1200], [3960, 560], [4120, 430], [4320, 330], [4520, 230], [4720, 110], [4920, 0],
	[5120, -120], [5340, -210], [5520, -380], [5700, -420], [5900, -370], [6100, -230], [6380, 20],
	[6650, 230], [6900, 420], [7080, 1200]]

## The great tree: trunk centred here, and its branches as one-way platforms
## [x, top, width, grows from the left end?]. Left and right of the trunk in
## turn, 112 px apart; the long bough crosses the chasm; above it, the crown.
const TREE_X := 7520.0
const BRANCHES := [
	[7330.0, 490.0, 130.0, false], [7580.0, 378.0, 130.0, true], [7320.0, 266.0, 140.0, false],
	[7580.0, 154.0, 120.0, true],
	[7560.0, 42.0, 900.0, true],        # the long bough, over the chasm to the far side
	[7340.0, -70.0, 130.0, false], [7580.0, -183.0, 120.0, true], [7350.0, -296.0, 120.0, false],
	[7430.0, -408.0, 230.0, true],      # the crown
	# the dead snag on the far side: the way back up to the bough
	[8600.0, 490.0, 110.0, false], [8730.0, 378.0, 110.0, true], [8600.0, 266.0, 110.0, false],
	[8730.0, 154.0, 110.0, true], [8520.0, 42.0, 190.0, false],
]
const SNAG_X := 8715.0
## The troop: [x, y, habit, hanging]
const MONKEYS := [
	[7660.0, 378.0, 0, false],
	[7360.0, 280.0, 0, true],            # hanging under a branch by its tail
	[7790.0, 42.0, 0, false], [8010.0, 42.0, 1, false], [8240.0, 42.0, 0, false],
	[7640.0, -183.0, 1, false],
]
## Old Bongo sits at the top of the crown, beside his banana box.
const ELDER_AT := Vector2(7620, -408)

## [x, y, lit at start]
const BONFIRES := [[520.0, GROUND_Y, true], [1720.0, GROUND_Y, false], [3560.0, GROUND_Y, false],
	[5710.0, -278.0, false], [7130.0, GROUND_Y, false], [8570.0, GROUND_Y, false],
	[11470.0, 700.0, false], [13860.0, 600.0, false]]   # an old hearth in each cave
## [x, y, bundles of wood in it]
const DEAD_TREES := [[1260.0, GROUND_Y, 2], [2400.0, 400.0, 1], [2855.0, GROUND_Y, 2], [5130.0, -52.0, 2], [7290.0, GROUND_Y, 2]]
## Loose bundles already on the ground: the crevice stash.
const WOOD := [[4200.0, 720.0], [4370.0, 720.0], [11600.0, 700.0], [13990.0, 600.0]]
## [left, right, start_x, floor_y]. Kept clear of the bonfires' light.
const WOLVES := [
	[1000.0, 1490.0, 1330.0, GROUND_Y], [1000.0, 1490.0, 1450.0, GROUND_Y],
	[2040.0, 2590.0, 2420.0, GROUND_Y], [2040.0, 2590.0, 2540.0, GROUND_Y],
	[2915.0, 3335.0, 3120.0, 700.0], [2915.0, 3335.0, 3220.0, 700.0], [2915.0, 3335.0, 3310.0, 700.0],
	[8890.0, 9300.0, 9050.0, GROUND_Y], [8890.0, 9300.0, 9200.0, GROUND_Y],
]
const BAT_HOVER := 70.0
## [x, the surface this bat belongs to]
const BATS := [[1880.0, GROUND_Y], [2360.0, 400.0], [4735.0, 172.0], [5455.0, -165.0], [11335.0, 700.0]]
const ROCK_PILES := [[760.0, GROUND_Y], [2130.0, 490.0], [2785.0, GROUND_Y], [5230.0, -52.0], [7200.0, GROUND_Y], [10600.0, 600.0]]
const BERRIES := [[960.0, 500.0], [2320.0, 400.0], [4290.0, 720.0], [5510.0, -398.0], [11700.0, 700.0], [14020.0, 600.0]]

## ---------------------------------------------------------------- caves
## Each cave: its camera bounds, its rock [x, y, w, h, kind], where he comes in,
## and its doorway outside [x, y, which way he walks in, "webs" | "skin"].
const CAVE_A := Rect2(10300, 150, 2100, 800)      # the Weeping Cave
const CAVE_A_ROCK := [
	[10300.0, 150.0, 100.0, 800.0, "wall"], [12300.0, 150.0, 100.0, 800.0, "wall"],
	[10400.0, 600.0, 500.0, 350.0, "floor"], [10900.0, 700.0, 350.0, 250.0, "floor"],
	[11420.0, 700.0, 660.0, 250.0, "floor"],           # after the pit
	[11800.0, 590.0, 100.0, 18.0, "floor"], [11950.0, 480.0, 100.0, 18.0, "floor"],
	[12080.0, 380.0, 220.0, 570.0, "floor"],           # the cocoon chamber
	[10400.0, 150.0, 500.0, 270.0, "roof"], [10900.0, 150.0, 860.0, 320.0, "roof"],
	[11760.0, 150.0, 320.0, 100.0, "roof"], [12080.0, 150.0, 220.0, 30.0, "roof"],
]
const CAVE_A_IN := Vector2(10470, 600)
const CAVE_A_DOOR := [7050.0, GROUND_Y, -1, "webs"]
const CAVE_A_WEBS := [[10840.0, 600.0, 180.0], [12160.0, 380.0, 200.0]]
## [x, roof y, floor y, left, right]
const SPIDERS := [[11080.0, 470.0, 700.0, 10910.0, 11240.0], [11650.0, 470.0, 700.0, 11440.0, 12070.0],
	[12140.0, 180.0, 380.0, 12090.0, 12290.0]]
const COCOON := [12240.0, 180.0, 380.0]

const CAVE_B := Rect2(12800, 150, 1700, 800)      # the Rattling Cave
const CAVE_B_ROCK := [
	[12800.0, 150.0, 100.0, 800.0, "wall"], [14400.0, 150.0, 100.0, 800.0, "wall"],
	[12900.0, 600.0, 400.0, 350.0, "floor"], [13300.0, 510.0, 90.0, 440.0, "floor"],   # a pillar, with a snake in it
	[13390.0, 600.0, 1010.0, 350.0, "floor"],
	[14120.0, 490.0, 110.0, 18.0, "floor"], [14260.0, 380.0, 140.0, 18.0, "floor"],   # up to the hoard
	[12900.0, 150.0, 400.0, 180.0, "roof"], [13300.0, 150.0, 120.0, 180.0, "roof"],
	[13420.0, 150.0, 340.0, 370.0, "roof"],            # the crawl tunnel: no room to jump
	[13760.0, 150.0, 640.0, 60.0, "roof"],
]
const CAVE_B_IN := Vector2(12970, 600)
## In the outcrop's far face: he sees it behind him once he has climbed over.
const CAVE_B_DOOR := [9600.0, GROUND_Y, -1, "skin"]
## [left, right, start x, floor y]
const RATS := [[12920.0, 13280.0, 13100.0, 600.0], [12920.0, 13280.0, 13220.0, 600.0],
	[13400.0, 13740.0, 13500.0, 600.0], [13400.0, 13740.0, 13650.0, 600.0],
	[13780.0, 14380.0, 14000.0, 600.0], [13780.0, 14380.0, 14250.0, 600.0]]
## [hole x, hole y, facing]
const SNAKES := [[13300.0, 580.0, -1], [14400.0, 580.0, -1]]
const NEST := [14330.0, 380.0]
## [x, darkness]. Dusk at the camp, darkest in the woods, thinner on the
## mountain where the moon reaches, dark again under the great tree.
const DARKNESS := [[0.0, 0.26], [700.0, 0.40], [1500.0, 0.62], [2600.0, 0.72], [3600.0, 0.74],
	[4300.0, 0.62], [5000.0, 0.56], [5700.0, 0.50], [6600.0, 0.60], [7100.0, 0.70], [7600.0, 0.64],
	[8500.0, 0.72], [10000.0, 0.74], [10250.0, 0.92], [14600.0, 0.92]]   # the caves: near black

var night: Night
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
var _region := 0             ## 0 the woods, 1 the Weeping Cave, 2 the Rattling Cave
var _moving := false
var _mouths: Array = []


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
	night = Night.new()
	night.table = DARKNESS
	night.player = player
	add_child(night)
	var wind := NightWoods.Wind.new()
	wind.x0 = WIND_ZONE[0]
	wind.x1 = WIND_ZONE[1]
	wind.player = player
	add_child(wind)
	_build_hud(true)
	_wire_player()
	wind.first_gust.connect(func() -> void:
		hud.say("Wind! In the air it carries him. Hold INTO it to brace — or get behind rock.", 5.0))
	_talk([
		["", "The sun is going down, and he is far from the cave he knows."],
		["", "Night is coming. Something out there is hungry. He will need fire."],
		["", "(Space, J or a tap to go on.)"],
	])


func _build_background() -> void:
	_sky_layer = CanvasLayer.new()
	_sky_layer.layer = -120
	add_child(_sky_layer)
	sky = NightWoods.NightSky.new()
	_sky_layer.add_child(sky)

	var pb := ParallaxBackground.new()
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


func _build_world() -> void:
	# scenery first, so everything solid draws over it
	var face := NightWoods.MountainFace.new()
	var pts := PackedVector2Array()
	for p in MOUNTAIN:
		pts.append(Vector2(p[0], p[1]))
	face.outline = pts
	add_child(face)
	var tree := NightWoods.GreatTree.new()
	tree.position = Vector2(TREE_X, GROUND_Y)
	add_child(tree)
	var snag := NightWoods.Snag.new()
	snag.position = Vector2(SNAG_X, GROUND_Y)
	add_child(snag)

	for seg in FLOORS:
		add_child(World.Slab.new(Rect2(seg[0], GROUND_Y, seg[1] - seg[0], 240)))
	add_child(World.Slab.new(Rect2(HOLLOW[0], HOLLOW[1], HOLLOW[2], 140)))
	for l in LEDGES:
		add_child(World.Slab.new(Rect2(l[0], l[1], l[2], 22)))
	for c in CRAGS:
		add_child(NightWoods.Crag.new(Rect2(c[0], c[1], c[2], c[3])))
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
	for b in BERRIES:
		var bush := World.BerryBush.new()
		bush.position = Vector2(b[0], b[1])
		add_child(bush)

	var exit := World.Exit.new()
	exit.position = Vector2(LEVEL_W - 90.0, GROUND_Y)
	exit.reached.connect(_on_exit)
	add_child(exit)


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
		add_child(bat)

	_note(980, "Eyes. They will not cross strong light — keep the torch above the notch.", 4.5)
	_note(1170, "A dead tree, dry as bone. Club it for wood.", 3.5)
	_note(2700, "Three of them down there. This is what fire is for.", 4.0)
	_note(3800, "The only way on is up.", 3.0)
	_spot(Rect2(4160, 620, 240, 110), "A crack in the rock — and someone's stash in it.")
	_spot(Rect2(5470, -480, 80, 90), "From up here, the whole valley. And something glints, high in the great tree.")
	_note(7240, "Monkeys, up in the great tree. Leave them be and they leave him be.", 4.5)
	_note(8480, "A dead snag, right by the fire. Its branches go all the way back up to the bough.", 4.5)


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
		var lines := [["", "A cave in the foot of the mountain. Cold air breathes out of it."]]
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
	cam.limit_left = int(rect.position.x)
	cam.limit_right = int(rect.end.x)
	cam.limit_top = int(rect.position.y)
	cam.limit_bottom = int(rect.end.y)
	night.moon_r = 70.0 if r == 0 else 0.0
	night.sky_lift = 1.0 if r == 0 else 0.0
	# underground, the sky and the woods are behind solid rock: don't draw them
	_sky_layer.visible = r == 0
	_bands.visible = r == 0
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
	var lines: Array = []
	if quest == "none" and not has_key:
		lines = [
			_bongo("Well, well. A hairless one, with a little sun on a stick. And he climbed all the way up my tree."),
			["CAVEMAN", "Ugh."],
			_bongo("Charming. I am Old Bongo, king of this tree. And I have a problem."),
		]
		if monkey_kills > 0:
			lines.append(_bongo("Also, you have been hitting my family. I saw that. Hmph."))
		lines += [
			_bongo("My banana box is locked, and I have lost the key. A whole box of bananas, and I cannot open it!"),
			["CAVEMAN", "...Banana?"],
			_bongo("Yes! Banana! You understand! Bring me my key, and this shiny stone is yours."),
			_bongo("I lost it in one of the two caves below. One is in the foot of the mountain. The other is past the chasm."),
			_bongo("It was dark. I was eating a banana, and then " + _clue()),
			_bongo("I ran. I did not go back for the key. I am a king, not a fool."),
			_bongo("Caves always tell you something at the door, if you look. Go on, hairless one."),
			["CAVEMAN", "Hnn."],
		]
		_talk(lines, func() -> void:
			quest = "asked"
			hud.set_quest("Find Old Bongo's key — in one of the two caves"))
	elif not has_key:
		var short := "so many legs" if key_cave == 0 else "no legs at all"
		_talk([_bongo("No key? It is in one of the caves below. Where the thing with " + short + " lives.")])
	else:
		if quest == "none":
			lines = [
				_bongo("Well, well. A hairless one, with a little sun on a stick. And — wait."),
				_bongo("Is that... MY KEY? The key to my banana box? You found it before I even asked!"),
				["CAVEMAN", "Ugh."],
			]
		else:
			lines = [
				_bongo("Is that... it is! MY KEY!"),
				["CAVEMAN", "Ugh!"],
			]
		lines += [
			_bongo("Hairless one, you are smarter than you smell."),
			_bongo("Bananas! Bananas for everyone!", _open_box),
			_bongo("And the shiny stone, as I promised. A king keeps his word.", _give_gem),
			_bongo("Go well. And keep that little sun burning. Something big walks the woods tonight — bigger than wolves."),
			["CAVEMAN", "..."],
		]
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


func _talk(lines: Array, after: Callable = Callable()) -> void:
	var d := Dialogue.new()
	d.lines = lines
	d.player = player
	d.line_started.connect(func(who: String) -> void:
		if elder != null:
			elder.speaking = who == "OLD BONGO")
	d.finished.connect(func() -> void:
		if elder != null:
			elder.speaking = false
		if after.is_valid():
			after.call())
	add_child(d)


func _update_elder(delta: float) -> void:
	if player.dead or player.talking or player.fury >= 0.0:
		return
	var d := player.global_position - elder.global_position
	var near := absf(d.x) < 190.0 and absf(d.y) < 30.0 and player.is_on_floor()
	if near and not _near_elder:
		_near_elder = true
		if quest == "done":
			hud.say("OLD BONGO:  \"Go well, hairless one. Mind the big one.\"", 3.0)
		else:
			_meet_elder()
	elif not near and absf(d.x) > 280.0:
		_near_elder = false
	# from the bough, a voice from above
	_callout_t -= delta
	var on_bough := absf(player.global_position.y - 42.0) < 12.0 and player.global_position.x > 7700.0
	if quest == "none" and on_bough and _callouts < 3 and _callout_t <= 0.0:
		_callouts += 1
		_callout_t = 10.0
		hud.say("A voice from above:  \"Psst! Hairless one! Up here!\"", 3.0)


## A note that trips only inside a small area (a secret spot), not on passing an x.
func _spot(r: Rect2, text: String) -> void:
	var t := World.Trigger.new(r)
	t.tripped.connect(func() -> void: hud.say(text, 4.0))
	add_child(t)


func _on_gem() -> void:
	gem_found = true
	hud.set_gem(true)
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
	if not player.has_torch:
		player.give_torch()
		hud.say("He pulls a burning branch from the fire. Bonfires feed it — keep it lit.", 5.0)


func _on_exit() -> void:
	if finished:
		return
	finished = true
	player.set_physics_process(false)
	var tail := "" if gem_found else " (He never got the gem.)"
	hud.say("Through the woods. Next: the Long Dark, and the sabre-tooth." + tail, 999.0)


func _process(delta: float) -> void:
	super._process(delta)
	_told_out = maxf(_told_out - delta, 0.0)
	hud.set_torch(player.has_torch, player.torch_fuel)
	sky.dusk = clampf(1.0 - player.global_position.x / 1500.0, 0.0, 1.0)
	var r := _region_at(player.global_position.x)
	if r != _region:
		_apply_region(r)
	_update_elder(delta)
