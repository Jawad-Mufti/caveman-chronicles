extends Node
## Test harness (not shipped): generates the mountain's text map (for
## level2_data.gd MOUNTAIN_MAP) from a few shapes, and prints it.
## Grid: 40 px; column c is at x = 5640 + 40 c (to 12080); row r at y = -540 + 40 r.
## Flat ground on solid row R lies at y = -560 + 40 R.
const W := 162
const H := 46
var g: Array = []        # rows of chars (Array of Array[String])

func put(c: int, r: int, ch: String) -> void:
	if c >= 0 and c < W and r >= 0 and r < H:
		g[r][c] = ch

func at(c: int, r: int) -> String:
	if c >= 0 and c < W and r >= 0 and r < H:
		return g[r][c]
	return " "

## A tunnel: a chain of capsules (radius in cells) through the points.
func tunnel(pts: Array, rad: float, ch := ".") -> void:
	for i in pts.size() - 1:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var n := int(ceil(a.distance_to(b) * 3.0)) + 1
		for k in n + 1:
			var p := a.lerp(b, float(k) / n)
			ellipse(p, rad, rad, ch)

func ellipse(c: Vector2, rx: float, ry: float, ch := ".") -> void:
	for r in range(int(c.y - ry) - 1, int(c.y + ry) + 2):
		for cc in range(int(c.x - rx) - 1, int(c.x + rx) + 2):
			var d := Vector2((cc - c.x) / rx, (r - c.y) / ry)
			if d.length_squared() <= 1.0:
				put(cc, r, ch)

func rect(c0: int, r0: int, c1: int, r1: int, ch: String) -> void:
	for r in range(r0, r1 + 1):
		for c in range(c0, c1 + 1):
			put(c, r, ch)

## Re-material solid cells only.
func paint(c: Vector2, rx: float, ry: float, ch: String) -> void:
	for r in range(int(c.y - ry) - 1, int(c.y + ry) + 2):
		for cc in range(int(c.x - rx) - 1, int(c.x + rx) + 2):
			var d := Vector2((cc - c.x) / rx, (r - c.y) / ry)
			if d.length_squared() <= 1.0 and at(cc, r) == "#":
				put(cc, r, ch)

func _ready() -> void:
	for r in H:
		var row: Array = []
		for c in W:
			row.append(" ")
		g.append(row)
	# ---- the outside: top solid row per column (the climb, left to right)
	var top := []
	top.resize(W)
	var prof := [
		[0, 29], [1, 28], [2, 27], [3, 26], [5, 26],          # the foot, up to the first step (480)
		[6, 32], [10, 32],                                     # the crevice (720)
		[11, 21], [16, 21],                                    # the boulder shelf (280)
		[17, 18], [19, 18],                                    # the bat ledge (160): a jump up
		[20, 16], [24, 16],                                    # (80)
		[25, 13], [34, 13],                                    # the dead-tree shelf (-40)
		[35, 10], [37, 10],                                    # the second bat ledge (-160)
		[38, 7], [51, 7],                                      # the summit (-280)
		[52, 10], [55, 10],                                    # down: the first Moonpuff (-160)
		[56, 13], [60, 13],                                    # (-40), the totem
		[61, 16], [64, 16],                                    # the second Moonpuff (80)
		[65, 18], [82, 18],                                    # THE SADDLE (160): a high valley, a cave mouth in its floor
		[83, 15], [86, 15],                                    # up again (40)
		[87, 12], [90, 12],                                    # (-80)
		[91, 9], [94, 9],                                      # (-200)
		[95, 6], [98, 6],                                      # (-320)
		[99, 3], [112, 3],                                     # THE HIGH PEAK (-440)
		[113, 6], [116, 6],                                    # the long way down (-320)
		[117, 9], [120, 9],                                    # (-200)
		[121, 12], [126, 12],                                  # a Moonpuff (-80)
		[127, 15], [131, 15],                                  # (40)
		[132, 18], [137, 18],                                  # a Moonpuff (160)
		[138, 21], [143, 21],                                  # (280)
		[144, 24], [149, 24],                                  # the third Moonpuff (400)
		[150, 26], [154, 26],                                  # (480)
		[155, 28], [156, 29], [161, 29],                       # back to the ground (600), flat into the Steppe
	]
	for i in prof.size() - 1:
		var a: Array = prof[i]
		var b: Array = prof[i + 1]
		for c in range(a[0], b[0] + 1):
			# steps are kept as steps (cliffs), runs between equal heights stay flat
			top[c] = a[1] if c < b[0] else b[1]
	for c in W:
		for r in range(top[c], H):
			put(c, r, "#")
	# the crevice: a slot down into the rock, open to the sky
	rect(6, 26, 10, 31, " ")
	# the ledges in the crevice: the way back out (on the left wall), and the step above (385)
	rect(6, 29, 7, 30, "#")
	rect(8, 24, 9, 25, "#")
	# the lookout: a rock high above the summit's left end (-480)
	rect(38, 2, 39, 3, "#")
	# ---- the deep earth: strata below the base, along a wavy line
	for c in W:
		var line := 35 + int(round(1.4 * sin(c * 0.33) + 0.9 * sin(c * 0.11 + 1.0)))
		for r in range(line, H):
			if at(c, r) == "#":
				put(c, r, "=")
	# ---- inside: tunnels and chambers
	# Echo Tunnel: from the crevice floor, east and up into the Crystal Grotto
	tunnel([Vector2(10.5, 31.0), Vector2(14.0, 31.5), Vector2(17.0, 30.5)], 1.6)
	ellipse(Vector2(21.5, 30.0), 4.8, 2.6)                    # Crystal Grotto
	paint(Vector2(21.5, 30.5), 7.0, 4.5, "o")
	# from the grotto, a short, level tunnel east into the Bone Hall
	tunnel([Vector2(25.5, 30.3), Vector2(29.5, 29.6)], 1.5)
	ellipse(Vector2(34.5, 27.2), 5.5, 2.6)                    # Bone Hall (floor ~ y 620)
	# THE CHIMNEY: a straight slot from the hall's right end up to the summit. Its two
	# walls are kick walls (MT_CHIMNEY in level2_data): wall to wall, up, up, UP.
	rect(42, 9, 43, 28, ".")
	rect(40, 26, 41, 28, ".")                                # (opening into the hall)
	# its mouth on the summit: the same width (a root mat lies over it, MT_LIDS)
	rect(39, 7, 45, 8, "#")
	rect(42, 7, 43, 8, ".")
	# down from the grotto, deep into the strata: the Painted Cave
	tunnel([Vector2(19.0, 32.0), Vector2(22.0, 34.5), Vector2(26.0, 35.0)], 1.4)
	ellipse(Vector2(31.0, 36.0), 5.0, 2.3)                    # Painted Cave
	paint(Vector2(31.0, 36.5), 7.0, 4.0, "d")
	# ---- the east: under the saddle and the High Peak
	# the Bone Hall goes on east: a long tunnel under the summit to the Great Cavern
	# (from the Painted Cave's east end, deep under the Chimney)
	tunnel([Vector2(35.5, 36.3), Vector2(42.0, 35.2), Vector2(50.0, 33.4), Vector2(58.0, 31.6), Vector2(63.0, 30.5)], 1.5)
	ellipse(Vector2(73.0, 30.0), 10.0, 4.2)                   # THE GREAT CAVERN (glowcaps bounce you up its walls)
	paint(Vector2(73.0, 31.0), 13.0, 6.0, "o")
	# the cave mouth in the saddle floor, winding down into it
	tunnel([Vector2(73.5, 18.5), Vector2(71.5, 21.5), Vector2(74.5, 24.0), Vector2(73.0, 26.5)], 1.5)
	# a ledge high on the cavern's east wall, under the mouth
	rect(80, 28, 82, 29, "#")
	# down from the cavern into the strata: the Deep Hollow
	tunnel([Vector2(66.0, 33.0), Vector2(64.0, 36.0), Vector2(67.0, 38.5)], 1.4)
	ellipse(Vector2(72.0, 39.5), 5.5, 2.3)                    # THE DEEP HOLLOW
	# east from the cavern, up to the Bat Roost
	tunnel([Vector2(82.5, 30.5), Vector2(88.0, 28.5), Vector2(92.0, 25.5)], 1.5)
	ellipse(Vector2(97.5, 23.5), 5.5, 2.6)                    # THE BAT ROOST
	# THE EAGLE SHAFT: from the roost straight up to the High Peak, kick walls (MT_CHIMNEY2)
	rect(104, 5, 105, 23, ".")
	rect(102, 21, 103, 23, ".")
	rect(101, 3, 108, 4, "#")
	rect(104, 3, 105, 4, ".")
	# from the roost east, a long gallery under the descent to the Glow Hollow
	tunnel([Vector2(102.5, 25.0), Vector2(112.0, 27.0), Vector2(124.0, 28.0), Vector2(136.0, 28.0), Vector2(142.0, 28.5)], 1.5)
	ellipse(Vector2(147.0, 28.6), 4.5, 2.3)                   # THE GLOW HOLLOW
	tunnel([Vector2(151.0, 28.8), Vector2(154.5, 27.4), Vector2(156.0, 26.6)], 1.4)  # out onto the east slope
	# whatever was carved above the surface is open sky, not a tunnel
	for c in W:
		for r in range(0, top[c]):
			if at(c, r) == ".":
				put(c, r, " ")
	# the lookout rock, high above the summit's left end (-480): a double jump
	rect(38, 2, 39, 3, "#")
	# the crevice stays open to the sky (carved last, over the tunnel mouth)
	rect(6, 26, 9, 31, " ")
	rect(6, 29, 7, 30, "#")
	# print
	print("MAP_BEGIN")
	for r in H:
		print("\t\"" + "".join(PackedStringArray(g[r])) + "\",")
	print("MAP_END")
	get_tree().quit()
