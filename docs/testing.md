# Testing: the tools in `tools/`

Run forms (Godot path, headless, screenshots) and the regression set are in the root `CLAUDE.md`.
`<godot>` below means the full console path from there.

## Regression tests (headless, `res://tools/<name>.tscn -- <args>`)
| Test | What it checks / args |
|---|---|
| `smoke` | both levels load, player ok |
| `jumps` | jump arcs onto shelves, snags, outcrops |
| `vines` | the gorge and Long Dark vine swings |
| `story` | `variant=0\|1`: the caves, the key, Bongo |
| `boss` | Old Scar, beaten with a plain club (long: run in the background) |
| `finale` | the ending |
| `econ` | shop prices, purchases, figs |
| `bones`, `loot`, `landing` | bone pouch, loot per hit, every pickup lands on ground |
| `caves` | `hall nursery chasm stampede pit rockfall` (one per process) |
| `sky` | `0\|1\|2\|3`, `margin=40`, `critters`: the sky lanes |
| `airjump` | the double jump |
| `wolves` | aggression report: notice, escape, stand, fight, above |
| `talk` | `pick=0\|1\|2`, `shots`: the talking animals and Bongo |
| `tarpits` | `sink cross geyser snap snapbonk skip` |
| `hoards` | `guard swat break` |
| `sunfire` | `unlock power charge menu` |
| `boulder` | `run\|stop` |
| `stomp` | `ground crack seal beast tough` |
| `explore` | `lanes jelly ray relic burrow worms snail angler` |
| `dig` | `mega down ahead sunstone clay bramble wind ways den mystery` |
| `mountain` | `climb inside paint hollow east rooms dark dig`: a waypoint bot over and through the mountain, wall-kicks both chimneys, digs, times a blow |
| `dash` | `open double left wall drill flip`, `shots`: ~205 px plain, ~350 gold (2026-10-10); `drill` checks the tunnel mid-span |
| `getup` | `fall cancel`, `shots` |
| `canyon` | `stones calm stand bonk rocks door` |
| `falls` | `lip mammoth crumble crumble2`: set down somewhere firm |
| `steppe` | `chimney nokick herd river ferry` (one per process) |
| `leak` | 40 s of everything; the node count must level off |
| `grab` | daze, grab, hold, bowl a pinned pack |
| `gorgechest` | walk the fallen giant, drop on it from the lane, stomp it (Moss + homing loot), the chests and relics |
| `orbs` | a wolf's Spirit Orbs arrive and are saved |
| `mtbeasts` | `shots`: no mountain bats, the grub heals, the skeleton rises, hits, gets up once |
| `combat` | `shots`: hold to swing, combo, damage numbers, knock-back, pogo, special |
| `aim` | `shots`: 8-way aim, swing up, 45-degree throw, rock bounce + ricochet |
| `swarm` | `shots`: wolves take turns, each new attack, the howl, an ambush fires and clears |
| `combos` | `shots`: cyclone, ram, launch, juggle, slam dunk, ambush escalation |
| `airkick` | `shots` (paused frame sequence, kick_*): UP+HIT in the air = snap kick then FLASH KICK, UP+side = club, hits above, lands, bare-handed |
| `loadflow` | the real SAVE / LOAD through the Camp Menu (the scene changes); `-- second`: a new run loads the last run's save. Also checks tests use their own save file |
| `sweep` | (rendering) a screenshot sweep of the whole level for looking it over: surface every `step=` px (1600), the underground, the caves; or `x:y` spots. Releases vines, waits for him to settle |
| `homeflow` | the trip HOME: UGU'S CAVE locked before Level 2, open after; Camp Menu -> the cave -> Esc -> back where he stood, SAVE untouched. `-- shots` (rendering): the era-2 cave. The cave alone: `shelter/home.tscn -- shot` |
| `homeuse` | (`--fixed-fps 60`) every cave interaction: the closet, the rack, Kekko's menu (fig, stone, sell a gem), the Toolmaker's (an upgrade), the workbench (a spark kit), the store, the bed, fishing then cooking (+1 fig), the pup's fetch |
| `shotdigflash` | (rendering) the digging light in the Dig, a paused frame every 3 through two blows: digflash_* |

## Other tools
- `wolfrock`; `vinereach` (`length=N`: how far a release flings him by angle, with/without the air jump; use it to space vines).
- Terrain: `terrain_bench` (chunk rebuild cost), `mountain_gen` (prints MOUNTAIN_MAP), `mountain_probe -- <x>...` (floors at those x's), `terrain_demo` (`shots`).
- Close-ups (with rendering): `shotugu` (`zoom= tag= x= sun level1`; use `x=1150` for flat ground (Level 1: `x=700`), the default 2700 drops him into a pit), `shotmoves`, `shotdig`, `shotdig2`, `shotunder`, `shotexplore`, `shotstomp`, `shotturf` (`game`), `shotsun`, `shotdanger`, `shotclue`, `shotdeath`, `shotbeasts2`, `shotsky`, `shotview` (`level1`), `shotzoom`, `shottumble -- nodark 50 58 66` (spear pose), `shottumble -- nodark drop 20 40` (tumble).
- Performance (with rendering, `--rendering-driver opengl3 --disable-vsync`, no `--headless`): `perf` (every 400 px: average and worst frame, draw calls), `perfsplit -- <x[:y]>...` (frame time per kind of thing, on/off alternated 3 times, medians; ~1 ms noise), `glowcost -- <x>` (the glow layer, per glowing thing), `hitch` (frames over 50 ms through the scripted events; `-- 200-6000 over=30` for your own spans), `wolfcost -- n=14` (a pack: drawing vs thinking).
- More perf probes (same run form; add `--resolution 1920x1080` for a big window): `spotcost -- [start dig hollows graveyard ...] [dig] [nohaze] [viewport]` (real frame at named spots, surface and underground), `freeze -- [x:y]...` (frames over 40 ms and the node kinds that appeared), `farcost -- [x:y] [far=2200] [kinds]` (what the far world costs), `sleepcost -- [x:y]` (the Sleeper on vs off), `nightcost` (headless: Night's script cost, lights and glows).
- `soak -- from=<x> to=<x> seed=<n>` (headless): a bot plays a stretch like a kid (runs, jumps, mashes, hotbar, specials) and flags stuck states, never-ending slow-motion, freezes over 0.5 s, falling out of the world, runaway nodes; one SOAK line. Stuck spots it hops are places a bot cannot pass (vines, chimneys, the river, the Boulder Run), not bugs. The caves: `from=34650 to=37950`, `from=38450 to=41200`. `slowmo`: overlapping slow-motion requests.
- `bag -- [shots]` (headless): the bag: sorting, stones from digging, every recipe, the made things used from the hotbar (tips thrown, salve, wall solid, ladder stood on, spark relights), edge/charm, saved, the view modes. Screenshots to `C:/tmp/shots/bag`.
- `windbreak -- [shots]` (headless): Shivers' side mission: the talk opens the mixing slab, wrong mixes hint and cost nothing, the right one is spent and built in 2 s, the reward, the mud bank, talking again after. Screenshots to `C:/tmp/shots/windbreak`.
- `idle -- [min=12] [safe]` (WITH rendering, real time): he stands idle; every minute the real frame time, nodes, objects, memory and what node kinds changed. 2026-10-08: flat over 12 min (no leak; the start area runs ~30 ms/frame rendered on this PC while dark, then ~17).
- `one_eye -- [shots]` (headless): Old One-Eye: the first meeting (tutorial pages, stones), TINK, it gives up outside, the trap recipe, set the trap, blinded twice, beaten, rewards.
- `snap` writes to `/tmp/shots`, which Godot can't save to on Windows: use `snapw`.

## Ugu's look (2D and 3D)
- `rigsheet -- tag=<name>` (rendering): a MODEL SHEET of the real 2D rig on a plain backdrop, big: a row of
  poses (idle, run, swing, hammer, throw), a row of looks (Level 1 leaves, wolf hood, ember paint, bear
  cloak, firekeeper). `face`: three big face close-ups (rest, the attack face, the hood). `wind`: idle, run,
  fall, the cloak and the hood running (the air on his hair and clothes). PNG: `C:/tmp/shots/rigsheet_<tag>.png`.
  Use it for every change to his art: the levels are too busy (spores, loot) to judge him.
- `shotdash -- [gold]` (rendering): the meteor dash's effects, a paused frame every 2 (`dash_*`).
- `ugu3dsheet -- tag=<name> [face] [turn] [moves]` (rendering): the 3D Ugu (`shelter/ugu3d.gd`): idle, running and
  in the air (the runners feel a run's velocity, so the air works on them), the costumes, era 1; `face`: a
  head close-up; `turn`: seen from the side; `moves`: sprint, rising, falling, mid-somersault, the landing
  squash, the yawn, looking aside. PNG: `C:/tmp/shots/ugu3d_<tag>.png` (`face` overwrites the same tag).
  2026-10-10 rebuild: 29 meshes (was 217); the home ~475 draw calls in all (was ~1079), median frame a bit lower.
- Ugu's drawing cost: `drawcost` (headless: microseconds per CaveMan / wolf / bat picture, and per circle /
  line / poly). 2026-10-10: the sheet look ~1.6-1.7 ms, the classic look ~1.1-1.25 ms. To compare against
  an old look: a worktree of tag `ugu-classic-look` and the same tool, same session.

## The home
- `homecost` (rendering, `--disable-vsync`): the home's real frame (median, p95, worst, draw calls,
  objects) with everything, without the 3D Ugu, and without the omni lights' shadows; also how many meshes
  and loose pieces the 3D Ugu has.

## Quirks
- After `GameState.reset()` set `GameState.seen["level2"] = true`.
- Hit-stop uses real time; long runs go in the background with logs.
- `landing` skips hand-placed ids (s, c, a, v, k).
- A bitten, tossed Ugu landing on a beast stomps it: tests that measure a beast set `stompable = false`.

## Not deterministic, and known failures
- Vary run to run (random loot, real-time hit-stop, random AI): `vines` (end x +-15 px), `bones` (pouch 0/1), `loot` (items per hit), `sky 0/2` (shell and cache counts), `swarm` (run it twice), `combos` (the slam dunk is a timing move: ~2 in 3 bot runs land it).
- To compare before/after a refactor, diff the logs and re-run any that differ a few times; smoke, jumps, story, econ, landing, caves and sky 1 match exactly.
- Expected failures: listed in the root `CLAUDE.md` (Testing). Details: `landing`'s 12 lines are t4-t9 and n0-n2; `canyon rocks` fails on bat randomness.
