extends LevelBase
## Level 2: Discovery of Fire. Night falls as he walks. The torch is his sight
## and his defence at once, and it burns down; bonfires feed it.
##   Dusk camp (0-900)          the torch, and the first eyes in the trees
##   Firelit woods (900-3980)   wolves, bats, dead trees, fire, the pack in the hollow
##   The Mountain (3980-7050)   a hard climb in the wind; a crevice stash; a lookout
##   The Great Tree (7050-8420) climb it, cross the chasm on its bough, mind the monkeys;
##                              the gem is at the very top, in a monkey's hands
##   Far side (8420-9300)       last bonfire, last wolves, the way on
## Still to come: the Long Dark and the sabre-tooth arena.

const GROUND_Y := 600.0
const LEVEL_W := 9300.0
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
]
## [x, y, habit, hanging, has the gem]
const MONKEYS := [
	[7660.0, 378.0, 0, false, false],
	[7360.0, 280.0, 0, true, false],     # hanging under a branch by its tail
	[7790.0, 42.0, 0, false, false], [8010.0, 42.0, 1, false, false], [8240.0, 42.0, 0, false, false],
	[7640.0, -183.0, 1, false, false],
	[7600.0, -408.0, 0, false, true],    # the one with the gem
]

## [x, y, lit at start]
const BONFIRES := [[520.0, GROUND_Y, true], [1720.0, GROUND_Y, false], [3560.0, GROUND_Y, false],
	[5710.0, -278.0, false], [7130.0, GROUND_Y, false], [8570.0, GROUND_Y, false]]
## [x, y, bundles of wood in it]
const DEAD_TREES := [[1260.0, GROUND_Y, 2], [2400.0, 400.0, 1], [2855.0, GROUND_Y, 2], [5130.0, -52.0, 2], [7290.0, GROUND_Y, 2]]
## Loose bundles already on the ground: the crevice stash.
const WOOD := [[4200.0, 720.0], [4370.0, 720.0]]
## [left, right, start_x, floor_y]. Kept clear of the bonfires' light.
const WOLVES := [
	[1000.0, 1490.0, 1330.0, GROUND_Y], [1000.0, 1490.0, 1450.0, GROUND_Y],
	[2040.0, 2590.0, 2420.0, GROUND_Y], [2040.0, 2590.0, 2540.0, GROUND_Y],
	[2915.0, 3335.0, 3120.0, 700.0], [2915.0, 3335.0, 3220.0, 700.0], [2915.0, 3335.0, 3310.0, 700.0],
	[8880.0, 9200.0, 9000.0, GROUND_Y], [8880.0, 9200.0, 9140.0, GROUND_Y],
]
const BAT_HOVER := 70.0
## [x, the surface this bat belongs to]
const BATS := [[1880.0, GROUND_Y], [2360.0, 400.0], [4735.0, 172.0], [5455.0, -165.0]]
const ROCK_PILES := [[760.0, GROUND_Y], [2130.0, 490.0], [2785.0, GROUND_Y], [5230.0, -52.0], [7200.0, GROUND_Y]]
const BERRIES := [[960.0, 500.0], [2320.0, 400.0], [4290.0, 720.0], [5510.0, -398.0]]
## [x, darkness]. Dusk at the camp, darkest in the woods, thinner on the
## mountain where the moon reaches, dark again under the great tree.
const DARKNESS := [[0.0, 0.26], [700.0, 0.40], [1500.0, 0.62], [2600.0, 0.72], [3600.0, 0.74],
	[4300.0, 0.62], [5000.0, 0.56], [5700.0, 0.50], [6600.0, 0.60], [7100.0, 0.70], [7600.0, 0.64],
	[8500.0, 0.72], [9300.0, 0.74]]

var night: Night
var sky: NightWoods.NightSky
var _told_wood := false
var _told_out := 0.0
var _told_monkeys := false


func _ready() -> void:
	level_w = LEVEL_W
	fall_y = FALL_Y
	cam_top = -900
	title = "LEVEL 2   DISCOVERY OF FIRE"
	_build_background()
	_build_world()
	_build_player(Vector2(140, GROUND_Y))
	# he keeps the club from Level 1, and he has his first hide
	player.pick_up_stick()
	player.costume = 2
	_build_critters()
	_build_tree_life()
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
	hud.say("Night is coming, and something is out there. He needs fire.", 5.0)


func _build_background() -> void:
	var sky_layer := CanvasLayer.new()
	sky_layer.layer = -120
	add_child(sky_layer)
	sky = NightWoods.NightSky.new()
	sky_layer.add_child(sky)

	var pb := ParallaxBackground.new()
	pb.layer = -100
	add_child(pb)
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


func _build_tree_life() -> void:
	for m in MONKEYS:
		var monkey := NightBeasts.Monkey.new()
		monkey.position = Vector2(m[0], m[1])
		monkey.habit = m[2]
		monkey.hanging = m[3]
		monkey.has_gem = m[4]
		monkey.player = player
		monkey.shrieked.connect(func() -> void:
			if not _told_monkeys:
				_told_monkeys = true
				hud.say("Now he's done it. Bananas that miss him are food, at least.", 4.0))
		monkey.gem_dropped.connect(func(g: World.Gem) -> void:
			g.found.connect(_on_gem))
		add_child(monkey)


## A note that trips only inside a small area (a secret spot), not on passing an x.
func _spot(r: Rect2, text: String) -> void:
	var t := World.Trigger.new(r)
	t.tripped.connect(func() -> void: hud.say(text, 4.0))
	add_child(t)


func _on_gem() -> void:
	gem_found = true
	hud.say("The hidden gem! Right out of the monkey's hands.", 4.0)


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
	var tail := "" if gem_found else " (He never found the gem.)"
	hud.say("Through the woods. Next: the Long Dark, and the sabre-tooth." + tail, 999.0)


func _process(delta: float) -> void:
	super._process(delta)
	_told_out = maxf(_told_out - delta, 0.0)
	hud.set_torch(player.has_torch, player.torch_fuel)
	sky.dusk = clampf(1.0 - player.global_position.x / 1500.0, 0.0, 1.0)
