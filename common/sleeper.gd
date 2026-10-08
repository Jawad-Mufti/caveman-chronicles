class_name Sleeper
extends Node
## DON'T SIMULATE WHAT NOBODY SEES. Things that only matter near him (treasure
## bobbing where it lies, beasts going about their business, swarms) are
## enrolled; far from the camera they are switched off (process_mode DISABLED:
## no _process, no _physics_process), and back on before they come into view.
## Their collisions stay (DISABLE_MODE_KEEP_ACTIVE), so nothing ever falls
## through anything, and a node's own set_process() choices are untouched.
## A level has one (LevelBase). With ~800 things asleep a big level saves about
## a quarter of its frame time (tools/farcost).
##
## Enrol with Sleeper.enrol(self) in _ready. Never enrol what must act while
## unseen: a boss that hunts a whole area, a level-wide manager, a moving
## platform he may be riding, a projectile that frees itself as it flies.
const GROUP := "sleeps"
const WAKE := 650.0         ## awake within this far past the edge of the view
const DOZE := 900.0         ## asleep beyond this (the gap keeps them from flickering)
const SLICES := 6           ## each thing is looked at every 6th frame

var _slice := 0
var _modes := {}            ## instance id -> its process_mode before it slept


static func enrol(n: Node) -> void:
	n.add_to_group(GROUP)
	if n is CollisionObject2D:
		(n as CollisionObject2D).disable_mode = CollisionObject2D.DISABLE_MODE_KEEP_ACTIVE


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS        # (the world can be paused: it still keeps count)


func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return
	var c := cam.get_screen_center_position()
	var half := get_viewport().get_visible_rect().size * 0.5 / cam.zoom
	var all := get_tree().get_nodes_in_group(GROUP)
	for i in range(_slice, all.size(), SLICES):
		var n := all[i] as Node2D
		if n == null:
			continue
		var d := (n.global_position - c).abs() - half
		var out := maxf(d.x, d.y)
		var id := n.get_instance_id()
		if _modes.has(id):
			if out < WAKE:
				wake(n)
		elif out > DOZE:
			_modes[id] = n.process_mode
			n.process_mode = Node.PROCESS_MODE_DISABLED
	_slice = (_slice + 1) % SLICES


## Back on at once (a teleport, a test putting him somewhere new).
func wake(n: Node) -> void:
	var id := n.get_instance_id()
	if _modes.has(id):
		n.process_mode = _modes[id]
		_modes.erase(id)


## Everything awake again: he jumped somewhere (a load, a respawn far away).
func wake_all() -> void:
	for n in get_tree().get_nodes_in_group(GROUP):
		wake(n)


func asleep() -> int:
	return _modes.size()
