# The Shelter: Ugu's Island, through the ages

Jawad's brief (2026-10-09): the most fantastic shelter ever, unique, creative, fun and interactive. In every
level Ugu evolves it with that level's resources. A store with a seller with unique attributes (stones,
diamonds, resources), a closet for clothes, a blacksmith for weapons, and more. Some levels are more
advanced civilisations (Level 6: the industrial revolution), so what we build must evolve. The inventory
rules (`docs/inventory_plan.md`) feed it: nothing looted is junk; the shelter is the forever-sink.

## Decisions so far
- **A 3D "paper diorama"** (Jawad liked the prototype, `shelter/proto.tscn`): the island and buildings are
  low-poly 3D built from shapes in code; Ugu, the friends, Kekko and the animals stay 2D paper cut-outs
  (their real 2D rigs drawn into a SubViewport on a billboard). A fixed tilted camera: kids never steer it.
  The levels stay 2D.
- **It must be BIG**: room for a steam-age town by Level 6.
- **Getting there (Jawad, 2026-10-09)**: the cave is reached from the CAMP MENU (its SHELTER row), unlocked once
  Level 2 is finished; until then the row stays locked. The eras are `docs/eras.md` (Ugu the Unbowed).
- **Horses**: in their own age (Farming); before that a mammoth calf.

## The ages (proposed; one per level)
| level | age | the big new thing |
|---|---|---|
| 1 | Raw Stone | a cave |
| 2 | Fire | the hearth, hides |
| 3 | The Hunt | spears, bows, traps |
| 4 | Farming & taming | fields, horses, pottery |
| 5 | Metal & kingdoms | bronze, then iron; stone walls, castles |
| 6 | Industrial revolution | steam, coal, rails, factories |

## The island grows with history
In the Stone Age only the village is open; the rest is wild, under MIST. Each age clears more land and opens
new DISTRICTS, and the old buildings are rebuilt in the new age's style. By Level 6 it is about four times
the Stone Age's size: a steam-age town on the same island.
Districts: the VILLAGE (the plaza), the FARM VALLEY (east), the QUARRY HILL (north-west; later the mine),
the HARBOUR BAY (south), the LIGHTHOUSE CAPE (north-east), the PARK of the Spirit Tree.

## "Same spot, new age": the building ladders
Each building is ONE spot with a ladder of looks, a rung per age. A rung costs that age's new material plus
older ones (old loot stays valuable); its perk is added to the old ones, never lost. In code: one table per
building, age -> [cost, look builder, perk]; a new level adds rows, not a new shelter.

| building | Stone / Fire | Hunt / Farming / Metal | Level 6: Industrial |
|---|---|---|---|
| HOME | cave -> hide hut of bones | longhouse -> stone house | a brick MANSION with a workshop: Ugu the inventor (the cave is its cellar) |
| HEARTH | campfire | clay oven -> kiln | a STEAM BOILER that powers the town |
| KEKKO'S | a log table with gems | a market of stalls | a DEPARTMENT STORE / trading house |
| BLACKSMITH | the Toolmaker's anvil stone | bronze -> iron smithy | a FOUNDRY and FACTORY: makes goods between levels |
| CLOSET | hides on a rack | a weaver's loom | a TAILOR'S: suits, goggles, explorer coats |
| TRAVEL | a mammoth calf | horses -> a carriage | a STEAM TRAIN round the island and a station (fast travel) |
| FARM | berry bushes | fields, a windmill | a steam tractor, a greenhouse |
| QUARRY / MINE | a dig spot | a copper, then iron mine | a COAL MINE with rails and carts |
| HARBOUR | a raft | a canoe -> a sailboat | a STEAMSHIP: sail to new islands (bonus places) |
| LOOKOUT | a tree perch | a watchtower | a LIGHTHOUSE with a turning lamp, a telescope for mysteries |
| TROPHY HALL | a trophy wall | a hall of relics | a MUSEUM of every age |
| PAINTED WALL | cave paintings | carved stones, tapestries | newspaper front pages of Ugu's adventures |
| SPIRIT TREE | a sapling | a great tree | still there in the town park: the one thing that never changes |

## The people
- **KEKKO the Pebble Merchant** (the store): tiny, very old, a pack bigger than himself, a cheeky monkey who
  bites every coin. Sells rare stones, gems and diamonds; buys what's spare; prices change with the moon; a
  riddle answered = a discount; once per age one LEGENDARY thing. He is the Collector too (one precious
  for two of another). By Level 6, a rich old tycoon in a top hat, the same monkey.
- **The village of friends**: everyone Ugu helps in a level moves to the island and runs something: Ooma
  the hearth, the Toolmaker the smithy, Pip the goats and later the farm, Taka the training ground, Shivers
  the lookout, Bongo the market's fruit. They grow up with the ages (by Level 6: workers, an engineer, a
  train driver).
- **The pets and mounts**: the lost pup (sniffs out precious stones), the mammoth calf -> the horse.

## What the resources are for
Building and upgrading the ladders; Kekko's trades; COOKING at the hearth (a meal = a buff for the next
level: +1 heart, a longer torch, faster digging); PLANTING (seeds -> berries, later crops); feeding and raising
the pet and the mount; the friends' requests (a board by the plaza); decorating (relics, shells, trophies);
the Spirit Tree (spirit orbs: permanent upgrades); and in the industrial age the FACTORY turning raw
resources into goods while he is away.

## Life on the island
- It answers the last level: after the fire level Ooma has lit torches everywhere; after a storm the roof
  needs mending.
- Small things to do at home: fishing off the pier, digging the quarry, a race on the mount, the training
  ground, hide-and-seek mysteries.
- Coming home after a level: the CAMPFIRE SORT (the inventory plan) packs the level's leftovers into the
  stockpile, the factory hands over what it made, and a friend has news.

## Build order
1. **Prototype, bigger** (now): the island with its districts under mist, and an AGE SWITCH (1 / 2 / 3:
   Stone, Farming, Industrial) to judge the evolution. Not wired into the game.
2. The real Stone Age shelter: Kekko and Shivers as cut-outs, building and upgrading with real resources
   (`GameState.home`, the stockpile), the hearth's cooking, the closet, the mammoth calf; reached from the
   Camp Menu's SHELTER and between levels.
3. Each new level: its age's rungs, its new district, its new friends.
