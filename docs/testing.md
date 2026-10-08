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
| `dash` | `open double left wall drill flip`, `shots` |
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

## Other tools
- `wolfrock`; `vinereach` (`length=N`: how far a release flings him by angle, with/without the air jump; use it to space vines).
- Terrain: `terrain_bench` (chunk rebuild cost), `mountain_gen` (prints MOUNTAIN_MAP), `mountain_probe -- <x>...` (floors at those x's), `terrain_demo` (`shots`).
- Close-ups (with rendering): `shotugu` (`zoom= tag= x= sun`; use `x=1150` for flat ground, the default 2700 drops him into a pit), `shotmoves`, `shotdig`, `shotdig2`, `shotunder`, `shotexplore`, `shotstomp`, `shotturf` (`game`), `shotsun`, `shotdanger`, `shotclue`, `shotdeath`, `shotbeasts2`, `shotsky`, `shotview` (`level1`), `shotzoom`, `shottumble -- nodark 50 58 66` (spear pose), `shottumble -- nodark drop 20 40` (tumble).
- Performance (with rendering, `--rendering-driver opengl3 --disable-vsync`, no `--headless`): `perf` (every 400 px: average and worst frame, draw calls), `perfsplit -- <x>...` (frame time per kind of thing; ~1.3 ms noise), `glowcost -- <x>` (the glow layer, per glowing thing), `hitch` (frames over 50 ms through the scripted events; `-- 200-6000 over=30` for your own spans), `wolfcost -- n=14` (a pack: drawing vs thinking).
- `soak -- from=<x> to=<x> seed=<n>` (headless): a bot plays a stretch like a kid (runs, jumps, mashes, hotbar, specials) and flags stuck states, never-ending slow-motion, freezes over 0.5 s, falling out of the world, runaway nodes; one SOAK line. Stuck spots it hops are places a bot cannot pass (vines, chimneys, the river, the Boulder Run), not bugs. The caves: `from=34650 to=37950`, `from=38450 to=41200`. `slowmo`: overlapping slow-motion requests.
- `bag -- [shots]` (headless): the bag: sorting, stones from digging, every recipe, the made things used from the hotbar (tips thrown, salve, wall solid, ladder stood on, spark relights), edge/charm, saved, the view modes. Screenshots to `C:/tmp/shots/bag`.
- `windbreak -- [shots]` (headless): Shivers' side mission: the talk opens the mixing slab, wrong mixes hint and cost nothing, the right one is spent and built in 2 s, the reward, the mud bank, talking again after. Screenshots to `C:/tmp/shots/windbreak`.
- `idle -- [min=12] [safe]` (WITH rendering, real time): he stands idle; every minute the real frame time, nodes, objects, memory and what node kinds changed. 2026-10-08: flat over 12 min (no leak; the start area runs ~30 ms/frame rendered on this PC while dark, then ~17).
- `one_eye -- [shots]` (headless): Old One-Eye: the first meeting (tutorial pages, stones), TINK, it gives up outside, the trap recipe, set the trap, blinded twice, beaten, rewards.
- `snap` writes to `/tmp/shots`, which Godot can't save to on Windows: use `snapw`.

## Quirks
- After `GameState.reset()` set `GameState.seen["level2"] = true`.
- Hit-stop uses real time; long runs go in the background with logs.
- `landing` skips hand-placed ids (s, c, a, v, k).
- A bitten, tossed Ugu landing on a beast stomps it: tests that measure a beast set `stompable = false`.

## Not deterministic, and known failures
- Vary run to run (random loot, real-time hit-stop, random AI): `vines` (end x +-15 px), `bones` (pouch 0/1), `loot` (items per hit), `sky 0/2` (shell and cache counts), `swarm` (run it twice), `combos` (the slam dunk is a timing move: ~2 in 3 bot runs land it).
- To compare before/after a refactor, diff the logs and re-run any that differ a few times; smoke, jumps, story, econ, landing, caves and sky 1 match exactly.
- Expected failures: listed in the root `CLAUDE.md` (Testing). Details: `landing`'s 12 lines are t4-t9 and n0-n2; `canyon rocks` fails on bat randomness.
