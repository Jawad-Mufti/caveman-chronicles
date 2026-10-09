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
- **A 3D "paper diorama"**: the cave and its grounds low-poly 3D built from shapes in code; Ugu, his wife,
  Kekko, the blacksmith and the animals stay 2D paper cut-outs (their rigs drawn into a SubViewport on a
  billboard). A fixed tilted camera. The levels stay 2D.
- **Getting there**: from the CAMP MENU (its SHELTER row), unlocked once Level 2 is finished.
- v1 = Levels 1-3 + this home (eras.md).

## The cave itself
Mammoth bones and hides, a fire at its heart, the time rift glowing in the back. It GROWS with bones, not
with civilisation: more chambers, a bigger bone frame, a lookout ledge, a hot spring, a store room. Whatever
history Ugu drags home, he uses HIS way (below), so the cave gets funnier with every era, never tidier.

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
| # | era | costume (closet) | Kekko's stall becomes... | the forge becomes... | artifact (and how Ugu uses it) |
|---|---|---|---|---|---|
| 1 | Raw Stone | leaf loincloth | a log table of pebbles | the Toolmaker's anvil stone | Tuskar's tusk: the coat hook |
| 2 | Fire | hide loincloth | gems on a hide | the Firestone forge pit | Old Scar's skull: the fire guard |
| 3 | Ice Age | thick fur coat + hair tie | furs, ivory, amber | a forge of bone and ice | Gorrak's tusks: an arch over the cave mouth |
| 4 | First Farmers | woven-reed headband | seeds, pots, grain | a mud-brick kiln | a carved stone pillar (Göbekli Tepe): his back-scratcher |
| 5 | River Kingdom | pharaoh headdress | papyrus, scarabs, perfumes | a bronze workshop | a sarcophagus: his BATHTUB |
| 6 | The Arena | sandals + laurel wreath | coins, amphorae | a Roman fabrica | a chariot: the wheelbarrow |
| 7 | Castle Siege | knight's helmet, too small | a fair tent | a castle forge with bellows | a knight's helmet: the cooking pot |
| 8 | High Seas | pirate hat + parrot "UGU!" | spices and maps | a ship's forge | a cannon: the SHOWER (it fires water) |
| 9 | Steam & Smoke | hard hat + soot goggles | gadgets and gears | a steam forge | a train wheel: the dinner table |
| 10 | Concrete Jungle | sunglasses + hoodie | a vending machine | a garage workshop | a traffic light: the night lamp |
| 11 | Neon Grid | VR visor | a hologram stall | a fabricator | a robot vacuum: the pet's ride |
| 12 | The Collapse | the leaf loincloth again | barter in the ruins | every forge in one | the Colossus' core: the hearth stone, full circle |

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
1. Reshape the prototype (`shelter/proto.tscn`) into the cave home: the bone cave, the fire, the closet,
   Kekko's stall, the forge, the artifact shelf, the rift; an ERA SWITCH to see the costumes, shops and
   artifacts pile up era by era. Not wired into the game.
2. The real home for v1 (eras 1-3): Kekko and the blacksmith as cut-outs, upgrading with real resources
   (`GameState.home`, storage), cooking, the closet, the artifacts; the Camp Menu's SHELTER, unlocked after
   Level 2.
3. Each new level: its costume, its shop upgrades, its artifact.
