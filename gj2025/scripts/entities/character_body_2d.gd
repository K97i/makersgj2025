extends CharacterBody2D
class_name Player

const SPEED = 200.0
const DASH_SPEED = 600.0
const JUMP_VELOCITY = -400.0
var dashing = false
var can_dash = true
var facing_direction := 1
var dash_direction := 1

@onready var coyotetimer: Timer = $"../coyotetimer"

func _ready():
	Gamemanager.player = self

func _physics_process(delta: float) -> void:
	var direction := Input.get_axis("move_left", "move_right")
	# Add the gravity.
	if not is_on_floor() and not dashing:
		velocity += get_gravity() * delta

	# Handle jump.
	if Input.is_action_just_pressed("jump") and is_on_floor() || Input.is_action_just_pressed("jump") and !$"../coyotetimer".is_stopped():
		velocity.y = JUMP_VELOCITY
		
	# Handle dash.
	if Input.is_action_just_pressed("dash") and can_dash:
		dashing = true
		can_dash = false
		if direction != 0:
			dash_direction = direction
		else:
			dash_direction = facing_direction
		$dash_timer.start()
		$dash_again_timer.start()

	# Flip the sprite
	if direction > 0:
		$AnimatedSprite2D.flip_h = false
		facing_direction = 1
	elif direction < 0:
		$AnimatedSprite2D.flip_h = true
		facing_direction = -1
		
	# Handle player animations.
	if is_on_floor():
		if direction == 0:
			$AnimatedSprite2D.play("idle")
		else:
			$AnimatedSprite2D.play("walk")
	else:
		$AnimatedSprite2D.play("jump")
	
	if dashing:
		velocity.x = dash_direction * DASH_SPEED
	elif direction:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
	if dashing:
		velocity.y = 0
		
	var was_on_floor = is_on_floor()
	
	# Updates is_on_floor value to false, but keeps was_on_floor to true
	move_and_slide()
	
	if was_on_floor && !is_on_floor():
		$"../coyotetimer".start()
	

func _on_dash_timer_timeout() -> void:
	dashing = false # Replace with function body.
	
func _on_dash_again_timer_timeout() -> void:
	can_dash = true # Replace with function body.

func reset_state():
	velocity = Vector2.ZERO
	dashing = false
	can_dash = true
