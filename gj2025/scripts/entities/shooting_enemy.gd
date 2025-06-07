extends CharacterBody2D
@onready var player: Player = $"../Player"

# Patrol
@export var speed := 30
@export var patrol_distance := 50
@export var wait_time := 1.0
var direction := 1
var start_position : Vector2
var waiting := false

# Gun
@onready var ray_cast: RayCast2D = $RayCast2D
@onready var shoot_timer: Timer = $"Shoot Timer"
@export var ammo : PackedScene


func _physics_process(delta: float) -> void:
	
	_aim()
	_check_player_collision()
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

func _aim():
	var target_global_pos = player.global_position
	if player.has_node("CollisionShape2D"):
		var shape_node = player.get_node("CollisionShape2D")
		var shape_position = shape_node.position  # This is the center of a CircleShape2D
		target_global_pos = player.to_global(shape_position)

	ray_cast.target_position = to_local(target_global_pos)
		
func _check_player_collision():
	if ray_cast.is_colliding() and ray_cast.get_collider() == player and shoot_timer.is_stopped():
		shoot_timer.start()
		print("DETECTED")
	elif ray_cast.get_collider() != player and !shoot_timer.is_stopped():
		shoot_timer.stop()

func _on_shoot_timer_timeout() -> void:
	_shoot()
	
func _shoot():
	var bullet = ammo.instantiate()
	bullet.position = position
	bullet.direction = (ray_cast.target_position).normalized()
	get_tree().current_scene.add_child(bullet)

func _on_killzone_body_entered(body: Node2D) -> void:
	player.reset_state()
	Gamemanager.respawn_player() 
	print("YOU DIED!") # Replace with function body.
