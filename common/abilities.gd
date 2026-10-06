class_name Abilities
extends RefCounted
## What he can do, as the Camp Menu shows it â two different things:
##   POWERS   abilities: big, spent and recharged. He carries TWO at a time
##            (picked in the menu); their circles sit at the bottom of the
##            screen, shining while ready, dark while spent.
##   MOVES    special moves: always his once learned â the TUTORIAL shows how.
## Every one has a carved symbol drawn in code. In the menu the unlocked ones
## all glow the same gold and the locked ones are slate; on the HUD each power
## burns in its own colour.

const GOLD := Color("ffc845")          ## every unlocked symbol in the menu
const SLATE := Color("5b6070")         ## every locked one
const SLOTS := 2

## [id, name, what it does, key, how to unlock it, its own colour]
const POWERS := [
	["sunfire", "SUNFIRE", "Fire in both fists for 30 seconds! Faster, stronger, burning blows â and fireballs. Then the sun must fill again: hit beasts, grab shells, sit by fires.", "Q", "Find the Sun Stone, deep in the Dig.", Color("ffb020")],
	["firering", "FIRE RING", "He gets angry... and a ring of flame bursts out around him: it burns what's close and scares off the rest. Costs two bundles of dry wood.", "F", "Carry a torch.", Color("ff4a2a")],
	["thunderclap", "THUNDER CLAP", "One clap of his hands and the ground shakes: every beast around falls down dizzy.", "?", "A later age.", Color("5ad1ff")],
	["stoneskin", "STONE SKIN", "Skin like granite for a while: nothing can hurt him.", "?", "A later age.", Color("9ad06a")],
	["spiritowl", "SPIRIT OWL", "An owl of light flies ahead and shows the way through the dark.", "?", "A later age.", Color("b48cff")],
	["beast", "BEAST FRIEND", "Call a mammoth friend to charge through everything.", "?", "Who knows?", Color("ff7ab8")],
]

## [id, name, how to do it, keys, how to unlock it]
const MOVES := [
	["strike", "CLUB SWING", "Whack whatever is in reach. Tap again quickly for a combo.", "J  or  HIT", ""],
	["throw", "STONE TOSS", "Pick up rocks on the way, then throw them at things that bite back.", "K  or  THROW", ""],
	["leap", "HERCULES LEAP", "Jump, then jump again in mid-air: a somersault, then the spear pose and a softer fall.", "SPACE  twice", ""],
	["stomp", "METEOR STOMP", "Jump, then press T: he spins into a ball and drops like a meteor â STOMP! Beasts go flat and cracked slabs in the ground break open. Double-jump first for a MEGA STOMP: the only thing that breaks a gold rune seal.", "jump + T  Â·  double jump + T", ""],
	["dash", "METEOR DASH", "Jump, then press T while holding LEFT or RIGHT: he spins, then shoots that way like a meteor, flat through the air. Beasts in the way go flying; a wall goes BOOM; and mountain rock... he drills right through it. Double-jump first for the long gold one.", "jump + T + LEFT / RIGHT", ""],
	["dig", "DIG", "Hold DOWN and HIT to dig the earth under him; HIT alone digs what is in front. Dirt goes in one blow, stones take three. Packed clay needs a SHOVEL.", "DOWN + J  Â·  J", ""],
	["homerun", "HOME RUN", "Hold HIT to wind up the club... let go: beasts go flying.", "hold  J", "Find a club."],
	["wallkick", "WALL KICK", "Between two close walls: hold toward a wall to slide, jump to kick across to the other.", "hold toward wall + SPACE", "Climb the split rock on the Mammoth Steppe."],
	["torch", "TORCH", "Holds back the dark â and the wolves. It burns down: feed it at every bonfire.", "always lit", "Take a burning branch from a fire."],
	["slam", "HAMMER SLAM", "Hold HIT to raise the Firestone Hammer, let go: SLAM! A wave of fire rolls along the ground.", "hold  J", "Forge the Firestone Hammer."],
	["axe", "AXE THROW", "Hold HIT, let go: the stone axe spins out and comes back to his hand.", "hold  J", "Trade for the stone axe."],
	["spear", "SPEAR THROW", "The broken fang becomes a spear. Throw it far, and fetch it back.", "?", "Level 3."],
]


static func row(id: String) -> Array:
	for r in POWERS + MOVES:
		if r[0] == id:
			return r
	return []


static func colour(id: String) -> Color:
	for r in POWERS:
		if r[0] == id:
			return r[5]
	return GOLD


## Is it his yet? Some come with the level, some are learned once and saved.
static func unlocked(id: String, p: CaveMan) -> bool:
	match id:
		"strike", "throw", "leap", "stomp", "dash", "dig":
			return true
		"homerun":
			return p == null or p.has_stick
		"torch", "firering":
			return p != null and p.has_torch
		"slam":
			return GameState.weapons.has("hammer")
		"axe":
			return GameState.weapons.has("axe")
		"wallkick", "sunfire":
			return GameState.abilities.has(id)
	return false


## The two powers he carries. Until he picks for himself, the first ones he
## has unlocked fill the slots.
static func slots(p: CaveMan) -> Array:
	var out: Array = []
	if GameState.equip_picked:
		for id in GameState.equipped:
			if unlocked(id, p) and out.size() < SLOTS:
				out.append(id)
		return out
	for r in POWERS:
		if unlocked(r[0], p) and out.size() < SLOTS:
			out.append(r[0])
	return out


static func is_equipped(id: String, p: CaveMan) -> bool:
	return slots(p).has(id)


## Put a power in a slot, or take it out. Full: the newest goes in, the
## oldest comes out. Returns what happened, for the menu to say.
static func toggle(id: String, p: CaveMan) -> String:
	if not unlocked(id, p):
		return "locked"
	var now := slots(p)
	if now.has(id):
		now.erase(id)
		GameState.set_equipped(now)
		return "off"
	now.append(id)
	if now.size() > SLOTS:
		now.pop_front()
	GameState.set_equipped(now)
	return "on"


## The carved symbol, centred on c, about 2r across, all in one colour.
static func draw_symbol(b: Batch, id: String, c: Vector2, r: float, col: Color, t: float) -> void:
	var dk := col.darkened(0.5)
	var k := r / 50.0
	var w := 6.0 * k
	match id:
		"strike":
			# a knobbly club mid-swing, with whoosh arcs
			var a := -0.7 + sin(t * 3.0) * 0.12
			var base := c + Vector2(-26, 26) * k
			var tip := base + Vector2(cos(a - 0.9), sin(a - 0.9)) * 70.0 * k
			b.line(base, tip, dk, w * 2.2)
			b.line(base, tip, col, w * 1.5)
			b.circle(tip, 14.0 * k, dk, 14)
			b.circle(tip, 11.0 * k, col, 14)
			for i in 3:
				b.circle(tip + Vector2.from_angle(i * 2.1 + 0.4) * 9.0 * k, 3.5 * k, dk, 8)
			for i in 3:
				b.arc(base, (48.0 + i * 12.0) * k, a - 2.2, a - 1.2, 10, Color(col, 0.75 - i * 0.2), 3.0 * k)
		"throw":
			# a stone flying along a dotted arc, speed lines behind
			var q := fmod(t * 0.8, 1.0)
			for i in 7:
				var s := i / 6.0
				var p := c + Vector2(-44.0 + 88.0 * s, 26.0 - 64.0 * s + 50.0 * s * s) * k
				b.circle(p, 2.8 * k, Color(col, 0.6), 6)
			var sp := c + Vector2(-44.0 + 88.0 * q, 26.0 - 64.0 * q + 50.0 * q * q) * k
			b.circle(sp, 15.0 * k, dk, 14)
			b.circle(sp, 12.0 * k, col, 14)
			b.circle(sp + Vector2(-4, -4) * k, 4.0 * k, dk, 8)
			for i in 3:
				b.line(sp + Vector2(-20.0 - i * 4.0, -8.0 + i * 8.0) * k, sp + Vector2(-34.0 - i * 6.0, -8.0 + i * 8.0) * k, col, 3.0 * k)
		"leap":
			# two chevrons climbing, and the somersault's swirl
			for i in 2:
				var y := (26.0 - i * 34.0 - fmod(t * 20.0, 10.0)) * k
				b.polyline(PackedVector2Array([c + Vector2(-26 * k, y + 18 * k), c + Vector2(0, y - 4 * k), c + Vector2(26 * k, y + 18 * k)]), dk, w * 1.8)
				b.polyline(PackedVector2Array([c + Vector2(-26 * k, y + 18 * k), c + Vector2(0, y - 4 * k), c + Vector2(26 * k, y + 18 * k)]), col, w)
			b.arc(c + Vector2(0, -34) * k, 14.0 * k, t * 6.0, t * 6.0 + 4.5, 14, col, 3.0 * k)
		"homerun":
			# the club and a big star: POW
			var star := PackedVector2Array()
			for i in 16:
				var rr := (34.0 if i % 2 == 0 else 15.0) * k * (1.0 + 0.08 * sin(t * 8.0))
				star.append(c + Vector2(14, -14) * k + Vector2.from_angle(i * TAU / 16.0 + t * 0.6) * rr)
			b.poly(star, dk)
			b.line(c + Vector2(-38, 38) * k, c + Vector2(4, -4) * k, dk, w * 2.4)
			b.line(c + Vector2(-38, 38) * k, c + Vector2(4, -4) * k, col, w * 1.6)
			b.circle(c + Vector2(6, -6) * k, 12.0 * k, col, 14)
			b.circle(c + Vector2(30, -30) * k, 6.0 * k, col, 10)
		"torch":
			b.line(c + Vector2(0, 44) * k, c + Vector2(0, 0), dk, w * 2.0)
			b.line(c + Vector2(0, 44) * k, c + Vector2(0, 0), col, w * 1.2)
			b.rect(Rect2(c + Vector2(-9, -4) * k, Vector2(18, 10) * k), dk)
			_flame(b, c + Vector2(0, -6) * k, 30.0 * k, col, t)
		"firering":
			for i in 10:
				var a2 := i * TAU / 10.0 + t * 0.9
				_flame(b, c + Vector2.from_angle(a2) * 34.0 * k, 12.0 * k, col, t + i)
			b.arc(c, 34.0 * k, 0.0, TAU, 32, dk, 3.0 * k)
			_flame(b, c + Vector2(0, 8) * k, 22.0 * k, col, t * 1.3)
		"wallkick":
			b.rect(Rect2(c + Vector2(-46, -46) * k, Vector2(12, 92) * k), dk)
			b.rect(Rect2(c + Vector2(34, -46) * k, Vector2(12, 92) * k), dk)
			var zz := PackedVector2Array([c + Vector2(-30, 40) * k, c + Vector2(28, 14) * k, c + Vector2(-30, -10) * k, c + Vector2(28, -36) * k])
			b.polyline(zz, col, w)
			b.tri(c + Vector2(28, -36) * k + Vector2(-12, -2) * k, c + Vector2(28, -36) * k + Vector2(6, 2) * k, c + Vector2(28, -36) * k + Vector2(-6, 12) * k, col)
			b.circle(zz[1], 5.0 * k, col, 8)
			b.circle(zz[2], 5.0 * k, col, 8)
		"slam":
			# the hammer coming down, shock waves out both ways
			b.line(c + Vector2(20, -42) * k, c + Vector2(-2, 6) * k, dk, w * 1.8)
			b.line(c + Vector2(20, -42) * k, c + Vector2(-2, 6) * k, col, w)
			b.rect(Rect2(c + Vector2(-26, 0) * k, Vector2(46, 26) * k), col)
			b.rect(Rect2(c + Vector2(-26, 18) * k, Vector2(46, 8) * k), dk)
			for s in [-1.0, 1.0]:
				for i in 3:
					var x: float = (34.0 + i * 12.0 + fmod(t * 30.0, 12.0)) * s
					b.arc(c + Vector2(x * 0.6, 40) * k, (10.0 + i * 6.0) * k, PI, TAU, 8, Color(col, 0.8 - i * 0.22), 3.0 * k)
		"axe":
			# a spinning axe on a curving path
			var spin := t * 5.0
			var at := c + Vector2(cos(t * 1.5) * 10.0, sin(t * 1.5) * 6.0) * k
			var hx := Transform2D(spin, at)
			b.line(hx * (Vector2(0, 30) * k), hx * (Vector2(0, -26) * k), dk, w * 1.8)
			b.line(hx * (Vector2(0, 30) * k), hx * (Vector2(0, -26) * k), col, w)
			b.poly(PackedVector2Array([hx * (Vector2(0, -30) * k), hx * (Vector2(26, -40) * k), hx * (Vector2(30, -12) * k), hx * (Vector2(0, -14) * k)]), col)
			b.arc(c, 46.0 * k, spin, spin + 1.6, 12, Color(col, 0.6), 3.0 * k)
		"sunfire":
			# a blazing sun with a face of fire, two flaming fists either side
			var rays := PackedVector2Array()
			for i in 24:
				var rr2 := (30.0 if i % 2 == 0 else 22.0) * k * (1.0 + 0.1 * sin(t * 6.0 + i))
				rays.append(c + Vector2.from_angle(i * TAU / 24.0 + t * 0.5) * rr2)
			b.poly(rays, col)
			b.circle(c, 18.0 * k, dk, 18)
			b.circle(c, 14.0 * k, col, 18)
			b.circle(c + Vector2(-5, -3) * k, 2.5 * k, dk, 6)
			b.circle(c + Vector2(5, -3) * k, 2.5 * k, dk, 6)
			b.arc(c + Vector2(0, 2) * k, 6.0 * k, 0.3, PI - 0.3, 8, dk, 2.0 * k)
			for s2 in [-1.0, 1.0]:
				var f := c + Vector2(s2 * 40.0, 22.0) * k
				b.circle(f, 9.0 * k, col, 12)
				_flame(b, f + Vector2(0, -6) * k, 18.0 * k, col, t * 1.4 + s2)
		"dig":
			# a shovel biting into blocks of earth, clods flying
			var bob := sin(t * 5.0) * 4.0
			for gx in 3:
				for gy in 2:
					if gx == 1 and gy == 0:
						continue
					b.rect(Rect2(c + Vector2(-42.0 + gx * 28.0, 8.0 + gy * 22.0) * k, Vector2(26, 20) * k), dk if (gx + gy) % 2 == 0 else col.darkened(0.3))
			b.line(c + Vector2(10, -46 + bob) * k, c + Vector2(0, 0 + bob) * k, col, 5.0 * k)
			b.poly(PackedVector2Array([c + Vector2(-10, -2 + bob) * k, c + Vector2(10, -2 + bob) * k, c + Vector2(6, 22 + bob) * k, c + Vector2(-6, 22 + bob) * k]), col)
			for i in 3:
				var q := fmod(t * 1.3 + i * 0.33, 1.0)
				b.rect(Rect2(c + Vector2(20.0 + q * 18.0, -8.0 - q * 22.0 + q * q * 30.0) * k, Vector2(6, 6) * k), Color(col, 1.0 - q))
		"dash":
			# a ball of light shooting sideways, streaks flying out behind it
			var run := fmod(t * 0.8, 1.0)
			var bx := lerpf(-34.0, 30.0, run)
			for i in 4:
				var sy := -12.0 + i * 8.0
				b.line(c + Vector2(bx - 14.0, sy) * k, c + Vector2(bx - 44.0 - i * 6.0, sy) * k, Color(col, 0.55), 3.0 * k)
			b.circle(c + Vector2(bx, 0) * k, 13.0 * k, col, 14)
			b.circle(c + Vector2(bx + 3.0, -3.0) * k, 5.0 * k, Color(1, 1, 1, 0.7), 10)
			b.rect(Rect2(c + Vector2(36, -26) * k, Vector2(8, 52) * k), dk)
		"stomp":
			# a foot coming down like a meteor onto a cracking slab
			var drop := fmod(t * 0.9, 1.0)
			var fy := lerpf(-40.0, 4.0, minf(drop / 0.45, 1.0))
			var foot := c + Vector2(0, fy) * k
			for i in 3:
				b.line(foot + Vector2(-10.0 + i * 10.0, -14.0) * k, foot + Vector2(-10.0 + i * 10.0, -40.0) * k, Color(col, 0.5), 3.0 * k)
			b.poly(PackedVector2Array([foot + Vector2(-16, -12) * k, foot + Vector2(10, -12) * k, foot + Vector2(22, 0) * k,
				foot + Vector2(22, 8) * k, foot + Vector2(-16, 8) * k]), col)
			for i in 3:
				b.circle(foot + Vector2(14.0 + i * 3.0, -2.0 - i * 3.0) * k, 3.0 * k, col, 8)
			b.rect(Rect2(c + Vector2(-40, 14) * k, Vector2(80, 10) * k), dk)
			if drop > 0.45:
				var q := (drop - 0.45) / 0.55
				for s in [-1.0, 1.0]:
					b.arc(c + Vector2(s * 20.0, 14.0) * k, (10.0 + 24.0 * q) * k, PI, TAU, 8, Color(col, 1.0 - q), 3.0 * k)
					b.line(c + Vector2(s * 6.0, 18.0) * k, c + Vector2(s * (14.0 + 20.0 * q), 22.0) * k, dk, 2.0 * k)
		"thunderclap":
			# two hands meeting, a lightning bolt between, shock arcs
			for s in [-1.0, 1.0]:
				var hc := c + Vector2(s * 26.0, 6.0) * k
				b.circle(hc, 14.0 * k, col, 14)
				for f in 3:
					b.line(hc + Vector2(s * -4.0, -8.0 + f * 7.0) * k, hc + Vector2(s * -18.0, -12.0 + f * 7.0) * k, col, 5.0 * k)
			b.poly(PackedVector2Array([c + Vector2(4, -44) * k, c + Vector2(-8, -8) * k, c + Vector2(2, -8) * k, c + Vector2(-6, 22) * k,
				c + Vector2(10, -16) * k, c + Vector2(0, -16) * k]), col.lightened(0.3))
			for i in 2:
				b.arc(c + Vector2(0, 6) * k, (44.0 + i * 10.0 + fmod(t * 20.0, 10.0)) * k, PI * 1.15, PI * 1.85, 10, Color(col, 0.7 - i * 0.3), 3.0 * k)
		"stoneskin":
			# a shield of stone plates, a crack of light down it
			var sh := PackedVector2Array([c + Vector2(-36, -38) * k, c + Vector2(36, -38) * k, c + Vector2(32, 10) * k, c + Vector2(0, 44) * k, c + Vector2(-32, 10) * k])
			b.poly(sh, dk)
			b.poly(PackedVector2Array([c + Vector2(-30, -32) * k, c + Vector2(30, -32) * k, c + Vector2(26, 8) * k, c + Vector2(0, 36) * k, c + Vector2(-26, 8) * k]), col)
			for p in [Vector2(-14, -16), Vector2(12, -18), Vector2(-4, 6), Vector2(14, 12)]:
				b.circle(c + p * k, 6.0 * k, dk, 8)
			b.polyline(PackedVector2Array([c + Vector2(0, -30) * k, c + Vector2(-6, -8) * k, c + Vector2(4, 8) * k, c + Vector2(0, 30) * k]), Color(1, 1, 1, 0.4 + 0.3 * sin(t * 4.0)), 2.0 * k)
		"spiritowl":
			# an owl with wide glowing eyes, wings spread
			var flap := sin(t * 4.0) * 6.0
			for s in [-1.0, 1.0]:
				b.poly(PackedVector2Array([c + Vector2(s * 12, -6) * k, c + Vector2(s * 48, -18 - flap) * k, c + Vector2(s * 40, 6) * k, c + Vector2(s * 14, 18) * k]), dk)
			b.circle(c, 24.0 * k, col, 18)
			b.tri(c + Vector2(-20, -16) * k, c + Vector2(-14, -34) * k, c + Vector2(-6, -20) * k, col)
			b.tri(c + Vector2(20, -16) * k, c + Vector2(14, -34) * k, c + Vector2(6, -20) * k, col)
			for s2 in [-1.0, 1.0]:
				b.circle(c + Vector2(s2 * 10, -4) * k, 8.0 * k, dk, 12)
				b.circle(c + Vector2(s2 * 10, -4) * k, 4.0 * k, col.lightened(0.5), 10)
			b.tri(c + Vector2(-4, 4) * k, c + Vector2(4, 4) * k, c + Vector2(0, 12) * k, dk)
		"spear":
			b.line(c + Vector2(-40, 40) * k, c + Vector2(30, -30) * k, col, w)
			b.tri(c + Vector2(26, -22) * k, c + Vector2(44, -44) * k, c + Vector2(22, -38) * k, col)
			for i in 3:
				b.line(c + Vector2(-34 + i * 6, 30 - i * 6) * k, c + Vector2(-46 + i * 6, 30 - i * 6) * k, dk, 3.0 * k)
		"beast":
			# a mammoth's head: dome, trunk curling, tusks
			b.circle(c + Vector2(0, -10) * k, 30.0 * k, col, 20)
			b.circle(c + Vector2(-26, -4) * k, 16.0 * k, dk, 14)
			b.circle(c + Vector2(26, -4) * k, 16.0 * k, dk, 14)
			b.polyline(PackedVector2Array([c + Vector2(0, 10) * k, c + Vector2(2, 30) * k, c + Vector2(-8, 42) * k, c + Vector2(-16, 36) * k]), col, w * 1.3)
			for s3 in [-1.0, 1.0]:
				b.polyline(PackedVector2Array([c + Vector2(s3 * 10, 14) * k, c + Vector2(s3 * 24, 32) * k, c + Vector2(s3 * 38, 28) * k]), col, 4.0 * k)
			b.circle(c + Vector2(-10, -12) * k, 3.0 * k, dk, 6)
			b.circle(c + Vector2(10, -12) * k, 3.0 * k, dk, 6)


## A flickering tongue of flame, pointing up from its base.
static func _flame(b: Batch, base: Vector2, h: float, col: Color, t: float) -> void:
	var sway := sin(t * 9.0) * 0.18 * h
	var pts := PackedVector2Array([base + Vector2(-h * 0.42, 0), base + Vector2(-h * 0.3, -h * 0.5),
		base + Vector2(sway, -h * (1.0 + 0.1 * sin(t * 13.0))), base + Vector2(h * 0.3, -h * 0.45), base + Vector2(h * 0.42, 0),
		base + Vector2(0, h * 0.22)])
	b.poly(pts, col)
	b.poly(PackedVector2Array([base + Vector2(-h * 0.2, 0), base + Vector2(sway * 0.5, -h * 0.55), base + Vector2(h * 0.2, 0), base + Vector2(0, h * 0.12)]), col.darkened(0.35))
