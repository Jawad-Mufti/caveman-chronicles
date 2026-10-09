# The Bag Through the Ages: the inventory plan

Jawad's brief (2026-10-09): everything Ugu loots must be useful, in this level, in the next ones, or in the
SHELTER. Never "I looted all that and lost it in the next level". Every level is a more advanced world, so
things must EVOLVE with him. Cheap things are easy to find; rare things are rare. Many mysteries and shelter
resources are coming.

## The promise: nothing is junk
Every item has at least one of three futures, and the bag SHOWS which (three small marks on its tooltip):
- **NOW** (a hand): a use in this level: a recipe, an errand, a mystery, a boss.
- **LATER** (an arrow): it EVOLVES in a later age: new recipes for old stuff. Before that age it reads
  "Later: ???" (a teaser: keep it!), after it, the real use.
- **HOME** (a hut): it builds or decorates the SHELTER, and every shelter part gives a perk in EVERY level.

## What is wrong today (the Level 2 audit)
| item | rarity shown | how it comes | used for now | after Level 2 |
|---|---|---|---|---|
| rocks | common | everywhere, every visit | throw, wall, windbreak | LOST (a level-only stack) |
| wood | common | dead trees, every visit | fire, ladder, windbreak | LOST (level-only stack) |
| berries | common | bushes, every visit | heal, salve, glare trap | LOST (level-only stack) |
| clay | common | 11 in the whole level, HIDDEN, no glint | salve, wall, trap, windbreak | kept, no use |
| flint | common | 10 in the whole level, HIDDEN, no glint | tips, spark, edge | kept, no use |
| fire-gold | uncommon | 5, hidden | spark kit, trap | kept, no use |
| quartz | uncommon | 5, hidden / Pip | lucky charm, trap | kept, no use |
| obsidian | rare | 5, hidden / errands | obsidian edge (2) | 3 left over, no use |
| bones | common | beasts, every visit | tips, ladder, edge; "the shelter" | kept, no shelter yet |
| figs, shells | | | heal; the shop | kept (fine) |
| spirit orbs | uncommon | beasts, every visit | "saved for upgrades" | NO SINK AT ALL yet |
| glare trap | rare | made | Old One-Eye only | useless once he is beaten |
| relics | rare / legendary | edges of the world | "kept for the shelter" | no shelter yet |

The problems:
1. **Level-only stacks vanish** (rocks, wood, berries) at the end of a level.
2. **Leftovers with no future**: spare obsidian, quartz, fire-gold; spare glare traps.
3. **Spirit orbs have no sink.**
4. **Cheap stones feel rare**: clay and flint are hidden, finite, invisible without the lucky charm. A kid
   digs for ages to find "just a rock". (Jawad: "some items look rare to find while they are only rocks".)
5. **Rarity colours don't follow effort**: quartz (hidden, 5 in the level) shows the same green as a fig.
6. **The shelter is promised but has no sink yet** (bones, relics).

## The rules
**R1. Four kinds of loot.**
- **MATERIALS** (common, white): rocks, wood, clay, flint, bones, berries; later fibre, hide, feathers,
  reeds. RENEWABLE every visit, VISIBLE, cheap. Carried up to a pouch cap; the rest "goes home".
- **PRECIOUS** (green to purple): fire-gold, quartz, obsidian; later amber, jade, copper, tin, iron, gold.
  FINITE per level, hidden (they glint only with the LUCKY CHARM), never wasted: each has a NOW use, a
  LATER evolution and a HOME use.
- **MADE** (tools and consumables): from recipes, carried forward. A level-only made thing (the glare
  trap) turns into a KEEPSAKE when its job is done.
- **KEEPSAKES** (relics, boss trophies): for the shelter, each with a perk; the legendary feel.

**R2. Rarity = effort**, and the colour says so:
| tier | colour | means | today |
|---|---|---|---|
| COMMON | white | every visit, out in the open, renewable | rocks, wood, clay, flint, bones, berries, shells, made-from-commons (tips, salve, wall, ladder), figs, torch, club |
| UNCOMMON | green | a few per level, a little hidden | fire-gold, spirit orbs, spark kit |
| RARE | blue | a handful per level, hidden or earned | quartz, flint axe, shovel, lucky charm, glare trap, moonstone-class relics |
| VERY RARE | purple | 1-3 per level, earned (errand, chest, boss) | obsidian, obsidian edge, the deep relics |
| LEGENDARY | gold | one per age, a story moment | the Firestone hammer, the thunder egg, the golden horn |

**R3. The CAMPFIRE SORT** (the end of every level, after the scroll): Ugu by the fire, packing up. Level-only
stacks are sorted, with a little tally and a sound per line:
- wood -> the shelter WOODPILE; rocks -> the STONE HEAP;
- berries -> dried into FIGS (2 berries = 1 fig, up to the pouch), the rest -> SEEDS for the garden;
- used-up quest things -> KEEPSAKES (spare glare traps -> one GLARE LAMP for the shelter).
"Sent home: 14 wood, 9 rocks, 3 seeds. Dried: 2 figs." Nothing lost, and it FEELS like a reward.

**R4. Pouch caps and "send it home"**: materials have a carry cap (the pouch upgrade raises it); past the
cap a pickup isn't refused: it flies off with a little "-> HOME" pop into the shelter stockpile. Looting is
never wasted, and the bag never becomes a junk drawer.

**R5. EVOLUTION, the Age Book**: each new age adds recipes that need OLD materials mixed with NEW ones, so a
stash from Level 2 is valuable in Level 5. Ugu "learns" a page at the start of each age (the Guide).

**R6. The SHELTER is the forever-sink**: every material builds a part; parts have tiers that later
materials upgrade; every part gives a perk in every level.

**R7. The bag tells the truth**: every tooltip shows NOW / LATER / HOME lines (data: `Bag.FUTURE`, a table
beside `Bag.ITEMS` so no row indexes change).

## The evolution ladder
Ages, one per level (proposed; the names are for fun):
L1 Raw Stone, L2 Fire, **L3 The Hunt** (the fang becomes a spear), **L4 The Herd** (taming, wool, milk),
**L5 The Potter** (kilns, fired clay, the first garden), **L6 The Smith** (copper, then bronze), and on.

| material | L2 Fire (now) | L3 Hunt | L4 Herd | L5 Potter | L6 Smith | HOME (shelter) |
|---|---|---|---|---|---|---|
| rocks | throw, wall | SLING stones (sling: hide + fibre) | pen walls | kiln base | anvil | foundations, hearth ring |
| wood | fire, ladder | spear shafts, the first BOW | fences, gates | kiln fuel | CHARCOAL (the forge's fuel) | woodpile, frame |
| clay | salve, wall, trap | water pots (carry water) | troughs | FIRED POTS, bricks | casting moulds | floor, oven |
| flint | tips, spark kit | SPEARHEADS, hide scrapers | wool shears | | forge sparker | tool rack |
| bones | tips, ladder, edge | NEEDLE (hide clothes), fish hooks | a FLUTE that calls animals | | | the frame (main) |
| berries | heal, salve, bait | BAIT for hunting traps | TREATS (taming!) | SEEDS -> the garden | | garden, larder |
| fire-gold | spark kit | FIRE SPEAR (burning tip) | | kiln lighter | SMELTING partner (copper ore) | the hearth that never dies |
| quartz | lucky charm | SUN LENS: start a fire anywhere | | GLAZE (shiny pots) | | window, sun-clock |
| obsidian | obsidian edge | OBSIDIAN SPEAR (the best) | | | mirror polish | OBSIDIAN MIRROR |
| shells | money | necklace trades | | | | wind-chime |
| spirit orbs | (no sink!) | the SPIRIT TREE: upgrades bought with orbs, every age | | | | spirit totems |
| relics | | | | | | trophy wall (each a perk) |
| glare trap | Old One-Eye | (beaten: -> a GLARE LAMP keepsake) | | | | lights the shelter |

Rule of thumb when making Level N: at least two recipes use Level N-1 materials, and one needs something
from two ages back. Each age adds 1-2 new commons and 1-2 new precious things, never more.

## The SHELTER (the home level): sinks and perks
Each part has a cost, a perk (in EVERY level) and tiers that later materials improve.
| part | cost (tier 1) | perk | later tiers |
|---|---|---|---|
| FRAME | 30 bones + 10 wood | the shelter exists; Ugu can rest (full hearts) | hide walls (L3), wool (L4) |
| HEARTH | 12 rocks + 4 clay + 1 fire-gold | every level starts with the torch full and one fig | bricks (L5): +1 fig |
| WOODPILE | any wood | every level starts with 2 wood | |
| STONE HEAP | any rocks | every level starts with 4 rocks | |
| DRYING RACK | 8 bones + 4 wood | at level end, berries dry into figs by themselves | |
| LARDER | figs | +1 fig pouch | fired pots (L5): +1 more |
| GARDEN | seeds (berries) | a berry bush near every level's start | |
| TOOL RACK | 6 flint + 4 bones | swap weapons at home; show off every tool found | |
| TROPHY WALL | relics, boss trophies | each relic a perk (below) | |
| PAINTED WALL | red ochre | every solved MYSTERY appears as a cave painting: the game's story book | |
| WINDOW | 3 quartz | morning light: +5 s of SUNFIRE | glaze (L5) |
| OBSIDIAN MIRROR | 2 obsidian | secret doors shimmer (like the charm, for rooms) | |
| SPIRIT TREE | spirit orbs | the orb shop: permanent upgrades | grows a branch per age |

Relic perks (on the trophy wall): moonstone (torch burns 20% longer), glow crystal (caves a little
brighter), star shard (sitting by a fire heals faster), giant feather (the roof: +1 heart), amber bug
(lucky: +10% shells), mammoth ivory (+1 damage with the next age's weapon), cave bear fang (wolves keep
further away), red ochre (the painted wall), thunder egg (storms warn ahead), golden horn (once per level:
call a friend). Boss trophies: Old Scar's fang (already: Level 3's spear), One-Eye's lens (dark places
show their outline), Tuskar's tusk.

## Mysteries that eat the inventory
- **The Collector**: an old trader at the shelter: one precious for two of another (fixes "I have three
  obsidian and no quartz"); his wants change every age.
- **The Elders' Wants**: a board by the shelter door, three requests per age, some needing OLD materials
  ("five fired pots and a Level-2 fire-gold"). Rewards: relics, page of the Age Book.
- **Riddle altars**: a stone circle with sockets; the right stones (quartz at the moon, fire-gold at the
  sun) open a hidden way.
- **The Bone Map**: twelve special bones (one per level, a different beast) laid out at home make a
  skeleton that points to the legendary chest of the next age.
- **The Moon Pool**: at night, quartz + moonstone in the pool show a path on the cave wall.
- **The Lost Pup** (later, the pet): it needs berries, bones and a ladder to reach; brought home, it sniffs
  out PRECIOUS stones (a living lucky charm).

## Do now: the rarity fix (Phase 1)
- Re-tier `Bag.ITEMS` by R2 (quartz to RARE, obsidian to VERY RARE, the hammer LEGENDARY, things made
  from commons COMMON, the shovel RARE).
- Common stones are EASY: digging hands out clay (dirt) and flint (rock, strata) as renewable chance drops,
  every visit (`Bag.DIG_DROPS`); their hidden spots glint WITHOUT the charm. Precious stones stay finite,
  hidden and glint only with the charm.

## Build order
1. **Phase 1 (now)**: the rarity fix above.
2. **Phase 2**: `Bag.FUTURE` and the NOW / LATER / HOME lines in tooltips; `GameState.home` (the shelter
   stockpile, id -> count); pouch caps send overflow home; the CAMPFIRE SORT at the level end.
3. **Phase 3**: no leftovers in Level 2: glare trap -> GLARE LAMP; the SPIRIT TREE (orb sink) in the camp
   menu, even before the shelter exists.
4. **Phase 4**: the shelter level: parts, costs, tiers, perks; the painted wall from `GameState.mysteries`.
5. **Phase 5**: Level 3's Age Book (spearheads, sling, bow, needle, sun lens, bait), using Level 2 stuff.

## Open questions for Jawad (playtest)
- Drop chances for clay / flint (start: dirt 1 in 6 clay, rock 1 in 8 flint): plenty, or flooding the bag
  again ("the diggable land is full of items", 2026-10-07)?
- Pouch caps per material, and whether "-> HOME" is fun or noisy.
- The ages after Level 3: is The Herd / The Potter / The Smith the road you want?
