extends Node2D

func _ready():
	$fade_transition/AnimationPlayer.play("fade_out")
	$next_scene_start.start()
	
func _on_next_scene_start_timeout() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
