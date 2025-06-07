extends Node2D
class_name Checkpoint

@export var spawnpoint = false
var activated = false

func activate():
	Gamemanager.current_checkpoint = self
	activated = true 
	print("Checkpoint Saved at: ", position)

func _on_area_2d_area_entered(area: Area2D) -> void:
	if area.get_parent() is Player && !activated:
		activate()
