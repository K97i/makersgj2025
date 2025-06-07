extends CharacterBody2D
@onready var player: Player = $"../Player"
@export var speed := 30
@export var patrol_distance := 50
@export var wait_time := 1.0
var direction := 1
var start_position : Vector2
var waiting := false


func _ready():
	start_position = position

func _physics_process(delta: float) -> void:
	if waiting:
		return
		
	if direction == 1:
		$AnimatedSprite2D.flip_h = false
	elif direction == -1:
		$AnimatedSprite2D.flip_h = true
	
	# Move enemy
	velocity.x = speed * direction
	move_and_slide()
	
	# Check patrol distance
	var distance_moved = position.x - start_position.x
	if abs(distance_moved) >= patrol_distance:
		direction *= -1
		start_position = position
		waiting = true
		await get_tree().create_timer(0.5).timeout
		waiting = false
		
func _on_killzone_body_entered(body: Node2D) -> void:
	player.reset_state()
	Gamemanager.respawn_player() 
	print("YOU DIED!") # Replace with function body.
