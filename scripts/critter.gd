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


## True when the player is falling and his feet are still above this critter's back.
func _is_stomp() -> bool:
	if not stompable or dying > 0.0 or player == null:
		return false
	if player.velocity.y <= 40.0:
		return false
	return player.global_position.y <= global_position.y + stomp_top + 10.0


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
			player.stomp_bounce()
		elif damage > 0:
			player.hurt(damage, global_position.x)

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
