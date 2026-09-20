class_name Critter
extends Area2D
## Base for everything that can hurt the caveman or be hit by him.
## Subclasses set up their shape in _setup, move in _tick, and draw themselves.

var hp := 1
var damage := 1
var flash := 0.0
var dying := 0.0
var player: CaveMan

## Stomping. Landing on a critter from above crushes it.
## Big or spiked things set stompable = false so the player learns the exception.
var stompable := true
var stomp_top := -14.0    ## y offset of this critter's top, relative to its origin
var stomp_damage := 99    ## a clean landing kills almost anything small
var stomp_push := 0.0     ## sideways shove handed to the player, so big things throw him clear
var _prev_feet := -1000000.0   ## where his feet were last frame, so fast falls still register
var _prev_vy := 0.0            ## and how fast he was going, so the landing frame still counts


func _ready() -> void:
	collision_layer = 4
	collision_mask = 2
	monitoring = true
	monitorable = true
	_setup()


func _setup() -> void:
	pass


func _tick(_delta: float) -> void:
	pass


func _on_hit(_from_dir: int) -> void:
	pass


func _on_die() -> void:
	pass


func _on_stomped() -> void:
	pass


func take_hit(dmg: int, from_dir: int) -> void:
	if dying > 0.0:
		return
	hp -= dmg
	flash = 0.15
	_on_hit(from_dir)
	if hp <= 0:
		dying = 0.35
		set_deferred("monitoring", false)
		set_deferred("monitorable", false)
		_on_die()


## True when he is coming down and his feet are above this critter's back.
## Checks last frame as well as this one: at full fall speed he covers ~10 px
## per physics step, so a single-frame test misses the landing entirely.
func _is_stomp() -> bool:
	if not stompable or dying > 0.0 or player == null:
		return false
	# Landing on the floor zeroes his fall speed in the SAME frame he touches a
	# ground-level critter, so testing only the current velocity makes anything
	# standing on the floor impossible to stomp. Last frame's speed counts too.
	if player.velocity.y <= 40.0 and _prev_vy <= 40.0:
		return false
	# The faster he is falling, the further past the ideal point he will be by
	# the time this runs, so the allowance grows with fall speed.
	var slack := 18.0 + maxf(player.velocity.y, 0.0) * 0.035
	var line := global_position.y + stomp_top + slack
	return player.global_position.y <= line or _prev_feet <= line


func _physics_process(delta: float) -> void:
	flash = maxf(flash - delta, 0.0)
	if dying > 0.0:
		dying -= delta
		modulate.a = clampf(dying / 0.35, 0.0, 1.0)
		if dying <= 0.0:
			queue_free()
			return
		queue_redraw()
		return

	if player == null:
		var p := get_tree().get_first_node_in_group("player")
		if p != null:
			player = p as CaveMan

	_tick(delta)

	if player != null and not player.dead and overlaps_body(player):
		if _is_stomp():
			_on_stomped()
			take_hit(stomp_damage, 0)
			# bounce him off to whichever side he landed on, so he cannot keep
			# dropping onto the same back over and over
			var away := signf(player.global_position.x - global_position.x)
			if away == 0.0:
				away = float(player.facing)
			player.stomp_bounce(stomp_push * away)
		elif damage > 0:
			player.hurt(damage, global_position.x)

	if player != null:
		_prev_feet = player.global_position.y
		_prev_vy = player.velocity.y

	queue_redraw()


func add_circle_shape(radius: float, offset: Vector2 = Vector2.ZERO) -> void:
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = radius
	cs.shape = c
	cs.position = offset
	add_child(cs)


func add_rect_shape(size: Vector2, offset: Vector2 = Vector2.ZERO) -> void:
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = size
	cs.shape = r
	cs.position = offset
	add_child(cs)
