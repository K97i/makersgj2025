extends Node2D


func _on_basic_hit_box_2d_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		queue_free()
