extends Node3D
## A part of the home (shelter/home.gd) in a file of its own: nature, the bone
## builds, the relics, the visits. The home makes each one first thing in
## _ready (`home` set; `reserved()` keeps trees and rocks off its ground), adds
## it and calls build() before it merges its still shapes (anything that
## moves, glows or changes goes in movers()). E on one of its spots: use(id).
## Shapes come from the home's own helpers, so they bake like the rest.

const MirrorKind := preload("res://shelter/mirror.gd")

var home: Node3D


func build() -> void:
	pass


## E at `id` (a spot): true if it was this system's.
func use(_id: String) -> bool:
	return false


## Ground this system keeps clear (no trees, rocks, flowers on it).
func reserved(_p: Vector2, _pad: float) -> bool:
	return false


## Nodes the home must not merge into its still mesh.
func movers() -> Array:
	return []


## He bounced off one of the pads (home.add_pad, with "bounce").
func bounced(_pad: Dictionary) -> void:
	pass


## ---- helpers
func ground(x: float, z: float) -> float:
	return home.height(x, z)


func at_ground(x: float, z: float, up := 0.0) -> Vector3:
	return Vector3(x, home.height(x, z) + up, z)


func shape(mesh: Mesh, col: Color, at: Vector3, rot := Vector3.ZERO, scl := Vector3.ONE, parent: Node3D = null) -> MeshInstance3D:
	return home._shape(mesh, col, at, rot, scl, parent if parent != null else self)


func ball(r: float, segs := 6) -> SphereMesh:
	return home._ball(r, segs)


func cyl(r: float, h: float, segs := 7, top := -1.0) -> CylinderMesh:
	return home._cyl(r, h, segs, top)


func cone(r: float, h: float, segs := 8) -> CylinderMesh:
	return home._cone(r, h, segs)


## Something that glows by itself (never merged).
func glowing(mesh: Mesh, col: Color, energy: float, at: Vector3, rot := Vector3.ZERO, scl := Vector3.ONE, parent: Node3D = null) -> MeshInstance3D:
	var m := shape(mesh, col, at, rot, scl, parent)
	m.material_override = home._glow(col, energy)
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return m


## A node to hang moving things on.
func pivot(at: Vector3, parent: Node3D = null) -> Node3D:
	var n := Node3D.new()
	n.position = at
	(parent if parent != null else self).add_child(n)
	return n


## 0 noon .. 1 deep night.
func night() -> float:
	return home._night


## Where Ugu is (world).
func ugu() -> Vector3:
	return home._pos


## A word that pops up in the world and floats away ("BOING!", "+12 SHELLS").
func pop_word(text: String, at: Vector3, col := Color("ffe066"), size := 72) -> void:
	var l := Label3D.new()
	l.text = text
	l.font = Pal.title_font()
	l.font_size = size
	l.pixel_size = 0.006
	l.outline_size = 16
	l.modulate = col
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.position = at
	l.layers = MirrorKind.LAYER_LABELS
	home.add_child(l)
	var tw := l.create_tween().set_parallel(true)
	tw.tween_property(l, "position", at + Vector3(0, 1.4, 0), 1.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 1.3).set_delay(0.5)
	tw.chain().tween_callback(l.queue_free)


## A puff of particles (dust, sparkles), gone by itself.
func puff(at: Vector3, col: Color, n := 18, speed := 2.0, glow := false, up := 1.0) -> void:
	var p: CPUParticles3D = home._particles(n, 0.9, col, 0.05, 0.14, glow)
	p.one_shot = true
	p.explosiveness = 0.9
	p.direction = Vector3.UP
	p.spread = 70.0
	p.initial_velocity_min = speed * 0.5
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, -2.0 * up, 0)
	p.position = at
	home.add_child(p)
	p.emitting = true
	get_tree().create_timer(1.6).timeout.connect(p.queue_free)


## The shelter's own save (GameState.shelter): one key.
func saved(key: String, default: Variant) -> Variant:
	return GameState.shelter.get(key, default)


func save_key(key: String, value: Variant) -> void:
	GameState.shelter[key] = value
	GameState.save()


func now() -> float:
	return Time.get_unix_time_from_system()
