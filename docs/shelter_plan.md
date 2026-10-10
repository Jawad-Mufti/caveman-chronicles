# The Shelter: Ugu's Cave, the home of the Unbowed

Jawad's brief (2026-10-09): the most fantastic shelter ever, unique, creative, fun and interactive; in every
level Ugu evolves it with that level's resources; a store with a seller with unique attributes (stones,
diamonds, resources), a closet for clothes, a blacksmith for weapons. The eras are `docs/eras.md` (Ugu the
Unbowed: every era tries to civilize him and fails) and the weapons `docs/weapons.md`. The inventory rules
(`docs/inventory_plan.md`) feed it: nothing looted is junk; the shelter is the forever-sink.

## Decisions (Jawad, 2026-10-09)
- **Home: Ugu's Cave** (eras.md): his shelter, built from mammoth bones; build and upgrade with bones; his
  wife, a pet, storage; trophies from each era appear here. It never becomes a town: Ugu is UNBOWED.
- **What comes home from every era: looted COSTUMES, UPGRADED SHOPS, and ARTIFACTS.**
- **A 3D "paper diorama"**: the cave and its grounds low-poly 3D built from shapes in code; Kekko, the
  blacksmith and the animals are 2D paper cut-outs. A camera that follows him. The levels stay 2D.
- **Ugu at home** (2026-10-10): Jawad asked for a real 3D Ugu ("make it 3d"), then for him to look EXACTLY
  like the 2D Ugu. Two ways, both built to the design sheet (`docs/caveman_design.png`):
  - `shelter/ugu3d.gd`, the 3D figure: one smooth head mesh (skull, brow ridge, squared jaw, chin), the
    beard and the hair cap as shells of that head cut along smooth curves, the mane's spikes, a tunic shell
    cut on the diagonal with a light-fur trim, every loose piece moving in the air. REBUILT 2026-10-10
    ("exactly like in 2D but in 3D, a bit taller, freer movement"): the face placed from the 2D rig's own
    numbers, toon-shaded with rims in darker tones, his 2D moods; in the home he speeds up and slows down,
    slides along things, runs flat out on Shift, jumps twice (a somersault), squashes on landing, looks at
    what he is next to, grins when he buys something.
  - `shelter/ugu_paper.gd`, the paper cut-out: the real 2D rig (CaveMan) drawn into a SubViewport and shown
    on a billboard. Identical by construction: every expression, the air, costumes, future changes; flat
    seen from the side. Same interface as the figure (`speed`, `air`, `era`, `refresh()`).
  Jawad picks; until then **P** in the home swaps them live (`home.swap_ugu`; shots: `home.tscn -- shot paper`
  writes `home_paper_*`). Both cost about the same there (~9.3 ms frame; the figure is ~650 draw calls, the
  paper one is CPU: the 2D rig's picture).
- **Ugga**, his wife (blonde), comes next, in the same style, 2D and 3D.
- **Getting there**: from the CAMP MENU (its SHELTER row), unlocked once Level 2 is finished.
- v1 = Levels 1-3 + this home (eras.md).

## The cave itself
Mammoth bones and hides, a fire at its heart, the time rift glowing in the back. It GROWS with bones (more
chambers, a bigger bone frame, a hot spring, a store room) AND it is UPGRADED every era (Jawad, 2026-10-09):
each era's tech is bolted on, Ugu-style, but it always stays a CAVE: a drawbridge over a cave mouth, steam
pipes through the rock, a neon sign on a skull. It never turns into a house or a town.
Whatever history Ugu drags home, he uses HIS way (below), so the cave gets funnier with every era, never tidier.

## 1. COSTUMES (the closet)
Every era's costume gag (eras.md) is looted and hangs in the closet: a bone rack that grows a hook per era.
He can wear any of them anywhere (they show on his rig in the levels too); a small perk each is optional.

## 2. SHOPS that upgrade with every era
- **KEKKO the Pebble Merchant** (the store): tiny, very old, a pack bigger than himself, a cheeky monkey who
  bites every coin; prices change with the moon; a riddle answered = a discount; once per era one LEGENDARY
  thing; he is the Collector too (one precious for two of another). He follows Ugu through time, and his
  stall upgrades each era: its look and its wares.
- **THE BLACKSMITH** (weapons): the one-armed Toolmaker, then his descendant in each era (eras.md), forging
  the level's gem into its special weapon (weapons.md) and upgrading what Ugu carries. The forge upgrades
  each era.
- Both cost that era's resources (and older ones) to upgrade: the inventory plan's sink.

## 3. ARTIFACTS (the trophy chamber)
One artifact per era, plus the boss trophies and the gems, displayed in the cave, each with a perk, and
most of them USED caveman-style. The joke grows with history.

## Era by era (what comes home)
| # | era | the CAVE gets... | costume (closet) | Kekko's stall becomes... | the forge becomes... | artifact (and how Ugu uses it) |
|---|---|---|---|---|---|---|
| 1 | Raw Stone | a fire pit and a bed of leaves | leaf loincloth | a log table of pebbles | the Toolmaker's anvil stone | Tuskar's tusk: the coat hook |
| 2 | Fire | a hide curtain over the mouth, a bone frame | fur tunic over one shoulder (the design sheet) | gems on a hide | the Firestone forge pit | Old Scar's skull: the fire guard |
| 3 | Ice Age | a mammoth-bone hut built into the mouth (Mezhyrich), a hot spring | thick fur coat + hair tie | furs, ivory, amber | a forge of bone and ice | Gorrak's tusks: an arch over the cave mouth |
| 4 | First Farmers | a mud-brick front, a ladder entrance through the roof (Çatalhöyük), a little garden | woven-reed headband | seeds, pots, grain | a mud-brick kiln | a carved stone pillar (Göbekli Tepe): his back-scratcher |
| 5 | River Kingdom | a carved stone doorway, two columns, hieroglyph doodles of Ugu | pharaoh headdress | papyrus, scarabs, perfumes | a bronze workshop | a sarcophagus: his BATHTUB |
| 6 | The Arena | an arch, a mosaic floor of Ugu clubbing a lion, an aqueduct filling the hot spring | sandals + laurel wreath | coins, amphorae | a Roman fabrica | a chariot: the wheelbarrow |
| 7 | Castle Siege | a drawbridge over the cave mouth, a tower of stones on top, banners | knight's helmet, too small | a fair tent | a castle forge with bellows | a knight's helmet: the cooking pot |
| 8 | High Seas | a ship's figurehead over the door, sails as curtains, a crow's nest lookout | pirate hat + parrot "UGU!" | spices and maps | a ship's forge | a cannon: the SHOWER (it fires water) |
| 9 | Steam & Smoke | steam pipes through the rock, a lift (elevator) to the lookout, furnace heating | hard hat + soot goggles | gadgets and gears | a steam forge | a train wheel: the dinner table |
| 10 | Concrete Jungle | electric light bulbs, a satellite dish, a neon sign: UGU | sunglasses + hoodie | a vending machine | a garage workshop | a traffic light: the night lamp |
| 11 | Neon Grid | a hologram door, a robot butler (that Ugu ignores) | VR visor | a hologram stall | a fabricator | a robot vacuum: the pet's ride |
| 12 | The Collapse | overgrown again: vines through everything, back to the wild | the leaf loincloth again | barter in the ruins | every forge in one | the Colossus' core: the hearth stone, full circle |

## The people
- **His wife**: rolls her eyes at every new "treasure", runs the home; her requests use resources.
- **The pet**: sleeps on the latest artifact; later sniffs out precious stones in the levels.
- **Kekko** and **the blacksmith** (above).
- (Optional, later: friends from the levels visiting.)

## What the resources are for
Upgrading the cave (bones), Kekko's and the forge (each era's resources plus older ones), Kekko's trades,
COOKING at the fire (a meal = a buff for the next level: +1 heart, a longer torch, faster digging), the
wife's requests, the pet, displaying artifacts and relics, the Spirit Tree / orbs (permanent upgrades).
Coming home after a level: the CAMPFIRE SORT (the inventory plan) packs the level's leftovers into storage.

## Build order
The rule (Jawad, 2026-10-09): the shelter grows WITH the game. After each level is finished, its era is added to
the home (the cave upgrade, the costume, the shops, the artifact), then the next level starts. No era is
built into the home before its level exists.
1. DONE (d038ac1 .. e255b9c): the home for eras 1-2, `shelter/home.tscn` (`home.gd`), reached from the Camp
   Menu after Level 2 (Esc returns where he stood): an island with shader water, wind, day and night, trees
   that fade in front of him; the bone cave and fire, the closet (costumes) and the weapon rack, Kekko's
   stall (buy / sell), the Toolmaker (upgrades), the workbench (crafting from the bag), the store corner,
   the bed (night to day, saves), fishing at the pier and cooking at the fire, the pup that fetches.
   Tests: `homeflow`, `homeuse`; cost: `homecost`.
2. NOW: Ugu at home to the design sheet (above), then Ugga.
3. The rest of v1 (era 3): upgrading with real resources (`GameState.home`, storage), the artifacts.
4. Each new level: its costume, its shop upgrades, its artifact.
