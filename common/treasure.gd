## Treasure, Captain Claw style: shells lying along the paths (and hanging
## along jump arcs, showing the way), a few big ones tucked into secret spots,
## and hollow logs and termite mounds to smash open. Shells are the money: the
## trader and the Toolmaker take them for upgrades and skins.
##   shell 1 · conch 5 · amber 25
## Every piece has an id within its level; once taken it never comes back.
class_name Treasure
extends RefCounted

const VALUE := {"shell": 1, "conch": 5, "amber": 25}


static func shape_into(b: Batch, kind: String, at: Vector2) -> void:
	match kind:
		"shell":
			# a little cowrie
			var pts := PackedVector2Array()
			for i in 12:
				var a := TAU * i / 12.0
				pts.append(at + Vector2(cos(a) * 7.0, sin(a) * 5.0))
			b.poly(pts, Color("e9dcc0"))
			b.line(at + Vector2(-5, 0), at + Vector2(5, 0), Color("b79b72"), 1.5)
			b.circle(at + Vector2(-2, -2), 1.5, Color("fff6e4"), 6)
		"conch":
			# a spiral conch, pink at the lip
			var pts := PackedVector2Array([at + Vector2(-10, 4), at + Vector2(-6, -8), at + Vector2(4, -11), at + Vector2(11, -3),
				at + Vector2(8, 7), at + Vector2(-2, 9)])
			b.poly(pts, Color("e8c79c"))
			b.poly(PackedVector2Array([at + Vector2(-2, 9), at + Vector2(8, 7), at + Vector2(4, 2)]), Color("d98f86"))
			b.polyline(PackedVector2Array([at + Vector2(-5, -4), at + Vector2(0, -7), at + Vector2(5, -5), at + Vector2(6, 0)]), Color("b0845c"), 1.5)
		"amber":
			# a rough drop of amber with something trapped inside
			var pts := PackedVector2Array([at + Vector2(-9, 2), at + Vector2(-6, -10), at + Vector2(3, -13), at + Vector2(10, -4),
				at + Vector2(7, 8), at + Vector2(-3, 10)])
			b.poly(pts, Color("c9761f"))
			b.poly(PackedVector2Array([at + Vector2(-5, -1), at + Vector2(-3, -8), at + Vector2(3, -9), at + Vector2(1, -2)]), Color("f3b04a"))
			b.circle(at + Vector2(2, 3), 2.2, Color("5b3a14"), 8)


class Pickup extends Area2D:
	## One piece of treasure. Bobs gently where it lies; one popped out of a
	## log falls to the ground first.
	signal collected(value: int)
	var kind := "shell"
	var level_id := ""
	var id := ""
	var vel := Vector2.ZERO        ## for pieces popped out of something
	var floor_y := INF
	var t := 0.0
	var _base_y := 0.0
	var _gone := false

	func _ready() -> void:
		if GameState.is_taken(level_id, id):
			queue_free()
			return
		collision_layer = 0
		collision_mask = 2
		var cs := CollisionShape2D.new()
		var c := CircleShape2D.new()
		c.radius = 16.0 if kind == "shell" else 20.0
		cs.shape = c
		add_child(cs)
		body_entered.connect(_on_body)
		t = randf() * TAU
		_base_y = position.y
		if kind == "amber":
			add_to_group("glow")

	func _on_body(b: Node) -> void:
		if _gone or not (b is CaveMan) or vel != Vector2.ZERO:
			return
		_gone = true
		var v: int = VALUE[kind]
		GameState.take(level_id, id, v)
		collected.emit(v)
		var pop := FloatText.new()
		pop.text = "+%d" % v
		pop.position = global_position + Vector2(-8, -18)
		get_parent().call_deferred("add_child", pop)
		set_deferred("monitoring", false)
		call_deferred("queue_free")

	func _process(delta: float) -> void:
		t += delta
		if vel != Vector2.ZERO:
			vel.y += 1300.0 * delta
			position += vel * delta
			if position.y >= floor_y - 10.0 and vel.y > 0.0:
				position.y = floor_y - 10.0
				vel = Vector2.ZERO
				_base_y = position.y
				for body in get_overlapping_bodies():
					_on_body(body)
			return
		if LevelBase.near_view(self):
			# moved, not redrawn: the shape itself is drawn once
			position.y = _base_y + sin(t * 2.2) * 3.0

	func _draw() -> void:
		var b := Batch.new()
		if kind == "amber":
			b.circle(Vector2.ZERO, 14.0, Color("f3b04a", 0.18), 16)
		Treasure.shape_into(b, kind, Vector2.ZERO)
		b.draw(self)

	func draw_glow(g: Node2D) -> void:
		var s := absf(sin(t * 1.4))
		g.draw_circle(global_position, 8.0 + s * 5.0, Color("f3b04a", 0.12 + 0.12 * s))


class FloatText extends Node2D:
	## "+5" rising off a pickup.
	var text := ""
	var t := 0.0

	func _process(delta: float) -> void:
		t += delta
		position.y -= 40.0 * delta
		modulate.a = clampf(1.0 - t / 0.8, 0.0, 1.0)
		if t > 0.8:
			queue_free()

	func _draw() -> void:
		draw_string(ThemeDB.fallback_font, Vector2.ZERO, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("f3d08a"))


class Breakable extends Area2D:
	## Something to smash for what is inside: a hollow log (two hits) or a
	## termite mound (three). Whatever was inside and taken stays taken; the
	## rest comes back if the level is restarted.
	var kind := "log"               ## log, mound
	var contents: Array = []        ## kinds of treasure inside
	var level_id := ""
	var id := ""
	var hits := 2
	var _shake := 0.0
	var _base := Vector2.ZERO

	func _ready() -> void:
		collision_layer = 4          # his swing and his rocks find it
		collision_mask = 0
		monitoring = false
		hits = 3 if kind == "mound" else 2
		var cs := CollisionShape2D.new()
		var sh := RectangleShape2D.new()
		sh.size = Vector2(70, 36) if kind == "log" else Vector2(50, 70)
		cs.shape = sh
		cs.position = Vector2(0, -sh.size.y * 0.5)
		add_child(cs)
		_base = position

	func take_hit(_dmg: int, from_dir: int) -> void:
		if hits <= 0:
			return
		hits -= 1
		_shake = 0.25
		if hits > 0:
			return
		# burst: out comes everything not already taken
		for i in contents.size():
			var tid := "%s_%d" % [id, i]
			if GameState.is_taken(level_id, tid):
				continue
			var p := Pickup.new()
			p.kind = contents[i]
			p.level_id = level_id
			p.id = tid
			p.position = global_position + Vector2(0, -30)
			p.vel = Vector2(randf_range(-160, 160) - from_dir * 40.0, randf_range(-460, -300))
			p.floor_y = global_position.y
			var level := get_parent()
			if level.has_method("_on_treasure_popped"):
				level._on_treasure_popped(p)
			level.call_deferred("add_child", p)
		set_deferred("monitorable", false)
		call_deferred("queue_free")

	func _process(delta: float) -> void:
		if _shake > 0.0:
			_shake = maxf(_shake - delta, 0.0)
			position = _base + Vector2(sin(_shake * 90.0) * 4.0 * (_shake / 0.25), 0)

	func _draw() -> void:
		var b := Batch.new()
		if kind == "log":
			b.quad(Vector2(-36, -2), Vector2(-32, -34), Vector2(34, -32), Vector2(36, 0), Pal.BARK)
			b.line(Vector2(-30, -26), Vector2(30, -25), Pal.BARK_DARK, 3.0)
			b.line(Vector2(-30, -12), Vector2(30, -10), Pal.BARK_DARK, 3.0)
			b.circle(Vector2(34, -16), 16.0, Pal.DEADWOOD, 16)
			b.circle(Vector2(34, -16), 11.0, Pal.CAVE_DARK, 14)
			b.circle(Vector2(34, -16), 5.0, Color("f3d08a", 0.35), 8)   # something pale inside
		else:
			var pts := PackedVector2Array([Vector2(-26, 0), Vector2(-18, -30), Vector2(-10, -52), Vector2(-2, -70),
				Vector2(6, -58), Vector2(12, -40), Vector2(20, -22), Vector2(28, 0)])
			b.poly(pts, Color("9a7852"))
			b.poly(PackedVector2Array([Vector2(-18, 0), Vector2(-10, -40), Vector2(-2, -66), Vector2(4, -44), Vector2(10, 0)]), Color("b18d63"))
			for k in 6:
				b.circle(Vector2(-12 + k * 5, -8 - (k % 3) * 14), 2.2, Color("6c5236"), 8)
		b.draw(self)
