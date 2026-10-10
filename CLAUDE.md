# Caveman Chronicles

Godot 4.7.2 (GL Compatibility) 2D platformer for kids: Ugu the caveman through the ages, an era per level.
All GDScript, everything drawn in code. Repo: github.com/Jawad-Mufti/caveman-chronicles.
Level 1 done; Level 2 "Discovery of Fire" (night) nearly done; its map: `docs/level2.md`.

## How to work here (cheaply)
- Read only what the task needs; `grep -n` first. Big files (level2.gd, player.gd): ranges.
  Coordinates, loot, balance: `level2/level2_data.gd`. When Jawad names files, start there; widen only
  if the cause is elsewhere, and say so.
- Edit in place, never reprint whole files. Commit when done and tests pass.
- Be concise: Jawad is a software engineer. The game is for kids: fun, fair, "a bit harder".
- Screenshots only when visuals change; prefer headless tests (a PASS/FAIL line each).
- Jawad playtests the feel: ask him, don't guess about fun.

## Decisions (Jawad's)
- UGU'S LOOK = the design sheet `docs/caveman_design.png` (since 2026-10-10, commit a707e3b): wild spiky
  mane (dark brown, a bit lighter than the sheet), a connected fringe of locks, two heavy brows in a scowl,
  squared jaw, short beard + moustache, brown eyes; fur tunic over ONE shoulder (Level 2 on; leaf skirt in
  Level 1), fang necklace, rope belt + pouch, forearm and calf wraps, bare feet. EVERY expression and pose
  stays (tongue out, yawn, ooh, grin, roar...). No black outlines: rims are darker tones of each fill.
  Changes: small, shown as close-ups first (`tools/rigsheet -- face`). The old look: tag `ugu-classic-look`.
- THE AIR: everything loose on him (hair, fur, hems, cords, capes) drags behind his motion, lifts in a fall
  and flutters faster as he speeds up (`CaveMan._flutter`; the 3D figure does the same).
- 2D and 3D Ugu must look the same (Jawad, 2026-10-10). Next: UGGA, a blonde woman, in the same style.
- No bats in or on the mountain; bats live in the caves.
- Spirit Orbs: their own blue-white currency (beasts respawn each visit); never shells.
- MYSTERY HINTS: near anything unsolved, a SMALL card left of the bag (`level2._hints`, `Hud.set_hint`).
- SIDE MISSIONS ("as many as possible", using the bag's items): `windbreak.gd`, `errands.gd` (Errand base:
  recipe, odd/short lines, beats, finish). Saying yes puts a JOB in the bag (`Bag.offer_job`: a "!" on the
  sack, a banner in the big view, the small hint): HE opens the bag and starts mixing (`Bag.start_job`).
  Hints and pages NUDGE (riddles); the exact recipe shows only after two wrong mixes. Old One-Eye's trap too.
- THE BAG (`Bag`): everything carried, in boxes down the right; I/B or the sack: strip -> big view (tabs,
  CRAFT) -> hidden. COMMON stones (clay, flint) drop as he digs, every visit (`Bag.DIG_DROPS`);
  new item: a row in `Bag.ITEMS` + `draw_icon`. INVENTORY RULES: `docs/inventory_plan.md` (nothing looted is junk:
  NOW / LATER / HOME; rarity = effort; the shelter is the sink). Read it before adding loot or a level.
  The big view and a mixing slab PAUSE the world (`Bag.hold_world`; never another pause, e.g. the menu).
  Every dig blow flashes light + sparks (`FX.dig_flash`).
- SPACE is the only jump; UP/W and DOWN/S aim (8 ways, UP+RIGHT = 45 degrees).
- Terraria-fast combat: hold HIT keeps swinging; combos unlocked from the start; specials on L.
  A Terraria HOTBAR (1-9/wheel/tap; HIT uses the slot: weapon, shovel digs where aimed, rocks, figs): no row
  of its own (Jawad: remove "these squares"); it is the top of the BAG's strip, numbered.
- AIR KICKS: in the air UP + HIT with no side = snap kick, then FLASH KICK (backflip, launches); UP + a side
  + HIT stays the aimed club. Only the first two kicks of a jump lift him.
- Painted earth under the grass, not the banded soil cut-away ("pixelated").
- The meteor dash (jump + T + a side) stays short and FAST (2026-10-10): ~205 px at 1500 px/s, the gold one
  (after a double jump) ~350 px at 1900; a quick spin first (`Stomp.DASH_CHARGE`); a launch ring, a blade
  of light, after-images, sparks, speed lines, a puff (`Stomp.Trail`). He runs faster (330).
- ZOOM while playing: + / - / 0 (`LevelBase.look_zoom`, over the chosen VIEW, not saved).
- Ambushes escalate the deeper into a level they are.
- Keep the hollow pack scene ("This is what fire is for").

## Files
common/: `critter.gd` (creature base, attack director, launch), `enemies.gd` (Level 1; Insect base),
`player_body.gd` (CaveManBody: what he DOES: moving, combat, torch, hotbar, SUNFIRE, STOMP), `player.gd`
(CaveMan extends it: only how he LOOKS; the game uses CaveMan), `sleeper.gd` (far things sleep), `bag.gd` (inventory: items, stone drops, recipes, the bag UI), `hud.gd`, `abilities.gd` (MOVES = Tutorial), `terrain.gd`, `game_state.gd`;
the rest one file per system (`ls common`). level2/: `level2_data.gd` (tables), `level2.gd` (builders;
extends the data: tables are bare names); the rest one file per area or system (`ls level2`).
shelter/: `home.gd` (UGU'S CAVE, the 3D island, eras by `GameState.home_era()`; docs/shelter_plan.md),
`ugu3d.gd` (Ugu as a 3D figure, his 2D self made solid and a bit taller: face features placed from the 2D
rig's design units (`_face`), toon light + rims in darker tones (a hull pass), meshes merged per bone
(`Lump`), the air in the vertex shader (UV2 = looseness), moods (smile, tongue on a run, ooh, grin, yawn,
blinks); `speed`, `sprint`, `air`, `look_at_point`, `era`, `refresh()`, `jumped(double)`, `landed(k)`,
`cheer()`), `ugu_paper.gd` (the alternative: the REAL 2D rig drawn into a SubViewport on a billboard, so
he is exactly his 2D self; `CaveMan.puppet_air` gives the jump pose), `menu.gd` (trade / upgrade / craft).

## Conventions
- Talkers: bubble, E/TALK starts (`_talkers`); again = a varied line. Lines short. Choice:
  `{"choose": [[answer, [lines]], ...]}`; new talkers need a `Dialogue.TAGS` colour + `speaking` var.
  Tests' `_next()` on a choice picks the first answer.
- Drawing: override `_paint()`; `_draw()` submits one Batch. Helpers `_ln _pl _cc _pg _rc _ac _st _stm`.
  Redraw only when `LevelBase.near_view(self)`. Never `Batch.poly()` for a shape drawn every frame: use
  `tri`/`quad`/`ellipse`. HUD parts redraw only when what they show changed.
- Darkness: lights join "light" (`light() -> Vector4(x, y, r, warmth)`, `light_strength()`); glowing ones join
  "glow" (`draw_glow(g)`, world coords, `g` is ONE shared Batch: only draw_circle/line/colored_polygon/
  set_transform, reset the transform). Max 12 lights on screen.
- Fonts: `Pal.text_font()` (Fredoka, the fallback everywhere via `Pal.install_fonts`) and `Pal.title_font()`
  (Luckiest Guy: titles, names, comic words). Hints go through `hud.say`: a banner, CAPS words in gold.
- Textured things set `texture_filter = TEXTURE_FILTER_LINEAR_WITH_MIPMAPS` (project default is NEAREST).
  Paint built-once shapes with `Terrain.paint_poly` / `paint_rect`, tints `Terrain.NIGHT_ROCK/EARTH/GRASS`.
  No flat slate-blue rock: warm painted stone, outlined. Fur shapes: `Critter._fur_shape`, `CaveMan._fur`.
- Critters: layer 4, `take_hit(dmg, dir)` (call super: damage numbers + knock-back come from the base).
  Breakables are layer-4 Areas with `take_hit`. `make_elite()` only AFTER `add_child`. Launch: hp <= 20 only.
- Attack director: before any attack a beast calls `Critter.may_attack(self, ms)` LAST in its `and` chain
  (it grants a turn) and `Critter.attack_done(self)` after. Every attack gets a tell (`tell("!")`).
- Platforms: `World.Slab`, `NightWoods.Crag` solid; one-way: `cs.one_way_collision = true`.
- Safe ground: after a fall he is set down on a static body not in "unsafe_ground" with ground under both
  sides. Anything that breaks, burns or falls joins "unsafe_ground"; moving platforms never count.
- Treasure ids: taken once per save. Never insert into SHELL_ROWS, SHELL_POINTS, CONCHES, AMBERS,
  BREAKABLES, POTS, TOTEMS (ids by index); moving coordinates is fine. New loot gets its own prefix. Used:
  v, q%d_%d, sac<x>, k, k2_, sc, sc2_, m, t, n, h, g, ch, gw, u, mt, mb, r (relics, shared), x0/x1 (hoards),
  st (mountain stones), sd (the Dig's stones), mud (the mud bank).
- Economy: prices = fraction x the level's one-time shell total (`ECONOMY`, now 832; "a bit costly": see
  docs/level2.md "The budget"). PRECIOUS stones are finite per level (`MT_STONES`...); common ones renew. Bonuses (chests,
  buried finds, stomp loot) are NOT counted. Relics are not money.
- One-shot kills call `end_sunfire()` first.
- Drawing Ugu cheaply (he is redrawn every frame; one picture ~1.6 ms, `tools/drawcost`): a big shape whose
  points only move a little uses `_shape_k(key, ...)` (triangulated once, then reused); a 3-point
  `_shape` goes through `_tri3` (no outline polyline); constant geometry (the head outline, the hair cap,
  the mane's roots) is built once and kept; per-frame terms (`_flutter`) are worked out once per frame;
  bands on limbs use `_wrap_band` (no round caps). New function names must be unique in CaveMan/Body.
- THE HOME merges every plain, still shape into one vertex-coloured mesh after it is built (`home._bake_static`;
  each fading tree into its own): ~1400 draw calls -> ~290. Anything NEW that moves, fades, or changes colour
  at runtime must be added to its skip list (or hold a non-plain material), or it will be frozen in place.
  Things made after `_ready` (the stick, caught fish) are never merged. Cost: `tools/homecost`.
- Shared helpers (don't copy the maths): `CaveMan.hurt_toss`, `Pickup.aim_at`, `Pickup.homing`,
  `Breakable.carry_to`, `Batch.ellipse`, `LevelBase.near_view`, `FX.burst`, `FX.shards`.
- View: "on screen?" uses `LevelBase.view_half(n)`, never 640/1280. Slabs draw `fill_below`;
  backgrounds use `scroll_ignore_camera_zoom`.
- New ability: a row in `Abilities.LIST`, a rule in `Abilities.unlocked`, a symbol in `draw_symbol`.
  Learned ones: `GameState.learn(id)`.
- Terrain: text map (`#` rock, `=` strata, `o` stone, `d` dirt, `.` tunnel, space air), 40 px samples; flat
  ground on solid row R: y = position.y - 20 + 40 R; features >= 2 rows/columns thick; slopes over
  ~45 degrees can't be walked. Place things with `ground_y` / `roof_y` / `is_inside`. `MOUNTAIN_MAP` comes
  from `tools/mountain_gen` (regenerating changes the buried "mb" ids).
- Perf: `perf` vs a HEAD worktree, same session (this PC drifts). Rock blow ~7 ms worst; `leak` levels off.
  Measure before fixing (`spotcost`, `sleepcost`, `freeze`; `perfsplit` alternates: ~1 ms noise). Budget 16.7 ms at
  1080p (60 Hz): the heavy spots (the Dig, the graveyard) run ~10-17. It is CPU (scripts), not fill rate.
- SLEEP what only matters near him: `Sleeper.enrol(self)` in `_ready` (pickups, beasts, ambient things).
  Never: bosses (`sleeps_far = false` in `_setup`), level-wide managers, moving platforms, self-freeing
  projectiles. Asleep = not processed; collisions stay. A teleport calls `sleeper.wake_all()`.
- A new particle kind or shader goes in `FX.warm_up` too (first draws compile: a 50-500 ms freeze).
- New class file: commit its `.uid`; Jawad must Project > Reload. A `preload`-ed file needs neither.

## Player numbers (for level design)
Run 330 px/s on the ground, 320 in the air (AIR_SPEED: keep 320; 330/335 break the Glowcap Chasm and the
chimney). Jump -640: ~133 px up, ~260 across. Double jump -520: ~230 up total, ~430 across, then a softer
fall (GLIDE_GRAVITY 1900, capped 620 px/s). A fall over 0.4 s (0.8 s after a double jump) becomes the tumble.
Wall kick off "kick_wall" bodies (slide 150 px/s, kick +-340 -600, lock 0.16 s) and diggable rock. ROCK CLIMB:
UP + toward a steep rock face (in the air: toward it) = up 170 px/s, heave over the top; HIT held digs.
MoonPuff -1100 (~393 up, 390 across); GlowCap -1000. Capsule r13 h64. Below y 1020: -1 hp.
Torch 50 s. Releasing jump while rising cuts it (JUMP_CUT 0.45): bots hold it.

## Testing
Godot (not on PATH): `"C:\Users\wadah\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe"`
Headless: `<godot> --headless --fixed-fps 60 --path . res://tools/<name>.tscn -- <args>`
Screenshots: `<godot> --rendering-driver opengl3 --fixed-fps 60 --path . res://tools/snapw.tscn -- name:x:y
[nodark] [notorch] [freeze]` (PNGs to `C:/tmp/shots`; name it `topic/shot` for a folder).
Regression set: smoke, jumps, vines, story, boss, finale, econ, bones, loot, landing, caves, sky, airjump,
wolves, talk, tarpits, hoards, sunfire, boulder, stomp, explore, dig, mountain, dash, getup, canyon, falls,
steppe, leak, grab, gorgechest, orbs, mtbeasts, combat, aim, swarm, combos, hotbar, weapons, slowmo, soak, bag, windbreak, errands, one_eye, airkick, loadflow (+ `-- second`), homeflow, homeuse.
Tests save to `user://caveman_save_test.json` (`GameState.save_path()`): never the player's save.
EXPECTED failures (not bugs): `vines` "three swings, let go late" MISS; `landing` prints 12 "no ground
under" lines; `canyon rocks`/`stones` fail ~1 in 4 (bats); `combos` slam dunk and `grab` (knocked out of reach) fail ~1 in 3.
New tests: `extends "res://tools/harness.gd"`, override `run()` (Level 2 built, `p`, frames/put/release/check/shot).
What each test does, args, close-up/perf tools, quirks: `docs/testing.md`.

## Pitfalls
- Duplicate (inner-)class names break a whole class and cascade ("Could not resolve class").
- GDScript can't infer types from dict/array lookups: `var x: float = arr[i]`.
- Avoid new two-way class references between common/ and level2/.
- No python here. Git Bash: Unix temp paths (`cygpath -u "$TEMP"`); awk -v mangles Windows paths; grep
  has no `\t`; apostrophes in heredocs break the shell (use Write/Edit).
- Git Bash sed: a multi-line `a\`/`i\` insert gets JOINED into one line (use Edit); and a line number from
  a grep that matched nothing makes `sed -i "${s}s|.*|...|"` rewrite EVERY line (it wiped ugu3d.gd once):
  check the number is set before any `sed -i` that uses it.
- FallingRock: warning = `delay` + ~0.5 s; trigger distance for a runner ~300 x that.
- Stale `.godot` cache: delete it and reopen.

## Open ideas
See `docs/level2.md`. More lanes; "?" reopens the guide; orb shop; Gulper / Old Scar
reworks; a shelter level (bones, wife, pet); Level 3: the fang is a spear. UGGA (blonde, same style,
2D + 3D); the home's Ugu: the 3D figure or the paper cut-out (Jawad picks).
