extends Area2D
@onready var respawn_timer: Timer = $respawn_timer
@onready var player: Player = $"../Player"

func _on_body_entered(body: Node2D) -> void:
	print("You Died!") # Replace with function body.
	player.reset_state()
	Gamemanager.respawn_player() 
