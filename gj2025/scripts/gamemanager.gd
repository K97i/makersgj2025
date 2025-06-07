extends Node
var current_checkpoint : Checkpoint
var player : Player
# Called when the node enters the scene tree for the first time.
func respawn_player():
	if current_checkpoint!= null:
		var offset = Vector2(20,-20)
		player.position = current_checkpoint.global_position + offset
		print("Respawning to:", player.position)
	else:
		print("No checkpoint set!")
