extends Node
## The trip HOME and back through the Camp Menu (see homeflow_runner.gd).
func _ready() -> void:
	get_tree().root.add_child.call_deferred(preload("res://tools/homeflow_runner.gd").new())
