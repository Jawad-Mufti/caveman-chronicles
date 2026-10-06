class_name FX
extends RefCounted
## Particles and shaders shared across the game.
##
## Particles use Godot's CPUParticles2D, which runs the same on every kind of
## device (the compatibility renderer included). Every particle is a soft
## round dot, coloured over its life by a ramp.
##   embers()  — a steady stream of embers rising from a fire (a node to add)
##   burst()   — a one-shot burst: "sparks", "dust", "embers" (frees itself)
## Shaders:
##   flash_material()   — a creature flashes white all over when struck
##   sway_material()    — plants sway in the wind, roots still, tips moving
##   shimmer()          — heat rippling the air above a fire

static var _dot: Texture2D
static var _flash: Shader
static var _sway: Shader
static var _shimmer: Shader


## A soft round dot, white in the middle fading to nothing at the edge.
static func dot() -> Texture2D:
	if _dot == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 32
		t.height = 32
		_dot = t
	return _dot


static func _ramp(cols: Array) -> Gradient:
	var g := Gradient.new()
	var offs := PackedFloat32Array()
	for i in cols.size():
		offs.append(float(i) / float(cols.size() - 1))
	g.offsets = offs
	g.colors = PackedColorArray(cols)
	return g


const FIRE := [Color(1.0, 0.95, 0.6, 1.0), Color(1.0, 0.6, 0.18, 0.95), Color(0.85, 0.22, 0.05, 0.6), Color(0.4, 0.1, 0.02, 0.0)]


## Embers rising from a fire, drifting and winking out. `width` is how wide
## the fire is; `k` scales their size.
static func embers(width: float = 26.0, amount: int = 14, k: float = 1.0) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.texture = dot()
	p.amount = amount
	p.lifetime = 1.5
	p.local_coords = false          # they stay where they were born as the fire moves
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(width, 3.0)
	p.direction = Vector2(0, -1)
	p.spread = 22.0
	p.gravity = Vector2(0, -70)
	p.initial_velocity_min = 25.0
	p.initial_velocity_max = 75.0
	p.tangential_accel_min = -30.0
	p.tangential_accel_max = 30.0
	p.damping_min = 8.0
	p.damping_max = 20.0
	p.scale_amount_min = 0.22 * k
	p.scale_amount_max = 0.45 * k
	p.color_ramp = _ramp(FIRE)
	return p


## A one-shot burst at `at` (in `parent`'s space). `dir` leans it left or right.
static func burst(parent: Node, at: Vector2, kind: String, dir: float = 0.0) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var p := CPUParticles2D.new()
	p.texture = dot()
	p.one_shot = true
	p.explosiveness = 0.95
	p.local_coords = false
	p.position = at
	match kind:
		"sparks":
			p.amount = 20
			p.lifetime = 0.45
			p.direction = Vector2(dir, -0.7).normalized() if dir != 0.0 else Vector2(0, -1)
			p.spread = 55.0
			p.initial_velocity_min = 220.0
			p.initial_velocity_max = 440.0
			p.gravity = Vector2(0, 900)
			p.scale_amount_min = 0.16
			p.scale_amount_max = 0.3
			p.color_ramp = _ramp([Color(1, 1, 0.9, 1), Color(1.0, 0.85, 0.35, 1), Color(1.0, 0.45, 0.1, 0.0)])
		"dust":
			p.amount = 12
			p.lifetime = 0.7
			p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
			p.emission_rect_extents = Vector2(22, 2)
			p.direction = Vector2(dir * 0.6, -1).normalized()
			p.spread = 75.0
			p.initial_velocity_min = 40.0
			p.initial_velocity_max = 130.0
			p.gravity = Vector2(0, -15)
			p.damping_min = 80.0
			p.damping_max = 140.0
			p.scale_amount_min = 0.45
			p.scale_amount_max = 1.0
			p.color_ramp = _ramp([Color(0.78, 0.7, 0.6, 0.55), Color(0.7, 0.64, 0.55, 0.3), Color(0.6, 0.55, 0.5, 0.0)])
		"kick":
			# a little dust kicked back off a running foot
			p.amount = 5
			p.lifetime = 0.4
			p.direction = Vector2(-dir, -0.6).normalized()
			p.spread = 25.0
			p.initial_velocity_min = 60.0
			p.initial_velocity_max = 120.0
			p.gravity = Vector2(0, 260)
			p.scale_amount_min = 0.3
			p.scale_amount_max = 0.6
			p.color_ramp = _ramp([Color(0.78, 0.7, 0.6, 0.5), Color(0.6, 0.55, 0.5, 0.0)])
		"ring":
			# a ring of air pushed out under a jump in mid-air
			p.amount = 16
			p.lifetime = 0.35
			p.direction = Vector2(0, 1)
			p.spread = 85.0
			p.initial_velocity_min = 220.0
			p.initial_velocity_max = 260.0
			p.damping_min = 500.0
			p.damping_max = 600.0
			p.scale_amount_min = 0.25
			p.scale_amount_max = 0.4
			p.color_ramp = _ramp([Color(1, 1, 1, 0.7), Color(0.85, 0.9, 1.0, 0.0)])
		"smoke":
			p.amount = 8
			p.lifetime = 0.9
			p.direction = Vector2(dir * 0.3, -1).normalized()
			p.spread = 30.0
			p.initial_velocity_min = 30.0
			p.initial_velocity_max = 70.0
			p.gravity = Vector2(0, -40)
			p.scale_amount_min = 0.35
			p.scale_amount_max = 0.75
			p.color_ramp = _ramp([Color(0.3, 0.28, 0.26, 0.55), Color(0.45, 0.43, 0.4, 0.35), Color(0.6, 0.58, 0.55, 0.0)])
		_:
			# embers: a puff of them
			p.amount = 12
			p.lifetime = 0.8
			p.direction = Vector2(dir * 0.5, -1).normalized()
			p.spread = 60.0
			p.initial_velocity_min = 60.0
			p.initial_velocity_max = 190.0
			p.gravity = Vector2(0, -60)
			p.scale_amount_min = 0.2
			p.scale_amount_max = 0.4
			p.color_ramp = _ramp(FIRE)
	parent.add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)


## ------------------------------------------------------------------ shaders
## The whole silhouette flashes white when struck. Set its "flash" (0..1).
static func flash_material() -> ShaderMaterial:
	if _flash == null:
		_flash = Shader.new()
		_flash.code = """shader_type canvas_item;
uniform float flash = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
void fragment() {
	COLOR.rgb = mix(COLOR.rgb, flash_color.rgb, flash);
}
"""
	var m := ShaderMaterial.new()
	m.shader = _flash
	return m


## Plants in the wind: their roots (at base_y) stay put, the higher a point
## the more it sways, each plant a little out of step with its neighbours.
static func sway_material(base_y: float, strength: float = 4.0) -> ShaderMaterial:
	if _sway == null:
		_sway = Shader.new()
		_sway.code = """shader_type canvas_item;
uniform float base_y = 566.0;
uniform float strength = 4.0;
void vertex() {
	float h = clamp((base_y - VERTEX.y) / 70.0, 0.0, 1.0);
	VERTEX.x += (sin(TIME * 1.6 + VERTEX.x * 0.031) + 0.4 * sin(TIME * 3.7 + VERTEX.x * 0.08)) * strength * h * h;
}
"""
	var m := ShaderMaterial.new()
	m.shader = _sway
	m.set_shader_parameter("base_y", base_y)
	m.set_shader_parameter("strength", strength)
	return m


## Heat rippling the air above a fire: a patch that bends what's behind it,
## strongest just above the flames and fading upward.
static func shimmer(w: float, h: float) -> ColorRect:
	if _shimmer == null:
		_shimmer = Shader.new()
		_shimmer.code = """shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float strength = 0.0035;
void fragment() {
	float fade = (1.0 - UV.y) * UV.y * 4.0 * (1.0 - abs(UV.x - 0.5) * 2.0);
	vec2 uv = SCREEN_UV;
	uv.x += sin(UV.y * 26.0 - TIME * 7.0) * strength * fade;
	uv.y += cos(UV.x * 18.0 + TIME * 5.0) * strength * 0.5 * fade;
	COLOR = vec4(texture(screen_tex, uv).rgb, fade);
}
"""
	var r := ColorRect.new()
	r.size = Vector2(w, h)
	r.position = Vector2(-w * 0.5, -h)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = _shimmer
	r.material = m
	return r
