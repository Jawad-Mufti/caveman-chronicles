extends LevelBase
## Level 2's data tables: layout coordinates, loot, the caves, the sky lanes and
## the economy. level2.gd extends this file, so its builders use every table by
## its bare name. Treasure ids are by index: never insert into the old loot tables.

const GROUND_Y := 600.0
const LEVEL_W := 33600.0
const FALL_Y := 1020.0

## Reachability budget: a jump climbs ~133 px and carries ~227 px. Every step
## here asks for 100-125 up; the mountain's are the ones near the top of that.
## Ground runs: [x0, x1] at GROUND_Y.
const FLOORS := [[0.0, 1500.0], [1640.0, 2600.0], [2760.0, 2900.0], [3350.0, 4060.0], [5420.0, 5680.0], [12050.0, 13800.0], [14300.0, 14600.0], [14780.0, 14870.0], [15190.0, 16080.0], [16280.0, 16420.0], [16840.0, 16960.0], [17600.0, 17950.0], [20200.0, 20450.0], [22640.0, 23700.0],
	[24420.0, 26920.0], [27030.0, 27400.0], [27530.0, 27940.0], [28080.0, 28240.0], [28400.0, 28900.0], [29300.0, 29600.0], [30000.0, 30250.0], [30700.0, LEVEL_W]]
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
	# (the mountain itself is MOUNTAIN_MAP, a Terrain)
	[25350.0, 490.0, 250.0, 710.0],     # the far-side outcrop: the Rattling Cave's mouth is in its far face
]
## Boulders to shelter behind, [x, surface y]. The wind blows down the climb
## (from the right), so the lee is the left side.
const BOULDERS := [[6265.0, 280.0], [6950.0, -40.0]]
const WIND_ZONE := [5870.0, 10200.0]     ## both climbs: up to the summit, and from the saddle up the High Peak
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
## Shaken out of the fallen giant by METEOR STOMPs on top of it (3 a stomp, 5 a MEGA
## stomp), flying straight to him. Ids "gw%d". A bonus: not counted in the shop prices.
const GORGE_WOOD_LOOT := ["conch", "shell", "shell", "shell", "conch", "shell", "shell", "amber", "shell", "shell"]
## Moss, shaken awake on her tree by a stomp: a line for each one, in turn.
const MOSS_SHAKEN := [
	"Moss:  \"W-WHOA!! ...The tree... is SHAKING! ...Don't drop me... I'm too slow... to fall!\"",
	"Moss:  \"EEK! ...Who's... jumping... on my... ceiling?!\"",
	"Moss:  \"Please... stop... I'm holding on... with all... four... claws...\"",
	"Moss:  \"My whole life... flashed before my eyes. ...It was... mostly naps.\"",
]
## The mountain (2026-10-06): a Terrain (common/terrain.gd) from this text map,
## made by tools/mountain_gen (edit the map by hand, or the shapes there and regenerate).
## Column c is at x = MOUNTAIN_AT.x + 40 c, row r at y = MOUNTAIN_AT.y + 40 r; flat ground
## on solid row R lies at y = MOUNTAIN_AT.y - 20 + 40 R (the climb: 480, crevice 720,
## shelf 280, bat ledge 160, 80, dead-tree shelf -40, bat ledge -160, summit -280,
## lookout -480; down: -160, -40, 80, 200, 320, then the ground).
## Inside: Echo Tunnel (from the crevice floor) -> Crystal Grotto -> up to the Bone
## Hall -> THE CHIMNEY (wall-kick, MT_CHIMNEY) up and out onto the summit; down from the grotto to the Painted
## Cave in the strata; Glow Hollow between the descent's 200 step and the east foot.
const MOUNTAIN_AT := Vector2(5640, -540)
const MOUNTAIN_MAP := [
	"                                                                                                                                                                  ",
	"                                                                                                                                                                  ",
	"                                      ##                                                                                                                          ",
	"                                      ##                                                           #####..#######                                                 ",
	"                                                                                                   #####..#######                                                 ",
	"                                                                                                   #####..#######                                                 ",
	"                                                                                               #########..###########                                             ",
	"                                      ####..########                                           #########..###########                                             ",
	"                                      ####..########                                           #########..###########                                             ",
	"                                      ####..########                                       #############..###############                                         ",
	"                                   #######..############                                   #############..###############                                         ",
	"                                   #######..############                                   #############..###############                                         ",
	"                                   #######..############                               #################..#####################                                   ",
	"                         #################..#################                          #################..#####################                                   ",
	"                         #################..#################                          #################..#####################                                   ",
	"                         #################..#################                      #####################..##########################                              ",
	"                    ######################..#####################                  #####################..##########################                              ",
	"                    ######################..#####################                  #####################..##########################                              ",
	"                 #########################..#############################..#############################..################################                        ",
	"                 #########################..############################...#############################..################################                        ",
	"                 #########################..###########################....#############################..################################                        ",
	"           ###############################..###########################...######################....##....######################################                  ",
	"           ###############################..###########################....###################............######################################                  ",
	"           ###############################..###########################.....#################.............######################################                  ",
	"        ## ###############################..#############################....###############..............############################################            ",
	"        ## #####################......####..#############################...###############...................########################################            ",
	"   ###     ###################..............######################oooo.......oooo########.....##....##.................####################################       ",
	"  ####     #######oooooooo####..............####################ooo.............ooo#####.....############......................................#.......#...       ",
	" #####     #####ooo......ooo##..............##################ooo...............###oo#......##################..............................................      ",
	"########   ####oo......................######################oo.................###.......############################.....................................#######",
	"########   ....................############################..............................#####################################################.#........##########",
	"######     ....................#######################................................o###########################################################################",
	"##########...............oooo#####################..............o.................oooo############################################################################",
	"##############.#ooo....oooooddd======########..............##oooo...............oooooo##======###################################################======###########",
	"#############=====oo.......dd.....=====##..............#######oo....oo.......oooooooo#==========###########=====###############=====###########==========#########",
	"###########==========.............................=======######....o==========ooooo================#####==========###########==========######===============#####=",
	"==#######==============.......................=============####....=================================================#######=======================================",
	"===========================..............=======================....==============================================================================================",
	"=============================.....===============================............=====================================================================================",
	"==================================================================............====================================================================================",
	"===================================================================...........====================================================================================",
	"====================================================================.........=====================================================================================",
	"==================================================================================================================================================================",
	"==================================================================================================================================================================",
	"==================================================================================================================================================================",
	"==================================================================================================================================================================",
]

## ---------------------------------------------------------------- the Mammoth Steppe
## Between the mountain's foot and the great tree. A split rock blocks the way:
## he walks in under its loose slab and climbs the chimney by jumping from wall
## to wall. Then a herd of mammoths on the path (mind the feet, ride the backs),
## a river only the old bull wades, and a mammoth graveyard under the tree.
const CHIMNEY := [12450.0, 120.0, 60.0, 380.0]      ## the loose slab [x, top, w, h]: hangs 100 px off the ground
const CLIFF := [12600.0, 100.0, 400.0]               ## [x, top, w]: the face to climb, and the top
const CLIFF_STEPS := [[13000.0, 260.0, 110.0], [13110.0, 420.0, 100.0]]   ## the way down: [x, top, w]
## The herd: [x0, x1, start x, speed, size]. The calf's back is one jump up;
## the bull's needs the double jump (or the calf as a step).
const HERD := [[13200.0, 13500.0, 13300.0, 70.0, 1.0], [13300.0, 13660.0, 13600.0, 95.0, 0.72]]
const RIVER := [13800.0, 14300.0]
## The old bull who wades the river: [x0, x1, ground y (in the water), speed].
## His back is one jump up from either bank.
const FERRY := [13920.0, 14180.0, 680.0, 70.0]
const GRAVEYARD := [[14650.0, 1.0], [15200.0, 0.8], [15650.0, 1.15]]   ## skeletons: [x, size]
## Hand-placed treasure in the Steppe: [x, y, kind]. Ids "m0", "m1"...
const STEPPE_LOOT := [
	[12555.0, 420.0, "shell"], [12555.0, 320.0, "shell"], [12555.0, 220.0, "conch"],      # up the chimney
	[12720.0, 70.0, "shell"], [12800.0, 70.0, "shell"], [12880.0, 70.0, "bone"],         # the clifftop
	[13055.0, 230.0, "shell"],
	[13250.0, 570.0, "bone"], [13450.0, 570.0, "shell"], [13630.0, 570.0, "bone"],    # under the herd's feet
	[13770.0, 570.0, "shell"],
	[14050.0, 420.0, "shell"], [14050.0, 350.0, "shell"],                              # jump for them off the bull's back
	[14600.0, 570.0, "bone"], [14660.0, 570.0, "bone"], [14720.0, 570.0, "tusk"],      # the graveyard
	[15150.0, 570.0, "bone"], [15200.0, 480.0, "shell"], [15250.0, 570.0, "bone"],
	[15600.0, 570.0, "shell"], [15660.0, 480.0, "conch"], [15720.0, 570.0, "bone"],
]

## ---------------------------------------------------------------- the Tar Pits
## Past the graveyard (it's why the bones are there): three pools of black,
## bubbling tar, each wider than the last. Logs float on them â until he
## stands on one, and it slowly sinks. The last two are too wide to jump, so
## he hops log to log and keeps moving. In the tar he's stuck: hauled out on
## the near bank, a heart lighter.
const TAR_POOLS := [[16080.0, 16280.0], [16420.0, 16840.0], [16960.0, 17480.0]]   ## [x0, x1]
const TAR_LOGS := [[16180.0, 110.0], [16520.0, 100.0], [16750.0, 100.0],           ## [centre x, width]
	[17060.0, 100.0], [17180.0, 100.0], [17300.0, 100.0], [17400.0, 90.0]]
const TAR_ROCKS := [[16605.0, 540.0, 70.0]]        ## a boulder stuck fast in the middle pool: [x, top, w]
const TAR_GEYSERS := [[16130.0, 0.0], [16825.0, 1.1], [16990.0, 2.2]]   ## [x, start offset s]: wait on firm ground for each to blow
const TAR_SNAPPER := [16960.0, 17480.0]          ## the croc's pool: [left bank, right bank]
const TAR_LOOT := [                                ## [x, y, kind]; ids "t0", "t1"...
	[16180.0, 545.0, "shell"], [16350.0, 570.0, "tusk"],
	[16520.0, 545.0, "shell"], [16640.0, 490.0, "conch"], [16750.0, 545.0, "shell"],
	[16900.0, 570.0, "bone"],
	[17060.0, 545.0, "shell"], [17180.0, 545.0, "shell"], [17300.0, 545.0, "bone"], [17400.0, 545.0, "shell"],
]

## ---------------------------------------------------------------- Thunder Canyon
## Past Nutmeg's creek, before the great tree: a deep canyon. Falling in costs
## a heart, as any pit does.
##   Sky Stones (17950-16900): flying rocks with vines, each in its own space â
##     drifting, bobbing or circling. They share one beat (STONE_BEAT s), and
##     their closest moments come in a wave along the line: each one swings
##     close to the next (130-150 px) every half beat. They never touch.
##   a rest ledge with a fire (20200-17150)
##   floating rocks at different heights (20580-19290), some bobbing; once he
##     is on the second, bats dive straight down at him (a shadow warns)
##   a rock outcrop at the end (22680-19600): the Weeping Cave's mouth is in
##     its far face, by the great tree
## Sky Stones: [kind, x, y, amp, vine length, look]
const SKY_STONES := [
	["drift", 18150.0, 230.0, 60.0, 200.0, 0], ["orbit", 18400.0, 210.0, 60.0, 200.0, 1],
	["bob", 18600.0, 240.0, 30.0, 200.0, 2], ["drift", 18810.0, 230.0, 70.0, 200.0, 0],
	["orbit", 19090.0, 220.0, 70.0, 200.0, 1], ["drift", 19350.0, 240.0, 60.0, 190.0, 2],
	["bob", 19550.0, 230.0, 30.0, 200.0, 0], ["orbit", 19750.0, 230.0, 60.0, 200.0, 1],
	["drift", 20020.0, 230.0, 60.0, 200.0, 2],
]
const STONE_BEAT := 6.0
## Floating rocks to hop across: [x, top, w, bob]
const FLOAT_ROCKS := [[20580.0, 520.0, 130.0, 0.0], [20800.0, 460.0, 110.0, 8.0], [21000.0, 400.0, 120.0, 0.0],
	[21210.0, 460.0, 110.0, 10.0], [21420.0, 380.0, 130.0, 0.0], [21640.0, 320.0, 110.0, 8.0],
	[21840.0, 400.0, 120.0, 0.0], [22060.0, 470.0, 110.0, 10.0], [22270.0, 410.0, 130.0, 0.0],
	[22480.0, 500.0, 110.0, 0.0]]
const BAT_SKY := [20580.0, 22600.0, 1.5]       ## [from x, to x, s between attacks]
const CANYON_OUTCROP := [22680.0, 500.0, 220.0]  ## [x, top, w]: the Weeping Cave is in its far face
const CANYON_LOOT := [                          ## [x, y, kind]; ids "n0", "n1"...
	[18275.0, 430.0, "shell"], [18530.0, 430.0, "shell"], [18710.0, 430.0, "shell"], [18950.0, 420.0, "conch"],
	[19220.0, 430.0, "shell"], [19450.0, 430.0, "shell"], [19650.0, 430.0, "shell"], [19890.0, 430.0, "bone"],
	[20340.0, 570.0, "bone"],
	[20645.0, 490.0, "shell"], [21055.0, 370.0, "shell"], [21485.0, 350.0, "conch"], [21695.0, 290.0, "shell"],
	[22335.0, 380.0, "shell"], [22790.0, 470.0, "bone"],
]

## ---------------------------------------------------------------- talking animals
## Met in passing: a bubble shows over them when he's close; E (or TALK) to talk.
const MOSS_AT := Vector2(4075.0, 262.0)        ## the sloth's grip, under the fallen giant over the gorge
const NUTMEG_AT := Vector2(17740.0, 600.0)     ## the beaver by her dam on a little creek, past the tar pits
const CREEK := [17600.0, 70.0]                ## [x, width]: the little creek she has dammed

## The great tree: trunk centred here, and its branches as one-way platforms
## [x, top, width, grows from the left end?]. Left and right of the trunk in
## turn, 112 px apart; the long bough crosses the chasm; above it, the crown.
const TREE_X := 23520.0
const BRANCHES := [
	[23330.0, 490.0, 130.0, false], [23580.0, 378.0, 130.0, true], [23320.0, 266.0, 140.0, false],
	[23580.0, 154.0, 120.0, true],
	[23560.0, 42.0, 900.0, true],        # the long bough, over the chasm to the far side
	[23340.0, -70.0, 130.0, false], [23580.0, -183.0, 120.0, true], [23350.0, -296.0, 120.0, false],
	[23430.0, -408.0, 230.0, true],      # the crown
	# the dead snag on the far side: the way back up to the bough
	[24600.0, 490.0, 110.0, false], [24730.0, 378.0, 110.0, true], [24600.0, 266.0, 110.0, false],
	[24730.0, 154.0, 110.0, true], [24520.0, 42.0, 190.0, false],
]
const SNAG_X := 24715.0
## The troop: [x, y, habit, hanging]
const MONKEYS := [
	[23660.0, 378.0, 0, false],
	[23360.0, 280.0, 0, true],            # hanging under a branch by its tail
	[23790.0, 42.0, 0, false], [24010.0, 42.0, 1, false], [24240.0, 42.0, 0, false],
	[23640.0, -183.0, 1, false],
]
## Old Bongo sits at the top of the crown, beside his banana box.
const ELDER_AT := Vector2(23620, -408)

## [x, y, lit at start]
const BONFIRES := [[520.0, GROUND_Y, true], [1720.0, GROUND_Y, false], [3560.0, GROUND_Y, false],
	[7470.0, -280.0, false], [23130.0, GROUND_Y, false], [24570.0, GROUND_Y, false],
	[35770.0, 700.0, false], [37590.0, 700.0, false], [39440.0, 600.0, false], [40600.0, 600.0, false],   # old hearths in the caves
	[12260.0, GROUND_Y, false],   # the mountain's foot, before the Steppe
	[20320.0, GROUND_Y, false],  # the rest ledge in Thunder Canyon
	[26280.0, GROUND_Y, false]]  # before the Boulder Run: caught by the boulder, he wakes here
## [x, y, bundles of wood in it]
const DEAD_TREES := [[1260.0, GROUND_Y, 2], [2400.0, 400.0, 1], [2855.0, GROUND_Y, 2], [6830.0, -40.0, 2], [23290.0, GROUND_Y, 2]]
## Loose bundles already on the ground: the crevice stash.
const WOOD := [[5900.0, 720.0], [5975.0, 720.0], [35900.0, 700.0], [40730.0, 600.0]]
## [left, right, start_x, floor_y]. Kept clear of the bonfires' light.
const WOLVES := [
	[1000.0, 1490.0, 1330.0, GROUND_Y], [1000.0, 1490.0, 1450.0, GROUND_Y],
	[2040.0, 2590.0, 2420.0, GROUND_Y], [2040.0, 2590.0, 2540.0, GROUND_Y],
	[2915.0, 3335.0, 3120.0, 700.0], [2915.0, 3335.0, 3220.0, 700.0], [2915.0, 3335.0, 3310.0, 700.0],
	[24890.0, 25300.0, 25050.0, GROUND_Y], [24890.0, 25300.0, 25200.0, GROUND_Y],
]
## AMBUSHES (level2/ambush.gd): walk into the stretch and beasts burst out at
## him, one after another; beat them all for a burst of Spirit Orbs. Every visit.
## ESCALATION: the further along, the harder (tier 1-5 from x: more beasts, waves, elites).
## [x0, x1, floor y, [kinds: wolf skeleton rat bat], the line on the HUD]
const AMBUSHES := [
	[3420.0, 3950.0, 600.0, ["wolf", "bat", "wolf"], "Eyes in the bushes... AMBUSH!"],
	[8350.0, 8750.0, 830.0, ["skeleton", "skeleton"], "The bones of the Great Cavern stir..."],
	[15250.0, 15900.0, 600.0, ["skeleton", "skeleton", "skeleton"], "The graveyard... the bones are MOVING!"],
	[12090.0, 12440.0, 600.0, ["wolf", "wolf", "bat"], "Out on the open Steppe... nowhere to hide!"],
	[25400.0, 26300.0, 600.0, ["wolf", "wolf", "bat", "wolf"], "The pack was lying in wait!"],
	[28420.0, 28880.0, 600.0, ["skeleton", "bat", "rat", "skeleton"], "In the last of the light... the dead walk!"],
]
const BAT_HOVER := 70.0
## [x, the surface this bat belongs to]
const BATS := [[1880.0, GROUND_Y], [2360.0, 400.0], [35635.0, 700.0], [36840.0, 700.0, 240.0]]
const ROCK_PILES := [[760.0, GROUND_Y], [2130.0, 490.0], [2785.0, GROUND_Y], [6900.0, -40.0], [23200.0, GROUND_Y], [34900.0, 600.0], [36360.0, 700.0], [39520.0, 600.0]]
const BERRIES := [[1030.0, 500.0], [2425.0, 400.0], [5970.0, 720.0], [7180.0, -480.0], [36000.0, 700.0], [40700.0, 600.0], [37360.0, 700.0], [39480.0, 600.0]]

## ---------------------------------------------------------------- caves
## Each cave: its camera bounds, its rock [x, y, w, h, kind], where he comes in,
## and its doorway outside [x, y, which way he walks in, "webs" | "skin"].
const CAVE_A := Rect2(34600, 150, 3370, 800)      # the Weeping Cave
const CAVE_A_ROCK := [
	[34600.0, 150.0, 100.0, 800.0, "wall"], [37870.0, 150.0, 100.0, 800.0, "wall"],
	[34700.0, 600.0, 500.0, 350.0, "floor"], [35200.0, 700.0, 350.0, 250.0, "floor"],
	[35720.0, 700.0, 990.0, 250.0, "floor"],           # after the pit: the old hearth, the Weeping Hall, the nursery
	[36950.0, 700.0, 120.0, 250.0, "floor"],           # the pillar in the Glowcap Chasm
	[37310.0, 700.0, 340.0, 250.0, "floor"],           # the far side of the chasm, and under the stairs
	[37370.0, 590.0, 100.0, 18.0, "floor"], [37520.0, 480.0, 100.0, 18.0, "floor"],
	[37650.0, 380.0, 220.0, 570.0, "floor"],           # the cocoon chamber
	[34700.0, 150.0, 500.0, 270.0, "roof"], [35200.0, 150.0, 860.0, 320.0, "roof"],
	[36060.0, 150.0, 340.0, 180.0, "roof"],            # the Weeping Hall: a high roof, to hang stalactites from
	[36400.0, 150.0, 310.0, 270.0, "roof"],            # the nursery: lower
	[36710.0, 150.0, 1160.0, 30.0, "roof"],            # the chasm and the chamber: very high
]
const CAVE_A_IN := Vector2(34770, 600)
const CAVE_A_DOOR := [22900.0, GROUND_Y, -1, "webs"]   # in the far face of the canyon's last outcrop, by the great tree
const CAVE_A_WEBS := [[35140.0, 600.0, 180.0], [37730.0, 380.0, 200.0]]
## [x, roof y, floor y, left, right]
const SPIDERS := [[35380.0, 470.0, 700.0, 35210.0, 35540.0], [35900.0, 470.0, 700.0, 35740.0, 35990.0],
	[37710.0, 180.0, 380.0, 37660.0, 37860.0], [36250.0, 330.0, 700.0, 36070.0, 36390.0]]
const COCOON := [37810.0, 180.0, 380.0]

const CAVE_B := Rect2(38400, 150, 2840, 800)      # the Rattling Cave
const CAVE_B_ROCK := [
	[38400.0, 150.0, 100.0, 800.0, "wall"], [41140.0, 150.0, 100.0, 800.0, "wall"],
	[38500.0, 600.0, 400.0, 350.0, "floor"], [38900.0, 510.0, 90.0, 440.0, "floor"],   # a pillar, with a snake in it
	[38990.0, 600.0, 410.0, 350.0, "floor"],
	[39400.0, 600.0, 280.0, 350.0, "floor"],           # the Stampede Alley
	[39680.0, 540.0, 80.0, 410.0, "floor"],            # the rat mound, with the burrow in its face
	[39900.0, 510.0, 80.0, 440.0, "floor"],            # the Rattle Pit's pillar: another snake
	[40130.0, 600.0, 1010.0, 350.0, "floor"],          # the rockfall run, then the old hearth and on to the hoard
	[40860.0, 490.0, 110.0, 18.0, "floor"], [41000.0, 380.0, 140.0, 18.0, "floor"],   # up to the hoard
	[38500.0, 150.0, 400.0, 180.0, "roof"], [38900.0, 150.0, 120.0, 180.0, "roof"],
	[39020.0, 150.0, 340.0, 370.0, "roof"],            # the crawl tunnel: no room to jump
	[39360.0, 150.0, 1780.0, 60.0, "roof"],
]
const CAVE_B_IN := Vector2(38570, 600)
## In the outcrop's far face: he sees it behind him once he has climbed over.
const CAVE_B_DOOR := [25600.0, GROUND_Y, -1, "skin"]
## [left, right, start x, floor y]
const RATS := [[38620.0, 38880.0, 38720.0, 600.0], [38620.0, 38880.0, 38820.0, 600.0],
	[39000.0, 39340.0, 39100.0, 600.0], [39000.0, 39340.0, 39250.0, 600.0],
	[40700.0, 41120.0, 40780.0, 600.0], [40700.0, 41120.0, 41000.0, 600.0]]
## [hole x, hole y, facing]
const SNAKES := [[38900.0, 580.0, -1], [41140.0, 580.0, -1], [39900.0, 580.0, -1]]
const NEST := [41070.0, 380.0]

## ---------------------------------------------------------------- the longer caves
## Each cave is two-thirds longer than it was, and the new stretch is made of
## set-pieces that each say what they are about to do before they do it.
##
## The Weeping Cave: the Weeping Hall (stalactites that fall behind a runner and
## on a dawdler), the nursery (egg sacs: pop them from afar, or they hatch), and
## the Glowcap Chasm (a mushroom on a pillar, a bat, and a high shelf).
## [x, the roof's underside, length]
const HALL_STALACTITES := [[36100.0, 330.0, 96.0], [36170.0, 330.0, 112.0], [36240.0, 330.0, 92.0], [36310.0, 330.0, 108.0], [36375.0, 330.0, 94.0]]
## [x, floor y]: the nursery's sacs; the nursery's own limits are below
const EGG_SACS := [[36500.0, 700.0], [36590.0, 700.0], [36670.0, 700.0]]
const NURSERY := [36410.0, 36700.0]
## [x, floor y, tint]: glowing mushrooms (tint 0 teal, 1 violet)
const GLOWCAPS := [[37010.0, 700.0, 0]]
## [x, y, width]: a one-way shelf in the air over the chasm
const CAVE_SHELVES := [[37130.0, 470.0, 150.0]]
## The Rattling Cave: the Stampede Alley (a burrow that empties out at him),
## the Rattle Pit (rib bridge, a snake pillar), the Rockfall Run.
const STAMPEDE := [39680.0, 600.0]                   # the burrow's mouth, in the mound's face
const STAMPEDE_ZONE := [39410.0, 39060.0]            # [where it wakes, where the rats are gone]
const BONE_SLABS := [[39770.0, 600.0, 80.0], [40020.0, 600.0, 80.0]]
const ROCKFALL_XS := [40370.0, 40460.0, 40550.0]
## [x, y, hanging from the roof?, tint]: glowing crystal (0 teal, 1 violet, 2 amber, 3 rose)
const CRYSTALS := [
	[35820.0, 700.0, false, 0], [36045.0, 330.0, true, 0], [36440.0, 420.0, true, 3], [36630.0, 700.0, false, 3],
	[36780.0, 180.0, true, 1], [37060.0, 700.0, false, 1], [37250.0, 180.0, true, 0], [37590.0, 180.0, true, 1],
	[38740.0, 600.0, false, 2], [39390.0, 210.0, true, 2], [39600.0, 210.0, true, 2], [39740.0, 540.0, false, 3],
	[39960.0, 210.0, true, 2], [40320.0, 600.0, false, 2], [40780.0, 210.0, true, 3], [41080.0, 210.0, true, 2],
]
const TINTS := [Color("5ee0d0"), Color("b084ff"), Color("ffb347"), Color("ff7fa8")]

## ---------------------------------------------------------------- the Long Dark
## [anchor x, anchor y, length]: the grip hangs at anchor y + length.
const VINES := [[29100.0, 330.0, 190.0], [30290.0, 310.0, 230.0], [30660.0, 310.0, 230.0]]
## [x, top y, width]: rotten rock over the second pit.
const CRUMBLES := [[29630.0, 600.0, 80.0], [29760.0, 600.0, 80.0], [29890.0, 600.0, 80.0]]
const FIREFLIES := [[28800.0, 520.0], [29100.0, 440.0], [29450.0, 520.0], [29800.0, 480.0], [30120.0, 520.0], [30470.0, 420.0]]
## eyes in the trees, watching
const WATCHERS := [[25950.0, 430.0], [28700.0, 400.0], [29520.0, 380.0], [30250.0, 390.0]]
const CLAW_MARKS := [[26150.0, 470.0], [29380.0, 460.0]]
const PANIC_AT := 25950.0          ## the wolves come running past here
const SNUFF_AT := 28650.0         ## the roar, and the dark
## ---------------------------------------------------------------- the Boulder Run
## A boulder on a crumbling ledge breaks loose as he passes beneath it and
## rolls after him down the pass: over fallen logs (it smashes them), across
## gaps, until it plunges into the ravine at the end â and the crash shakes a
## stash loose from the cliff. Caught, he is flattened (dead: he wakes by the
## fire just before the pass); fallen into a gap, he starts the run again.
const RUN_START := 26540.0
const RUN_TRIGGER := 26630.0
const RUN_LEDGE := Vector2(26410.0, 520.0)
const RUN_LOGS := [27230.0, 27680.0, 27840.0]
const RUN_RAVINE := [28240.0, 28400.0]
const RUN_STASH := ["shell", "shell", "shell", "shell", "conch", "tusk", "bone", "bone", "bone", "bone"]

## ---------------------------------------------------------------- the end
const TOOLMAKER_AT := Vector2(31060, 600)
const CAMP_AT := Vector2(31000, 600)       ## his home under the overhang
## The Three Fires: a trial between his home and the clearing. A cracked
## boulder bars the way; a pack of wolves waits in the dark; three stone bowls
## must all burn â then the old palisade across the path burns down.
const TRIAL_ROCK := Vector2(31470, 600)
const TRIAL_BOWLS := [[31640.0, 600.0], [31890.0, 480.0], [32130.0, 600.0]]
const TRIAL_LEDGE := [31820.0, 480.0, 140.0]
const TRIAL_WOLVES := [[31560.0, 32200.0, 31760.0], [31560.0, 32200.0, 32000.0], [31560.0, 32200.0, 32180.0]]
const TRIAL_GATE_X := 32250.0
const ARENA := Rect2(32300, -900, 1300, 2100)
const BRAZIERS := [[32420.0, 600.0], [33260.0, 600.0]]
const LAIR_X := 33450.0           ## his lair's mouth, in the rock at the far end
const ARENA_LEDGES := [[32600.0, 480.0, 140.0], [33160.0, 480.0, 140.0]]
const BONGO_PERCH := Vector2(32370, 330)

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
	[6330.0, 6390.0, 160.0, 2],     # the narrow ledge with the bat
	[7050.0, 7110.0, -160.0, 2],    # the other narrow ledge
	[25440.0, 25510.0, 490.0, 3],     # on top of the outcrop
	[34860.0, 34940.0, 600.0, 3],   # Weeping Cave: by the rock pile
	[35790.0, 35870.0, 700.0, 3],   # Weeping Cave: past the pit, by the old hearth
	[38915.0, 38975.0, 510.0, 3],   # Rattling Cave: on the snake's pillar
	[40610.0, 40690.0, 600.0, 3],   # Rattling Cave: by the old hearth
]
## Single shells: arcs over jumps and swings, trails up the trees, and a
## column above each Moonpuff on the way down the mountain.
const SHELL_POINTS := [
	[1520.0, 540.0], [1570.0, 515.0], [1620.0, 540.0],              # the first pit
	[2630.0, 540.0], [2680.0, 515.0], [2730.0, 540.0],              # the second pit
	[7780.0, -400.0], [7780.0, -460.0], [7780.0, -520.0, "shell"],           # Moonpuff 1
	[8140.0, -160.0], [8140.0, -220.0], [8140.0, -280.0, "shell"],           # Moonpuff 2
	[11480.0, 160.0], [11480.0, 100.0], [11480.0, 40.0, "shell"],             # Moonpuff 3 (at the far end of the mountain now)
	[23395.0, 466.0], [23645.0, 354.0], [23390.0, 242.0], [23640.0, 130.0],   # up the great tree
	[23405.0, -94.0], [23635.0, -207.0], [23410.0, -320.0, "shell"],            # on up to Bongo
	[24785.0, 354.0], [24785.0, 130.0],                               # up the snag
	[28960.0, 470.0], [29040.0, 520.0], [29160.0, 520.0], [29240.0, 470.0],   # the first vine's swing
	[29670.0, 560.0], [29800.0, 560.0], [29930.0, 560.0],           # the crumbling bridge
	[30400.0, 470.0], [30475.0, 440.0], [30550.0, 470.0],           # the two vines
	# the Boulder Run: shells over the gaps (no time to stop for them!), bones on the way
	[26980.0, 520.0, "shell"], [27470.0, 520.0, "shell"], [28015.0, 520.0, "shell"],
	[27120.0, 560.0], [27300.0, 500.0], [27600.0, 560.0], [27760.0, 500.0], [28160.0, 560.0],
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
	[25020.0, 482.0], [25060.0, 472.0],
	[30790.0, 478.0],
	[35000.0, 478.0], [35040.0, 470.0],
	# ...and these, higher, need the double jump
	[3420.0, 352.0, "shell"], [3460.0, 342.0, "shell"], [3500.0, 352.0, "shell"],
	[23190.0, 348.0, "shell"], [23230.0, 342.0, "shell"],
	[30090.0, 348.0, "shell"], [30130.0, 342.0, "shell"],
]
## Conches (5): out-of-the-way spots.
const CONCHES := [
	[4715.0, 490.0],
	[1000.0, 470.0], [2400.0, 370.0], [3310.0, 670.0], [6080.0, 690.0], [7680.0, -300.0], [8140.0, -320.0],
	[23450.0, -430.0], [24660.0, 20.0], [25480.0, 460.0], [29230.0, 430.0], [37470.0, 670.0], [37830.0, 350.0],
	[41040.0, 570.0], [40900.0, 460.0],
]
## [x, y, secret]: amber (25), one in each secret place.
const AMBERS := [[5990.0, 690.0, "crevice"], [7190.0, -505.0, "lookout"], [37750.0, 350.0, "weeping"], [41110.0, 350.0, "rattling"]]
## [x, surface y, "log" | "mound", contents]: the treasure boxes.
const LOG := ["bone", "shell", "bone", "shell", "bone", "shell", "bone"]
const MOUND := ["bone", "shell", "bone", "shell", "bone", "shell", "tusk", "conch"]
const BREAKABLES := [
	[640.0, 600.0, "log", LOG], [1950.0, 600.0, "mound", MOUND], [3480.0, 600.0, "log", LOG],
	[7620.0, -280.0, "mound", MOUND], [25100.0, 600.0, "log", LOG],
	[29480.0, 600.0, "mound", MOUND], [30790.0, 600.0, "log", LOG],
	[35350.0, 700.0, "log", LOG], [40790.0, 600.0, "mound", MOUND],
]
## Clay pots, in little groups: one smack each, a few shells. [x, surface y, how many]
const POTS := [
	[5520.0, 600.0, 2],
	[330.0, 600.0, 2], [2170.0, 490.0, 2], [3640.0, 600.0, 3], [7540.0, -280.0, 2], [23470.0, 600.0, 2],
	[24480.0, 600.0, 2], [28820.0, 600.0, 2], [30920.0, 600.0, 3], [34800.0, 600.0, 2], [38600.0, 600.0, 2],
]
## ---------------------------------------------------------------- the sky lanes
## Optional roads of floating stone above the ground road. Each starts with a
## bounce bloom on the ground ("pad": [x, y]) that throws him up to the first
## rock; then it is hops and bounces from stone to stone. [x, top y, width,
## flags] â flags: 1 = a bounce bloom on the rock, 2 = a lamp (a real light in
## the dark). A lane over solid ground costs nothing to fall from: the ground
## catches him. Each ends above solid ground, and he just steps off.
## Reach budget: hops of up to ~90 up and ~130 across; a bloom carries ~330
## across and puts him ~390 higher than where it launched him.
const SKY_LANES := [
	{
		"name": "Moonstep Road",          # the firelit woods: over the first wolves and the first pit, to the bonfire
		"pad": [800.0, 600.0],
		"rocks": [[940.0, 300.0, 190.0, 0], [1200.0, 200.0, 120.0, 0], [1370.0, 175.0, 110.0, 0], [1560.0, 310.0, 140.0, 1], [1780.0, 70.0, 170.0, 0]],
		"cache": [4, ["shell", "shell", "shell", "shell", "conch", "bone", "bone", "bone"]],
		"motes": [1100.0, 1700.0],
		"note": [690.0, "Stepping stones in the sky! The bloom bounces you up.", 5.0],
	},
	{
		"name": "Silver Stair",           # the far side: over the wolves and the outcrop, to before the boulder run
		"pad": [24910.0, 600.0],
		"rocks": [[25040.0, 300.0, 190.0, 0], [25310.0, 290.0, 110.0, 1], [25560.0, 40.0, 160.0, 0], [25790.0, 80.0, 110.0, 0],
			[25980.0, 130.0, 110.0, 0], [26160.0, 210.0, 110.0, 0], [26310.0, 330.0, 80.0, 0]],
		"cache": [2, ["shell", "shell", "shell", "shell", "conch", "tusk", "bone", "bone"]],
		"bat": [25890.0, 70.0],
		"motes": [25200.0, 25800.0, 26300.0],
		"note": [24860.0, "More sky islands! Bounce up on the bloom.", 4.5],
	},
	{
		"name": "Starlit Road",           # the Long Dark: glowing stones over the three pits, down to the toolmaker's fire
		"pad": [28780.0, 600.0],
		"rocks": [[28860.0, 290.0, 150.0, 2], [29090.0, 220.0, 100.0, 0], [29290.0, 230.0, 110.0, 2], [29470.0, 300.0, 140.0, 1],
			[29780.0, 120.0, 130.0, 2], [29990.0, 150.0, 100.0, 0], [30140.0, 190.0, 100.0, 2], [30290.0, 270.0, 130.0, 1], [30630.0, 160.0, 140.0, 2]],
		"cache": [8, ["shell", "shell", "shell", "shell", "shell", "conch", "conch", "tusk", "bone", "bone"]],
		"bat": [29950.0, 150.0],
		"motes": [29100.0, 29800.0, 30400.0],
		"note": [28740.0, "Glowing islands, like fallen stars. Bloom up!", 5.0],
	},
	{
		"name": "Mammoth Sky",            # the Steppe: off the split rock, over the herd and the river, down past the graveyard
		"pad": [12920.0, 100.0],
		"rocks": [[13060.0, -110.0, 150.0, 0], [13290.0, -70.0, 110.0, 0], [13500.0, -20.0, 120.0, 1], [13720.0, -230.0, 170.0, 0],
			[13980.0, 40.0, 120.0, 0], [14200.0, 110.0, 110.0, 0], [14410.0, 200.0, 130.0, 0], [14630.0, 330.0, 140.0, 0]],
		"cache": [3, ["shell", "shell", "shell", "shell", "conch", "conch", "tusk", "bone", "bone"]],
		"motes": [13200.0, 13800.0, 14400.0],
		"note": [12860.0, "Islands over the herd! Bloom up for a mammoth-free ride.", 5.0],
	},
]

## More pots, for the longer caves: [x, surface y, how many]. Their own ids.
const POTS_LATE := [[39720.0, 540.0, 2]]
## Shell Totems: carved faces that spit two shells per hit, six hits.
const TOTEMS := [[2470.0, 600.0], [7980.0, -40.0], [29370.0, 600.0], [40920.0, 600.0]]
## Hanging hoards (Hoards.Hoard): a basket on a rope, swinging, guarded by dragonflies.
## [id, rope x, ground y, rope, swing degrees, guards, prop, drift, land x]. The basket's
## bottom swings 150 px over the ground (one good jump); its shells arc down onto
## that ground. "x0"/"x1" were the monkeys' stashes (same ids, same STASH inside).
const STASH := ["bone", "shell", "bone", "shell", "bone", "shell", "bone", "shell", "bone", "shell", "tusk", "conch", "conch"]
const HOARD := ["shell", "shell", "shell", "conch", "shell", "shell", "shell", "conch"]
const HOARDS := [
	["x0", 23840.0, 600.0, 352.0, 24.0, 2, "", 0.0, 23670.0],     # from the long bough, out over the chasm
	["x1", 23470.0, -418.0, 200.0, 30.0, 2, "bough", 0.0, 23470.0],
	["h0", 16640.0, 540.0, 210.0, 38.0, 2, "snag", 0.0, 16640.0],      # over the boulder in the middle tar pool
	["h1", 21485.0, 380.0, 190.0, 30.0, 2, "stone", 50.0, 21485.0],    # over a floating rock, among the bats
]
const HOARD_RISE := 150.0
## Stomp spots (Stomp.Spot): caches set into the ground, opened only by the
## METEOR STOMP. [x, kind]; ids "g0", "g1"... "crack": any stomp; "seal": a
## gold rune seal, only a MEGA stomp (after a double jump) breaks it.
const STOMP_SPOTS := [[1100.0, "crack"], [2350.0, "crack"], [3800.0, "seal"], [13550.0, "crack"],
	[15500.0, "seal"], [23350.0, "crack"], [25000.0, "seal"], [26000.0, "crack"]]
const STOMP_CRACK := ["shell", "shell", "conch"]
const STOMP_SEAL := ["conch", "shell", "shell", "shell", "conch"]
## Golden Hares: [left x, right x, start x, ground y] â catch one for a shower of treasure.
const HARES := [[3380.0, 3960.0, 3800.0, 600.0], [23060.0, 23700.0, 23560.0, 600.0], [24420.0, 24880.0, 24700.0, 600.0]]
const HARE_VALUE := 18
## Moonpuffs: bounce bushes on the mountain's way down, where he lands
## coming off each step.
const MOONPUFFS := [[7780.0, -160.0], [8140.0, 80.0], [11480.0, 400.0], [10560.0, -80.0], [11000.0, 160.0]]
const SECRETS := ["crevice", "lookout", "weeping", "rattling"]
## [x, y, kind]: the treasure of the longer caves. These have their own ids ("v0",
## "v1"...), separate from the old tables, so nothing already found moves.
const CAVE_LOOT := [
	# the Weeping Hall: a trail under the stalactites (run, don't linger)
	[36130.0, 676.0, "shell"], [36205.0, 676.0, "bone"], [36275.0, 676.0, "shell"], [36345.0, 676.0, "bone"],
	# the nursery
	[36430.0, 676.0, "bone"], [36545.0, 676.0, "shell"], [36630.0, 676.0, "bone"],
	# the Glowcap Chasm: an arc over the first gap, a column up the bounce, the shelf, an arc down
	[36790.0, 560.0, "shell"], [36840.0, 530.0, "shell"], [36890.0, 560.0, "shell"],
	[37010.0, 520.0, "shell"], [37010.0, 450.0, "shell"], [37010.0, 385.0, "shell"],
	[37190.0, 440.0, "conch"], [37145.0, 440.0, "tusk"], [37235.0, 440.0, "shell"],
	[37290.0, 570.0, "shell"], [37330.0, 625.0, "shell"], [37370.0, 676.0, "bone"],
	# the Stampede Alley
	[39490.0, 576.0, "shell"], [39550.0, 576.0, "bone"], [39620.0, 576.0, "shell"], [39720.0, 500.0, "shell"],
	# the Rattle Pit: over the slabs, and a conch on the snake's pillar
	[39810.0, 560.0, "shell"], [39940.0, 476.0, "conch"], [40060.0, 560.0, "shell"], [39860.0, 520.0, "bone"],
	# the Rockfall Run: greedy, under the rocks
	[40300.0, 576.0, "bone"], [40370.0, 576.0, "shell"], [40460.0, 576.0, "bone"], [40550.0, 576.0, "shell"],
]
## [x, darkness]. Dusk at the camp, darkest in the woods, thinner on the
## mountain where the moon reaches, dark again under the great tree.
## THE COLOUR SCRIPT (caveman_visuals_spec item 1): the sky and the four backdrop
## bands take each region's colours, lerped by x as he walks (like DARKNESS). Each
## region HOLDS its colours and blends into the next over a few hundred px at its
## border. A first pass (Jawad: "to look at, not final").
## [x, sky_high, sky_low, ridge, pine, woods, under, accent]
const PALETTE := [
	[0.0, Color("1b2440"), Color("2a3350"), Color("33405e"), Color("273349"), Color("1e2a3a"), Color("16202c"), Color("e08a3c")],      # firelit woods
	[3600.0, Color("1b2440"), Color("2a3350"), Color("33405e"), Color("273349"), Color("1e2a3a"), Color("16202c"), Color("e08a3c")],
	[4100.0, Color("16233a"), Color("27384f"), Color("3b5163"), Color("2d4150"), Color("223440"), Color("1a2730"), Color("a8c7cf")],   # Hanging Gorge
	[5450.0, Color("16233a"), Color("27384f"), Color("3b5163"), Color("2d4150"), Color("223440"), Color("1a2730"), Color("a8c7cf")],
	[5900.0, Color("1a2033"), Color("2f3a4d"), Color("4a5668"), Color("3a4557"), Color("2b3443"), Color("202734"), Color("cdd6e0")],   # the mountain
	[11800.0, Color("1a2033"), Color("2f3a4d"), Color("4a5668"), Color("3a4557"), Color("2b3443"), Color("202734"), Color("cdd6e0")],
	[12300.0, Color("1d2133"), Color("343148"), Color("4d4552"), Color("3e3a44"), Color("2f2d35"), Color("242229"), Color("c9a86a")],  # Mammoth Steppe
	[15700.0, Color("1d2133"), Color("343148"), Color("4d4552"), Color("3e3a44"), Color("2f2d35"), Color("242229"), Color("c9a86a")],
	[16100.0, Color("141a18"), Color("1e2622"), Color("2b352c"), Color("222b24"), Color("19201b"), Color("121715"), Color("c8d44a")],  # Tar Pits
	[17500.0, Color("141a18"), Color("1e2622"), Color("2b352c"), Color("222b24"), Color("19201b"), Color("121715"), Color("c8d44a")],
	[18000.0, Color("1a1630"), Color("2a2246"), Color("3d3360"), Color("312a4e"), Color("241f3a"), Color("1a172b"), Color("e8e4ff")],  # Thunder Canyon
	[22400.0, Color("1a1630"), Color("2a2246"), Color("3d3360"), Color("312a4e"), Color("241f3a"), Color("1a172b"), Color("e8e4ff")],
	[22900.0, Color("201a2e"), Color("33263c"), Color("4a3246"), Color("3b2a3a"), Color("2b2030"), Color("1f1824"), Color("f0c070")],  # the great tree, the far side
	[26200.0, Color("201a2e"), Color("33263c"), Color("4a3246"), Color("3b2a3a"), Color("2b2030"), Color("1f1824"), Color("f0c070")],
	[26600.0, Color("1c1620"), Color("2c2029"), Color("423029"), Color("352720"), Color("271d18"), Color("1b1511"), Color("d47a4a")],  # Boulder Run
	[28300.0, Color("1c1620"), Color("2c2029"), Color("423029"), Color("352720"), Color("271d18"), Color("1b1511"), Color("d47a4a")],
	[28700.0, Color("080c14"), Color("0d141f"), Color("131c2a"), Color("101722"), Color("0c121a"), Color("080d13"), Color("5ee0d0")],  # the Long Dark
	[30600.0, Color("080c14"), Color("0d141f"), Color("131c2a"), Color("101722"), Color("0c121a"), Color("080d13"), Color("5ee0d0")],
	[32300.0, Color("1a1016"), Color("2b1620"), Color("41202a"), Color("331a21"), Color("261419"), Color("1a0e12"), Color("e2622f")],  # Old Scar (the Toolmaker's home blends in)
	[33600.0, Color("1a1016"), Color("2b1620"), Color("41202a"), Color("331a21"), Color("261419"), Color("1a0e12"), Color("e2622f")],
]
## The underground (UNDER), blended in by depth, not by x: it lies under the Steppe.
const PALETTE_UNDER := [Color("0c0a0b"), Color("161012"), Color("241a18"), Color("1c1413"), Color("140f0f"), Color("0d0a0a"), Color("d08a3a")]
const DARKNESS := [[0.0, 0.26], [700.0, 0.40], [1500.0, 0.62], [2600.0, 0.72], [3600.0, 0.74],
	[3950.0, 0.64], [4300.0, 0.50], [5400.0, 0.50], [5800.0, 0.60],                       # the gorge: the last light of dusk
	[6000.0, 0.62], [6700.0, 0.56], [7400.0, 0.50], [8300.0, 0.60],
	[12100.0, 0.60], [12500.0, 0.64], [13100.0, 0.54], [14000.0, 0.48], [14800.0, 0.56], [15700.0, 0.64], [16700.0, 0.62], [18700.0, 0.56], [20300.0, 0.58], [21600.0, 0.70], [22700.0, 0.72],   # the Steppe: open sky, a bright river
	[23100.0, 0.70], [23600.0, 0.64],
	[24500.0, 0.72], [26000.0, 0.76], [26450.0, 0.70], [28450.0, 0.72], [28600.0, 0.86], [28700.0, 0.92], [30650.0, 0.92],   # the Long Dark
	[30800.0, 0.74], [31350.0, 0.76], [31450.0, 0.88], [32250.0, 0.88],                   # his home; the Three Fires
	[32300.0, 0.82], [33600.0, 0.82],                                                     # the clearing
	[34550.0, 0.92], [41350.0, 0.92],   # the caves: near black
	[41600.0, 0.88], [44800.0, 0.88]]   # the Root Hollows: lit by what lives there


## ---------------------------------------------------------------- the shop
## The economy. Prices are worked out from how much treasure the level holds
## (_treasure_total), so that a player who finds about 60% of it can buy
## exactly one new weapon, one new costume and three roast figs:
##     axe 26%  +  a costume ~19%  +  3 figs x 4%   =  57%
## The upgrades are extra, for the ones who search every corner. Move or add
## treasure and the prices follow on their own.
const ECONOMY := {"axe": 0.26, "wolf_hood": 0.16, "ember_paint": 0.18, "bear_cloak": 0.21, "firekeeper": 0.20,
	"fig": 0.04, "heart": 0.18, "torch": 0.11, "pouch": 0.11}


## ---------------------------------------------------------------- exploring
## More sky lanes, going UP from places he can already reach â with jellies to
## bounce on, rays to ride, a cache and a rare find at the top. Their own ids
## ("k2_%d" shells, "sc2_%d" caches): SKY_LANES above must never change.
##   start  where the lane begins (the top of something he already stands on)
##   rocks  [x, top, w, flags]     flags: 2 = a lamp island
##   jellies [x, y, look, drift]   rays [x0, x1, y, seconds to cross]
##   relic  [x, y, kind, id]       (ids "r0", "r1"... shared by every rare find)
const SKY_LANES_2 := [
	{
		"name": "Moon Garden",            # on up from the Moonstep Road, over the wolf hollow
		"start": [1865.0, 70.0],
		"rocks": [[2010.0, -40.0, 120.0, 0], [2340.0, -240.0, 150.0, 0], [2560.0, -310.0, 110.0, 0], [2760.0, -400.0, 200.0, 2],
			[3700.0, -200.0, 140.0, 0], [3900.0, -60.0, 110.0, 0], [4060.0, 110.0, 110.0, 0]],
		"jellies": [[2240.0, 30.0, 0, 0.0], [3260.0, -150.0, 1, 30.0]],
		"rays": [[3060.0, 3580.0, -330.0, 6.0]],
		"cache": [3, ["shell", "shell", "shell", "conch", "shell", "bone", "bone"]],
		"relic": [2905.0, -445.0, "moonstone", "r0"],
		"note": [1700.0, "Above the Moonstep... a JELLYFISH? In the sky?", 5.0],
	},
	{
		"name": "Firefly Bridge",         # a high road over the Tar Pits, off a bloom by the graveyard
		"pad": [15760.0, 600.0],
		"start": [15760.0, 600.0],
		"rocks": [[15860.0, 250.0, 140.0, 0], [16090.0, 180.0, 110.0, 0], [16390.0, 10.0, 120.0, 0], [16720.0, -50.0, 150.0, 2],
			[17410.0, 60.0, 120.0, 0], [17600.0, 250.0, 120.0, 0]],
		"jellies": [[16310.0, 260.0, 2, 0.0]],
		"rays": [[16950.0, 17300.0, -40.0, 5.0]],
		"cache": [3, ["shell", "shell", "conch", "shell", "shell", "bone"]],
		"relic": [16795.0, -95.0, "star_shard", "r1"],
		"note": [15680.0, "A bloom by the tar... and lights high over it.", 4.5],
	},
	{
		"name": "Feather Peaks",          # the very top of the world, off the great tree's crown
		"start": [23545.0, -408.0],
		"rocks": [[23720.0, -520.0, 120.0, 0], [24060.0, -700.0, 150.0, 2], [24280.0, -640.0, 110.0, 0], [24470.0, -600.0, 210.0, 2],
			[25330.0, -400.0, 130.0, 0], [25540.0, -240.0, 120.0, 0]],
		"jellies": [[23940.0, -420.0, 1, 0.0]],
		"rays": [[24760.0, 25240.0, -520.0, 6.0]],
		"cache": [3, ["shell", "shell", "conch", "conch", "shell", "tusk", "bone"]],
		"relic": [24600.0, -645.0, "giant_feather", "r2"],
		"note": [23400.0, "Higher than the crown? Something soft is floating up there.", 5.0],
	},
]

## ---------------------------------------------------------------- underground
## Under the Steppe graveyard and the Tar Pits, right below the ground he walks
## on: no doors, the world just goes on down.
##   The Dig     a column of earth in the graveyard ground (x 14870-11890).
##               Its crust is baked hard: a MEGA STOMP breaks it. Then DOWN +
##               HIT digs down, HIT digs ahead; stones take three blows; packed
##               CLAY near the bottom needs the SHOVEL. The Sun Stone (SUNFIRE)
##               sits in a hollow halfway down. Under the clay it breaks through
##               into the Root Hollows' first hall.
##   The den     off the shaft, behind bones and claw marks in the wall: dig
##               sideways, and the rocks fall in behind him â THE GULPER.
##   The Root Hollows  the halls under the Tar Pits.
##   Updrafts    two chimneys of warm, rising air float him back up to the
##               ground: one beside the shaft (the root tunnel above the clay
##               leads into it), one at the Hollows' far end (up at the creek).
const UNDER := Rect2(14300, 840, 3700, 1560)       ## everything down here (camera, darkness, no "fell")
const DIG_GRID := [14870.0, 600.0, 8, 27]          ## [x, y, columns, rows] of 40-px blocks; row 0 is the crust
const DIG_POCKET := [15, 16, 2, 5]                 ## rows 15-16, columns 2-5: the Sun Stone's hollow
const DIG_CLAY := [21, 22]                         ## rows of packed clay
const DIG_LOOT := ["shell", "shell", "shell", "conch", "shell", "shell", "tusk", "shell", "conch", "shell"]   ## ids "dg0"...
const DEN_PASSAGE := [15190.0, 1080.0, 3, 2]       ## a short dig sideways, off the shaft, into the den
const DEN := Rect2(15310, 880, 550, 280)           ## THE GULPER's den
const UNDER_ROCK := [                               ## [x, y, w, h, kind]
	[14300.0, 840.0, 300.0, 660.0, "wall"],                                          # under the ground, west of the updraft
	[14780.0, 840.0, 90.0, 510.0, "wall"], [14780.0, 1450.0, 90.0, 50.0, "wall"],     # between the updraft and the shaft (the root tunnel in between)
	[15190.0, 840.0, 120.0, 240.0, "wall"], [15190.0, 1160.0, 120.0, 340.0, "wall"],  # round the passage to the den
	[15310.0, 840.0, 770.0, 40.0, "roof"], [15310.0, 1160.0, 770.0, 340.0, "floor"], [15860.0, 880.0, 220.0, 280.0, "wall"],
	[16080.0, 840.0, 1400.0, 660.0, "wall"],                                         # under the tar
	[17600.0, 840.0, 40.0, 660.0, "wall"], [17640.0, 840.0, 310.0, 660.0, "wall"],    # under the creek, east of its updraft
	# the Root Hollows
	[14600.0, 2050.0, 800.0, 250.0, "floor"],
	[15020.0, 1940.0, 110.0, 22.0, "floor"], [15180.0, 1820.0, 130.0, 22.0, "floor"],   # up to the amber nook
	[15400.0, 2130.0, 300.0, 170.0, "floor"],                                          # a step down; then a pit
	[15820.0, 2130.0, 380.0, 170.0, "floor"],                                          # under the glow-worms
	[16200.0, 2090.0, 700.0, 210.0, "floor"],                                          # the angler's hall
	[16900.0, 2050.0, 400.0, 250.0, "floor"],                                          # the snail's garden
	[17300.0, 1990.0, 300.0, 310.0, "floor"],                                          # the far end: the second updraft
	[14780.0, 1500.0, 90.0, 160.0, "roof"], [15190.0, 1500.0, 2290.0, 160.0, "roof"],
	[15190.0, 1660.0, 120.0, 80.0, "roof"],
	[16350.0, 1660.0, 420.0, 150.0, "roof"],                                           # low: the angler hides in it
	[14560.0, 1500.0, 40.0, 800.0, "wall"], [17580.0, 1500.0, 40.0, 800.0, "wall"],
]
const UPDRAFTS := [[14600.0, 14780.0, 520.0, 2050.0], [17480.0, 17580.0, 520.0, 1990.0]]   ## [x0, x1, top, bottom]
const LIDS := [[14600.0, 180.0], [17480.0, 120.0]]   ## root mats over the updrafts, on the ground: [x, width]
const DEEP_WORMS := [[15200.0, 1740.0, 110.0, 200.0], [15840.0, 1660.0, 340.0, 465.0]]   ## [x, roof y, width, reach]
const DEEP_ANGLER := [16560.0, 1810.0, 230.0]       ## [x, roof y, how far its lure hangs]
const DEEP_SNAIL := [16940.0, 17260.0, 2050.0]      ## [from x, to x, floor y]; it carries "r3"
const DEEP_RELICS := [[15245.0, 1790.0, "amber_bug", "r4"], [16840.0, 2050.0, "ivory", "r5"]]
const DEEP_LOOT := [                                ## [x, y, kind]; ids "u0", "u1"...
	[14820.0, 2020.0, "shell"], [14900.0, 2020.0, "shell"], [15075.0, 1910.0, "shell"], [15230.0, 1790.0, "conch"],
	[15500.0, 2100.0, "shell"], [15760.0, 2050.0, "shell"], [15900.0, 2100.0, "bone"], [16100.0, 2100.0, "shell"],
	[16300.0, 2060.0, "shell"], [16700.0, 2060.0, "conch"], [17000.0, 2020.0, "shell"], [17200.0, 2020.0, "shell"],
	[17450.0, 1960.0, "bone"],
]

## The windy heights: up from the Moon Garden, before the gorge's first rope.
## Gusts blow here (only up in the sky); at the top, the bramble with the
## SHOVEL in it â only SUNFIRE burns it, and SUNFIRE is found in the Dig.
const WINDY_ROCKS := [[3560.0, -260.0, 110.0, 0], [3760.0, -400.0, 120.0, 0], [3600.0, -530.0, 100.0, 0], [3850.0, -640.0, 180.0, 2]]
const WINDY_JELLY := [3470.0, -170.0, 2, 0.0]     ## under the ray's flight; it bounces him up toward the top rocks
const WINDY_WIND := [3420.0, 4150.0, -800.0, -230.0, -240.0]   ## [x0, x1, y0, y1, strength]: not down on the Moon Garden rock below
const BRAMBLE_AT := Vector2(3940, -640)

## ---------------------------------------------------------------- inside the mountain
## (MOUNTAIN_MAP). Floors and roofs are found from the terrain itself, so
## these only need an x and a rough y near the right floor/roof.
## The rooms, each announced the first time he steps in: [rect, title, line].
const MT_ROOMS := [
	[Rect2(6290, 540, 420, 260), "THE CRYSTAL GROTTO", "the mountain's heart glitters in the dark"],
	[Rect2(6780, 420, 470, 230), "THE BONE HALL", "something huge came here to die"],
	[Rect2(6680, 790, 410, 230), "THE PAINTED CAVE", "the old ones were here, long ago"],
	[Rect2(11340, 510, 360, 200), "THE GLOW HOLLOW", "mind the sticky threads"],
	[Rect2(8160, 500, 800, 330), "THE GREAT CAVERN", "bounce on the glowcaps to reach the high ledge"],
	[Rect2(8300, 960, 440, 140), "THE DEEP HOLLOW", "down where the old bones sleep"],
	[Rect2(9320, 300, 440, 210), "THE SLEEPING HALL", "shhh... the dead are sleeping"],
	[Rect2(9770, -420, 100, 720), "THE EAGLE SHAFT", "kick wall to wall, all the way to the High Peak"],
	[Rect2(7290, -250, 100, 860), "THE CHIMNEY", "wall to wall — up, up, UP!"],
]
## Crystals: [x, near y, on the roof?, tint (TINTS)].
const MT_CRYSTALS := [
	[6380.0, 740.0, false, 0], [6470.0, 600.0, true, 0], [6580.0, 760.0, false, 1], [6640.0, 620.0, true, 0],
	[6320.0, 640.0, true, 1], [11440.0, 690.0, false, 0], [11600.0, 690.0, false, 1],
	[8300.0, 520.0, true, 2], [8560.0, 500.0, true, 0], [8820.0, 520.0, true, 1], [8440.0, 830.0, false, 2],   # the Great Cavern
	[8420.0, 1080.0, false, 1], [8640.0, 1080.0, false, 3],                                                     # the Deep Hollow
]
const MT_SKELETON := [6990.0, 620.0, 0.85]            ## [x, near floor y, size]: the Bone Hall
const MT_PAINT := [6880.0, 980.0]                    ## [x, near floor y]: the Painted Cave's wall
const MT_WORMS := [[11520.0, 510.0, 150.0, 120.0]]   ## [x, near roof y, width, reach]: Glow Hollow
## No bats in the mountain (they live in the caves). Its tunnels have CAVE WORMS
## (harmless; a bonk and they drop a roasted grub: food) and RISEN SKELETONS (a heap
## of bones that rattles back together when he comes near; gets up once more).
## [x, near floor y, left x, right x] (Mountain.CaveWorm, Mountain.RisenSkeleton).
const MT_CAVEWORMS := [[6450.0, 760.0, 6330.0, 6650.0], [6850.0, 980.0, 6720.0, 7050.0], [8450.0, 830.0, 8250.0, 8650.0],
	[11500.0, 660.0, 11380.0, 11660.0]]
const MT_SKELETONS := [[7130.0, 620.0, 6820.0, 7230.0], [8600.0, 1080.0, 8330.0, 8720.0], [9450.0, 520.0, 9340.0, 9740.0],
	[9650.0, 520.0, 9340.0, 9740.0]]
const MT_RELICS := [[6860.0, 620.0, "bear_fang", "r6"], [7000.0, 980.0, "red_ochre", "r7"]]
## Two small chests hidden deep in the mountain: [x, near floor y, contents, id]. Three
## whacks and a fountain of loot, and a VERY rare relic in each ("relic:<kind>:<id>").
## A bonus for exploring, like the buried finds: NOT counted in the shop prices.
## One in the far corner of THE DEEP HOLLOW, one at the back of THE BAT ROOST.
const MT_CHESTS := [
	[8330.0, 1080.0, ["amber", "conch", "conch", "shell", "shell", "shell", "shell", "shell", "relic:thunder_egg:r11"], "ch0"],
	[9740.0, 515.0, ["amber", "conch", "conch", "shell", "shell", "shell", "shell", "shell", "relic:golden_horn:r12"], "ch1"],
]
## Finds: [x, y, kind, on the floor?]; ids "mt0", "mt1"... (never insert, only append)
const MT_LOOT := [
	[6060.0, 760.0, "shell", true], [6140.0, 760.0, "shell", true], [6220.0, 760.0, "shell", true],      # Echo Tunnel
	[6420.0, 740.0, "shell", true], [6520.0, 740.0, "conch", true], [6620.0, 760.0, "shell", true],      # the grotto
	[6920.0, 620.0, "bone", true], [7060.0, 620.0, "shell", true], [7200.0, 620.0, "tusk", true],       # the Bone Hall
	[7340.0, 300.0, "shell", false], [7340.0, 120.0, "shell", false], [7340.0, -80.0, "conch", false], # up the Chimney
	[6780.0, 980.0, "shell", true], [6960.0, 980.0, "shell", true],                                       # the Painted Cave
	[11420.0, 690.0, "shell", true], [11560.0, 690.0, "conch", true], [11620.0, 690.0, "shell", true],   # Glow Hollow
	[8300.0, 830.0, "shell", true], [8420.0, 830.0, "shell", true], [8700.0, 830.0, "bone", true],       # the Great Cavern
	[8880.0, 700.0, "conch", false],                                                                    # on its high ledge
	[8460.0, 1080.0, "tusk", true], [8580.0, 1080.0, "shell", true],                                     # the Deep Hollow
	[9440.0, 500.0, "shell", true], [9680.0, 500.0, "shell", true],                                      # the Bat Roost
	[9820.0, 120.0, "shell", false], [9820.0, -100.0, "shell", false], [9820.0, -300.0, "conch", false], # up the Eagle Shaft
	[10000.0, -460.0, "shell", false], [10120.0, -460.0, "shell", false],                                # on the High Peak
]
const MT_LIDS := [[7262.0, -268.0, 152.0], [9742.0, -428.0, 152.0]]   ## [x, y, width]: root mats over the Chimney (summit) and the Eagle Shaft (High Peak)
## THE CHIMNEY: [left face x, right face x, top y, bottom y]: its two walls are kick walls.
const MT_CHIMNEY := [7300.0, 7380.0, -262.0, 478.0]
const MT_CHIMNEY2 := [9780.0, 9860.0, -422.0, 278.0]  ## THE EAGLE SHAFT, from the Bat Roost up to the High Peak
const MT_CAPS := [[8320.0, 830.0, 0], [8800.0, 830.0, 1], [9820.0, 540.0, 2]]   ## glowcaps: two in the Great Cavern, one under the Eagle Shaft (bounce up into it): [x, near floor y, tint]
## Buried finds (dug out of the rock; not counted in the shop's prices): how many of each,
## and the rare ones deep in the strata. Placed by a seeded roll over the map (ids "mb%d").
const MT_BURIED := {"shell": 40, "bone": 10, "conch": 8, "tusk": 4}
const MT_BURIED_RARE := [["moonstone", "r8"], ["glow_crystal", "r9"], ["star_shard", "r10"]]
