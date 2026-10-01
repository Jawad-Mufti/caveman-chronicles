extends LevelBase
## Level 2's data tables: layout coordinates, loot, the caves, the sky lanes and
## the economy. level2.gd extends this file, so its builders use every table by
## its bare name. Treasure ids are by index: never insert into the old loot tables.

const GROUND_Y := 600.0
const LEVEL_W := 19300.0
const FALL_Y := 1020.0

## Reachability budget: a jump climbs ~133 px and carries ~227 px. Every step
## here asks for 100-125 up; the mountain's are the ones near the top of that.
## Ground runs: [x0, x1] at GROUND_Y.
const FLOORS := [[0.0, 1500.0], [1640.0, 2600.0], [2760.0, 2900.0], [3350.0, 4060.0], [5420.0, 5680.0], [8750.0, 9400.0],
	[10120.0, 12620.0], [12730.0, 13100.0], [13230.0, 13640.0], [13780.0, 13940.0], [14100.0, 14600.0], [15000.0, 15300.0], [15700.0, 15950.0], [16400.0, LEVEL_W]]
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
## The vines hang far apart: every swing needs a well-timed release, or it's
## a long drop into the ravine.
const GORGE_VINES := [[4200.0, 262.0, 255.0], [4500.0, 262.0, 255.0], [4940.0, 262.0, 255.0], [5250.0, 262.0, 255.0]]
const GORGE_LEDGE := [4640.0, 520.0, 140.0]          ## a narrow resting ledge
const GORGE_CRUMBLES := []
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
	[21470.0, 700.0, false], [23290.0, 700.0, false], [25140.0, 600.0, false], [26300.0, 600.0, false]]   # old hearths in the caves
## [x, y, bundles of wood in it]
const DEAD_TREES := [[1260.0, GROUND_Y, 2], [2400.0, 400.0, 1], [2855.0, GROUND_Y, 2], [6830.0, -52.0, 2], [8990.0, GROUND_Y, 2]]
## Loose bundles already on the ground: the crevice stash.
const WOOD := [[5900.0, 720.0], [6070.0, 720.0], [21600.0, 700.0], [26430.0, 600.0]]
## [left, right, start_x, floor_y]. Kept clear of the bonfires' light.
const WOLVES := [
	[1000.0, 1490.0, 1330.0, GROUND_Y], [1000.0, 1490.0, 1450.0, GROUND_Y],
	[2040.0, 2590.0, 2420.0, GROUND_Y], [2040.0, 2590.0, 2540.0, GROUND_Y],
	[2915.0, 3335.0, 3120.0, 700.0], [2915.0, 3335.0, 3220.0, 700.0], [2915.0, 3335.0, 3310.0, 700.0],
	[10590.0, 11000.0, 10750.0, GROUND_Y], [10590.0, 11000.0, 10900.0, GROUND_Y],
]
const BAT_HOVER := 70.0
## [x, the surface this bat belongs to]
const BATS := [[1880.0, GROUND_Y], [2360.0, 400.0], [6435.0, 172.0], [7155.0, -165.0], [21335.0, 700.0], [22540.0, 700.0, 240.0]]
const ROCK_PILES := [[760.0, GROUND_Y], [2130.0, 490.0], [2785.0, GROUND_Y], [6930.0, -52.0], [8900.0, GROUND_Y], [20600.0, 600.0], [22060.0, 700.0], [25220.0, 600.0]]
const BERRIES := [[1030.0, 500.0], [2425.0, 400.0], [5970.0, 720.0], [7160.0, -398.0], [21700.0, 700.0], [26400.0, 600.0], [23060.0, 700.0], [25180.0, 600.0]]

## ---------------------------------------------------------------- caves
## Each cave: its camera bounds, its rock [x, y, w, h, kind], where he comes in,
## and its doorway outside [x, y, which way he walks in, "webs" | "skin"].
const CAVE_A := Rect2(20300, 150, 3370, 800)      # the Weeping Cave
const CAVE_A_ROCK := [
	[20300.0, 150.0, 100.0, 800.0, "wall"], [23570.0, 150.0, 100.0, 800.0, "wall"],
	[20400.0, 600.0, 500.0, 350.0, "floor"], [20900.0, 700.0, 350.0, 250.0, "floor"],
	[21420.0, 700.0, 990.0, 250.0, "floor"],           # after the pit: the old hearth, the Weeping Hall, the nursery
	[22650.0, 700.0, 120.0, 250.0, "floor"],           # the pillar in the Glowcap Chasm
	[23010.0, 700.0, 340.0, 250.0, "floor"],           # the far side of the chasm, and under the stairs
	[23070.0, 590.0, 100.0, 18.0, "floor"], [23220.0, 480.0, 100.0, 18.0, "floor"],
	[23350.0, 380.0, 220.0, 570.0, "floor"],           # the cocoon chamber
	[20400.0, 150.0, 500.0, 270.0, "roof"], [20900.0, 150.0, 860.0, 320.0, "roof"],
	[21760.0, 150.0, 340.0, 180.0, "roof"],            # the Weeping Hall: a high roof, to hang stalactites from
	[22100.0, 150.0, 310.0, 270.0, "roof"],            # the nursery: lower
	[22410.0, 150.0, 1160.0, 30.0, "roof"],            # the chasm and the chamber: very high
]
const CAVE_A_IN := Vector2(20470, 600)
const CAVE_A_DOOR := [8750.0, GROUND_Y, -1, "webs"]
const CAVE_A_WEBS := [[20840.0, 600.0, 180.0], [23430.0, 380.0, 200.0]]
## [x, roof y, floor y, left, right]
const SPIDERS := [[21080.0, 470.0, 700.0, 20910.0, 21240.0], [21600.0, 470.0, 700.0, 21440.0, 21690.0],
	[23410.0, 180.0, 380.0, 23360.0, 23560.0], [21950.0, 330.0, 700.0, 21770.0, 22090.0]]
const COCOON := [23510.0, 180.0, 380.0]

const CAVE_B := Rect2(24100, 150, 2840, 800)      # the Rattling Cave
const CAVE_B_ROCK := [
	[24100.0, 150.0, 100.0, 800.0, "wall"], [26840.0, 150.0, 100.0, 800.0, "wall"],
	[24200.0, 600.0, 400.0, 350.0, "floor"], [24600.0, 510.0, 90.0, 440.0, "floor"],   # a pillar, with a snake in it
	[24690.0, 600.0, 410.0, 350.0, "floor"],
	[25100.0, 600.0, 280.0, 350.0, "floor"],           # the Stampede Alley
	[25380.0, 540.0, 80.0, 410.0, "floor"],            # the rat mound, with the burrow in its face
	[25600.0, 510.0, 80.0, 440.0, "floor"],            # the Rattle Pit's pillar: another snake
	[25830.0, 600.0, 1010.0, 350.0, "floor"],          # the rockfall run, then the old hearth and on to the hoard
	[26560.0, 490.0, 110.0, 18.0, "floor"], [26700.0, 380.0, 140.0, 18.0, "floor"],   # up to the hoard
	[24200.0, 150.0, 400.0, 180.0, "roof"], [24600.0, 150.0, 120.0, 180.0, "roof"],
	[24720.0, 150.0, 340.0, 370.0, "roof"],            # the crawl tunnel: no room to jump
	[25060.0, 150.0, 1780.0, 60.0, "roof"],
]
const CAVE_B_IN := Vector2(24270, 600)
## In the outcrop's far face: he sees it behind him once he has climbed over.
const CAVE_B_DOOR := [11300.0, GROUND_Y, -1, "skin"]
## [left, right, start x, floor y]
const RATS := [[24320.0, 24580.0, 24420.0, 600.0], [24320.0, 24580.0, 24520.0, 600.0],
	[24700.0, 25040.0, 24800.0, 600.0], [24700.0, 25040.0, 24950.0, 600.0],
	[26400.0, 26820.0, 26480.0, 600.0], [26400.0, 26820.0, 26700.0, 600.0]]
## [hole x, hole y, facing]
const SNAKES := [[24600.0, 580.0, -1], [26840.0, 580.0, -1], [25600.0, 580.0, -1]]
const NEST := [26770.0, 380.0]

## ---------------------------------------------------------------- the longer caves
## Each cave is two-thirds longer than it was, and the new stretch is made of
## set-pieces that each say what they are about to do before they do it.
##
## The Weeping Cave: the Weeping Hall (stalactites that fall behind a runner and
## on a dawdler), the nursery (egg sacs: pop them from afar, or they hatch), and
## the Glowcap Chasm (a mushroom on a pillar, a bat, and a high shelf).
## [x, the roof's underside, length]
const HALL_STALACTITES := [[21800.0, 330.0, 96.0], [21870.0, 330.0, 112.0], [21940.0, 330.0, 92.0], [22010.0, 330.0, 108.0], [22075.0, 330.0, 94.0]]
## [x, floor y]: the nursery's sacs; the nursery's own limits are below
const EGG_SACS := [[22200.0, 700.0], [22290.0, 700.0], [22370.0, 700.0]]
const NURSERY := [22110.0, 22400.0]
## [x, floor y, tint]: glowing mushrooms (tint 0 teal, 1 violet)
const GLOWCAPS := [[22710.0, 700.0, 0]]
## [x, y, width]: a one-way shelf in the air over the chasm
const CAVE_SHELVES := [[22830.0, 470.0, 120.0]]
## The Rattling Cave: the Stampede Alley (a burrow that empties out at him),
## the Rattle Pit (rib bridge, a snake pillar), the Rockfall Run.
const STAMPEDE := [25380.0, 600.0]                   # the burrow's mouth, in the mound's face
const STAMPEDE_ZONE := [25110.0, 24760.0]            # [where it wakes, where the rats are gone]
const BONE_SLABS := [[25470.0, 600.0, 80.0], [25720.0, 600.0, 80.0]]
const ROCKFALL_XS := [26070.0, 26160.0, 26250.0]
## [x, y, hanging from the roof?, tint]: glowing crystal (0 teal, 1 violet, 2 amber, 3 rose)
const CRYSTALS := [
	[21520.0, 700.0, false, 0], [21745.0, 330.0, true, 0], [22140.0, 420.0, true, 3], [22330.0, 700.0, false, 3],
	[22480.0, 180.0, true, 1], [22760.0, 700.0, false, 1], [22950.0, 180.0, true, 0], [23290.0, 180.0, true, 1],
	[24440.0, 600.0, false, 2], [25090.0, 210.0, true, 2], [25300.0, 210.0, true, 2], [25440.0, 540.0, false, 3],
	[25660.0, 210.0, true, 2], [26020.0, 600.0, false, 2], [26480.0, 210.0, true, 3], [26780.0, 210.0, true, 2],
]
const TINTS := [Color("5ee0d0"), Color("b084ff"), Color("ffb347"), Color("ff7fa8")]

## ---------------------------------------------------------------- the Long Dark
## [anchor x, anchor y, length]: the grip hangs at anchor y + length.
const VINES := [[14800.0, 330.0, 190.0], [16060.0, 310.0, 230.0], [16330.0, 310.0, 230.0]]
## [x, top y, width]: rotten rock over the second pit.
const CRUMBLES := [[15330.0, 600.0, 80.0], [15460.0, 600.0, 80.0], [15590.0, 600.0, 80.0]]
const FIREFLIES := [[14500.0, 520.0], [14800.0, 440.0], [15150.0, 520.0], [15500.0, 480.0], [15820.0, 520.0], [16170.0, 420.0]]
## eyes in the trees, watching
const WATCHERS := [[11650.0, 430.0], [14400.0, 400.0], [15220.0, 380.0], [15950.0, 390.0]]
const CLAW_MARKS := [[11850.0, 470.0], [15080.0, 460.0]]
const PANIC_AT := 11650.0          ## the wolves come running past here
const SNUFF_AT := 14350.0         ## the roar, and the dark
## ---------------------------------------------------------------- the Boulder Run
## A boulder on a crumbling ledge breaks loose as he passes beneath it and
## rolls after him down the pass: over fallen logs (it smashes them), across
## gaps, until it plunges into the ravine at the end — and the crash shakes a
## stash loose from the cliff. Caught, or fallen, he starts the run again.
const RUN_START := 12240.0
const RUN_TRIGGER := 12330.0
const RUN_LEDGE := Vector2(12110.0, 520.0)
const RUN_LOGS := [12930.0, 13380.0, 13540.0]
const RUN_RAVINE := [13940.0, 14100.0]
const RUN_STASH := ["shell", "shell", "shell", "shell", "conch", "tusk", "bone", "bone", "bone", "bone"]

## ---------------------------------------------------------------- the end
const TOOLMAKER_AT := Vector2(16760, 600)
const CAMP_AT := Vector2(16700, 600)       ## his home under the overhang
## The Three Fires: a trial between his home and the clearing. A cracked
## boulder bars the way; a pack of wolves waits in the dark; three stone bowls
## must all burn — then the old palisade across the path burns down.
const TRIAL_ROCK := Vector2(17170, 600)
const TRIAL_BOWLS := [[17340.0, 600.0], [17590.0, 480.0], [17830.0, 600.0]]
const TRIAL_LEDGE := [17520.0, 480.0, 140.0]
const TRIAL_WOLVES := [[17260.0, 17900.0, 17460.0], [17260.0, 17900.0, 17700.0], [17260.0, 17900.0, 17880.0]]
const TRIAL_GATE_X := 17950.0
const ARENA := Rect2(18000, -900, 1300, 2100)
const BRAZIERS := [[18120.0, 600.0], [18960.0, 600.0]]
const LAIR_X := 19150.0           ## his lair's mouth, in the rock at the far end
const ARENA_LEDGES := [[18300.0, 480.0, 140.0], [18860.0, 480.0, 140.0]]
const BONGO_PERCH := Vector2(18070, 330)

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
	[24615.0, 24675.0, 510.0, 3],   # Rattling Cave: on the snake's pillar
	[26310.0, 26390.0, 600.0, 3],   # Rattling Cave: by the old hearth
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
	[14660.0, 470.0], [14740.0, 520.0], [14860.0, 520.0], [14940.0, 470.0],   # the first vine's swing
	[15370.0, 560.0], [15500.0, 560.0], [15630.0, 560.0],           # the crumbling bridge
	[16020.0, 480.0], [16175.0, 520.0], [16340.0, 480.0],           # the two vines
	# the Boulder Run: shells over the gaps (no time to stop for them!), bones on the way
	[12680.0, 520.0, "shell"], [13170.0, 520.0, "shell"], [13715.0, 520.0, "shell"],
	[12820.0, 560.0], [13000.0, 500.0], [13300.0, 560.0], [13460.0, 500.0], [13860.0, 560.0],
	# the Hanging Gorge: along the swings, shells up at the top of them,
	# and a tusk and a conch waiting on the resting ledge
	[4290.0, 500.0], [4350.0, 520.0], [4410.0, 500.0],
	[4600.0, 370.0, "shell"], [4630.0, 345.0, "shell"],
	[4665.0, 494.0, "tusk"],
	[5030.0, 500.0], [5095.0, 520.0], [5160.0, 500.0],
	[5340.0, 370.0, "shell"], [5370.0, 345.0, "shell"],
	[5480.0, 560.0], [5540.0, 560.0],
	# up in the air over the path: a jump gets these...
	[1090.0, 482.0], [1130.0, 472.0], [1170.0, 482.0],
	[10720.0, 482.0], [10760.0, 472.0],
	[16490.0, 478.0],
	[20700.0, 478.0], [20740.0, 470.0],
	# ...and these, higher, need the double jump
	[3420.0, 352.0, "shell"], [3460.0, 342.0, "shell"], [3500.0, 352.0, "shell"],
	[8890.0, 348.0, "shell"], [8930.0, 342.0, "shell"],
	[15790.0, 348.0, "shell"], [15830.0, 342.0, "shell"],
]
## Conches (5): out-of-the-way spots.
const CONCHES := [
	[4715.0, 490.0],
	[1000.0, 470.0], [2400.0, 370.0], [3310.0, 670.0], [6080.0, 690.0], [7680.0, -300.0], [8140.0, -320.0],
	[9150.0, -430.0], [10360.0, 20.0], [11180.0, 460.0], [14930.0, 430.0], [23170.0, 670.0], [23530.0, 350.0],
	[26740.0, 570.0], [26600.0, 460.0],
]
## [x, y, secret]: amber (25), one in each secret place.
const AMBERS := [[6030.0, 690.0, "crevice"], [7220.0, -420.0, "lookout"], [23450.0, 350.0, "weeping"], [26810.0, 350.0, "rattling"]]
## [x, surface y, "log" | "mound", contents]: the treasure boxes.
const LOG := ["bone", "shell", "bone", "shell", "bone", "shell", "bone"]
const MOUND := ["bone", "shell", "bone", "shell", "bone", "shell", "tusk", "conch"]
const BREAKABLES := [
	[640.0, 600.0, "log", LOG], [1950.0, 600.0, "mound", MOUND], [3480.0, 600.0, "log", LOG],
	[7580.0, -278.0, "mound", MOUND], [10800.0, 600.0, "log", LOG],
	[15180.0, 600.0, "mound", MOUND], [16490.0, 600.0, "log", LOG],
	[21050.0, 700.0, "log", LOG], [26490.0, 600.0, "mound", MOUND],
]
## Clay pots, in little groups: one smack each, a few shells. [x, surface y, how many]
const POTS := [
	[5520.0, 600.0, 2],
	[330.0, 600.0, 2], [2170.0, 490.0, 2], [3640.0, 600.0, 3], [7490.0, -278.0, 2], [9170.0, 600.0, 2],
	[10180.0, 600.0, 2], [14520.0, 600.0, 2], [16620.0, 600.0, 3], [20500.0, 600.0, 2], [24300.0, 600.0, 2],
]
## ---------------------------------------------------------------- the sky lanes
## Optional roads of floating stone above the ground road. Each starts with a
## bounce bloom on the ground ("pad": [x, y]) that throws him up to the first
## rock; then it is hops and bounces from stone to stone. [x, top y, width,
## flags] — flags: 1 = a bounce bloom on the rock, 2 = a lamp (a real light in
## the dark). A lane over solid ground costs nothing to fall from: the ground
## catches him. Each ends above solid ground, and he just steps off.
## Reach budget: hops of up to ~90 up and ~130 across; a bloom carries ~330
## across and puts him ~390 higher than where it launched him.
const SKY_LANES := [
	{
		"name": "Moonstep Road",          # the firelit woods: over the first wolves and the first pit, to the bonfire
		"pad": [800.0, 600.0],
		"rocks": [[940.0, 300.0, 190.0, 0], [1200.0, 280.0, 120.0, 0], [1370.0, 250.0, 110.0, 0], [1560.0, 310.0, 140.0, 1], [1780.0, 70.0, 170.0, 0]],
		"cache": [4, ["shell", "shell", "shell", "shell", "conch", "bone", "bone", "bone"]],
		"motes": [1100.0, 1700.0],
		"note": [690.0, "Pale stones float in the sky: a road above the road. The bloom throws him up.", 5.0],
	},
	{
		"name": "Silver Stair",           # the far side: over the wolves and the outcrop, to before the boulder run
		"pad": [10610.0, 600.0],
		"rocks": [[10740.0, 300.0, 190.0, 0], [11010.0, 290.0, 110.0, 1], [11260.0, 40.0, 160.0, 0], [11490.0, 80.0, 110.0, 0],
			[11680.0, 130.0, 110.0, 0], [11860.0, 210.0, 110.0, 0], [12010.0, 330.0, 80.0, 0]],
		"cache": [2, ["shell", "shell", "shell", "shell", "conch", "tusk", "bone", "bone"]],
		"bat": [11590.0, 70.0],
		"motes": [10900.0, 11500.0, 12000.0],
		"note": [10560.0, "Stones in the sky again: a silver stair. The bloom throws him up.", 4.5],
	},
	{
		"name": "Starlit Road",           # the Long Dark: glowing stones over the three pits, down to the toolmaker's fire
		"pad": [14480.0, 600.0],
		"rocks": [[14560.0, 290.0, 150.0, 2], [14790.0, 220.0, 100.0, 0], [14990.0, 230.0, 110.0, 2], [15170.0, 300.0, 140.0, 1],
			[15480.0, 120.0, 130.0, 2], [15690.0, 150.0, 100.0, 0], [15840.0, 190.0, 100.0, 2], [15990.0, 270.0, 130.0, 1], [16330.0, 160.0, 140.0, 2]],
		"cache": [8, ["shell", "shell", "shell", "shell", "shell", "conch", "conch", "tusk", "bone", "bone"]],
		"bat": [15650.0, 150.0],
		"motes": [14800.0, 15500.0, 16100.0],
		"note": [14440.0, "Glowing stones over the pits, like dropped stars. A bloom lifts him to them.", 5.0],
	},
]

## More pots, for the longer caves: [x, surface y, how many]. Their own ids.
const POTS_LATE := [[25420.0, 540.0, 2]]
## Shell Totems: carved faces that spit two shells per hit, six hits.
const TOTEMS := [[2470.0, 600.0], [8000.0, -30.0], [15070.0, 600.0], [26620.0, 600.0]]
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
## [x, y, kind]: the treasure of the longer caves. These have their own ids ("v0",
## "v1"...), separate from the old tables, so nothing already found moves.
const CAVE_LOOT := [
	# the Weeping Hall: a trail under the stalactites (run, don't linger)
	[21830.0, 676.0, "shell"], [21905.0, 676.0, "bone"], [21975.0, 676.0, "shell"], [22045.0, 676.0, "bone"],
	# the nursery
	[22130.0, 676.0, "bone"], [22245.0, 676.0, "shell"], [22330.0, 676.0, "bone"],
	# the Glowcap Chasm: an arc over the first gap, a column up the bounce, the shelf, an arc down
	[22490.0, 560.0, "shell"], [22540.0, 530.0, "shell"], [22590.0, 560.0, "shell"],
	[22710.0, 520.0, "shell"], [22710.0, 450.0, "shell"], [22710.0, 385.0, "shell"],
	[22890.0, 440.0, "conch"], [22845.0, 440.0, "tusk"], [22935.0, 440.0, "shell"],
	[22990.0, 570.0, "shell"], [23030.0, 625.0, "shell"], [23070.0, 676.0, "bone"],
	# the Stampede Alley
	[25190.0, 576.0, "shell"], [25250.0, 576.0, "bone"], [25320.0, 576.0, "shell"], [25420.0, 500.0, "shell"],
	# the Rattle Pit: over the slabs, and a conch on the snake's pillar
	[25510.0, 560.0, "shell"], [25640.0, 476.0, "conch"], [25760.0, 560.0, "shell"], [25560.0, 520.0, "bone"],
	# the Rockfall Run: greedy, under the rocks
	[26000.0, 576.0, "bone"], [26070.0, 576.0, "shell"], [26160.0, 576.0, "bone"], [26250.0, 576.0, "shell"],
]
## [x, darkness]. Dusk at the camp, darkest in the woods, thinner on the
## mountain where the moon reaches, dark again under the great tree.
const DARKNESS := [[0.0, 0.26], [700.0, 0.40], [1500.0, 0.62], [2600.0, 0.72], [3600.0, 0.74],
	[3950.0, 0.64], [4300.0, 0.50], [5400.0, 0.50], [5800.0, 0.60],                       # the gorge: the last light of dusk
	[6000.0, 0.62], [6700.0, 0.56], [7400.0, 0.50], [8300.0, 0.60], [8800.0, 0.70], [9300.0, 0.64],
	[10200.0, 0.72], [11700.0, 0.76], [12150.0, 0.70], [14150.0, 0.72], [14300.0, 0.86], [14400.0, 0.92], [16350.0, 0.92],   # the Long Dark
	[16500.0, 0.74], [17050.0, 0.76], [17150.0, 0.88], [17950.0, 0.88],                   # his home; the Three Fires
	[18000.0, 0.82], [19300.0, 0.82],                                                     # the clearing
	[20250.0, 0.92], [27050.0, 0.92]]   # the caves: near black


## ---------------------------------------------------------------- the shop
## The economy. Prices are worked out from how much treasure the level holds
## (_treasure_total), so that a player who finds about 60% of it can buy
## exactly one new weapon, one new costume and three roast figs:
##     axe 26%  +  a costume ~19%  +  3 figs x 4%   =  57%
## The upgrades are extra, for the ones who search every corner. Move or add
## treasure and the prices follow on their own.
const ECONOMY := {"axe": 0.26, "wolf_hood": 0.16, "ember_paint": 0.18, "bear_cloak": 0.21, "firekeeper": 0.20,
	"fig": 0.04, "heart": 0.18, "torch": 0.11, "pouch": 0.11}
