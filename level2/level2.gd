extends LevelBase
## Level 2: Discovery of Fire. Night falls as he walks. The torch is his sight
## and his defence at once, and it burns down; bonfires feed it.
##   Dusk camp (0-900)          the torch, and the first eyes in the trees
##   Firelit woods (900-3980)   wolves, bats, dead trees, fire, the pack in the hollow
##   The Mountain (3980-7050)   a hard climb in the wind; a crevice stash; a lookout
##   The Great Tree (7050-8420) climb it, cross the chasm on its bough, mind the monkeys.
##                              At the very top: Old Bongo, the monkey king, who talks.
##   Far side (8420-10600)      last bonfire, a dead snag to climb back up, wolves running scared
##   The Long Dark (10600-12700) the roar that snuffs his torch; fireflies; vines; crumbling rock
##   The Toolmaker (12700-13400) a hermit's fire: the forge (gem -> Fire Club) and his shop
##   Old Scar's clearing (13400-14700) the boss
##
## The story: Old Bongo has lost the key to his banana box in one of two
## caves, and he'll trade the gem for it. Which cave is decided fresh each
## time the level starts. His memory of what chased him, and what lies at each
## cave's door, are the clues. The caves are built off to the right of the
## woods (x > 10,000); their doorways fade him there and back.
##   The Weeping Cave  (mouth in the mountain's foot)  spiders, webs; a cocoon in the roof
##   The Rattling Cave (mouth in the far-side outcrop) rats, snakes; the rats' hoard
## Beaten, Old Scar flees and dawn comes up; the end-of-level scroll counts
## what was found.

const GROUND_Y := 600.0
const LEVEL_W := 14700.0
const FALL_Y := 1020.0

## Reachability budget: a jump climbs ~133 px and carries ~227 px. Every step
## here asks for 100-125 up; the mountain's are the ones near the top of that.
## Ground runs: [x0, x1] at GROUND_Y.
const FLOORS := [[0.0, 1500.0], [1640.0, 2600.0], [2760.0, 2900.0], [3350.0, 3980.0], [7050.0, 7700.0],
	[8420.0, 10900.0], [11300.0, 11600.0], [12000.0, 12250.0], [12700.0, LEVEL_W]]
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
	[21470.0, 700.0, false], [23860.0, 600.0, false]]   # an old hearth in each cave
## [x, y, bundles of wood in it]
const DEAD_TREES := [[1260.0, GROUND_Y, 2], [2400.0, 400.0, 1], [2855.0, GROUND_Y, 2], [5130.0, -52.0, 2], [7290.0, GROUND_Y, 2]]
## Loose bundles already on the ground: the crevice stash.
const WOOD := [[4200.0, 720.0], [4370.0, 720.0], [21600.0, 700.0], [23990.0, 600.0]]
## [left, right, start_x, floor_y]. Kept clear of the bonfires' light.
const WOLVES := [
	[1000.0, 1490.0, 1330.0, GROUND_Y], [1000.0, 1490.0, 1450.0, GROUND_Y],
	[2040.0, 2590.0, 2420.0, GROUND_Y], [2040.0, 2590.0, 2540.0, GROUND_Y],
	[2915.0, 3335.0, 3120.0, 700.0], [2915.0, 3335.0, 3220.0, 700.0], [2915.0, 3335.0, 3310.0, 700.0],
	[8890.0, 9300.0, 9050.0, GROUND_Y], [8890.0, 9300.0, 9200.0, GROUND_Y],
]
const BAT_HOVER := 70.0
## [x, the surface this bat belongs to]
const BATS := [[1880.0, GROUND_Y], [2360.0, 400.0], [4735.0, 172.0], [5455.0, -165.0], [21335.0, 700.0]]
const ROCK_PILES := [[760.0, GROUND_Y], [2130.0, 490.0], [2785.0, GROUND_Y], [5230.0, -52.0], [7200.0, GROUND_Y], [20600.0, 600.0]]
const BERRIES := [[960.0, 500.0], [2320.0, 400.0], [4290.0, 720.0], [5510.0, -398.0], [21700.0, 700.0], [24020.0, 600.0]]

## ---------------------------------------------------------------- caves
## Each cave: its camera bounds, its rock [x, y, w, h, kind], where he comes in,
## and its doorway outside [x, y, which way he walks in, "webs" | "skin"].
const CAVE_A := Rect2(20300, 150, 2100, 800)      # the Weeping Cave
const CAVE_A_ROCK := [
	[20300.0, 150.0, 100.0, 800.0, "wall"], [22300.0, 150.0, 100.0, 800.0, "wall"],
	[20400.0, 600.0, 500.0, 350.0, "floor"], [20900.0, 700.0, 350.0, 250.0, "floor"],
	[21420.0, 700.0, 660.0, 250.0, "floor"],           # after the pit
	[21800.0, 590.0, 100.0, 18.0, "floor"], [21950.0, 480.0, 100.0, 18.0, "floor"],
	[22080.0, 380.0, 220.0, 570.0, "floor"],           # the cocoon chamber
	[20400.0, 150.0, 500.0, 270.0, "roof"], [20900.0, 150.0, 860.0, 320.0, "roof"],
	[21760.0, 150.0, 320.0, 100.0, "roof"], [22080.0, 150.0, 220.0, 30.0, "roof"],
]
const CAVE_A_IN := Vector2(20470, 600)
const CAVE_A_DOOR := [7050.0, GROUND_Y, -1, "webs"]
const CAVE_A_WEBS := [[20840.0, 600.0, 180.0], [22160.0, 380.0, 200.0]]
## [x, roof y, floor y, left, right]
const SPIDERS := [[21080.0, 470.0, 700.0, 20910.0, 21240.0], [21650.0, 470.0, 700.0, 21440.0, 22070.0],
	[22140.0, 180.0, 380.0, 22090.0, 22290.0]]
const COCOON := [22240.0, 180.0, 380.0]

const CAVE_B := Rect2(22800, 150, 1700, 800)      # the Rattling Cave
const CAVE_B_ROCK := [
	[22800.0, 150.0, 100.0, 800.0, "wall"], [24400.0, 150.0, 100.0, 800.0, "wall"],
	[22900.0, 600.0, 400.0, 350.0, "floor"], [23300.0, 510.0, 90.0, 440.0, "floor"],   # a pillar, with a snake in it
	[23390.0, 600.0, 1010.0, 350.0, "floor"],
	[24120.0, 490.0, 110.0, 18.0, "floor"], [24260.0, 380.0, 140.0, 18.0, "floor"],   # up to the hoard
	[22900.0, 150.0, 400.0, 180.0, "roof"], [23300.0, 150.0, 120.0, 180.0, "roof"],
	[23420.0, 150.0, 340.0, 370.0, "roof"],            # the crawl tunnel: no room to jump
	[23760.0, 150.0, 640.0, 60.0, "roof"],
]
const CAVE_B_IN := Vector2(22970, 600)
## In the outcrop's far face: he sees it behind him once he has climbed over.
const CAVE_B_DOOR := [9600.0, GROUND_Y, -1, "skin"]
## [left, right, start x, floor y]
const RATS := [[22920.0, 23280.0, 23100.0, 600.0], [22920.0, 23280.0, 23220.0, 600.0],
	[23400.0, 23740.0, 23500.0, 600.0], [23400.0, 23740.0, 23650.0, 600.0],
	[23780.0, 24380.0, 24000.0, 600.0], [23780.0, 24380.0, 24250.0, 600.0]]
## [hole x, hole y, facing]
const SNAKES := [[23300.0, 580.0, -1], [24400.0, 580.0, -1]]
const NEST := [24330.0, 380.0]

## ---------------------------------------------------------------- the Long Dark
## [anchor x, anchor y, length]: the grip hangs at anchor y + length.
const VINES := [[11100.0, 330.0, 190.0], [12390.0, 320.0, 200.0], [12560.0, 320.0, 200.0]]
## [x, top y, width]: rotten rock over the second pit.
const CRUMBLES := [[11630.0, 600.0, 80.0], [11760.0, 600.0, 80.0], [11890.0, 600.0, 80.0]]
const FIREFLIES := [[10800.0, 520.0], [11100.0, 440.0], [11450.0, 520.0], [11800.0, 480.0], [12120.0, 520.0], [12470.0, 420.0]]
## eyes in the trees, watching
const WATCHERS := [[9950.0, 430.0], [10700.0, 400.0], [11520.0, 380.0], [12250.0, 390.0]]
const CLAW_MARKS := [[10150.0, 470.0], [11380.0, 460.0]]
const PANIC_AT := 9950.0          ## the wolves come running past here
const SNUFF_AT := 10650.0         ## the roar, and the dark

## ---------------------------------------------------------------- the end
const TOOLMAKER_AT := Vector2(13020, 600)
const ARENA := Rect2(13400, -900, 1300, 2100)
const BRAZIERS := [[13520.0, 600.0], [14580.0, 600.0]]
const ARENA_LEDGES := [[13700.0, 480.0, 140.0], [14260.0, 480.0, 140.0]]
const BONGO_PERCH := Vector2(13470, 330)

## ---------------------------------------------------------------- treasure
## Rows of shells [x0, x1, surface y, how many], floating a hand's height up.
const SHELL_ROWS := [
	[200.0, 440.0, 600.0, 5], [620.0, 850.0, 600.0, 4], [895.0, 1035.0, 500.0, 4], [1100.0, 1460.0, 600.0, 6],
	[1680.0, 2040.0, 600.0, 5], [2090.0, 2215.0, 490.0, 3], [2300.0, 2425.0, 400.0, 3], [2930.0, 3320.0, 700.0, 6],
	[3380.0, 3950.0, 600.0, 6], [3990.0, 4150.0, 490.0, 3], [4410.0, 4540.0, 285.0, 3], [5070.0, 5300.0, -52.0, 4],
	[5620.0, 5980.0, -278.0, 6], [6020.0, 6190.0, -155.0, 2], [6400.0, 6570.0, 95.0, 2], [6780.0, 6950.0, 345.0, 2],
	[7070.0, 7440.0, 600.0, 5], [7600.0, 8440.0, 42.0, 8], [8430.0, 9300.0, 600.0, 7], [9650.0, 10880.0, 600.0, 8],
	[11320.0, 11590.0, 600.0, 4], [12010.0, 12240.0, 600.0, 3], [12720.0, 12880.0, 600.0, 3],
	[20420.0, 20880.0, 600.0, 5], [21430.0, 22060.0, 700.0, 6], [22920.0, 23280.0, 600.0, 5],
	[23420.0, 23740.0, 600.0, 4], [23800.0, 24100.0, 600.0, 4],
]
## Single shells, mostly strung along jump arcs and vine swings to show the way.
const SHELL_POINTS := [
	[1520.0, 540.0], [1570.0, 515.0], [1620.0, 540.0], [2630.0, 540.0], [2680.0, 515.0], [2730.0, 540.0],
	[4240.0, 360.0], [4290.0, 360.0], [4705.0, 150.0], [4760.0, 150.0], [4885.0, 38.0], [4945.0, 38.0],
	[5430.0, -188.0], [5480.0, -188.0],
	[10960.0, 470.0], [11040.0, 520.0], [11160.0, 520.0], [11240.0, 470.0],
	[11670.0, 560.0], [11800.0, 560.0], [11930.0, 560.0],
	[12320.0, 480.0], [12475.0, 520.0], [12640.0, 480.0],
]
## [x, y]: conches (5) in out-of-the-way spots.
const CONCHES := [
	[1000.0, 470.0], [2370.0, 370.0], [3310.0, 670.0], [4380.0, 690.0], [5980.0, -300.0], [7450.0, -430.0],
	[8660.0, 20.0], [9480.0, 460.0], [11230.0, 430.0], [21900.0, 670.0], [22260.0, 350.0], [24300.0, 570.0], [24160.0, 460.0],
]
## [x, y, secret]: amber (25), one in each secret place.
const AMBERS := [[4330.0, 690.0, "crevice"], [5520.0, -420.0, "lookout"], [22180.0, 350.0, "weeping"], [24370.0, 350.0, "rattling"]]
## [x, surface y, "log" | "mound", contents]
const BREAKABLES := [
	[700.0, 600.0, "log", ["shell", "shell", "shell", "conch"]],
	[1950.0, 600.0, "mound", ["conch", "conch", "shell", "shell", "shell"]],
	[3480.0, 600.0, "log", ["shell", "shell", "shell", "conch"]],
	[5180.0, -52.0, "mound", ["conch", "conch", "shell", "shell", "shell"]],
	[7380.0, 600.0, "log", ["shell", "shell", "shell", "conch"]],
	[9100.0, 600.0, "log", ["shell", "shell", "shell", "conch"]],
	[11480.0, 600.0, "mound", ["conch", "conch", "shell", "shell", "shell"]],
	[12790.0, 600.0, "log", ["shell", "shell", "shell", "conch"]],
]
const SECRETS := ["crevice", "lookout", "weeping", "rattling"]
## [x, darkness]. Dusk at the camp, darkest in the woods, thinner on the
## mountain where the moon reaches, dark again under the great tree.
const DARKNESS := [[0.0, 0.26], [700.0, 0.40], [1500.0, 0.62], [2600.0, 0.72], [3600.0, 0.74],
	[4300.0, 0.62], [5000.0, 0.56], [5700.0, 0.50], [6600.0, 0.60], [7100.0, 0.70], [7600.0, 0.64],
	[8500.0, 0.72], [10000.0, 0.76], [10600.0, 0.86], [10700.0, 0.92], [12650.0, 0.92],   # the Long Dark
	[12800.0, 0.76], [13400.0, 0.82], [14700.0, 0.82],                                    # the Toolmaker; the clearing
	[20250.0, 0.92], [24600.0, 0.92]]   # the caves: near black

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
var _region := 0             ## 0 the woods, 1 the Weeping Cave, 2 the Rattling Cave, 3 the fight
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
	_build_long_dark()
	_build_the_end()
	_build_treasure()
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
	_spot(Rect2(4160, 620, 240, 110), "A crack in the rock — and someone's stash in it.", "crevice")
	_spot(Rect2(5470, -480, 80, 90), "From up here, the whole valley. And something glints, high in the great tree.", "lookout")
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


func _talk(lines: Array, after: Callable = Callable(), _speaker: Node = null) -> void:
	var d := Dialogue.new()
	d.lines = lines
	d.player = player
	d.line_started.connect(func(who: String) -> void:
		if elder != null:
			elder.speaking = who == "OLD BONGO"
		if toolmaker != null:
			toolmaker.speaking = who == "TOOLMAKER")
	d.finished.connect(func() -> void:
		if elder != null:
			elder.speaking = false
		if toolmaker != null:
			toolmaker.speaking = false
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


## ---------------------------------------------------------------- the Long Dark
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
			wolf.panic_end = 9660.0
			wolf.left_x = 9000.0
			wolf.right_x = 11000.0
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
	# the Toolmaker, at his fire
	toolmaker = NightBeasts.Toolmaker.new()
	toolmaker.position = TOOLMAKER_AT
	toolmaker.player = player
	add_child(toolmaker)
	# the clearing: two stone bowls, two ledges, a gate that shuts behind him
	for b in BRAZIERS:
		var bowl := NightWoods.Brazier.new()
		bowl.position = Vector2(b[0], b[1])
		add_child(bowl)
	for l in ARENA_LEDGES:
		add_child(NightWoods.Crag.new(Rect2(l[0], l[1], l[2], 18)))
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
	scar.ledges = []
	for l in ARENA_LEDGES:
		scar.ledges.append([l[0], l[0] + l[2], l[1]])
	scar.roared.connect(_on_scar_roar)
	scar.phase_changed.connect(_on_scar_phase)
	scar.beaten.connect(_on_scar_beaten)
	add_child(scar)
	arena_bongo = NightBeasts.Elder.new()
	arena_bongo.position = BONGO_PERCH
	arena_bongo.show_box = false
	arena_bongo.has_gem = false
	arena_bongo.player = player
	arena_bongo.visible = false
	add_child(arena_bongo)
	player.died.connect(_on_died_in_fight)
	_note(12200, "Firelight ahead. Someone lives out here.", 3.0)


func _update_toolmaker() -> void:
	if player.dead or player.talking or player.fury >= 0.0 or _fight:
		return
	var d := absf(player.global_position.x - toolmaker.global_position.x)
	var near := d < 150.0 and absf(player.global_position.y - toolmaker.global_position.y) < 40.0 and player.is_on_floor()
	if near and not _near_toolmaker:
		_near_toolmaker = true
		if not _met_toolmaker:
			_met_toolmaker = true
			var lines := [
				["TOOLMAKER", "Hm? A live one. Most who walk the Long Dark end up as his supper."],
				["CAVEMAN", "Ugh?"],
				["TOOLMAKER", "Old Scar. The sabre-tooth. He took this arm, forty winters ago."],
				["TOOLMAKER", "His clearing is just past my fire. He fears one thing: fire in his face. Hold your torch toward him when he leaps."],
				["TOOLMAKER", "And light the two old stone bowls. Their fire will keep him off you — and relight your torch when he roars it out."],
			]
			if gem_found and GameState.gems.get("level2", "") == "found":
				lines.append(["TOOLMAKER", "Wait... what's that you carry? A Firestone! Give it here, and I'll forge you a club that bites like fire."])
			else:
				lines.append(["TOOLMAKER", "If you had something that burns inside — a Firestone — I could forge you a weapon that bites. You don't. Pity."])
			lines.append(["TOOLMAKER", "I trade, too. Shells for my work. Let's see what you've got."])
			_talk(lines, _open_shop, toolmaker)
		else:
			hud.say("TOOLMAKER:  \"Back again? Let's see your shells.\"", 2.0)
			_open_shop()
	elif not near and d > 260.0:
		_near_toolmaker = false


## ---------------------------------------------------------------- the shop
const WARES := [
	["forge", "Forge the Firestone into the Fire Club", "His club burns: harder hits, Old Scar always flinches from it, and it feeds his torch: never below half, and no roar can put it out.", 0],
	["heart", "An extra heart", "Toughened by the Toolmaker's bitter roots: one more heart, for good.", 60],
	["torch", "A long-burning torch", "Resin-soaked wrappings: his torch burns 40% longer.", 40],
	["pouch", "A bigger pouch", "Carry one more bundle of wood, two more rocks and one more berry.", 40],
	["club", "A heavier club", "A stone knot bound into the head: every club hit does one more damage.", 80],
	["wolf_pelt", "Skin: Wolf Pelt", "A grey wolf-fur loincloth. Looks wonderful. Does nothing.", 30],
	["war_paint", "Skin: War Paint", "Red stripes across the brow and chest. Fearsome.", 20],
	["bone_necklace", "Skin: Bone Necklace", "A cord of small bones. Every hunter wants one.", 25],
	["plain", "Skin: Plain", "His ordinary look.", 0],
]


func _open_shop() -> void:
	var shop := Shop.new()
	shop.title = "THE TOOLMAKER"
	shop.player = player
	shop.list_items = _shop_items
	shop.buy = _shop_buy
	add_child(shop)


func _shop_items() -> Array:
	var out: Array = []
	for w in WARES:
		var id: String = w[0]
		var price: int = w[3]
		var text := "%d shells" % price
		var enabled := GameState.shells >= price
		if id == "forge":
			var gem_state: String = GameState.gems.get("level2", "")
			if gem_state == "forged":
				text = "forged"
				enabled = false
			elif gem_state == "found":
				text = "costs the Firestone"
				enabled = true
			else:
				text = "needs a Firestone"
				enabled = false
		elif id in GameState.upgrades:
			var have: int = GameState.upgrades[id]
			if have >= int(GameState.UPGRADE_MAX[id]):
				text = "owned"
				enabled = false
			elif id == "heart" and have == 1:
				price = 120
				text = "120 shells"
				enabled = GameState.shells >= price
		else:
			if GameState.skin == id:
				text = "wearing"
				enabled = false
			elif id in GameState.skins or id == "plain":
				text = "wear"
				enabled = true
		out.append({"id": id, "name": w[1], "desc": w[2], "price_text": text, "enabled": enabled})
	return out


func _shop_buy(id: String) -> String:
	var price := 0
	for w in WARES:
		if w[0] == id:
			price = w[3]
	if id == "forge":
		GameState.gems["level2"] = "forged"
		player.fire_club = true
		toolmaker.forging = 1.6
		GameState.save()
		return "Sparks fly. The Fire Club! It burns — and never burns out."
	if id in GameState.upgrades:
		if id == "heart" and int(GameState.upgrades["heart"]) == 1:
			price = 120
		if GameState.shells < price:
			return "Not enough shells."
		GameState.shells -= price
		GameState.upgrades[id] = int(GameState.upgrades[id]) + 1
		_apply_upgrade(id)
		GameState.save()
		hud.set_shells(GameState.shells)
		return "Done. The Toolmaker grunts, pleased."
	# skins: buy once, then wear any time
	if not (id in GameState.skins) and id != "plain":
		if GameState.shells < price:
			return "Not enough shells."
		GameState.shells -= price
		GameState.skins.append(id)
	GameState.skin = id
	player.skin = id
	GameState.save()
	hud.set_shells(GameState.shells)
	return "He tries it on. Very fine."


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
	hud.title_card("OLD SCAR", "Terror of the Long Dark")
	hud.set_boss(1.0)
	var line := "OLD BONGO (from the treetops):  \"Hairless one! Keep your little sun in his face — he hates it!\""
	if monkey_kills > 0:
		line = "OLD BONGO (from the treetops):  \"You hit my family. Good luck, hairless one.\""
	get_tree().create_timer(3.4).timeout.connect(func() -> void: hud.say(line, 4.0))


func _on_scar_roar() -> void:
	if not _fight:
		return
	cam.offset = Vector2(0, 0)
	if scar.state == "intro":
		return
	if player.fire_club:
		hud.say("He roars — but the Firestone's fire holds. The torch burns on.", 3.0)
	elif player.has_torch and player.torch_fuel > 0.0:
		player.torch_fuel = 0.0
		hud.say("His roar snuffs the torch! Relight it at a stone bowl.", 3.0)
	for i in 4:
		var rock := NightWoods.FallingRock.new()
		rock.floor_y = GROUND_Y
		rock.position = Vector2(clampf(player.global_position.x + randf_range(-260.0, 260.0), ARENA.position.x + 60.0, ARENA.end.x - 60.0), 0)
		rock.delay = 0.7 + i * 0.25
		add_child(rock)


func _on_scar_phase(ph: int) -> void:
	if ph == 2:
		hud.say("OLD BONGO:  \"He'll roar your fire out! Light the stone bowls — relight there!\"", 4.0)
	elif ph == 3:
		hud.say("OLD BONGO:  \"He's charging blind! Step aside — let him hit the rocks!\"", 4.0)


func _on_died_in_fight() -> void:
	if not _fight:
		return
	# back to the Toolmaker's fire; the beast goes back into the dark
	_fight = false
	scar.reset_fight()
	arena_bongo.visible = false
	_gate.get_child(0).set_deferred("disabled", true)
	hud.set_boss(-1.0)


func _on_scar_beaten() -> void:
	_fight = false
	_scar_beaten = true
	hud.set_boss(-1.0)
	_gate.get_child(0).set_deferred("disabled", true)
	var fang := Caves.KeyItem.new()
	fang.real = false
	fang.position = scar.global_position
	fang.taken.connect(func(_r: bool) -> void: _on_fang())
	add_child(fang)
	hud.say("Old Scar turns and flees into the dark, limping. Something white lies where he fell.", 5.0)


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
			gem = "forged: Fire Club"
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
	var n := 0
	for r in SHELL_ROWS:
		var count: int = r[3]
		for i in count:
			var x := lerpf(r[0], r[1], (i + 0.5) / count)
			_treasure("shell", "s%d" % n, Vector2(x, float(r[2]) - 24.0))
			n += 1
	for p in SHELL_POINTS:
		_treasure("shell", "s%d" % n, Vector2(p[0], p[1]))
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
			_treasure_total += int(Treasure.VALUE[k])


func _treasure(kind: String, id: String, at: Vector2) -> void:
	_treasure_total += int(Treasure.VALUE[kind])
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


func _on_treasure(_value: int) -> void:
	hud.set_shells(GameState.shells)


## How much of this level's treasure has been taken, by value.
func _treasure_found() -> int:
	var total := 0
	var taken: Dictionary = GameState.taken.get("level2", {})
	for id in taken:
		var key := String(id)
		if key.begins_with("s"):
			total += 1
		elif key.begins_with("c"):
			total += 5
		elif key.begins_with("a"):
			total += 25
		elif key.begins_with("b"):
			var parts := key.substr(1).split("_")
			var b: Array = BREAKABLES[int(parts[0])]
			total += int(Treasure.VALUE[b[3][int(parts[1])]])
	return total


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
	super._process(delta)
	_told_out = maxf(_told_out - delta, 0.0)
	hud.set_torch(player.has_torch, player.torch_fuel)
	sky.dusk = clampf(1.0 - player.global_position.x / 1500.0, 0.0, 1.0)
	var r := 3 if _fight else _region_at(player.global_position.x)
	if r != _region:
		_apply_region(r)
	_update_elder(delta)
	if not finished:
		_time += delta
	_update_long_dark()
	_update_toolmaker()
	_update_fight(delta)
