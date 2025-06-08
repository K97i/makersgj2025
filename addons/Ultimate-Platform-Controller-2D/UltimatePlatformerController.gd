extends CharacterBody2D
class_name PlatformerController2D

@export var README: String = "IMPORTANT: MAKE SURE TO ASSIGN 'left' 'right' 'jump' 'dash' 'up' in the project settings input map. Usage tips. 1. Hover over each toggle and variable to read what it does and to make sure nothing bugs. 2. Animations are very primitive. To make full use of your custom art, you may want to slightly change the code for the animations"

@export_category("Necesary Child Nodes")
#@export var PlayerSprite: AnimatedSprite2D
# PlayerCollider export removed as the script doesn't directly use 'col' variable anymore.
# The CollisionShape2D node must still be a child of CharacterBody2D in the scene.

@export_category("L/R Movement")
@export_range(50, 500) var maxSpeed: float = 200.0
@export_range(0, 4) var timeToReachMaxSpeed: float = 0.2 # If 0, movement is instant
@export_range(0, 4) var timeToReachZeroSpeed: float = 0.2 # If 0, stopping is instant

@export_category("Jumping and Gravity")
@export_range(0, 200) var jumpHeight: float = 48.0 # Represents target pixel height if using physics-based jumpMagnitude
@export_range(0, 4) var jumps: int = 1
@export_range(100, 2000) var gravityScale: float = 1080.0 # Acceleration (e.g., units/sec^2)
@export_range(0, 1000) var terminalVelocity: float = 500.0
@export_range(0.5, 3) var descendingGravityFactor: float = 1.3
@export var shortHopAkaVariableJumpHeight: bool = true
@export_range(0, 0.5) var coyoteTime: float = 0.2
@export_range(0, 0.5) var jumpBuffering: float = 0.2

@export_category("Wall Jumping")
@export var wallJump: bool = false
@export_range(0, 0.5) var inputPauseAfterWallJump: float = 0.1
@export_range(0, 90) var wallKickAngle: float = 60.0

@export_category("Dashing")
@export_enum("None", "Horizontal", "Vertical", "Four Way", "Eight Way") var dashType: int
@export_range(0, 10) var dashes: int = 1
@export var dashCancel: bool = true
@export_range(1.5, 4) var dashLength: float = 2.5 # Multiplier for dash distance based on maxSpeed

@export_category("Animations (Check Box if has animation)")
@export var run: bool
@export var jump: bool
@export var idle: bool
@export var walk: bool
@export var falling: bool
@export var dash: bool

# Variables calculated based on exports
var acceleration: float
var deceleration: float # Should be a positive value representing deceleration rate
var jumpMagnitude: float = 500.0
var dashMagnitude: float

# State variables
var jumpCount: int
var dashCount: int
var jumpWasPressed: bool = false
var coyoteActive: bool = false
var gravityActive: bool = true
var dashing: bool = false
var wasMovingR: bool = true
var wasPressingR: bool = true # Default to right for initial dash direction if no input pressed yet
var movementInputMonitoring: Vector2 = Vector2.ONE # .x for right, .y for left

#var anim: AnimatedSprite2D
#var animScaleLock : Vector2

# Input state variables
var upHold: bool
var leftHold: bool
var leftTap: bool
#var leftRelease: bool # Not used, can be removed if not planned for future
var rightHold: bool
var rightTap: bool
#var rightRelease: bool # Not used, can be removed if not planned for future
var jumpTap: bool
var jumpRelease: bool
var dashTap: bool

# Timer node references
var coyote_timer_node: Timer
var jump_buffer_timer_node: Timer
var input_pause_timer_node: Timer
var gravity_pause_timer_node: Timer
var dashing_state_timer_node: Timer

var was_on_floor: bool = false
var collision_positions: Array

# these are all managed by states, utilized by the AnimationTree and others
# only the states ever write to this, which means only one state can write
# at a time. thus, no race conditions!
var is_holding_sword: bool = false
var is_blocking: bool = false
var speed_multiplier: float = 1.0

func _ready():
	var collision_shapes = get_tree().get_nodes_in_group("collision_shapes")
	for i in collision_shapes:
		collision_positions.append(i.position.x)

	#anim = PlayerSprite
	_updateData()
	#animScaleLock = abs(PlayerSprite.scale)
	# Initialize was_on_floor. is_on_floor() is reliable after the first physics frame.
	# Call differed ensures it runs after node is ready for physics checks.
	call_deferred("_initialize_floor_state")

func _initialize_floor_state():
	was_on_floor = is_on_floor()


func _updateData():
	acceleration = maxSpeed / timeToReachMaxSpeed if timeToReachMaxSpeed > 0 else maxSpeed * 1000 # Effectively instant if time is 0
	deceleration = maxSpeed / timeToReachZeroSpeed if timeToReachZeroSpeed > 0 else maxSpeed * 1000 # Effectively instant if time is 0
	
	# Physics-based jump magnitude: jumpHeight is target peak in pixels
	if jumpHeight > 0:
		jumpMagnitude = sqrt(2.0 * gravityScale * abs(jumpHeight))
	else:
		jumpMagnitude = 0.0
	
	dashMagnitude = maxSpeed * dashLength
	
	jumpCount = jumps # Initialize jump count
	dashCount = dashes # Initialize dash count
		
	if jumps > 1: # Multi-jumps disable coclass_name Enemy yote time and jump buffering
		jumpBuffering = 0
		coyoteTime = 0
	
	coyoteTime = abs(coyoteTime)
	jumpBuffering = abs(jumpBuffering)

var previous_health = 0.0
func _process(_delta):
	var current_health = $Health.percent()
	if current_health != previous_health:
		print(current_health)
	previous_health = current_health
	pass
	
	# Animation Handling
	#PlayerSprite.speed_scale = 1
	#var current_animation = PlayerSprite.animation

	#if dashing:
		#if dash and current_animation != "dash": PlayerSprite.play("dash")
	#elif not is_on_floor():
		#if velocity.y < 0: # Jumping/Rising
			#if jump and current_animation != "jump": PlayerSprite.play("jump")
		#else: # Falling
			#if falling and current_animation != "falling": PlayerSprite.play("falling")
	#elif abs(velocity.x) > 5: # Moving horizontally
		#var target_move_anim = "idle"
		#if run: target_move_anim = "run"
		#elif walk: target_move_anim = "walk"
		#
		#if current_animation != target_move_anim:
			#PlayerSprite.play(target_move_anim)
		#elif idle and current_animation != "idle" and target_move_anim == "idle": # Fallback if no run/walk
			#PlayerSprite.play("idle")
	#else: # Idle on floor
		#if idle and current_animation != "idle": PlayerSprite.play("idle")

	# Flip sprite based on movement direction
	var collision_shapes = get_tree().get_nodes_in_group("collision_shapes")
	if velocity.x != 0 and not is_blocking:
		var direction = sign(velocity.x)
		for i in range(collision_positions.size()):
			collision_shapes[i].position.x = collision_positions[i] * direction

func _physics_process(delta: float):
	# Input Detection
	leftHold = Input.is_action_pressed("left")
	rightHold = Input.is_action_pressed("right")
	upHold = Input.is_action_pressed("up")
	leftTap = Input.is_action_just_pressed("left")
	rightTap = Input.is_action_just_pressed("right")
	#leftRelease = Input.is_action_just_released("left")   # Kept commented if needed later
	#rightRelease = Input.is_action_just_released("right") # Kept commented if needed later
	jumpTap = Input.is_action_just_pressed("jump")
	jumpRelease = Input.is_action_just_released("jump")
	dashTap = Input.is_action_just_pressed("dash")
	
	# Horizontal Movement
	var target_x_velocity = 0.0
	if rightHold and movementInputMonitoring.x:
		target_x_velocity = maxSpeed
	elif leftHold and movementInputMonitoring.y:
		target_x_velocity = -maxSpeed
	
	if target_x_velocity != 0: # Player wants to move
		velocity.x = move_toward(velocity.x, target_x_velocity * speed_multiplier, (acceleration if timeToReachMaxSpeed > 0 else maxSpeed * 1000) * delta)
	else: # Player wants to stop
		velocity.x = move_toward(velocity.x, 0, (deceleration if timeToReachZeroSpeed > 0 else maxSpeed * 1000) * delta)

	if velocity.x > 0.1: wasMovingR = true
	elif velocity.x < -0.1: wasMovingR = false
	if rightTap: wasPressingR = true
	if leftTap: wasPressingR = false
			
	# Gravity
	if gravityActive:
		var current_gravity_pull = gravityScale * (descendingGravityFactor if velocity.y > 0 else 1.0)
		velocity.y += current_gravity_pull * delta
		velocity.y = min(velocity.y, terminalVelocity)
		
	if shortHopAkaVariableJumpHeight and jumpRelease and velocity.y < 0:
		velocity.y *= 0.5 # More concise
	
	# Coyote Time and Jump Buffering Logic
	var currently_on_floor = is_on_floor()

	if jumps == 1: # Coyote time and buffering only for single jump mode
		if was_on_floor and not currently_on_floor and not is_on_wall(): # Just left ground (not by wall interaction)
			if coyoteTime > 0:
				coyoteActive = true
				_start_timer("coyote", coyoteTime, "_on_coyote_timer_timeout")
		
		if currently_on_floor:
			jumpCount = jumps # Replenish jump
			coyoteActive = true # Ready for next fall/jump
			_stop_timer("coyote")
			if jumpWasPressed:
				_jump()
				_stop_timer("jump_buffer")

	# Jump Input
	if jumpTap:
		if currently_on_floor:
			_jump()
		elif wallJump and is_on_wall() and not currently_on_floor:
			_wallJump()
		elif jumps == 1 and coyoteActive: # Coyote Jump
			_jump()
		elif jumpCount > 0 and jumps > 1: # Air jump for multi-jump
			velocity.y = -jumpMagnitude
			jumpCount -= 1
		elif jumpBuffering > 0 and jumps == 1: # Buffer jump
			jumpWasPressed = true
			_start_timer("jump_buffer", jumpBuffering, "_on_jump_buffer_timer_timeout")
			
	# Dashing
	if currently_on_floor:
		dashCount = dashes # Replenish dashes
		
	if dashTap and dashCount > 0 and not dashing:
		var dTime = 0.0625 * dashLength # Dash duration based on length
		var dash_vector = Vector2.ZERO

		match dashType:
			1: # Horizontal
				dash_vector = Vector2.RIGHT if wasPressingR else Vector2.LEFT
			2: # Vertical (Upwards only)
				if upHold: dash_vector = Vector2.UP
			3: # Four Way (L/R/Up)
				var h_input = Input.get_action_strength("right") - Input.get_action_strength("left")
				var v_input = -1.0 if upHold else 0.0 # Only up
				dash_vector = Vector2(h_input, v_input).normalized() if Vector2(h_input, v_input) != Vector2.ZERO else Vector2.ZERO
			4: # Eight Way (L/R/Up + non-downward diagonals)
				var input_dir_raw = Input.get_vector("left", "right", "up", "down")
				# Filter out explicit downward movement for the dash
				var filtered_y = input_dir_raw.y if input_dir_raw.y <= 0 else 0.0
				dash_vector = Vector2(input_dir_raw.x, filtered_y).normalized() if Vector2(input_dir_raw.x, filtered_y) != Vector2.ZERO else Vector2.ZERO
		
		if dash_vector != Vector2.ZERO:
			velocity = dashMagnitude * dash_vector
			dashing = true
			_start_timer("dashing_state", dTime, "_on_dashing_state_timer_timeout")
			gravityActive = false
			_start_timer("gravity_pause", dTime, "_on_gravity_pause_timer_timeout")
			dashCount -= 1
			movementInputMonitoring = Vector2.ZERO # Pause L/R input
			_start_timer("input_pause", dTime, "_on_input_pause_timer_timeout")

	if dashing and dashCancel: # Dash cancelling
		if (velocity.x > 0 and leftTap) or (velocity.x < 0 and rightTap):
			velocity.x = 0
			
	move_and_slide()
	was_on_floor = currently_on_floor

# --- Timer Management ---
func _start_timer(timer_type: String, duration: float, timeout_method: String):
	var timer_node_ref: Timer = get(timer_type + "_timer_node")
	if timer_node_ref != null and is_instance_valid(timer_node_ref): # Clean up existing timer
		timer_node_ref.stop()
		timer_node_ref.queue_free()

	var new_timer = Timer.new()
	new_timer.name = timer_type.capitalize() + "Timer" # Concise name
	new_timer.wait_time = duration
	new_timer.one_shot = true
	new_timer.connect("timeout", Callable(self, timeout_method))
	add_child(new_timer)
	new_timer.start()
	set(timer_type + "_timer_node", new_timer)

func _stop_timer(timer_type: String):
	var timer_node_ref: Timer = get(timer_type + "_timer_node")
	if timer_node_ref != null and is_instance_valid(timer_node_ref):
		timer_node_ref.stop()
		timer_node_ref.queue_free()
		set(timer_type + "_timer_node", null)

# --- Timer Timeout Callbacks ---
func _on_coyote_timer_timeout():
	coyoteActive = false
	_stop_timer("coyote")

func _on_jump_buffer_timer_timeout():
	jumpWasPressed = false
	_stop_timer("jump_buffer")

func _on_input_pause_timer_timeout():
	movementInputMonitoring = Vector2.ONE # Resume L/R input
	_stop_timer("input_pause")

func _on_gravity_pause_timer_timeout():
	gravityActive = true
	_stop_timer("gravity_pause")

func _on_dashing_state_timer_timeout():
	dashing = false
	_stop_timer("dashing_state")

# --- Action Functions ---
func _jump():
	if jumpCount > 0 or coyoteActive: # coyoteActive implies a jump is available
		velocity.y = -jumpMagnitude
		if not coyoteActive : jumpCount -= 1 # Don't double-consume if it was a multi-jump that also had coyote
		
		if coyoteActive: # Consume coyote
			coyoteActive = false
			_stop_timer("coyote")
		if jumpWasPressed: # Consume buffer
			jumpWasPressed = false
			_stop_timer("jump_buffer")
		
func _wallJump():
	# Wall jump does not consume jumpCount unless explicitly designed to
	var angle_rad = deg_to_rad(wallKickAngle)
	var horizontal_kick = abs(jumpMagnitude * cos(angle_rad)) # Use jumpMagnitude as base for consistency
	var vertical_kick = abs(jumpMagnitude * sin(angle_rad))
	
	velocity.y = -vertical_kick
	
	var wall_normal_x = get_wall_normal().x
	if wall_normal_x != 0:
		velocity.x = wall_normal_x * horizontal_kick # Push away from wall
	else: # Fallback if normal is somehow zero (e.g. perfect corner)
		velocity.x = -horizontal_kick if wasMovingR else horizontal_kick # Push opposite to last movement

	if inputPauseAfterWallJump > 0:
		movementInputMonitoring = Vector2.ZERO
		_start_timer("input_pause", inputPauseAfterWallJump, "_on_input_pause_timer_timeout")


func _on_torso_animation_tree_animation_started(anim_name: StringName) -> void:
	pass
	#print("animation started: ", anim_name)


func _on_parrying_state_exited(extra_arg_0: String, extra_arg_1: bool) -> void:
	pass # Replace with function body.


func _on_parry_hit_box_2d_parry_successful(hit_box: HitBox2D) -> void:
	print("player: parry success!!!") # Replace with function body.
