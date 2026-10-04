class_name Abilities
extends RefCounted
## Everything he can do, as the Camp Menu shows it: a carved symbol for each,
## what it does, the keys, and how a locked one is earned. The symbols are
## drawn in code in ONE colour (plus a darker shade of it for depth), so all
## the unlocked ones glow the same sun-gold and the locked ones the same slate.

const GOLD := Color("ffc845")          ## every unlocked symbol
const SLATE := Color("5b6070")         ## every locked one

## [id, name, what it does, keys, how to unlock it]
const LIST := [
	["strike", "CLUB SWING", "Whack whatever is in reach. Tap again quickly for a combo.", "J  or  HIT", ""],
	["throw", "STONE TOSS", "Pick up rocks and throw them at things that bite back.", "K  or  THROW", ""],
	["leap", "HERCULES LEAP", "Jump again in mid-air: a somersault, then the spear pose and a softer fall.", "SPACE  twice", ""],
	["homerun", "HOME RUN", "Hold HIT to wind up the club, let go: beasts go flying.", "hold  J", "Find a club."],
	["torch", "TORCH", "Holds back the dark — and the wolves. Feed it at every bonfire.", "always lit", "Take a burning branch from a fire."],
	["firering", "FIRE RING", "Burn two bundles of wood: a ring of flame bursts out around him.", "F  or  FIRE", "Carry a torch."],
	["wallkick", "WALL KICK", "Between two close walls: slide down one, kick across to the other.", "hold toward wall + SPACE", "Climb the split rock on the Mammoth Steppe."],
	["slam", "HAMMER SLAM", "Raise the Firestone Hammer and SLAM: a wave of fire rolls along the ground.", "hold  J", "Forge the Firestone Hammer."],
	["axe", "AXE THROW", "Hurl the stone axe; it spins out and comes back to his hand.", "hold  J", "Trade for the stone axe."],
	["sunfire", "SUNFIRE", "Fire in both fists for 30 seconds! Faster, stronger, burning blows — and fireballs.", "Q  or  SUN  when the sun is full", "Light a cold fire with your own torch."],
	["spear", "SPEAR THROW", "The broken fang becomes a spear. Throw it far, and fetch it back.", "?", "Level 3."],
	["beast", "BEAST FRIEND", "Something big wants to be his friend...", "?", "Who knows?"],
]


## Is it his yet? Some come with the level, some are learned once and saved.
static func unlocked(id: String, p: CaveMan) -> bool:
	match id:
		"strike", "throw", "leap":
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
