extends Node
## The real SAVE / LOAD path: the game's own scene, the Camp Menu's SAVE, then
## LOAD (pressed twice) changing the scene, and where he wakes. Headless is fine.
func _ready() -> void:
	get_tree().root.add_child.call_deferred(preload("res://tools/loadflow_runner.gd").new())
