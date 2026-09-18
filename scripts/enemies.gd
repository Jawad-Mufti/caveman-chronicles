## Level 1 critters: insect, lizard, falling stone, and the boar boss.
## Kept in one file so the whole bestiary for the stone age is in view.
class_name Bestiary
extends RefCounted


class Insect extends Critter:
	var anchor := Vector2.ZERO
	var t := 0.0

	func _setup() -> void:
		hp = 1
		damage = 1
		stomp_top = -14.0
		anchor = position
		t = randf() * 10.0
		add_circle_shape(12.0)

	func _tick(delta: float) -> void:
		t += delta
		var target := anchor + Vector2(sin(t * 1.3) * 90.0, sin(t * 2.7) * 30.0)
		if player != null and absf(player.global_position.x - global_position.x) < 380.0:
			# Follows him SIDEWAYS only. It must never climb to match a jump —
			# if it tracks his height he can never get above it to land on it.
			# The bob still dips it into head height, so it stays a real threat.
			target = Vector2(player.global_position.x, anchor.y + sin(t * 2.4) * 30.0)
		global_position = global_position.move_toward(target, 120.0 * delta)

	func _draw() -> void:
		var c := Pal.CHARCOAL
		var w := sin(t * 42.0) * 6.0
		draw_line(Vector2(0, -2), Vector2(-11, -9 - w), Pal.STONE, 2.0)
		draw_line(Vector2(0, -2), Vector2(11, -9 + w), Pal.STONE, 2.0)
		draw_circle(Vector2.ZERO, 7.0, c)
		draw_circle(Vector2(-7, 2), 5.0, c)
		draw_circle(Vector2(6, -1), 4.0, c)
		draw_circle(Vector2(8, -3), 1.2, Pal.EMBER)
		if flash > 0.0:
			draw_circle(Vector2.ZERO, 14.0, Color(1, 1, 1, 0.5))


class Lizard extends Critter:
	var left_x := 0.0
	var right_x := 0.0
	var dir := 1
	var speed := 120.0
	var t := 0.0

	func _setup() -> void:
		hp = 2
		damage = 1
		stomp_top = -16.0
		add_rect_shape(Vector2(46, 16), Vector2(0, -8))

	func _tick(delta: float) -> void:
		t += delta
		position.x += dir * speed * delta
		if position.x > right_x:
			dir = -1
		elif position.x < left_x:
			dir = 1

	func _on_hit(from_dir: int) -> void:
		position.x += from_dir * 22.0

	func _draw() -> void:
		var f := float(dir)
		var c := Pal.CHARCOAL
		var wig := sin(t * 14.0) * 4.0
		# tail
		draw_line(Vector2(-f * 20, -8), Vector2(-f * 40, -6 + wig), c, 4.0)
		# legs
		draw_line(Vector2(-f * 10, -8), Vector2(-f * 14 + wig, 0), c, 3.0)
		draw_line(Vector2(f * 10, -8), Vector2(f * 14 - wig, 0), c, 3.0)
		# body
		draw_polygon(PackedVector2Array([Vector2(-f * 22, -12), Vector2(f * 18, -14), Vector2(f * 22, -6), Vector2(f * 16, -2), Vector2(-f * 20, -3)]), PackedColorArray([c]))
		# head
		draw_circle(Vector2(f * 26, -10), 6.0, c)
		draw_circle(Vector2(f * 28, -12), 1.4, Pal.OCHRE)
		if flash > 0.0:
			draw_circle(Vector2(0, -8), 26.0, Color(1, 1, 1, 0.45))


class Stone extends Critter:
	var vy := 0.0
	var floor_y := 0.0
	var landed := false
	var rest := 2.5
	var spin := 0.0
	var r := 14.0

	func _setup() -> void:
		hp = 9999
		damage = 1
		stompable = false
		add_circle_shape(r)
		spin = randf_range(-3.0, 3.0)

	func take_hit(_dmg: int, _from_dir: int) -> void:
		pass

	func _tick(delta: float) -> void:
		if landed:
			rest -= delta
			modulate.a = clampf(rest / 0.6, 0.0, 1.0)
			if rest <= 0.0:
				queue_free()
			return
		vy += 1300.0 * delta
		position.y += vy * delta
		rotation += spin * delta
		if position.y >= floor_y:
			position.y = floor_y
			landed = true
			set_deferred("monitoring", false)

	func _draw() -> void:
		var pts := PackedVector2Array([
			Vector2(-r, -r * 0.3), Vector2(-r * 0.5, -r), Vector2(r * 0.4, -r * 0.9),
			Vector2(r, -r * 0.2), Vector2(r * 0.7, r * 0.8), Vector2(-r * 0.4, r)
		])
		draw_polygon(pts, PackedColorArray([Pal.STONE]))
		draw_polygon(PackedVector2Array([pts[0], pts[1], Vector2(0, 0)]), PackedColorArray([Pal.STONE_DARK]))


class Boar extends Critter:
	signal defeated
	signal woke

	var arena_l := 0.0
	var arena_r := 0.0
	var state := "sleep"
	var dir := -1
	var vx := 0.0
	var stun := 0.0
	var t := 0.0
	var max_hp := 12

	func _setup() -> void:
		hp = max_hp
		damage = 2
		stompable = false
		add_rect_shape(Vector2(104, 56), Vector2(0, -28))

	func wake() -> void:
		if state == "sleep":
			state = "stun"
			stun = 0.6
			woke.emit()

	func _tick(delta: float) -> void:
		t += delta
		match state:
			"sleep":
				pass
			"charge":
				vx = move_toward(vx, dir * 560.0, 1100.0 * delta)
				position.x += vx * delta
				var hit_wall := (dir > 0 and position.x >= arena_r - 60.0) or (dir < 0 and position.x <= arena_l + 60.0)
				if hit_wall:
					position.x = clampf(position.x, arena_l + 60.0, arena_r - 60.0)
					state = "stun"
					stun = 1.0
					vx = 0.0
			"stun":
				stun -= delta
				if stun <= 0.0 and player != null:
					dir = 1 if player.global_position.x > position.x else -1
					state = "charge"

	func _on_hit(_from_dir: int) -> void:
		if state == "charge":
			vx *= 0.6

	func _on_die() -> void:
		defeated.emit()

	func _draw() -> void:
		var f := float(dir)
		var c := Pal.CHARCOAL
		var running := state == "charge"
		var bob := sin(t * 18.0) * 3.0 if running else 0.0
		if state == "sleep":
			bob = sin(t * 2.0) * 2.0

		for i in 4:
			var lx := -34.0 + i * 22.0
			var sw := sin(t * 18.0 + i * 1.5) * 9.0 if running else 0.0
			draw_line(Vector2(lx, -22), Vector2(lx + sw, 0), c, 8.0)

		draw_set_transform(Vector2(0, -36 + bob), 0.0, Vector2(1.75, 1.0))
		draw_circle(Vector2.ZERO, 30.0, c)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

		draw_circle(Vector2(f * 48, -32 + bob), 19.0, c)
		draw_circle(Vector2(f * 64, -25 + bob), 8.0, Pal.OCHRE_DARK)
		draw_line(Vector2(f * 58, -20 + bob), Vector2(f * 72, -36 + bob), Pal.BONE, 4.0)
		var eye := Pal.EMBER if running else Pal.OCHRE
		if state == "sleep":
			draw_line(Vector2(f * 46, -38 + bob), Vector2(f * 54, -38 + bob), Pal.OCHRE, 2.0)
		else:
			draw_circle(Vector2(f * 50, -38 + bob), 2.6, eye)
		draw_polygon(PackedVector2Array([
			Vector2(-22, -62 + bob), Vector2(-12, -76 + bob), Vector2(0, -62 + bob),
			Vector2(12, -74 + bob), Vector2(24, -62 + bob)
		]), PackedColorArray([c]))

		if state == "stun":
			for i in 3:
				var a := t * 6.0 + i * 2.1
				draw_circle(Vector2(f * 48 + cos(a) * 22.0, -60 + sin(a) * 6.0), 3.0, Pal.BONE)
		if flash > 0.0:
			draw_set_transform(Vector2(0, -36), 0.0, Vector2(1.75, 1.0))
			draw_circle(Vector2.ZERO, 34.0, Color(1, 1, 1, 0.4))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


class Flytrap extends Critter:
	## A rooted snapping plant. It opens on a cycle and bites what is near it.
	## Deliberately NOT stompable: it snaps upward, so landing on it is a mistake.
	var t := 0.0
	var open := false
	var cycle := 2.2
	var phase := 0.0

	func _setup() -> void:
		hp = 3
		damage = 0
		stompable = false
		phase = randf() * cycle
		add_rect_shape(Vector2(40, 46), Vector2(0, -30))

	func _tick(delta: float) -> void:
		t += delta
		open = fmod(t + phase, cycle) < cycle * 0.45
		# harmless while shut, so the open window is the telegraph
		damage = 1 if open else 0

	func _draw() -> void:
		var c := Pal.CHARCOAL
		var sway := sin(t * 1.7) * 3.0
		var head := Vector2(sway, -40)
		# stem
		draw_line(Vector2(0, 0), head, Pal.OCHRE_DEEP, 7.0)
		# base leaves
		draw_polygon(PackedVector2Array([Vector2(-18, 0), Vector2(-5, -12), Vector2(0, 0)]), PackedColorArray([Pal.OCHRE_DARK]))
		draw_polygon(PackedVector2Array([Vector2(18, 0), Vector2(5, -12), Vector2(0, 0)]), PackedColorArray([Pal.OCHRE_DARK]))
		if open:
			# upper and lower jaw, spread apart
			draw_polygon(PackedVector2Array([head + Vector2(-17, -2), head + Vector2(0, -6), head + Vector2(17, -2), head + Vector2(0, -24)]), PackedColorArray([c]))
			draw_polygon(PackedVector2Array([head + Vector2(-15, 6), head + Vector2(15, 6), head + Vector2(0, 22)]), PackedColorArray([c]))
			for i in 5:
				var x := -13.0 + i * 6.5
				draw_line(head + Vector2(x, 0), head + Vector2(x + 2, 8), Pal.BONE, 2.0)
		else:
			draw_polygon(PackedVector2Array([head + Vector2(-14, 10), head + Vector2(0, -18), head + Vector2(14, 10)]), PackedColorArray([c]))
		if flash > 0.0:
			draw_circle(head, 26.0, Color(1, 1, 1, 0.45))


class Runner extends Critter:
	## One beast in the stampede. Stompable like any small thing, but they come
	## packed, so crushing one only drops you into the next. High ground is the answer.
	var speed := 430.0
	var dir := -1
	var despawn_x := -500.0
	var t := 0.0

	func _setup() -> void:
		hp = 1
		damage = 1
		stomp_top = -34.0
		t = randf() * 4.0
		add_rect_shape(Vector2(44, 36), Vector2(0, -18))

	func _tick(delta: float) -> void:
		t += delta
		position.x += dir * speed * delta
		if dir < 0 and position.x < despawn_x:
			queue_free()
		elif dir > 0 and position.x > despawn_x:
			queue_free()

	func _draw() -> void:
		var f := float(dir)
		var c := Pal.CHARCOAL
		var run := sin(t * 22.0)
		for i in 4:
			var lx := -14.0 + i * 10.0
			draw_line(Vector2(lx, -16), Vector2(lx + sin(t * 22.0 + i * 1.6) * 7.0, 0), c, 4.0)
		draw_polygon(PackedVector2Array([
			Vector2(-f * 22, -20), Vector2(f * 16, -24), Vector2(f * 22, -14), Vector2(f * 14, -8), Vector2(-f * 20, -8)
		]), PackedColorArray([c]))
		draw_circle(Vector2(f * 26, -24 + run * 2.0), 8.0, c)
		draw_line(Vector2(f * 24, -30), Vector2(f * 32, -40), Pal.BONE, 3.0)
		draw_circle(Vector2(f * 29, -26), 1.6, Pal.EMBER)
		if flash > 0.0:
			draw_circle(Vector2(0, -18), 26.0, Color(1, 1, 1, 0.45))
