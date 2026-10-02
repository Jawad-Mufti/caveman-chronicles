extends LevelBase
## Level 2's data tables: layout coordinates, loot, the caves, the sky lanes and
## the economy. level2.gd extends this file, so its builders use every table by
## its bare name. Treasure ids are by index: never insert into the old loot tables.

const GROUND_Y := 600.0
const LEVEL_W := 25300.0
const FALL_Y := 1020.0

## Reachability budget: a jump climbs ~133 px and carries ~227 px. Every step
## here asks for 100-125 up; the mountain's are the ones near the top of that.
## Ground runs: [x0, x1] at GROUND_Y.
const FLOORS := [[0.0, 1500.0], [1640.0, 2600.0], [2760.0, 2900.0], [3350.0, 4060.0], [5420.0, 5680.0], [8750.0, 10500.0], [11000.0, 12780.0], [12980.0, 13120.0], [13540.0, 13660.0], [14180.0, 15400.0],
	[16120.0, 18620.0], [18730.0, 19100.0], [19230.0, 19640.0], [19780.0, 19940.0], [20100.0, 20600.0], [21000.0, 21300.0], [21700.0, 21950.0], [22400.0, LEVEL_W]]
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
	[17050.0, 490.0, 250.0, 710.0],     # the far-side outcrop: the Rattling Cave's mouth is in its far face
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
## a long drop into the ravine. 470 apart for vines 255 long, measured with
## tools/vinereach: let go late, high in the forward swing, and he reaches the
## next on his own (~450-510 px); let go mid-swing and he needs the air jump
## too (~525-565); let go early and he falls short even with it (~410).
const GORGE_VINES := [[4200.0, 262.0, 255.0], [4670.0, 262.0, 255.0], [5140.0, 262.0, 255.0]]
const GORGE_LEDGE := [4880.0, 560.0, 120.0]          ## a narrow resting ledge, low: it catches a short jump
const GORGE_CRUMBLES := []
## The mountain's silhouette, drawn behind the climb.
const MOUNTAIN := [[5630, 1200], [5660, 560], [5820, 430], [6020, 330], [6220, 230], [6420, 110], [6620, 0],
	[6820, -120], [7040, -210], [7220, -380], [7400, -420], [7600, -370], [7800, -230], [8080, 20],
	[8350, 230], [8600, 420], [8780, 1200]]

## ---------------------------------------------------------------- the Mammoth Steppe
## Between the mountain's foot and the great tree. A split rock blocks the way:
## he walks in under its loose slab and climbs the chimney by jumping from wall
## to wall. Then a herd of mammoths on the path (mind the feet, ride the backs),
## a river only the old bull wades, and a mammoth graveyard under the tree.
const CHIMNEY := [9150.0, 120.0, 60.0, 380.0]      ## the loose slab [x, top, w, h]: hangs 100 px off the ground
const CLIFF := [9300.0, 100.0, 400.0]               ## [x, top, w]: the face to climb, and the top
const CLIFF_STEPS := [[9700.0, 260.0, 110.0], [9810.0, 420.0, 100.0]]   ## the way down: [x, top, w]
## The herd: [x0, x1, start x, speed, size]. The calf's back is one jump up;
## the bull's needs the double jump (or the calf as a step).
const HERD := [[9900.0, 10200.0, 10000.0, 70.0, 1.0], [10000.0, 10360.0, 10300.0, 95.0, 0.72]]
const RIVER := [10500.0, 11000.0]
## The old bull who wades the river: [x0, x1, ground y (in the water), speed].
## His back is one jump up from either bank.
const FERRY := [10620.0, 10880.0, 680.0, 70.0]
const GRAVEYARD := [[11350.0, 1.0], [11900.0, 0.8], [12350.0, 1.15]]   ## skeletons: [x, size]
## Hand-placed treasure in the Steppe: [x, y, kind]. Ids "m0", "m1"...
const STEPPE_LOOT := [
	[9255.0, 420.0, "shell"], [9255.0, 320.0, "shell"], [9255.0, 220.0, "conch"],      # up the chimney
	[9420.0, 70.0, "shell"], [9500.0, 70.0, "shell"], [9580.0, 70.0, "bone"],         # the clifftop
	[9755.0, 230.0, "shell"],
	[9950.0, 570.0, "bone"], [10150.0, 570.0, "shell"], [10330.0, 570.0, "bone"],    # under the herd's feet
	[10470.0, 570.0, "shell"],
	[10750.0, 420.0, "shell"], [10750.0, 350.0, "shell"],                              # jump for them off the bull's back
	[11300.0, 570.0, "bone"], [11360.0, 570.0, "bone"], [11420.0, 570.0, "tusk"],      # the graveyard
	[11850.0, 570.0, "bone"], [11900.0, 480.0, "shell"], [11950.0, 570.0, "bone"],
	[12300.0, 570.0, "shell"], [12360.0, 480.0, "conch"], [12420.0, 570.0, "bone"],
]

## ---------------------------------------------------------------- the Tar Pits
## Past the graveyard (it's why the bones are there): three pools of black,
## bubbling tar, each wider than the last. Logs float on them — until he
## stands on one, and it slowly sinks. The last two are too wide to jump, so
## he hops log to log and keeps moving. In the tar he's stuck: hauled out on
## the near bank, a heart lighter.
const TAR_POOLS := [[12780.0, 12980.0], [13120.0, 13540.0], [13660.0, 14180.0]]   ## [x0, x1]
const TAR_LOGS := [[12880.0, 110.0], [13220.0, 100.0], [13450.0, 100.0],           ## [centre x, width]
	[13760.0, 100.0], [13880.0, 100.0], [14000.0, 100.0], [14100.0, 90.0]]
const TAR_ROCKS := [[13305.0, 540.0, 70.0]]        ## a boulder stuck fast in the middle pool: [x, top, w]
const TAR_LOOT := [                                ## [x, y, kind]; ids "t0", "t1"...
	[12880.0, 545.0, "shell"], [13050.0, 570.0, "tusk"],
	[13220.0, 545.0, "shell"], [13340.0, 490.0, "conch"], [13450.0, 545.0, "shell"],
	[13600.0, 570.0, "bone"],
	[13760.0, 545.0, "shell"], [13880.0, 545.0, "shell"], [14000.0, 545.0, "bone"], [14100.0, 545.0, "shell"],
]

## ---------------------------------------------------------------- talking animals
## Met in passing; the talk starts when he comes by (once).
const MOSS_AT := Vector2(4075.0, 262.0)        ## the sloth's grip, under the fallen giant over the gorge
const MOSS_MEET := [3880.0, 120.0]            ## [x, width] where the talk starts
const NUTMEG_AT := Vector2(14440.0, 600.0)     ## the beaver by her dam on a little creek, past the tar pits
const NUTMEG_MEET := [14220.0, 110.0]
const CREEK := [14300.0, 70.0]                ## [x, width]: the little creek she has dammed

## The great tree: trunk centred here, and its branches as one-way platforms
## [x, top, width, grows from the left end?]. Left and right of the trunk in
## turn, 112 px apart; the long bough crosses the chasm; above it, the crown.
const TREE_X := 15220.0
const BRANCHES := [
	[15030.0, 490.0, 130.0, false], [15280.0, 378.0, 130.0, true], [15020.0, 266.0, 140.0, false],
	[15280.0, 154.0, 120.0, true],
	[15260.0, 42.0, 900.0, true],        # the long bough, over the chasm to the far side
	[15040.0, -70.0, 130.0, false], [15280.0, -183.0, 120.0, true], [15050.0, -296.0, 120.0, false],
	[15130.0, -408.0, 230.0, true],      # the crown
	# the dead snag on the far side: the way back up to the bough
	[16300.0, 490.0, 110.0, false], [16430.0, 378.0, 110.0, true], [16300.0, 266.0, 110.0, false],
	[16430.0, 154.0, 110.0, true], [16220.0, 42.0, 190.0, false],
]
const SNAG_X := 16415.0
## The troop: [x, y, habit, hanging]
const MONKEYS := [
	[15360.0, 378.0, 0, false],
	[15060.0, 280.0, 0, true],            # hanging under a branch by its tail
	[15490.0, 42.0, 0, false], [15710.0, 42.0, 1, false], [15940.0, 42.0, 0, false],
	[15340.0, -183.0, 1, false],
]
## Old Bongo sits at the top of the crown, beside his banana box.
const ELDER_AT := Vector2(15320, -408)

## [x, y, lit at start]
const BONFIRES := [[520.0, GROUND_Y, true], [1720.0, GROUND_Y, false], [3560.0, GROUND_Y, false],
	[7410.0, -278.0, false], [14830.0, GROUND_Y, false], [16270.0, GROUND_Y, false],
	[27470.0, 700.0, false], [29290.0, 700.0, false], [31140.0, 600.0, false], [32300.0, 600.0, false],   # old hearths in the caves
	[8960.0, GROUND_Y, false]]   # the mountain's foot, before the Steppe
## [x, y, bundles of wood in it]
const DEAD_TREES := [[1260.0, GROUND_Y, 2], [2400.0, 400.0, 1], [2855.0, GROUND_Y, 2], [6830.0, -52.0, 2], [14990.0, GROUND_Y, 2]]
## Loose bundles already on the ground: the crevice stash.
const WOOD := [[5900.0, 720.0], [6070.0, 720.0], [27600.0, 700.0], [32430.0, 600.0]]
## [left, right, start_x, floor_y]. Kept clear of the bonfires' light.
const WOLVES := [
	[1000.0, 1490.0, 1330.0, GROUND_Y], [1000.0, 1490.0, 1450.0, GROUND_Y],
	[2040.0, 2590.0, 2420.0, GROUND_Y], [2040.0, 2590.0, 2540.0, GROUND_Y],
	[2915.0, 3335.0, 3120.0, 700.0], [2915.0, 3335.0, 3220.0, 700.0], [2915.0, 3335.0, 3310.0, 700.0],
	[16590.0, 17000.0, 16750.0, GROUND_Y], [16590.0, 17000.0, 16900.0, GROUND_Y],
]
const BAT_HOVER := 70.0
## [x, the surface this bat belongs to]
const BATS := [[1880.0, GROUND_Y], [2360.0, 400.0], [6435.0, 172.0], [7155.0, -165.0], [27335.0, 700.0], [28540.0, 700.0, 240.0]]
const ROCK_PILES := [[760.0, GROUND_Y], [2130.0, 490.0], [2785.0, GROUND_Y], [6930.0, -52.0], [14900.0, GROUND_Y], [26600.0, 600.0], [28060.0, 700.0], [31220.0, 600.0]]
const BERRIES := [[1030.0, 500.0], [2425.0, 400.0], [5970.0, 720.0], [7160.0, -398.0], [27700.0, 700.0], [32400.0, 600.0], [29060.0, 700.0], [31180.0, 600.0]]

## ---------------------------------------------------------------- caves
## Each cave: its camera bounds, its rock [x, y, w, h, kind], where he comes in,
## and its doorway outside [x, y, which way he walks in, "webs" | "skin"].
const CAVE_A := Rect2(26300, 150, 3370, 800)      # the Weeping Cave
const CAVE_A_ROCK := [
	[26300.0, 150.0, 100.0, 800.0, "wall"], [29570.0, 150.0, 100.0, 800.0, "wall"],
	[26400.0, 600.0, 500.0, 350.0, "floor"], [26900.0, 700.0, 350.0, 250.0, "floor"],
	[27420.0, 700.0, 990.0, 250.0, "floor"],           # after the pit: the old hearth, the Weeping Hall, the nursery
	[28650.0, 700.0, 120.0, 250.0, "floor"],           # the pillar in the Glowcap Chasm
	[29010.0, 700.0, 340.0, 250.0, "floor"],           # the far side of the chasm, and under the stairs
	[29070.0, 590.0, 100.0, 18.0, "floor"], [29220.0, 480.0, 100.0, 18.0, "floor"],
	[29350.0, 380.0, 220.0, 570.0, "floor"],           # the cocoon chamber
	[26400.0, 150.0, 500.0, 270.0, "roof"], [26900.0, 150.0, 860.0, 320.0, "roof"],
	[27760.0, 150.0, 340.0, 180.0, "roof"],            # the Weeping Hall: a high roof, to hang stalactites from
	[28100.0, 150.0, 310.0, 270.0, "roof"],            # the nursery: lower
	[28410.0, 150.0, 1160.0, 30.0, "roof"],            # the chasm and the chamber: very high
]
const CAVE_A_IN := Vector2(26470, 600)
const CAVE_A_DOOR := [8750.0, GROUND_Y, -1, "webs"]
const CAVE_A_WEBS := [[26840.0, 600.0, 180.0], [29430.0, 380.0, 200.0]]
## [x, roof y, floor y, left, right]
const SPIDERS := [[27080.0, 470.0, 700.0, 26910.0, 27240.0], [27600.0, 470.0, 700.0, 27440.0, 27690.0],
	[29410.0, 180.0, 380.0, 29360.0, 29560.0], [27950.0, 330.0, 700.0, 27770.0, 28090.0]]
const COCOON := [29510.0, 180.0, 380.0]

const CAVE_B := Rect2(30100, 150, 2840, 800)      # the Rattling Cave
const CAVE_B_ROCK := [
	[30100.0, 150.0, 100.0, 800.0, "wall"], [32840.0, 150.0, 100.0, 800.0, "wall"],
	[30200.0, 600.0, 400.0, 350.0, "floor"], [30600.0, 510.0, 90.0, 440.0, "floor"],   # a pillar, with a snake in it
	[30690.0, 600.0, 410.0, 350.0, "floor"],
	[31100.0, 600.0, 280.0, 350.0, "floor"],           # the Stampede Alley
	[31380.0, 540.0, 80.0, 410.0, "floor"],            # the rat mound, with the burrow in its face
	[31600.0, 510.0, 80.0, 440.0, "floor"],            # the Rattle Pit's pillar: another snake
	[31830.0, 600.0, 1010.0, 350.0, "floor"],          # the rockfall run, then the old hearth and on to the hoard
	[32560.0, 490.0, 110.0, 18.0, "floor"], [32700.0, 380.0, 140.0, 18.0, "floor"],   # up to the hoard
	[30200.0, 150.0, 400.0, 180.0, "roof"], [30600.0, 150.0, 120.0, 180.0, "roof"],
	[30720.0, 150.0, 340.0, 370.0, "roof"],            # the crawl tunnel: no room to jump
	[31060.0, 150.0, 1780.0, 60.0, "roof"],
]
const CAVE_B_IN := Vector2(30270, 600)
## In the outcrop's far face: he sees it behind him once he has climbed over.
const CAVE_B_DOOR := [17300.0, GROUND_Y, -1, "skin"]
## [left, right, start x, floor y]
const RATS := [[30320.0, 30580.0, 30420.0, 600.0], [30320.0, 30580.0, 30520.0, 600.0],
	[30700.0, 31040.0, 30800.0, 600.0], [30700.0, 31040.0, 30950.0, 600.0],
	[32400.0, 32820.0, 32480.0, 600.0], [32400.0, 32820.0, 32700.0, 600.0]]
## [hole x, hole y, facing]
const SNAKES := [[30600.0, 580.0, -1], [32840.0, 580.0, -1], [31600.0, 580.0, -1]]
const NEST := [32770.0, 380.0]

## ---------------------------------------------------------------- the longer caves
## Each cave is two-thirds longer than it was, and the new stretch is made of
## set-pieces that each say what they are about to do before they do it.
##
## The Weeping Cave: the Weeping Hall (stalactites that fall behind a runner and
## on a dawdler), the nursery (egg sacs: pop them from afar, or they hatch), and
## the Glowcap Chasm (a mushroom on a pillar, a bat, and a high shelf).
## [x, the roof's underside, length]
const HALL_STALACTITES := [[27800.0, 330.0, 96.0], [27870.0, 330.0, 112.0], [27940.0, 330.0, 92.0], [28010.0, 330.0, 108.0], [28075.0, 330.0, 94.0]]
## [x, floor y]: the nursery's sacs; the nursery's own limits are below
const EGG_SACS := [[28200.0, 700.0], [28290.0, 700.0], [28370.0, 700.0]]
const NURSERY := [28110.0, 28400.0]
## [x, floor y, tint]: glowing mushrooms (tint 0 teal, 1 violet)
const GLOWCAPS := [[28710.0, 700.0, 0]]
## [x, y, width]: a one-way shelf in the air over the chasm
const CAVE_SHELVES := [[28830.0, 470.0, 120.0]]
## The Rattling Cave: the Stampede Alley (a burrow that empties out at him),
## the Rattle Pit (rib bridge, a snake pillar), the Rockfall Run.
const STAMPEDE := [31380.0, 600.0]                   # the burrow's mouth, in the mound's face
const STAMPEDE_ZONE := [31110.0, 30760.0]            # [where it wakes, where the rats are gone]
const BONE_SLABS := [[31470.0, 600.0, 80.0], [31720.0, 600.0, 80.0]]
const ROCKFALL_XS := [32070.0, 32160.0, 32250.0]
## [x, y, hanging from the roof?, tint]: glowing crystal (0 teal, 1 violet, 2 amber, 3 rose)
const CRYSTALS := [
	[27520.0, 700.0, false, 0], [27745.0, 330.0, true, 0], [28140.0, 420.0, true, 3], [28330.0, 700.0, false, 3],
	[28480.0, 180.0, true, 1], [28760.0, 700.0, false, 1], [28950.0, 180.0, true, 0], [29290.0, 180.0, true, 1],
	[30440.0, 600.0, false, 2], [31090.0, 210.0, true, 2], [31300.0, 210.0, true, 2], [31440.0, 540.0, false, 3],
	[31660.0, 210.0, true, 2], [32020.0, 600.0, false, 2], [32480.0, 210.0, true, 3], [32780.0, 210.0, true, 2],
]
const TINTS := [Color("5ee0d0"), Color("b084ff"), Color("ffb347"), Color("ff7fa8")]

## ---------------------------------------------------------------- the Long Dark
## [anchor x, anchor y, length]: the grip hangs at anchor y + length.
const VINES := [[20800.0, 330.0, 190.0], [21990.0, 310.0, 230.0], [22360.0, 310.0, 230.0]]
## [x, top y, width]: rotten rock over the second pit.
const CRUMBLES := [[21330.0, 600.0, 80.0], [21460.0, 600.0, 80.0], [21590.0, 600.0, 80.0]]
const FIREFLIES := [[20500.0, 520.0], [20800.0, 440.0], [21150.0, 520.0], [21500.0, 480.0], [21820.0, 520.0], [22170.0, 420.0]]
## eyes in the trees, watching
const WATCHERS := [[17650.0, 430.0], [20400.0, 400.0], [21220.0, 380.0], [21950.0, 390.0]]
const CLAW_MARKS := [[17850.0, 470.0], [21080.0, 460.0]]
const PANIC_AT := 17650.0          ## the wolves come running past here
const SNUFF_AT := 20350.0         ## the roar, and the dark
## ---------------------------------------------------------------- the Boulder Run
## A boulder on a crumbling ledge breaks loose as he passes beneath it and
## rolls after him down the pass: over fallen logs (it smashes them), across
## gaps, until it plunges into the ravine at the end — and the crash shakes a
## stash loose from the cliff. Caught, or fallen, he starts the run again.
const RUN_START := 18240.0
const RUN_TRIGGER := 18330.0
const RUN_LEDGE := Vector2(18110.0, 520.0)
const RUN_LOGS := [18930.0, 19380.0, 19540.0]
const RUN_RAVINE := [19940.0, 20100.0]
const RUN_STASH := ["shell", "shell", "shell", "shell", "conch", "tusk", "bone", "bone", "bone", "bone"]

## ---------------------------------------------------------------- the end
const TOOLMAKER_AT := Vector2(22760, 600)
const CAMP_AT := Vector2(22700, 600)       ## his home under the overhang
## The Three Fires: a trial between his home and the clearing. A cracked
## boulder bars the way; a pack of wolves waits in the dark; three stone bowls
## must all burn — then the old palisade across the path burns down.
const TRIAL_ROCK := Vector2(23170, 600)
const TRIAL_BOWLS := [[23340.0, 600.0], [23590.0, 480.0], [23830.0, 600.0]]
const TRIAL_LEDGE := [23520.0, 480.0, 140.0]
const TRIAL_WOLVES := [[23260.0, 23900.0, 23460.0], [23260.0, 23900.0, 23700.0], [23260.0, 23900.0, 23880.0]]
const TRIAL_GATE_X := 23950.0
const ARENA := Rect2(24000, -900, 1300, 2100)
const BRAZIERS := [[24120.0, 600.0], [24960.0, 600.0]]
const LAIR_X := 25150.0           ## his lair's mouth, in the rock at the far end
const ARENA_LEDGES := [[24300.0, 480.0, 140.0], [24860.0, 480.0, 140.0]]
const BONGO_PERCH := Vector2(24070, 330)

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
	[17140.0, 17210.0, 490.0, 3],     # on top of the outcrop
	[26560.0, 26640.0, 600.0, 3],   # Weeping Cave: by the rock pile
	[27490.0, 27570.0, 700.0, 3],   # Weeping Cave: past the pit, by the old hearth
	[30615.0, 30675.0, 510.0, 3],   # Rattling Cave: on the snake's pillar
	[32310.0, 32390.0, 600.0, 3],   # Rattling Cave: by the old hearth
]
## Single shells: arcs over jumps and swings, trails up the trees, and a
## column above each Moonpuff on the way down the mountain.
const SHELL_POINTS := [
	[1520.0, 540.0], [1570.0, 515.0], [1620.0, 540.0],              # the first pit
	[2630.0, 540.0], [2680.0, 515.0], [2730.0, 540.0],              # the second pit
	[7760.0, -395.0], [7760.0, -455.0], [7760.0, -515.0, "shell"],           # Moonpuff 1
	[8140.0, -145.0], [8140.0, -205.0], [8140.0, -265.0, "shell"],           # Moonpuff 2
	[8520.0, 105.0], [8520.0, 45.0], [8520.0, -15.0, "shell"],               # Moonpuff 3
	[15095.0, 466.0], [15345.0, 354.0], [15090.0, 242.0], [15340.0, 130.0],   # up the great tree
	[15105.0, -94.0], [15335.0, -207.0], [15110.0, -320.0, "shell"],            # on up to Bongo
	[16485.0, 354.0], [16485.0, 130.0],                               # up the snag
	[20660.0, 470.0], [20740.0, 520.0], [20860.0, 520.0], [20940.0, 470.0],   # the first vine's swing
	[21370.0, 560.0], [21500.0, 560.0], [21630.0, 560.0],           # the crumbling bridge
	[22100.0, 470.0], [22175.0, 440.0], [22250.0, 470.0],           # the two vines
	# the Boulder Run: shells over the gaps (no time to stop for them!), bones on the way
	[18680.0, 520.0, "shell"], [19170.0, 520.0, "shell"], [19715.0, 520.0, "shell"],
	[18820.0, 560.0], [19000.0, 500.0], [19300.0, 560.0], [19460.0, 500.0], [19860.0, 560.0],
	# the Hanging Gorge: along the swings, shells up at the top of them,
	# and a tusk and a conch waiting on the resting ledge
	[4400.0, 470.0], [4460.0, 440.0], [4520.0, 470.0],
	[4740.0, 370.0, "shell"], [4770.0, 345.0, "shell"],
	[4940.0, 534.0, "tusk"],
	[4870.0, 470.0], [4930.0, 440.0], [4990.0, 470.0],
	[5210.0, 370.0, "shell"], [5240.0, 345.0, "shell"],
	[5480.0, 560.0], [5540.0, 560.0],
	# up in the air over the path: a jump gets these...
	[1090.0, 482.0], [1130.0, 472.0], [1170.0, 482.0],
	[16720.0, 482.0], [16760.0, 472.0],
	[22490.0, 478.0],
	[26700.0, 478.0], [26740.0, 470.0],
	# ...and these, higher, need the double jump
	[3420.0, 352.0, "shell"], [3460.0, 342.0, "shell"], [3500.0, 352.0, "shell"],
	[14890.0, 348.0, "shell"], [14930.0, 342.0, "shell"],
	[21790.0, 348.0, "shell"], [21830.0, 342.0, "shell"],
]
## Conches (5): out-of-the-way spots.
const CONCHES := [
	[4715.0, 490.0],
	[1000.0, 470.0], [2400.0, 370.0], [3310.0, 670.0], [6080.0, 690.0], [7680.0, -300.0], [8140.0, -320.0],
	[15150.0, -430.0], [16360.0, 20.0], [17180.0, 460.0], [20930.0, 430.0], [29170.0, 670.0], [29530.0, 350.0],
	[32740.0, 570.0], [32600.0, 460.0],
]
## [x, y, secret]: amber (25), one in each secret place.
const AMBERS := [[6030.0, 690.0, "crevice"], [7220.0, -420.0, "lookout"], [29450.0, 350.0, "weeping"], [32810.0, 350.0, "rattling"]]
## [x, surface y, "log" | "mound", contents]: the treasure boxes.
const LOG := ["bone", "shell", "bone", "shell", "bone", "shell", "bone"]
const MOUND := ["bone", "shell", "bone", "shell", "bone", "shell", "tusk", "conch"]
const BREAKABLES := [
	[640.0, 600.0, "log", LOG], [1950.0, 600.0, "mound", MOUND], [3480.0, 600.0, "log", LOG],
	[7580.0, -278.0, "mound", MOUND], [16800.0, 600.0, "log", LOG],
	[21180.0, 600.0, "mound", MOUND], [22490.0, 600.0, "log", LOG],
	[27050.0, 700.0, "log", LOG], [32490.0, 600.0, "mound", MOUND],
]
## Clay pots, in little groups: one smack each, a few shells. [x, surface y, how many]
const POTS := [
	[5520.0, 600.0, 2],
	[330.0, 600.0, 2], [2170.0, 490.0, 2], [3640.0, 600.0, 3], [7490.0, -278.0, 2], [15170.0, 600.0, 2],
	[16180.0, 600.0, 2], [20520.0, 600.0, 2], [22620.0, 600.0, 3], [26500.0, 600.0, 2], [30300.0, 600.0, 2],
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
		"pad": [16610.0, 600.0],
		"rocks": [[16740.0, 300.0, 190.0, 0], [17010.0, 290.0, 110.0, 1], [17260.0, 40.0, 160.0, 0], [17490.0, 80.0, 110.0, 0],
			[17680.0, 130.0, 110.0, 0], [17860.0, 210.0, 110.0, 0], [18010.0, 330.0, 80.0, 0]],
		"cache": [2, ["shell", "shell", "shell", "shell", "conch", "tusk", "bone", "bone"]],
		"bat": [17590.0, 70.0],
		"motes": [16900.0, 17500.0, 18000.0],
		"note": [16560.0, "Stones in the sky again: a silver stair. The bloom throws him up.", 4.5],
	},
	{
		"name": "Starlit Road",           # the Long Dark: glowing stones over the three pits, down to the toolmaker's fire
		"pad": [20480.0, 600.0],
		"rocks": [[20560.0, 290.0, 150.0, 2], [20790.0, 220.0, 100.0, 0], [20990.0, 230.0, 110.0, 2], [21170.0, 300.0, 140.0, 1],
			[21480.0, 120.0, 130.0, 2], [21690.0, 150.0, 100.0, 0], [21840.0, 190.0, 100.0, 2], [21990.0, 270.0, 130.0, 1], [22330.0, 160.0, 140.0, 2]],
		"cache": [8, ["shell", "shell", "shell", "shell", "shell", "conch", "conch", "tusk", "bone", "bone"]],
		"bat": [21650.0, 150.0],
		"motes": [20800.0, 21500.0, 22100.0],
		"note": [20440.0, "Glowing stones over the pits, like dropped stars. A bloom lifts him to them.", 5.0],
	},
	{
		"name": "Mammoth Sky",            # the Steppe: off the split rock, over the herd and the river, down past the graveyard
		"pad": [9620.0, 100.0],
		"rocks": [[9760.0, -110.0, 150.0, 0], [9990.0, -70.0, 110.0, 0], [10200.0, -20.0, 120.0, 1], [10420.0, -230.0, 170.0, 0],
			[10680.0, 40.0, 120.0, 0], [10900.0, 110.0, 110.0, 0], [11110.0, 200.0, 130.0, 0], [11330.0, 330.0, 140.0, 0]],
		"cache": [3, ["shell", "shell", "shell", "shell", "conch", "conch", "tusk", "bone", "bone"]],
		"motes": [9900.0, 10500.0, 11100.0],
		"note": [9560.0, "Little islands in the sky, over the herd and the river. The bloom throws him up.", 5.0],
	},
]

## More pots, for the longer caves: [x, surface y, how many]. Their own ids.
const POTS_LATE := [[31420.0, 540.0, 2]]
## Shell Totems: carved faces that spit two shells per hit, six hits.
const TOTEMS := [[2470.0, 600.0], [8000.0, -30.0], [21070.0, 600.0], [32620.0, 600.0]]
## Monkey stashes: a log marked with a red X — a fountain of treasure.
const STASH := ["bone", "shell", "bone", "shell", "bone", "shell", "bone", "shell", "bone", "shell", "tusk", "conch", "conch"]
const STASHES := [[15320.0, 600.0], [15170.0, -418.0]]
## Golden Hares: [left x, right x, start x, ground y] — catch one for a shower of treasure.
const HARES := [[3380.0, 3960.0, 3800.0, 600.0], [14760.0, 15400.0, 15260.0, 600.0], [16120.0, 16580.0, 16400.0, 600.0]]
const HARE_VALUE := 18
## Moonpuffs: bounce bushes on the mountain's way down, where he lands
## coming off each step.
const MOONPUFFS := [[7760.0, -155.0], [8140.0, 95.0], [8520.0, 345.0]]
const SECRETS := ["crevice", "lookout", "weeping", "rattling"]
## [x, y, kind]: the treasure of the longer caves. These have their own ids ("v0",
## "v1"...), separate from the old tables, so nothing already found moves.
const CAVE_LOOT := [
	# the Weeping Hall: a trail under the stalactites (run, don't linger)
	[27830.0, 676.0, "shell"], [27905.0, 676.0, "bone"], [27975.0, 676.0, "shell"], [28045.0, 676.0, "bone"],
	# the nursery
	[28130.0, 676.0, "bone"], [28245.0, 676.0, "shell"], [28330.0, 676.0, "bone"],
	# the Glowcap Chasm: an arc over the first gap, a column up the bounce, the shelf, an arc down
	[28490.0, 560.0, "shell"], [28540.0, 530.0, "shell"], [28590.0, 560.0, "shell"],
	[28710.0, 520.0, "shell"], [28710.0, 450.0, "shell"], [28710.0, 385.0, "shell"],
	[28890.0, 440.0, "conch"], [28845.0, 440.0, "tusk"], [28935.0, 440.0, "shell"],
	[28990.0, 570.0, "shell"], [29030.0, 625.0, "shell"], [29070.0, 676.0, "bone"],
	# the Stampede Alley
	[31190.0, 576.0, "shell"], [31250.0, 576.0, "bone"], [31320.0, 576.0, "shell"], [31420.0, 500.0, "shell"],
	# the Rattle Pit: over the slabs, and a conch on the snake's pillar
	[31510.0, 560.0, "shell"], [31640.0, 476.0, "conch"], [31760.0, 560.0, "shell"], [31560.0, 520.0, "bone"],
	# the Rockfall Run: greedy, under the rocks
	[32000.0, 576.0, "bone"], [32070.0, 576.0, "shell"], [32160.0, 576.0, "bone"], [32250.0, 576.0, "shell"],
]
## [x, darkness]. Dusk at the camp, darkest in the woods, thinner on the
## mountain where the moon reaches, dark again under the great tree.
const DARKNESS := [[0.0, 0.26], [700.0, 0.40], [1500.0, 0.62], [2600.0, 0.72], [3600.0, 0.74],
	[3950.0, 0.64], [4300.0, 0.50], [5400.0, 0.50], [5800.0, 0.60],                       # the gorge: the last light of dusk
	[6000.0, 0.62], [6700.0, 0.56], [7400.0, 0.50], [8300.0, 0.60],
	[8800.0, 0.60], [9200.0, 0.64], [9800.0, 0.54], [10700.0, 0.48], [11500.0, 0.56], [12400.0, 0.64], [13400.0, 0.62],   # the Steppe: open sky, a bright river
	[14800.0, 0.70], [15300.0, 0.64],
	[16200.0, 0.72], [17700.0, 0.76], [18150.0, 0.70], [20150.0, 0.72], [20300.0, 0.86], [20400.0, 0.92], [22350.0, 0.92],   # the Long Dark
	[22500.0, 0.74], [23050.0, 0.76], [23150.0, 0.88], [23950.0, 0.88],                   # his home; the Three Fires
	[24000.0, 0.82], [25300.0, 0.82],                                                     # the clearing
	[26250.0, 0.92], [33050.0, 0.92]]   # the caves: near black


## ---------------------------------------------------------------- the shop
## The economy. Prices are worked out from how much treasure the level holds
## (_treasure_total), so that a player who finds about 60% of it can buy
## exactly one new weapon, one new costume and three roast figs:
##     axe 26%  +  a costume ~19%  +  3 figs x 4%   =  57%
## The upgrades are extra, for the ones who search every corner. Move or add
## treasure and the prices follow on their own.
const ECONOMY := {"axe": 0.26, "wolf_hood": 0.16, "ember_paint": 0.18, "bear_cloak": 0.21, "firekeeper": 0.20,
	"fig": 0.04, "heart": 0.18, "torch": 0.11, "pouch": 0.11}
