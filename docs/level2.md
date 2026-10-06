# Level 2 "Discovery of Fire": the map

x in px; ground y 600; `LEVEL_W` 33600. Coordinates live in `level2/level2_data.gd`.

## Along the level
| x | Stretch |
|---|---|
| 0–3980 | Firelit woods: camp, wolves, the hollow pack ("This is what fire is for") |
| 3980–5680 | Hanging Gorge: vines from the fallen giant (walkable; stomp it to scare Moss and shake loot loose) |
| 5640–12080 | THE MOUNTAIN (a diggable Terrain) + wind + Moonpuffs |
| 12050–15900 | Mammoth Steppe: split-rock chimney 12450–13000, herd 13200–13660, river 13800–14300 (wading bull), mammoth graveyard |
| 15900–17480 | Tar Pits: three pools, sinking logs |
| 17480–17900 | Nutmeg's creek |
| 17950–22900 | Thunder Canyon: Sky Stones (flying rocks with vines), rest ledge + bonfire, floating rocks with diving bats, the Weeping Cave's mouth at 22900 |
| 23050 | The great tree, Old Bongo (key quest) |
| ~23700–26500 | The far side |
| 26500–28500 | Boulder Run |
| 28600–30700 | Long Dark (torch snuffed at 28650) |
| 30700–32300 | Toolmaker's home, Three Fires trial |
| 32300–33600 | Old Scar |

Sky lanes (`SKY_LANES`): Moonstep Road 800–1950, Mammoth Sky 12920–14770 (bloom on the clifftop),
Silver Stair 24910–26390, Starlit Road 28780–30770. Higher lanes (`SKY_LANES_2`): Moon Garden (up from the
Moonstep Road; its last island is right over the fallen giant), Firefly Bridge (over the Tar Pits), Feather
Peaks (off the great tree's crown).

Caves are separate regions: Weeping Cave `CAVE_A` 34600–37970 (Hall of stalactites, nursery, Glowcap Chasm,
cocoon chamber); Rattling Cave `CAVE_B` 38400–41240 (crawl tunnel, Stampede Alley, Rattle Pit, Rockfall Run,
old hearth, hoard).

## Ambushes (`AMBUSHES`; danger tier from x)
After the hollow 3420–3950 (1) · Great Cavern 8350–8750 (2) · Steppe start 12090–12440 (2) ·
graveyard 15250–15900 (3) · far side 25400–26300 (4) · before the Long Dark 28420–28880 (5).

## The mountain (x 5640–12080)
Outside, the climb: crevice 720, shelf 280, ledges 160 and 80, dead-tree shelf −40, ledge −160, summit −280,
lookout −480; Moonpuff steps −160 / 80 / 320. The High Peak is at −440.
Inside (`MT_*` tables, `_build_mountain_inside`): Echo Tunnel from the crevice floor → Crystal Grotto → Bone
Hall (CAVE BEAR FANG r6) → THE CHIMNEY (wall-kick, `MT_CHIMNEY`) up through a root mat onto the summit. The
Painted Cave is below the grotto (RED OCHRE r7); a long tunnel east from it joins the Great Cavern. East half:
the saddle's cave mouth → THE GREAT CAVERN (glowcaps) → down to THE DEEP HOLLOW (chest ch0, THUNDER EGG r11);
east up to THE SLEEPING HALL (chest ch1, GOLDEN HORN r12) → THE EAGLE SHAFT (`MT_CHIMNEY2`) up to the High
Peak; a long gallery to THE GLOW HOLLOW, out onto the east slope. Rooms: `MT_ROOMS` (title card once each).
Cave worms (`MT_CAVEWORMS`) and risen skeletons (`MT_SKELETONS`; they guard both chests). Buried finds
`MT_BURIED`, rare relics r8–r10 deep in the strata (`MT_BURIED_RARE`).

## The underground (in place, no regions)
`UNDER`: x 11000–14700, y 840–2400, under the graveyard and the Tar Pits; the camera limit and `fall_y` drop
there (`_update_under`), and it darkens with depth. The Dig: a column in the graveyard ground (`DIG_GRID`;
row 0 is a crust only a MEGA stomp on the Burrow mound opens). Dirt 1 blow, stone 3, packed clay only with
the shovel. The Sun Stone halfway down teaches SUNFIRE. Under the clay: the Root Hollows (`DEEP*`, floors
y ~2000–2130). Back up: updraft chimneys under one-way root mats. THE GULPER's den: dig sideways off the
shaft; the seal shuts, the Gulper swims under the floor and bursts out under him, then sticks (6 hits only
while stuck); beaten, it leaves its teeth (item "gulper_teeth").

## The shovel mystery
Opens at the clay's first CLANG. Clues: the painting on the shaft wall by the clay; Moss (wakes once with the
clue); a glint in the bramble up the windy heights over the Moon Garden (it only burns under SUNFIRE).
Solved when the shovel is picked up.

## Mystery ideas not yet built
The Lost Cub (recommended), Painted Cave, Falling Star, Whispering Totems.

## Lane ideas not yet built
Tar Pits, Mammoth Ride, River Log Ride.
