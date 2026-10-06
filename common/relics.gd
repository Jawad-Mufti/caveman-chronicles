class_name Relics
extends RefCounted
## RARE FINDS: the special things out at the edges of the world — up the
## highest sky lanes, deep in the burrows, inside weird creatures. They are
## not money: each is kept (GameState.relics) for building the shelter later.
## Every one has its own look, glows a little in its own colour, and makes a
## big moment when he picks it up.

## kind -> [name, what it is for, glow colour]
const KINDS := {
	"moonstone": ["MOONSTONE", "A pale stone that holds moonlight. A night-lamp for the shelter.", Color("bfe3ff")],
	"star_shard": ["STAR SHARD", "A splinter of a fallen star, warm to hold. It could light a whole hearth.", Color("ffd25a")],
	"giant_feather": ["GIANT FEATHER", "From a bird bigger than a mammoth. A roof that never leaks.", Color("ff8fd8")],
	"glow_crystal": ["GLOW CRYSTAL", "It shines by itself, deep underground. Walls that glow at night.", Color("6dffd8")],
	"amber_bug": ["AMBER BUG", "A beetle asleep in amber for a thousand winters. A charm for the door.", Color("ffae42")],
	"ivory": ["MAMMOTH IVORY", "Old ivory, smooth as water. Carved, it makes the strongest tools.", Color("f3ead2")],
	"bear_fang": ["CAVE BEAR FANG", "From the biggest bear that ever lived. Hung by the door, no wolf comes near.", Color("efe3c8")],
	"red_ochre": ["RED OCHRE", "The old ones' paint, from the Painted Cave. Pictures for the shelter walls.", Color("c8553d")],
}


static func name_of(kind: String) -> String:
	return KINDS[kind][0] if KINDS.has(kind) else kind.to_upper()


static func colour(kind: String) -> Color:
	return KINDS[kind][2] if KINDS.has(kind) else Color.WHITE


## The relic's picture, centred on c, about 2r across (for the world, the
## pick-up moment and the Shelter page).
static func draw_icon(b: Batch, kind: String, c: Vector2, r: float, t: float) -> void:
	var col := colour(kind)
	var dk := col.darkened(0.55)
	var k := r / 20.0
	match kind:
		"moonstone":
			b.ellipse(c, 15.0 * k, 13.0 * k, dk)
			b.ellipse(c + Vector2(0, -1) * k, 13.0 * k, 11.0 * k, col)
			b.ellipse(c + Vector2(4, -2) * k, 9.0 * k, 9.0 * k, Color(0.12, 0.18, 0.32, 0.55), 0.0)
			b.ellipse(c + Vector2(-5, -5) * k, 3.5 * k, 2.5 * k, Color(1, 1, 1, 0.9))
		"star_shard":
			var pts := PackedVector2Array()
			for i in 10:
				var rr := (18.0 if i % 2 == 0 else 7.0) * k
				pts.append(c + Vector2.from_angle(i * TAU / 10.0 - PI * 0.5 + sin(t) * 0.1) * rr)
			for i in 10:
				b.tri(c, pts[i], pts[(i + 1) % 10], col if i % 2 == 0 else col.darkened(0.2))
			b.circle(c, 4.0 * k, Color(1, 1, 0.9), 10)
		"giant_feather":
			var spine := c + Vector2(0, 18) * k
			for i in 9:
				var q := i / 8.0
				var at := spine.lerp(c + Vector2(4, -18) * k, q)
				var w := sin(q * PI) * 10.0 * k
				var hue := Color.from_hsv(fmod(0.85 + q * 0.4, 1.0), 0.45, 1.0)
				b.tri(at, at + Vector2(-w, -4.0 * k), at + Vector2(-w * 0.6, 3.0 * k), hue)
				b.tri(at, at + Vector2(w, -4.0 * k), at + Vector2(w * 0.6, 3.0 * k), hue.darkened(0.15))
			b.line(spine, c + Vector2(4, -18) * k, Color("fff3e0"), 2.0 * k)
		"glow_crystal":
			for i in 3:
				var off := Vector2(-8.0 + i * 8.0, 6.0) * k
				var h := (22.0 if i == 1 else 15.0) * k
				b.tri(c + off + Vector2(-5, 0) * k, c + off + Vector2(0, -h / k) * k, c + off + Vector2(5, 0) * k, col.darkened(0.25 if i != 1 else 0.0))
				b.tri(c + off + Vector2(-2, 0) * k, c + off + Vector2(0, -h / k + 4.0) * k, c + off + Vector2(1, 0) * k, Color(1, 1, 1, 0.6))
			b.rect(Rect2(c + Vector2(-14, 6) * k, Vector2(28, 5) * k), Color("3a3046"))
		"amber_bug":
			var drop := PackedVector2Array()
			for i in 14:
				var a := i * TAU / 14.0
				drop.append(c + Vector2(cos(a) * 14.0, sin(a) * 16.0 - (6.0 if sin(a) < -0.7 else 0.0)) * k)
			b.poly(drop, col)
			b.ellipse(c + Vector2(0, 2) * k, 5.0 * k, 7.0 * k, Color("3a220c"))
			for s in [-1.0, 1.0]:
				for j in 3:
					b.line(c + Vector2(s * 4.0, -2.0 + j * 4.0) * k, c + Vector2(s * 9.0, -4.0 + j * 5.0) * k, Color("3a220c"), 1.2 * k)
			b.ellipse(c + Vector2(-6, -7) * k, 3.0 * k, 2.0 * k, Color(1, 1, 1, 0.6))
		"ivory":
			var arc := PackedVector2Array()
			for i in 12:
				var q2 := i / 11.0
				arc.append(c + Vector2(-16.0 + 30.0 * q2, 12.0 - sin(q2 * PI * 0.85) * 26.0) * k)
			b.polyline(arc, dk, 9.0 * k)
			b.polyline(arc, col, 6.0 * k)
			for i in 3:
				b.line(arc[3 + i * 2] + Vector2(-2, 2) * k, arc[3 + i * 2] + Vector2(2, -2) * k, Color("b8ab8a"), 1.5 * k)
		"bear_fang":
			# a great curved fang on a cord
			b.line(c + Vector2(-16, -14) * k, c + Vector2(16, -14) * k, Color("8a6a48"), 2.0 * k)
			var fang := PackedVector2Array([c + Vector2(-8, -14) * k, c + Vector2(8, -14) * k, c + Vector2(6, 0) * k, c + Vector2(0, 14) * k, c + Vector2(-5, 2) * k])
			b.tri(fang[0], fang[1], fang[2], dk)
			b.tri(fang[0], fang[2], fang[3], col)
			b.tri(fang[0], fang[3], fang[4], col)
			b.line(c + Vector2(-3, -10) * k, c + Vector2(-1, 6) * k, Color(1, 1, 1, 0.6), 1.6 * k)
		"red_ochre":
			# a lump of red earth, and a red hand print beside it
			b.ellipse(c + Vector2(-5, 4) * k, 11.0 * k, 9.0 * k, dk, 0.3)
			b.ellipse(c + Vector2(-6, 2) * k, 10.0 * k, 8.0 * k, col, 0.3)
			b.ellipse(c + Vector2(9, -6) * k, 5.0 * k, 6.0 * k, col.lightened(0.15))
			for f in 4:
				b.line(c + Vector2(6.0 + f * 2.6, -10) * k, c + Vector2(4.0 + f * 3.4, -18) * k, col.lightened(0.15), 2.0 * k)
			b.ellipse(c + Vector2(-9, -1) * k, 3.0 * k, 2.0 * k, Color(1, 0.85, 0.75, 0.6))
		_:
			b.circle(c, 14.0 * k, col, 14)


## ================================================================ RELIC
class Relic extends Area2D:
	## A rare find lying out in the world: it floats, turns gently, glows in
	## its colour with rays turning behind it, and sparkles. Touch it to keep.
	signal found(kind: String)
	var kind := "moonstone"
	var level_id := ""
	var id := ""
	var _t := 0.0
	var _base := Vector2.ZERO

	func _ready() -> void:
		if GameState.is_taken(level_id, id):
			queue_free()
			return
		collision_layer = 0
		collision_mask = 2
		var cs := CollisionShape2D.new()
		var c := CircleShape2D.new()
		c.radius = 26.0
		cs.shape = c
		add_child(cs)
		body_entered.connect(_on_body)
		add_to_group("glow")
		_base = position
		_t = randf() * 6.0
		z_index = 3

	func _on_body(b: Node) -> void:
		if not (b is CaveMan):
			return
		GameState.take(level_id, id, 0)
		GameState.add_relic(kind)
		found.emit(kind)
		var pop := Moment.new()
		pop.kind = kind
		pop.position = global_position
		get_parent().add_child.call_deferred(pop)
		set_deferred("monitoring", false)
		queue_free()

	func _process(delta: float) -> void:
		_t += delta
		if LevelBase.near_view(self):
			position = _base + Vector2(0, sin(_t * 2.0) * 5.0)
			queue_redraw()

	func _draw() -> void:
		var b := Batch.new()
		var col := Relics.colour(kind)
		for i in 10:
			var a := i * TAU / 10.0 + _t * 0.5
			b.tri(Vector2.from_angle(a + 0.12) * 16.0, Vector2.from_angle(a) * (40.0 + 6.0 * sin(_t * 3.0 + i)), Vector2.from_angle(a - 0.12) * 16.0, Color(col, 0.22))
		Relics.draw_icon(b, kind, Vector2.ZERO, 20.0, _t)
		b.draw(self)

	func draw_glow(g) -> void:   # g: the glow layer's Batch
		var o := global_position
		var col := Relics.colour(kind)
		g.draw_circle(o, 34.0 + 4.0 * sin(_t * 2.5), Color(col, 0.22))
		var spark := fmod(_t * 0.8, 1.6)
		if spark < 0.4:
			var k := sin(spark / 0.4 * PI)
			Treasure.glint(g, o + Vector2(12, -12), 10.0 * k, Color(1, 1, 1, k))


## ================================================================ MOMENT
class Moment extends Node2D:
	## The pick-up: the relic grows over his head in a burst of its colour,
	## with its name and "for the shelter", then floats up and fades.
	var kind := "moonstone"
	var t := 0.0

	func _ready() -> void:
		z_index = 30
		add_to_group("glow")

	func _process(delta: float) -> void:
		t += delta
		if t > 2.4:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var b := Batch.new()
		var col := Relics.colour(kind)
		var up := Vector2(0, -60.0 - 30.0 * minf(t, 1.0) - 20.0 * maxf(t - 1.6, 0.0))
		var pop := minf(t / 0.25, 1.0)
		var s := (0.5 + 1.0 * pop) * (1.0 + 0.05 * sin(t * 10.0))
		var a := clampf((2.4 - t) / 0.6, 0.0, 1.0)
		for i in 14:
			var ang := i * TAU / 14.0 + t
			b.tri(up + Vector2.from_angle(ang + 0.1) * 20.0, up + Vector2.from_angle(ang) * (70.0 * pop), up + Vector2.from_angle(ang - 0.1) * 20.0, Color(col, 0.35 * a))
		if t < 0.15:
			b.circle(up, 60.0 * (1.0 - t / 0.15) + 10.0, Color(1, 1, 1, 0.7), 24)
		Relics.draw_icon(b, kind, up, 22.0 * s, t)
		b.draw(self)
		var f := ThemeDB.fallback_font
		var title := "RARE FIND: " + Relics.name_of(kind)
		var w := f.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
		draw_string(f, up + Vector2(-w * 0.5 + 2, -48), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0, 0, 0, 0.6 * a))
		draw_string(f, up + Vector2(-w * 0.5, -50), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(col.lightened(0.3), a))
		var sub := "kept for the shelter"
		var w2 := f.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		draw_string(f, up + Vector2(-w2 * 0.5, -30), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, 0.8 * a))

	func draw_glow(g) -> void:   # g: the glow layer's Batch
		var col := Relics.colour(kind)
		g.draw_circle(global_position + Vector2(0, -80), 60.0, Color(col, 0.3 * clampf((2.4 - t) / 0.6, 0.0, 1.0)))
