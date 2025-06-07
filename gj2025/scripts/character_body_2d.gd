extends CharacterBody2D

const SPEED = 180.0
const DASH_SPEED = 600.0
const JUMP_VELOCITY = -250.0
var dashing = false
var can_dash = true

func _physics_process(delta: float) -> void:
	var direction := Input.get_axis("move_left", "move_right")
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY
		
	# Handle dash.
	if Input.is_action_just_pressed("dash") and can_dash:
		dashing = true
		can_dash = false
		$dash_timer.start()
		$dash_again_timer.start()

	# Flip the sprite
	if direction > 0:
		$AnimatedSprite2D.flip_h = false
	elif direction < 0:
		$AnimatedSprite2D.flip_h = true
	
	# Handle player animations.
	if is_on_floor():
		if direction == 0:
			$AnimatedSprite2D.play("idle")
		else:
			$AnimatedSprite2D.play("walk")
	else:
		$AnimatedSprite2D.play("jump")
	
	
	if direction:
		if dashing:
			velocity.x = direction * DASH_SPEED
		else:
			velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	move_and_slide()

func _on_dash_timer_timeout() -> void:
	dashing = false # Replace with function body.
	
func _on_dash_again_timer_timeout() -> void:
	can_dash = true # Replace with function body.
