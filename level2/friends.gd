## Animals who talk — not many, met in passing:
##   Moss    a sloth hanging from the fallen giant over the Hanging Gorge:
##           in no hurry about anything, least of all talking
##   Nutmeg  a giant beaver on the far bank of the Steppe's river, furious:
##           a monkey stole the red stone from her dam and rode off on the
##           old bull's back (it is the stone Old Bongo offers later)
## They are scenery with a face: the level starts the talk when he comes by.
class_name Friends
extends RefCounted


## ================================================================ MOSS
class Moss extends Node2D:
	## Hanging by all four claws from the trunk above, upside down, swaying a
	## little. Blinks very... slowly. The origin is where her claws grip.
	var speaking := false
	var asleep := false
	var _t := 0.0

	func _ready() -> void:
		_t = randf() * 5.0

	func _process(delta: float) -> void:
		_t += delta
		if NightWoods.near_view(self):
			queue_redraw()

	func _draw() -> void:
		var b := Batch.new()
		var fur := Color("7d6a52")
		var dark := Color("5a4a38")
		var face := Color("d9c7a3")
		var sway := sin(_t * 0.7) * 0.06
		b.set_xf(Transform2D(sway, Vector2.ZERO))
		# arms and legs up to the trunk, long claws hooked over it
		for gx in [-22.0, -8.0, 8.0, 22.0]:
			b.line(Vector2(gx * 0.6, 70), Vector2(gx, 4), dark if absf(gx) > 15.0 else fur, 9.0)
			for c in 3:
				b.line(Vector2(gx - 3.0 + c * 3.0, 4), Vector2(gx - 2.0 + c * 3.0, -6), Color("2b2219"), 2.0)
		# the body: a shaggy bag hanging down
		b.circle(Vector2(0, 92), 30.0, fur, 18)
		b.circle(Vector2(0, 118), 26.0, fur, 18)
		for k in 7:
			var hx := -24.0 + k * 8.0
			b.tri(Vector2(hx, 128), Vector2(hx + 8.0, 128), Vector2(hx + 4.0, 142.0 + sin(_t + k) * 2.0), dark)
		# moss in her fur (it's her name)
		b.circle(Vector2(-12, 86), 7.0, Color("5f8a46"), 8)
		b.circle(Vector2(10, 104), 5.0, Color("6f9a52"), 8)
		# the face, upside down at the bottom: pale, with dark eye stripes
		var f := Vector2(0, 150)
		# a furry rim, then a warm, round face
		b.circle(f, 25.0, fur, 18)
		b.circle(f + Vector2(0, 2), 21.0, face, 18)
		# the sloth's soft eye stripes, sloping down and out like a sleepy smile
		for s in [-1.0, 1.0]:
			b.poly(PackedVector2Array([f + Vector2(s * 4.0, -8), f + Vector2(s * 13.0, -7), f + Vector2(s * 18.0, 2),
				f + Vector2(s * 12.0, 3), f + Vector2(s * 5.0, -2)]), Color("6b5440"))
		var blink := asleep or fmod(_t, 4.2) < 0.9           # a long, slow blink
		for s in [-1.0, 1.0]:
			var e := f + Vector2(s * 9.0, -3)
			if blink:
				b.line(e + Vector2(-3.5, 0), e + Vector2(3.5, 1), Color("1a120c"), 2.0)
			else:
				b.circle(e, 3.6, Color("1a120c"), 10)
				b.circle(e + Vector2(-1, -1.2), 1.3, Color.WHITE, 6)
			b.circle(f + Vector2(s * 14.0, 9), 4.0, Color("e8a090", 0.7), 8)   # rosy cheeks
		b.circle(f + Vector2(0, 5), 4.5, Color("4a3426"), 10)            # nose
		# the mouth: a lazy smile, opening as she talks
		var open := (0.5 + 0.5 * sin(_t * 9.0)) if speaking else 0.0
		b.line(f + Vector2(-7, 11), f + Vector2(0, 14 + open * 4.0), Color("4a3426"), 2.2)
		b.line(f + Vector2(0, 14 + open * 4.0), f + Vector2(7, 11), Color("4a3426"), 2.2)
		b.draw(self)
		if asleep:
			# z... z... Z
			for k in 3:
				var q := fmod(_t * 0.5 + k * 0.33, 1.0)
				draw_string(ThemeDB.fallback_font, Vector2(26 + q * 30.0, 150 - q * 50.0), "z", HORIZONTAL_ALIGNMENT_LEFT, -1, 12 + k * 4, Color(1, 1, 1, 0.8 * (1.0 - q)))


## ================================================================ NUTMEG
class Nutmeg extends Node2D:
	## A giant beaver, up on her hind legs beside her little dam, flat tail
	## slapping the mud when she's cross — which is now. Origin: her feet.
	var speaking := false
	var calm := false            ## after the talk she settles down a bit
	var dirn := 1.0              ## 1: she faces left, toward the river (and him, coming off it)
	var _t := 0.0

	func _ready() -> void:
		_t = randf() * 5.0

	func _process(delta: float) -> void:
		_t += delta
		if NightWoods.near_view(self):
			queue_redraw()

	func _v(x: float, y: float) -> Vector2:
		return Vector2(x * dirn, y)

	func _draw() -> void:
		var b := Batch.new()
		var fur := Color("7a4e2c")
		var dark := Color("553520")
		var belly := Color("a8784c")
		# the dam behind her: a heap of sticks and mud
		for k in 9:
			var sx := 34.0 + k * 9.0
			b.line(_v(sx - 16.0, -2.0 - (k % 3) * 9.0), _v(sx + 22.0, -12.0 - (k % 4) * 8.0), Color("6b5236") if k % 2 == 0 else Color("4f3b27"), 5.0)
		b.circle(_v(70, -4), 22.0, Color("3b2e22"), 12)
		# the tail: a flat paddle, slapping when she's cross
		var slap := 0.0 if calm else maxf(0.0, sin(_t * 6.0))
		# a big flat paddle, scaly, lifting and smacking down on the mud
		var ang := (-0.15 - slap * 0.55) * dirn
		var tail := PackedVector2Array()
		for k in 16:
			var a := TAU * k / 16.0
			tail.append(_v(54, -8) + Vector2(cos(a) * 34.0 * dirn, sin(a) * 13.0).rotated(ang))
		b.poly(tail, Color("3a3333"))
		for k in 4:
			var c0 := _v(30.0 + k * 13.0, -8)
			b.line(c0 + Vector2(0, -9).rotated(ang), c0 + Vector2(0, 9).rotated(ang), Color("575050"), 1.5)
		b.line(_v(36, -18), _v(70, -2), Color("575050"), 1.2)
		# feet, body and belly
		b.circle(_v(-10, -4), 9.0, dark, 8)
		b.circle(_v(10, -4), 9.0, dark, 8)
		b.circle(_v(0, -34), 28.0, fur, 18)
		b.circle(_v(0, -58), 22.0, fur, 16)
		b.circle(_v(-4, -38), 18.0, belly, 14)
		# little arms: on her hips when cross, waving when she talks
		var wave := sin(_t * 10.0) * 8.0 if speaking else 0.0
		b.line(_v(-14, -56), _v(-26, -46 - wave), dark, 6.0)
		b.line(_v(12, -56), _v(22, -44), dark, 6.0)
		# head
		var h := _v(-6, -86)
		b.circle(h, 20.0, fur, 16)
		b.circle(h + _v(-14, -14), 6.0, dark, 8)      # ears
		b.circle(h + _v(10, -16), 6.0, dark, 8)
		b.circle(h + _v(-14, 4), 9.0, belly, 10)      # muzzle
		b.circle(h + _v(-20, 0), 4.0, Color("1a120c"), 8)   # nose
		# eyes: narrowed and cross, or round once she calms down
		var e := h + _v(-6, -6)
		if calm:
			b.circle(e, 3.5, Color("1a120c"), 8)
			b.circle(e + Vector2(-1, -1), 1.2, Color.WHITE, 6)
		else:
			b.circle(e, 3.0, Color("1a120c"), 8)
			b.line(e + _v(-5, -7), e + _v(5, -4), Color("1a120c"), 2.5)   # a scowl
		# the big orange teeth, chattering when she talks
		var chat := (0.5 + 0.5 * sin(_t * 18.0)) * 3.0 if speaking else 0.0
		b.rect(Rect2(h + _v(-18, 12) - Vector2(4, 0), Vector2(8, 9 + chat)), Color("e3943b"))
		b.line(h + _v(-18, 12), h + _v(-18, 21 + chat), Color("9a5a1c"), 1.2)
		# whiskers
		for k in 3:
			b.line(h + _v(-22, 6 + k * 3), h + _v(-34, 3 + k * 5), Color(1, 1, 1, 0.5), 1.0)
		b.draw(self)


## ================================================================ CREEK
class Creek extends Node2D:
	## The little creek Nutmeg has dammed: a strip of water over the ground,
	## ankle-deep — he walks straight through it. Origin: its left edge.
	var w := 70.0
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		if NightWoods.near_view(self):
			queue_redraw()

	func _draw() -> void:
		var b := Batch.new()
		b.poly(PackedVector2Array([Vector2(-8, 600), Vector2(w + 8, 600), Vector2(w, 612), Vector2(0, 612)]), Color("23415e"))
		b.rect(Rect2(0, 598, w, 3), Color("7fa6c9"))
		for k in 3:
			var x := fmod(k * 23.0 + _t * 30.0, w - 14.0)
			b.line(Vector2(x, 604), Vector2(x + 12.0, 604), Color("9cc3e0", 0.6), 1.5)
		b.draw(self)
