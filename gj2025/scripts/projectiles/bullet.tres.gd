extends Area2D
@onready var killzone: Area2D = $killzone
@onready var player: Player = $Player

var direction : Vector2 = Vector2.RIGHT
var speed : float = 200

func _physics_process(delta: float) -> void:
	position += direction * speed * delta
	
func _on_visible_on_screen_notifier_2d_screen_exited() -> void:
	queue_free()

func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		print("You Died!")
		body.reset_state()
		Gamemanager.respawn_player()
		queue_free()  # remove bullet after hitting player
