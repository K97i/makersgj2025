extends CharacterBody2D

@onready var player: Player = $"../Player"
@onready var ray_cast: RayCast2D = $RayCast2D

@export var speed := 30
@export var patrol_distance := 50
@export var wait_time := 1.0
var direction := 1
var start_position : Vector2

# NEW for charging enemy
enum State { PATROL, WAITING, CHARGING }
var state = State.PATROL

@export var charge_speed := 200
@export var charge_duration := 1.0

var wait_timer := 0.0
var charge_timer := 0.0

func _ready():
	start_position = position

func _physics_process(delta: float) -> void:
	_aim()

	match state:
		State.PATROL:
			_patrol(delta)
			if _can_see_player():
				state = State.WAITING
				wait_timer = 0.0
				
		State.WAITING:
			wait_timer += delta
			if wait_timer >= wait_time:
				state = State.CHARGING
				charge_timer = 0.0
				
		State.CHARGING:
			charge_timer += delta
			_charge_towards_player(delta)
			if charge_timer >= charge_duration:
				state = State.PATROL
				start_position = position

func _aim():
	var direction_to_player = (player.global_position - global_position).normalized()
	ray_cast.rotation = direction_to_player.angle()
	ray_cast.target_position = Vector2(300, 0)
	ray_cast.force_raycast_update()

func _can_see_player() -> bool:
	ray_cast.force_raycast_update()
	return ray_cast.is_colliding() and ray_cast.get_collider() == player

func _patrol(delta: float) -> void:
	velocity.x = speed * direction
	move_and_slide()

	var distance_moved = position.x - start_position.x
	if abs(distance_moved) >= patrol_distance:
		direction *= -1
		start_position = position

func _charge_towards_player(delta: float) -> void:
	var direction_to_player = (player.global_position - global_position).normalized()
	velocity = direction_to_player * charge_speed
	move_and_slide()
