# Spec: visual depth, colour script and materials (Level 2)

Goal: make the level look like a place rather than a drawing, without leaving the
code-drawn style. No sprites, no imported art. Everything here is reachable with
`Batch`, the existing `Panorama` bands, and one new shader.

The problem in one line: there are now eleven distinct regions across 33600 px, and
all of them share one sky and the same four parallax bands in the same colours.

Do the items in order. Each is independently shippable — stop and show Jawad after
each one rather than doing all five and then testing.

Perf guardrail throughout: `Batch` is one draw call per object and the perf tools
exist for a reason. Prefer per-pixel shader work and per-vertex colour (both free)
over extra triangles. Anything that adds geometry must stay behind the existing
`near_view` checks. Run `perf` before and after items 1, 3 and 5 and report both.

---

## 1. Colour script: palette by region

The backdrop bands are built once in `_build_background()` and never change colour.
Make them read a palette that varies with world x, interpolated as he walks.

Model it on `DARKNESS` in `level2_data.gd` — an `[x, value]` table the level already
lerps. Add a `PALETTE` table the same shape, each entry `[x, sky_high, sky_low,
ridge, pine, woods, under, accent]`, and interpolate every colour between the two
surrounding entries. Hard cuts at region borders would be visible; the lerp means
the world changes colour as he walks, which is the effect we want.

`NightSky` already lerps between night and dusk via `dusk` — extend that rather than
replacing it, so the existing dusk-to-night progression still works.

Starting palette. Treat these as a first pass to look at, not gospel — the ones that
matter most are that each region's accent is unique, and that the ridge band is
always closest to the sky colour:

| Region | approx x | sky high | sky low | ridge | pine | woods | undergrowth | accent |
|---|---|---|---|---|---|---|---|---|
| Firelit woods | 0 | `#1b2440` | `#2a3350` | `#33405e` | `#273349` | `#1e2a3a` | `#16202c` | `#e08a3c` |
| Hanging Gorge | 3980 | `#16233a` | `#27384f` | `#3b5163` | `#2d4150` | `#223440` | `#1a2730` | `#a8c7cf` |
| The mountain | 5640 | `#1a2033` | `#2f3a4d` | `#4a5668` | `#3a4557` | `#2b3443` | `#202734` | `#cdd6e0` |
| Mammoth Steppe | 12400 | `#1d2133` | `#343148` | `#4d4552` | `#3e3a44` | `#2f2d35` | `#242229` | `#c9a86a` |
| Underground | 14300 | `#0c0a0b` | `#161012` | `#241a18` | `#1c1413` | `#140f0f` | `#0d0a0a` | `#d08a3a` |
| Tar Pits | 16080 | `#141a18` | `#1e2622` | `#2b352c` | `#222b24` | `#19201b` | `#121715` | `#c8d44a` |
| Thunder Canyon | 17900 | `#1a1630` | `#2a2246` | `#3d3360` | `#312a4e` | `#241f3a` | `#1a172b` | `#e8e4ff` |
| Great tree | 22700 | `#201a2e` | `#33263c` | `#4a3246` | `#3b2a3a` | `#2b2030` | `#1f1824` | `#f0c070` |
| Long Dark | 28650 | `#080c14` | `#0d141f` | `#131c2a` | `#101722` | `#0c121a` | `#080d13` | `#5ee0d0` |
| Boulder Run | 30900 | `#1c1620` | `#2c2029` | `#423029` | `#352720` | `#271d18` | `#1b1511` | `#d47a4a` |
| Old Scar | 32400 | `#1a1016` | `#2b1620` | `#41202a` | `#331a21` | `#261419` | `#1a0e12` | `#e2622f` |

The caves already have their own crystal tints — leave them alone.

The `accent` colour is the one each region uses for its light, its glowing things and
its highlights. Nothing else in the level should use another region's accent.

## 2. Spread the depth values apart

Atmospheric perspective: the further back a band is, the lighter, the lower in
contrast, and the closer to the sky colour it should be. Right now the ridge and pine
bands sit at nearly the same lightness, so four bands read as roughly two.

Rule of thumb to apply across the palette above: each band forward should be
noticeably darker than the one behind it, and the ridge band should be no more than
about 25% away from the sky's lower colour. If after tuning three bands read clearly
and the fourth adds nothing, say so — three good layers beat four muddy ones.

## 3. Movement in the mid-ground

Depth is read from motion more than from detail. Add, at most three per region:

- A drifting mist band — a wide, very low-alpha strip at its own parallax speed,
  slower than the band behind it. Strongest in the gorge, the tar pits and the
  Long Dark.
- A slow cloud band across the sky, independent of the parallax bands.
- One distant moving thing per region where it fits: birds over the steppe, smoke
  rising from a far camp, bats over the canyon.

Keep them cheap: a handful of shapes each, inside the band's existing single
`Batch`, no per-frame allocation.

## 4. Light that spills onto the world

The biggest single gain in perceived quality. The level has bonfires, a torch and the
light group in `night.gd`, but the scenery around a light stays its flat base colour.

Make nearby scenery pick up the light: within a light's radius, blend the surface
colour toward that light's warmth, falling off with distance. The light positions are
already collected for the darkness pass, so the data is there — the work is applying
it to the ground, the trunks and the near band instead of only to the darkness mask.

Start with the ground and the undergrowth band only. If that looks right, extend to
trunks and crags. Do not try to light every object.

## 5. Materials: stop everything reading as flat fill

Five techniques, cheapest first. Apply per material, not globally — the point is that
rock, bark, turf, bone and tar should each read differently.

- **Grain.** A tileable hand-painted noise or paper texture over the backdrop bands
  only, very low amplitude (a few percent brightness), sampled in a small shader built
  the way the existing ones in `fx.gd` (`flash`, `sway`, `shimmer`) are — created once,
  reused. A texture beats procedural noise here: it keeps the painted style and the
  NEAREST filter the project already uses. This alone removes most of the "flat vector"
  feel and costs nothing per object. Do not apply it to characters or the HUD.
- **Value breakup inside a fill.** `Batch.quad` takes per-vertex colours and
  `poly_pair` already draws a lit and unlit pair — use them so a large surface has two
  or three tonal zones rather than one flat colour. Free: no extra triangles.
- **Dithered transitions.** Where two tones meet on a big surface, scatter a short
  band of small shapes of the darker tone into the lighter one instead of a hard
  edge. Reads as texture at almost no cost.
- **Per-material marks.** A small, fixed vocabulary, seeded from position so it never
  shimmers: bark gets vertical strokes, rock gets angular cracks, turf gets short
  blades at the lip, bone gets fine parallel lines, tar gets horizontal sheen bands.
  Six to ten marks per object, not fifty.
- **One highlight on hard, wet things only.** A single bright sliver on tar, crystal,
  bone, wet rock and snow. Nothing on fur, turf or cloth. The inconsistency is the
  point: it tells the eye which surfaces are hard.

## Sourcing textures

The project already does this correctly and the pattern should not drift: `common/art/`
holds CC0 hand-painted tileable textures, credited in `CREDITS.md`, resized through
`tools/prep_art`, applied as **materials on code-drawn shapes** — terrain tiles, mammoth
and wolf fur, painted rock. Keep to that.

The rule: import **materials**, never **objects**. A tileable rock surface serves a
hundred shapes the code already draws. A painted boulder sprite serves one and clashes
with everything beside it. Textures fill the shapes; the code still decides every form.

Style over source. Everything must be hand-painted, not photographic. A photo-real rock
next to a painted one is exactly what reads as cheap — it is the mismatch, not the
fidelity, that shows. This rules out most of the big CC0 libraries (Poly Haven,
ambientCG, 3DTextures.me, cgbookcase): excellent scans, wrong style here.

Where the existing ones came from, and where to get more: OpenGameArt curates two
collections, "Assets: Stylized Hand-Painted" and "handpainted style 3D assets and
textures" — browse those rather than searching. The project already uses rubberduck
and Drummyfish from there, and both have more sets; Cethiel's tileable sets and MELLE's
hand-painted stone are the same style. TextureCan supplied the fur. Kenney is CC0 and
consistent but flatter and more prototype-looking — usable for a UI or a prop, not for
these surfaces.

Licences: CC0 only, to keep it simple, and keep crediting in `CREDITS.md` even though
CC0 does not require it. CC-BY is fine if attributed. Avoid CC-BY-SA (viral: it can
reach the whole project) and CC-BY-NC outright (it forbids selling the game). Never
take anything off an image search.

What this spec still needs, in rough priority: a grain or paper noise for item 5, bark,
tar or wet sheen, sand or dry steppe ground, bone, moss, and a soft cloud or mist alpha
for item 3. Resize through `prep_art` as before and add every one to `CREDITS.md` with
its source, author and licence in the same pass — not later.

## Out of scope

Characters, the caves' interiors, vistas. (The character spec is now Ugu's design sheet,
`docs/caveman_design.png`, and its rules in `CLAUDE.md` "Decisions": the palette `#7A4B36 #B27A52
#D9B08E #8D9196`, dark-brown hair, no black outlines (each rim a darker tone of its own fill), light from
high-right, readable at ~71 px tall. The same rules fit this spec's materials item: fur and cloth get no
highlight, hard things one.) Vistas — one big distant
set-piece per region — are the natural next step once the palette lands, but they
need the colour script in place first to be worth drawing.

## Verification

- `smoke`, then the full regression set at the end.
- `perf` before and after items 1, 3 and 5; report the numbers.
- Screenshots with `tools/snap.tscn` at one spot per region, and the same set with
  `dark` where the region is dark, so the palette can be judged side by side.
- The test that matters: the screenshots should be tellable apart with the HUD
  cropped off. If two regions still look like the same place, the palette hasn't
  gone far enough.
