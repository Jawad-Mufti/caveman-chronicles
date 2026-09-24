class_name LevelBase
extends Node2D
## What every level shares: the caveman, the camera, the HUD, fall recovery,
## on-screen notes, restart, and the helpers that build the parallax bands.
## A level extends this and is left holding only its own data tables and its
## own set-pieces — which is the whole point: a new level is new tables.

var level_w := 9400.0
var fall_y := 1020.0
var cam_top := 0          ## raise (negative) for levels that climb
var title := ""
var player: CaveMan
var cam: Camera2D
var hud: Hud
var last_safe := Vector2(140, 600)
var last_safe_facing := 1
var finished := false
var gem_found := false
## Set by bonfires and the like. While there is one, death puts him back
## there after a beat instead of asking for a full restart.
var has_checkpoint := false
var checkpoint := Vector2.ZERO


func _build_player(start: Vector2) -> void:
	player = CaveMan.new()
	player.position = start
	last_safe = start
	add_child(player)

	cam = Camera2D.new()
	cam.limit_left = 0
	cam.limit_right = int(level_w)
	cam.limit_top = cam_top
	cam.limit_bottom = 1200
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 7.0
	add_child(cam)
	cam.make_current()


## Call after _build_player: the HUD listens to him.
func _build_hud(with_fire: bool = false) -> void:
	hud = Hud.new()
	hud.title = title
	add_child(hud)
	player.hp_changed.connect(func(v: int) -> void: hud.set_hp(v))
	player.berries_changed.connect(func(v: int) -> void: hud.set_berries(v))
	player.rocks_changed.connect(func(v: int) -> void: hud.set_rocks(v))
	player.wood_changed.connect(func(v: int) -> void: hud.set_wood(v))
	player.poultice.connect(func(_ok: bool, note: String) -> void: hud.say(note, 2.0))
	player.said.connect(func(note: String) -> void: hud.say(note, 2.5))
	player.died.connect(_on_died)
	if DisplayServer.is_touchscreen_available():
		hud.add_touch_controls(player, with_fire)


func set_checkpoint(at: Vector2) -> void:
	has_checkpoint = true
	checkpoint = at


func _on_died() -> void:
	if not has_checkpoint:
		hud.say("He did not make it. Press R.", 999.0)
		return
	hud.say("He did not make it.", 2.0)
	await get_tree().create_timer(2.2).timeout
	if not is_instance_valid(player) or not player.dead:
		return
	player.revive(checkpoint)
	last_safe = checkpoint
	hud.say("He wakes by the fire.", 2.5)


## ---------------------------------------------------------------- panorama
## A panorama band: no mirroring, and long enough to cover the whole level at
## this band's speed — a slower band needs less, because it moves less.
func _pano(pb: ParallaxBackground, art: World.Panorama, motion: Vector2) -> ParallaxLayer:
	art.s = motion.x
	art.length = (level_w - 1280.0) * motion.x + 1500.0
	var pl := ParallaxLayer.new()
	pl.motion_scale = motion
	pb.add_child(pl)
	pl.add_child(art)
	return pl


func _band(pb: ParallaxBackground, motion: Vector2, tile: float, art: Node2D) -> void:
	var pl := ParallaxLayer.new()
	pl.motion_scale = motion
	pl.motion_mirroring = Vector2(tile, 0)
	pb.add_child(pl)
	pl.add_child(art)


## A line of text the first time he walks past x.
func _note(x: float, text: String, seconds: float = 3.0) -> void:
	var t := World.Trigger.new(Rect2(x, 100, 60, 900))
	t.tripped.connect(func() -> void: hud.say(text, seconds))
	add_child(t)


func _process(_delta: float) -> void:
	cam.global_position = player.global_position + Vector2(0, -150)
	# the fire's wind-up trembles the view, and the release jolts it
	var shake := 0.0
	if player.fury >= 0.0:
		if player.fury < CaveMan.FURY_RELEASE:
			shake = 3.0 * player.fury / CaveMan.FURY_RELEASE
		else:
			shake = 8.0 * (1.0 - clampf((player.fury - CaveMan.FURY_RELEASE) / 0.25, 0.0, 1.0))
	cam.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * shake

	if player.is_on_floor() and not player.dead:
		last_safe = player.global_position
		last_safe_facing = player.facing
	if player.global_position.y > fall_y and not player.dead:
		# Set down well back from the lip he walked off, facing the way he came,
		# so he is not dropped straight back into the same hole.
		player.respawn_at(_safe_spot())
		player.facing = -last_safe_facing
		hud.say("He drags himself back up. That cost him.", 2.0)


## Back from the lip he fell off, facing the way he came — unless that would
## put him in the air (a narrow ledge), in which case right where he stood.
func _safe_spot() -> Vector2:
	var spot := last_safe + Vector2(-58.0 * last_safe_facing, -10.0)
	var q := PhysicsRayQueryParameters2D.create(spot + Vector2(0, -10), spot + Vector2(0, 60), 1)
	if get_world_2d().direct_space_state.intersect_ray(q).is_empty():
		spot = last_safe + Vector2(0, -10)
	return spot


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if (event as InputEventKey).physical_keycode == KEY_R:
			get_tree().reload_current_scene()
