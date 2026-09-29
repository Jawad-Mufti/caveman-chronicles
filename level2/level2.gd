extends LevelBase
## Level 2: Discovery of Fire. Night falls as he walks. The torch is his sight
## and his defence at once, and it burns down; bonfires feed it.
##   Dusk camp (0-900)          the torch, and the first eyes in the trees
##   Firelit woods (900-3980)   wolves, bats, dead trees, fire, the pack in the hollow
##   The Hanging Gorge (3980-5680) a ravine crossed by a chain of vines hanging from a
##                              fallen giant; a resting ledge; crumbling stepping stones
##   The Mountain (5680-8750)   a hard climb in the wind; a crevice stash; a lookout
##   The Great Tree (8750-10120) climb it, cross the chasm on its bough, mind the monkeys.
##                              At the very top: Old Bongo, the monkey king, who talks.
##   Far side (10120-12300)      last bonfire, a dead snag to climb back up, wolves running scared
##   The Long Dark (12300-14400) the roar that snuffs his torch; fireflies; vines; crumbling rock
##   The Toolmaker (14400-15080) his home under a rock overhang: the forge
##                              (Firestone -> the Firestone Hammer) and his shop
##   The Three Fires (15080-16000) a trial: a cracked boulder, wolves, and three
##                              stone bowls to light; they burn the gate down
##   Old Scar's clearing (15100-16400) the boss
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
const LEVEL_W := 17300.0
const FALL_Y := 1020.0

## Reachability budget: a jump climbs ~133 px and carries ~227 px. Every step
## here asks for 100-125 up; the mountain's are the ones near the top of that.
## Ground runs: [x0, x1] at GROUND_Y.
const FLOORS := [[0.0, 1500.0], [1640.0, 2600.0], [2760.0, 2900.0], [3350.0, 4060.0], [5420.0, 5680.0], [8750.0, 9400.0],
	[10120.0, 12600.0], [13000.0, 13300.0], [13700.0, 13950.0], [14400.0, LEVEL_W]]
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
	[5680.0, 490.0, 180.0, 710.0],     # first step up the mountain
	[5860.0, 720.0, 240.0, 480.0],     # crevice floor
	[5880.0, 610.0, 60.0, 16.0],       # the way back out of the crevice
	[5930.0, 385.0, 100.0, 18.0],
	[6100.0, 285.0, 200.0, 915.0],
	[6390.0, 172.0, 90.0, 18.0],       # narrow, and a bat waits here
	[6570.0, 60.0, 100.0, 18.0],
	[6760.0, -52.0, 260.0, 1252.0],    # a broad shelf: dead tree, rocks, a boulder
	[7110.0, -165.0, 90.0, 18.0],      # narrow, second bat
	[7290.0, -278.0, 420.0, 1478.0],   # the summit
	[7170.0, -398.0, 80.0, 18.0],      # the lookout, above and behind the summit
	# the way down, in steps
	[7710.0, -155.0, 190.0, 1355.0], [7900.0, -30.0, 190.0, 1230.0], [8090.0, 95.0, 190.0, 1105.0],
	[8280.0, 220.0, 190.0, 980.0], [8470.0, 345.0, 190.0, 855.0], [8660.0, 470.0, 90.0, 730.0],
	[11050.0, 490.0, 250.0, 710.0],     # the far-side outcrop: the Rattling Cave's mouth is in its far face
]
## Boulders to shelter behind, [x, surface y]. The wind blows down the climb
## (from the right), so the lee is the left side.
const BOULDERS := [[6265.0, 285.0], [6990.0, -52.0]]
const WIND_ZONE := [5870.0, 7290.0]
## ---------------------------------------------------------------- the Hanging Gorge
## Between the base camp and the mountain: a ravine crossed on old vines that
## hang from a giant tree fallen across it long ago. Two vines, a resting
## ledge, two more vines, two crumbling stepping stones, and the far side.
const GORGE_TRUNK := [3990.0, 5460.0, 250.0]        ## [x0, x1, y]: the fallen giant
const GORGE_VINES := [[4190.0, 262.0, 240.0], [4390.0, 262.0, 240.0], [4820.0, 262.0, 240.0], [5020.0, 262.0, 240.0]]
const GORGE_LEDGE := [4530.0, 520.0, 130.0]          ## the resting ledge
const GORGE_CRUMBLES := [[5170.0, 560.0, 70.0], [5290.0, 545.0, 70.0]]
## The mountain's silhouette, drawn behind the climb.
const MOUNTAIN := [[5630, 1200], [5660, 560], [5820, 430], [6020, 330], [6220, 230], [6420, 110], [6620, 0],
	[6820, -120], [7040, -210], [7220, -380], [7400, -420], [7600, -370], [7800, -230], [8080, 20],
	[8350, 230], [8600, 420], [8780, 1200]]

## The great tree: trunk centred here, and its branches as one-way platforms
## [x, top, width, grows from the left end?]. Left and right of the trunk in
## turn, 112 px apart; the long bough crosses the chasm; above it, the crown.
const TREE_X := 9220.0
const BRANCHES := [
	[9030.0, 490.0, 130.0, false], [9280.0, 378.0, 130.0, true], [9020.0, 266.0, 140.0, false],
	[9280.0, 154.0, 120.0, true],
	[9260.0, 42.0, 900.0, true],        # the long bough, over the chasm to the far side
	[9040.0, -70.0, 130.0, false], [9280.0, -183.0, 120.0, true], [9050.0, -296.0, 120.0, false],
	[9130.0, -408.0, 230.0, true],      # the crown
	# the dead snag on the far side: the way back up to the bough
	[10300.0, 490.0, 110.0, false], [10430.0, 378.0, 110.0, true], [10300.0, 266.0, 110.0, false],
	[10430.0, 154.0, 110.0, true], [10220.0, 42.0, 190.0, false],
]
const SNAG_X := 10415.0
## The troop: [x, y, habit, hanging]
const MONKEYS := [
	[9360.0, 378.0, 0, false],
	[9060.0, 280.0, 0, true],            # hanging under a branch by its tail
	[9490.0, 42.0, 0, false], [9710.0, 42.0, 1, false], [9940.0, 42.0, 0, false],
	[9340.0, -183.0, 1, false],
]
## Old Bongo sits at the top of the crown, beside his banana box.
const ELDER_AT := Vector2(9320, -408)

## [x, y, lit at start]
const BONFIRES := [[520.0, GROUND_Y, true], [1720.0, GROUND_Y, false], [3560.0, GROUND_Y, false],
	[7410.0, -278.0, false], [8830.0, GROUND_Y, false], [10270.0, GROUND_Y, false],
	[21470.0, 700.0, false], [23860.0, 600.0, false]]   # an old hearth in each cave
## [x, y, bundles of wood in it]
const DEAD_TREES := [[1260.0, GROUND_Y, 2], [2400.0, 400.0, 1], [2855.0, GROUND_Y, 2], [6830.0, -52.0, 2], [8990.0, GROUND_Y, 2]]
## Loose bundles already on the ground: the crevice stash.
const WOOD := [[5900.0, 720.0], [6070.0, 720.0], [21600.0, 700.0], [23990.0, 600.0]]
## [left, right, start_x, floor_y]. Kept clear of the bonfires' light.
const WOLVES := [
	[1000.0, 1490.0, 1330.0, GROUND_Y], [1000.0, 1490.0, 1450.0, GROUND_Y],
	[2040.0, 2590.0, 2420.0, GROUND_Y], [2040.0, 2590.0, 2540.0, GROUND_Y],
	[2915.0, 3335.0, 3120.0, 700.0], [2915.0, 3335.0, 3220.0, 700.0], [2915.0, 3335.0, 3310.0, 700.0],
	[10590.0, 11000.0, 10750.0, GROUND_Y], [10590.0, 11000.0, 10900.0, GROUND_Y],
]
const BAT_HOVER := 70.0
## [x, the surface this bat belongs to]
const BATS := [[1880.0, GROUND_Y], [2360.0, 400.0], [6435.0, 172.0], [7155.0, -165.0], [21335.0, 700.0]]
const ROCK_PILES := [[760.0, GROUND_Y], [2130.0, 490.0], [2785.0, GROUND_Y], [6930.0, -52.0], [8900.0, GROUND_Y], [20600.0, 600.0]]
const BERRIES := [[1030.0, 500.0], [2425.0, 400.0], [5970.0, 720.0], [7160.0, -398.0], [21700.0, 700.0], [23960.0, 600.0]]

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
const CAVE_A_DOOR := [8750.0, GROUND_Y, -1, "webs"]
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
const CAVE_B_DOOR := [11300.0, GROUND_Y, -1, "skin"]
## [left, right, start x, floor y]
const RATS := [[23020.0, 23280.0, 23120.0, 600.0], [23020.0, 23280.0, 23220.0, 600.0],
	[23400.0, 23740.0, 23500.0, 600.0], [23400.0, 23740.0, 23650.0, 600.0],
	[23780.0, 24380.0, 24000.0, 600.0], [23780.0, 24380.0, 24250.0, 600.0]]
## [hole x, hole y, facing]
const SNAKES := [[23300.0, 580.0, -1], [24400.0, 580.0, -1]]
const NEST := [24330.0, 380.0]

## ---------------------------------------------------------------- the Long Dark
## [anchor x, anchor y, length]: the grip hangs at anchor y + length.
const VINES := [[12800.0, 330.0, 190.0], [14090.0, 320.0, 200.0], [14260.0, 320.0, 200.0]]
## [x, top y, width]: rotten rock over the second pit.
const CRUMBLES := [[13330.0, 600.0, 80.0], [13460.0, 600.0, 80.0], [13590.0, 600.0, 80.0]]
const FIREFLIES := [[12500.0, 520.0], [12800.0, 440.0], [13150.0, 520.0], [13500.0, 480.0], [13820.0, 520.0], [14170.0, 420.0]]
## eyes in the trees, watching
const WATCHERS := [[11650.0, 430.0], [12400.0, 400.0], [13220.0, 380.0], [13950.0, 390.0]]
const CLAW_MARKS := [[11850.0, 470.0], [13080.0, 460.0]]
const PANIC_AT := 11650.0          ## the wolves come running past here
const SNUFF_AT := 12350.0         ## the roar, and the dark

## ---------------------------------------------------------------- the end
const TOOLMAKER_AT := Vector2(14760, 600)
const CAMP_AT := Vector2(14700, 600)       ## his home under the overhang
## The Three Fires: a trial between his home and the clearing. A cracked
## boulder bars the way; a pack of wolves waits in the dark; three stone bowls
## must all burn — then the old palisade across the path burns down.
const TRIAL_ROCK := Vector2(15170, 600)
const TRIAL_BOWLS := [[15340.0, 600.0], [15590.0, 480.0], [15830.0, 600.0]]
const TRIAL_LEDGE := [15520.0, 480.0, 140.0]
const TRIAL_WOLVES := [[15260.0, 15900.0, 15460.0], [15260.0, 15900.0, 15700.0], [15260.0, 15900.0, 15880.0]]
const TRIAL_GATE_X := 15950.0
const ARENA := Rect2(16000, -900, 1300, 2100)
const BRAZIERS := [[16120.0, 600.0], [17040.0, 600.0]]
const LAIR_X := 17220.0           ## his lair's mouth, in the rock at the far end
const ARENA_LEDGES := [[16300.0, 480.0, 140.0], [16860.0, 480.0, 140.0]]
const BONGO_PERCH := Vector2(16070, 330)

## ---------------------------------------------------------------- treasure
## Two kinds of find, in a fair mix. SHELLS (shell 1, conch 5, amber 25) are
## the currency: each one is found only once per save, so they can't be
## farmed. BONES (mammoth ribs 1, tusks 5) are the building material for his
## shelter: they come back on every visit. Clusters and arcs alternate the
## two; points marked "shell" or "tusk" are that; boxes hold a mix.
## Treasure is placed with a reason, never just lining the road:
##   arcs over a jump show where to go; small clusters reward a climb, a
##   detour or a risk; a column above each Moonpuff rewards bouncing; the
##   conches and amber sit in the out-of-the-way places; and the smashable
##   logs and mounds hold the biggest share.
## Clusters: [x0, x1, surface y, how many], a hand's height above the surface.
const SHELL_ROWS := [
	[895.0, 985.0, 500.0, 4],       # the first ledge above the camp: look up
	[2300.0, 2380.0, 400.0, 3],     # the high ledge by the dead tree
	[3060.0, 3190.0, 700.0, 5],     # down in the hollow, with the pack
	[6405.0, 6465.0, 172.0, 2],     # the narrow ledge with the bat
	[7125.0, 7185.0, -165.0, 2],    # the other narrow ledge
	[11140.0, 11210.0, 490.0, 3],     # on top of the outcrop
	[20560.0, 20640.0, 600.0, 3],   # Weeping Cave: by the rock pile
	[21490.0, 21570.0, 700.0, 3],   # Weeping Cave: past the pit, by the old hearth
	[23315.0, 23375.0, 510.0, 3],   # Rattling Cave: on the snake's pillar
	[23870.0, 23950.0, 600.0, 3],   # Rattling Cave: by the old hearth
]
## Single shells: arcs over jumps and swings, trails up the trees, and a
## column above each Moonpuff on the way down the mountain.
const SHELL_POINTS := [
	[1520.0, 540.0], [1570.0, 515.0], [1620.0, 540.0],              # the first pit
	[2630.0, 540.0], [2680.0, 515.0], [2730.0, 540.0],              # the second pit
	[7760.0, -395.0], [7760.0, -455.0], [7760.0, -515.0, "shell"],           # Moonpuff 1
	[8140.0, -145.0], [8140.0, -205.0], [8140.0, -265.0, "shell"],           # Moonpuff 2
	[8520.0, 105.0], [8520.0, 45.0], [8520.0, -15.0, "shell"],               # Moonpuff 3
	[9095.0, 466.0], [9345.0, 354.0], [9090.0, 242.0], [9340.0, 130.0],   # up the great tree
	[9105.0, -94.0], [9335.0, -207.0], [9110.0, -320.0, "shell"],            # on up to Bongo
	[10485.0, 354.0], [10485.0, 130.0],                               # up the snag
	[12660.0, 470.0], [12740.0, 520.0], [12860.0, 520.0], [12940.0, 470.0],   # the first vine's swing
	[13370.0, 560.0], [13500.0, 560.0], [13630.0, 560.0],           # the crumbling bridge
	[14020.0, 480.0], [14175.0, 520.0], [14340.0, 480.0],           # the two vines
	# the Hanging Gorge: along the swings, shells up at the top of them,
	# and a tusk and a conch waiting on the resting ledge
	[4230.0, 500.0], [4290.0, 520.0], [4350.0, 500.0],
	[4470.0, 380.0, "shell"], [4500.0, 350.0, "shell"],
	[4570.0, 494.0, "tusk"],
	[4860.0, 500.0], [4920.0, 520.0], [4980.0, 500.0],
	[5100.0, 380.0, "shell"], [5130.0, 350.0, "shell"],
	[5230.0, 510.0], [5350.0, 500.0],
	# up in the air over the path: a jump gets these...
	[1090.0, 482.0], [1130.0, 472.0], [1170.0, 482.0],
	[10720.0, 482.0], [10760.0, 472.0],
	[14490.0, 478.0],
	[20700.0, 478.0], [20740.0, 470.0],
	# ...and these, higher, need the double jump
	[3420.0, 352.0, "shell"], [3460.0, 342.0, "shell"], [3500.0, 352.0, "shell"],
	[8890.0, 348.0, "shell"], [8930.0, 342.0, "shell"],
	[13790.0, 348.0, "shell"], [13830.0, 342.0, "shell"],
]
## Conches (5): out-of-the-way spots.
const CONCHES := [
	[4630.0, 490.0],
	[1000.0, 470.0], [2400.0, 370.0], [3310.0, 670.0], [6080.0, 690.0], [7680.0, -300.0], [8140.0, -320.0],
	[9150.0, -430.0], [10360.0, 20.0], [11180.0, 460.0], [12930.0, 430.0], [21900.0, 670.0], [22260.0, 350.0],
	[24300.0, 570.0], [24160.0, 460.0],
]
## [x, y, secret]: amber (25), one in each secret place.
const AMBERS := [[6030.0, 690.0, "crevice"], [7220.0, -420.0, "lookout"], [22180.0, 350.0, "weeping"], [24370.0, 350.0, "rattling"]]
## [x, surface y, "log" | "mound", contents]: the treasure boxes.
const LOG := ["bone", "shell", "bone", "shell", "bone", "shell", "bone"]
const MOUND := ["bone", "shell", "bone", "shell", "bone", "shell", "tusk", "conch"]
const BREAKABLES := [
	[640.0, 600.0, "log", LOG], [1950.0, 600.0, "mound", MOUND], [3480.0, 600.0, "log", LOG],
	[7580.0, -278.0, "mound", MOUND], [10800.0, 600.0, "log", LOG],
	[13180.0, 600.0, "mound", MOUND], [14490.0, 600.0, "log", LOG],
	[21050.0, 700.0, "log", LOG], [24050.0, 600.0, "mound", MOUND],
]
## Clay pots, in little groups: one smack each, a few shells. [x, surface y, how many]
const POTS := [
	[5520.0, 600.0, 2],
	[330.0, 600.0, 2], [2170.0, 490.0, 2], [3640.0, 600.0, 3], [7490.0, -278.0, 2], [9170.0, 600.0, 2],
	[10180.0, 600.0, 2], [12520.0, 600.0, 2], [14620.0, 600.0, 3], [20500.0, 600.0, 2], [23000.0, 600.0, 2],
]
## Shell Totems: carved faces that spit two shells per hit, six hits.
const TOTEMS := [[2470.0, 600.0], [8000.0, -30.0], [13070.0, 600.0], [24180.0, 600.0]]
## Monkey stashes: a log marked with a red X — a fountain of treasure.
const STASH := ["bone", "shell", "bone", "shell", "bone", "shell", "bone", "shell", "bone", "shell", "tusk", "conch", "conch"]
const STASHES := [[9320.0, 600.0], [9170.0, -418.0]]
## Golden Hares: [left x, right x, start x, ground y] — catch one for a shower of treasure.
const HARES := [[3380.0, 3960.0, 3800.0, 600.0], [8760.0, 9400.0, 9260.0, 600.0], [10120.0, 10580.0, 10400.0, 600.0]]
const HARE_VALUE := 18
## Moonpuffs: bounce bushes on the mountain's way down, where he lands
## coming off each step.
const MOONPUFFS := [[7760.0, -155.0], [8140.0, 95.0], [8520.0, 345.0]]
const SECRETS := ["crevice", "lookout", "weeping", "rattling"]
## [x, darkness]. Dusk at the camp, darkest in the woods, thinner on the
## mountain where the moon reaches, dark again under the great tree.
const DARKNESS := [[0.0, 0.26], [700.0, 0.40], [1500.0, 0.62], [2600.0, 0.72], [3600.0, 0.74],
	[3950.0, 0.64], [4300.0, 0.50], [5400.0, 0.50], [5800.0, 0.60],                       # the gorge: the last light of dusk
	[6000.0, 0.62], [6700.0, 0.56], [7400.0, 0.50], [8300.0, 0.60], [8800.0, 0.70], [9300.0, 0.64],
	[10200.0, 0.72], [11700.0, 0.76], [12300.0, 0.86], [12400.0, 0.92], [14350.0, 0.92],   # the Long Dark
	[14500.0, 0.74], [15050.0, 0.76], [15150.0, 0.88], [15950.0, 0.88],                   # his home; the Three Fires
	[16000.0, 0.82], [17300.0, 0.82],                                                     # the clearing
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
	_build_gorge()
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
		["hammer", "THE FIRESTONE HAMMER", "Take it to the Toolmaker and he'll forge a legend. Hold attack, let go — FIRE SLAM! A wave of fire!"],
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
	for m in MOONPUFFS:
		var puff := NightWoods.MoonPuff.new()
		puff.position = Vector2(m[0], m[1])
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
	_note(3800, "A gorge — and old vines hanging from a fallen giant. Jump to a vine, swing, and let go at the top!", 5.0)
	_note(5500, "The only way on is up.", 3.0)
	_spot(Rect2(5860, 620, 240, 110), "A crack in the rock — and someone's stash in it.", "crevice")
	_spot(Rect2(7170, -480, 80, 90), "From up here, the whole valley. And something glints, high in the great tree.", "lookout")
	_note(8940, "Monkeys, up in the great tree. Leave them be and they leave him be.", 4.5)
	_note(10180, "A dead snag, right by the fire. Its branches go all the way back up to the bough.", 4.5)


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
	var on_bough := absf(player.global_position.y - 42.0) < 12.0 and player.global_position.x > 9400.0
	if quest == "none" and on_bough and _callouts < 3 and _callout_t <= 0.0:
		_callouts += 1
		_callout_t = 10.0
		hud.say("A voice from above:  \"Psst! Hairless one! Up here!\"", 3.0)


## ---------------------------------------------------------------- the Long Dark
## The Hanging Gorge: the fallen giant, its vines, the ledge, the crumbling stones.
func _build_gorge() -> void:
	var giant := NightWoods.FallenGiant.new()
	giant.position = Vector2(GORGE_TRUNK[0], GORGE_TRUNK[2])
	giant.w = GORGE_TRUNK[1] - GORGE_TRUNK[0]
	add_child(giant)
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
			wolf.panic_end = 11360.0
			wolf.left_x = 10700.0
			wolf.right_x = 12700.0
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
	_note(13900, "Firelight ahead, under the rocks. Someone lives out here.", 3.0)


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
	_note(TRIAL_ROCK.x - 140.0, "A boulder, split with old cracks. Something heavy could break it.", 3.5)


func _on_trial_fire() -> void:
	_trial_lit += 1
	if _trial_lit < TRIAL_BOWLS.size():
		hud.say("A bowl of fire! %d of %d." % [_trial_lit, TRIAL_BOWLS.size()], 2.5)
		return
	hud.say("The third fire! The old stakes across the path catch light...", 4.0)
	hud.set_quest("Face Old Scar")
	_trial_gate.burn()


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
			lines.append(["TOOLMAKER", "Past my fire, three old bowls stand before the stakes of his clearing. Light all three, and the way opens."])
			if gem_found and GameState.gems.get("level2", "") == "found":
				lines.append(["TOOLMAKER", "Wait... what's that you carry? A FIRESTONE?! Boy, I've waited forty winters to see one of those."])
				lines.append(["TOOLMAKER", "Pick it from my wares. Pay me nothing. Some things are worth more than shells."])
			else:
				lines.append(["TOOLMAKER", "If you had a Firestone, I could make you something he'd fear... but you don't. Pity."])
			lines.append(["TOOLMAKER", "I trade, too. Shells for my work. Let's see what you've got."])
			_talk(lines, _open_shop, toolmaker)
		else:
			hud.say("TOOLMAKER:  \"Back again? Let's see your shells.\"", 2.0)
			_open_shop()
	elif not near and d > 260.0:
		_near_toolmaker = false


## ---------------------------------------------------------------- the shop
## ---------------------------------------------------------------- the shop
## The economy. Prices are worked out from how much treasure the level holds
## (_treasure_total), so that a player who finds about 60% of it can buy
## exactly one new weapon, one new costume and three roast figs:
##     axe 26%  +  a costume ~19%  +  3 figs x 4%   =  57%
## The upgrades are extra, for the ones who search every corner. Move or add
## treasure and the prices follow on their own.
const ECONOMY := {"axe": 0.26, "wolf_hood": 0.16, "ember_paint": 0.18, "bear_cloak": 0.21, "firekeeper": 0.20,
	"fig": 0.04, "heart": 0.18, "torch": 0.11, "pouch": 0.11}
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
					item["price"] = 0
					var gem: String = GameState.gems.get("level2", "")
					if gem == "found":
						item["note"] = "COSTS THE FIRESTONE"
						item["can"] = true
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
	for i in STASHES.size():
		var box := Treasure.Breakable.new()
		box.kind = "stash"
		box.contents = STASH
		box.level_id = "level2"
		box.id = "x%d" % i
		box.position = Vector2(STASHES[i][0], STASHES[i][1])
		add_child(box)
		for c in STASH:
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
	super._process(delta)
	_told_out = maxf(_told_out - delta, 0.0)
	hud.set_torch(player.has_torch, player.torch_fuel)
	sky.dusk = clampf(1.0 - player.global_position.x / 1500.0, 0.0, 1.0)
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
	_update_fight(delta)
