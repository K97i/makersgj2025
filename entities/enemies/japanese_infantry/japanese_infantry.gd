extends CharacterBody2D

# --- Enums ---
enum State { IDLE, WALK, TAKE_AIM, PREPARE_SHOT, FIRE, COOLDOWN }

# --- Constants ---
const FLOOR_NORMAL = Vector2.UP
const DEBUG_PREFIX = "[Gunner %s]: "
const LOS_CHECK_INTERVAL: float = 0.25 # How often to check Line of Sight
const LOS_CONFIRMATION_DURATION: float = 0.5 # Delay after gaining LoS before taking aim

# --- Exports ---
@export var move_speed: float = 50.0
@export var gravity: float = 800.0 # ProjectSettings.physics.2d.default_gravity

@export_category("Ranged Combat")
@export var detection_range: float = 300.0
@export var optimal_range_min: float = 150.0
@export var optimal_range_max: float = 280.0
@export var retreat_distance_early_aim: float = 80.0

@export var take_aim_duration: float = 1.0
@export var prepare_shot_duration: float = 2.0
@export var fire_animation_duration: float = 0.3 # Visual duration of firing
@export var attack_cooldown_duration: float = 3.0

# --- Onready Variables ---
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
# @onready var animation_player: AnimationPlayer = $AnimationPlayer # Uncomment if using AnimationPlayer
@onready var health_component # : Health = $HealthComponent # Assign in editor or get by path
@onready var hurtbox # : BasicHurtBox2D = $BasicHurtBox2D # Assign in editor or get by path
@onready var hitscan_weapon: Node = $BasicHitScan2D # Assign type if you have custom class e.g. : YourHitScanClass
@onready var crosshair_sprite: Sprite2D = $CrosshairSprite2D

# --- State Variables ---
var current_state: State = State.IDLE
var player_ref: Node2D = null
var player_last_known_position: Vector2 = Vector2.ZERO # Used for aiming and firing
var has_line_of_sight: bool = false
var _debug_name: String

# --- Timers ---
var state_timer: float = 0.0 # Generic timer for current state's duration
var los_check_timer: float = 0.0
var los_confirmation_timer: float = 0.0
var pending_take_aim: bool = false

# --- Raycast for Line of Sight (LoS) ---
var los_ray: RayCast2D

# --- Initialization ---
func _ready():
	_debug_name = name
	print(DEBUG_PREFIX % _debug_name, "_ready() called.")

	# Attempt to get components if not assigned in editor (common for @onready if paths are fixed)
	if not health_component: health_component = get_node_or_null("HealthComponent") # Example path
	if not hurtbox: hurtbox = get_node_or_null("BasicHurtBox2D") # Example path
	
	if not hitscan_weapon:
		printerr(DEBUG_PREFIX % _debug_name, "ERROR: BasicHitScan2D node not found! Ensure it's named 'BasicHitScan2D' or update path.")
		# get_tree().quit() # Consider quitting or disabling enemy if critical component missing
	elif not hitscan_weapon.has_method("fire"):
		printerr(DEBUG_PREFIX % _debug_name, "ERROR: BasicHitScan2D node does not have a 'fire' method!")

	if not crosshair_sprite:
		printerr(DEBUG_PREFIX % _debug_name, "ERROR: CrosshairSprite2D node not found! Ensure it's named 'CrosshairSprite2D' or update path.")
	else:
		crosshair_sprite.visible = false # Hide crosshair initially

	# Connect HealthComponent's "died" signal
	if health_component and health_component.has_signal("died"):
		health_component.connect("died", Callable(self, "_on_died"))
	else:
		printerr(DEBUG_PREFIX % _debug_name, "HealthComponent or its 'died' signal not found for %s." % name)
	
	# Connect signals from hitscan_weapon if Gunner needs to react
	if hitscan_weapon and hitscan_weapon.has_method("fire"):
		if hitscan_weapon.has_signal("action_applied"): # Example signal
			hitscan_weapon.connect("action_applied", Callable(self, "_on_hitscan_action_applied"))


	# Setup Line of Sight RayCast2D
	los_ray = RayCast2D.new()
	los_ray.name = "LoSRay" # Good practice to name procedurally added nodes
	add_child(los_ray)
	#los_ray.collision_mask = 0
	los_ray.enabled = true # Must be enabled to use force_raycast_update effectively
	#los_ray.add_exception(self) # Don't hit self

	# IMPORTANT: Configure los_ray.collision_mask for YOUR game's layers
	# Example: Player on physics layer 1 (bit 0), Obstacles on physics layer 2 (bit 1)
	# Ensure these layers exist in Project > Project Settings > Layer Names > 2D Physics
	var player_physics_layer_bit = 1 # Corresponds to Layer 1 in editor
	var obstacle_physics_layer_bit = 20 # Corresponds to Layer 2 in editor
	los_ray.set_collision_mask_value(player_physics_layer_bit, true)
	los_ray.set_collision_mask_value(obstacle_physics_layer_bit, true)
	# You might need more obstacle layers: los_ray.set_collision_mask_value(another_obstacle_layer_bit, true)

	change_state(State.IDLE)


# --- Physics Processing ---
func _physics_process(delta: float):
	if current_state == State.FIRE and state_timer > 0: # Special handling for FIRE state duration
		velocity.y += gravity * delta
		move_and_slide()
		state_timer -= delta
		if state_timer <= 0:
			change_state(State.COOLDOWN)
		return # Skip rest of processing during fire animation
	
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		velocity.y = min(velocity.y, 5) # Prevent slight bouncing

	# Update timers
	if state_timer > 0 : state_timer -= delta # Generic state timer
	if los_check_timer > 0: los_check_timer -= delta

	if los_check_timer <= 0:
		scan_for_player_and_los()
		los_check_timer = LOS_CHECK_INTERVAL

	if pending_take_aim:
		if player_ref and has_line_of_sight:
			if los_confirmation_timer > 0: los_confirmation_timer -= delta
			if los_confirmation_timer <= 0:
				print(DEBUG_PREFIX % _debug_name, "LoS confirmed. Transitioning to TAKE_AIM.")
				change_state(State.TAKE_AIM)
				# pending_take_aim is reset in change_state or when entering TAKE_AIM
		else: # Lost LoS during confirmation
			print(DEBUG_PREFIX % _debug_name, "Lost LoS during confirmation. Resetting.")
			pending_take_aim = false
			los_confirmation_timer = 0.0


	match current_state:
		State.IDLE:
			velocity.x = 0
			play_animation("idle")
			if not pending_take_aim and player_ref and has_line_of_sight:
				var distance_to_player = global_position.distance_to(player_ref.global_position)
				if distance_to_player <= detection_range and distance_to_player <= optimal_range_max:
					print(DEBUG_PREFIX % _debug_name, "Player in LoS. Starting LoS confirmation for TAKE_AIM.")
					pending_take_aim = true
					los_confirmation_timer = LOS_CONFIRMATION_DURATION
			elif player_ref and not has_line_of_sight:
				if pending_take_aim: # Was trying to confirm but lost LoS
					pending_take_aim = false
					los_confirmation_timer = 0.0
				if global_position.distance_to(player_last_known_position) > 10: # Threshold for "giving up"
					pass # Optional: move towards last_known_position briefly
				else:
					player_ref = null # Truly lost

		State.WALK:
			play_animation("walk")
			if player_ref:
				var distance_to_player = global_position.distance_to(player_ref.global_position)
				if distance_to_player > optimal_range_min and has_line_of_sight and not pending_take_aim:
					print(DEBUG_PREFIX % _debug_name, "WALK: Reached safe distance or have LoS. Starting LoS confirmation.")
					pending_take_aim = true # Try to aim again
					los_confirmation_timer = LOS_CONFIRMATION_DURATION
					velocity.x = 0 # Stop walking to aim
				elif distance_to_player > detection_range or not player_ref:
					change_state(State.IDLE)
				else: # Continue retreating (player too close or no LoS to aim yet)
					var direction_away_from_player = (global_position - player_ref.global_position).normalized()
					velocity.x = direction_away_from_player.x * move_speed
					update_facing_direction(direction_away_from_player.x)
			else:
				change_state(State.IDLE)

		State.TAKE_AIM:
			play_animation("take_aim")
			velocity.x = 0
			if player_ref and has_line_of_sight:
				update_facing_direction_towards_point(player_ref.global_position)
				if crosshair_sprite: crosshair_sprite.global_position = player_ref.global_position
				player_last_known_position = player_ref.global_position # Update for PREPARE_SHOT

				var distance_to_player = global_position.distance_to(player_ref.global_position)
				if distance_to_player < retreat_distance_early_aim:
					print(DEBUG_PREFIX % _debug_name, "TAKE_AIM: Player too close. Retreating.")
					change_state(State.WALK)
					return # Process WALK next frame
				if state_timer <= 0:
					change_state(State.PREPARE_SHOT)
			elif not player_ref or not has_line_of_sight: # Lost LoS or player
				change_state(State.IDLE)

		State.PREPARE_SHOT:
			#play_animation("prepare_shot")
			velocity.x = 0
			# Aiming is static, crosshair and facing set on state entry.
			if player_last_known_position == Vector2.ZERO: # Safety check
				change_state(State.IDLE)
				return
			# Optional: Cancel if player breaks LoS for too long, even if aim is static
			# if not has_line_of_sight and state_timer < (prepare_shot_duration - 0.2):
			#    change_state(State.IDLE)
			#    return
			if state_timer <= 0:
				change_state(State.FIRE)

		State.COOLDOWN:
			play_animation("idle")
			velocity.x = 0
			if state_timer <= 0:
				change_state(State.IDLE)
	
	# Only call move_and_slide if not in FIRE animation phase
	if not (current_state == State.FIRE and state_timer > 0):
		move_and_slide()

# --- State Management ---
func change_state(new_state: State):
	if current_state == new_state and new_state != State.IDLE : return # Allow re-entering IDLE for re-evaluation
	print(DEBUG_PREFIX % _debug_name, "Changing state from '%s' to '%s'" % [State.keys()[current_state], State.keys()[new_state]])

	# Reset flags/timers that should not persist across most state changes
	if new_state != State.IDLE or not pending_take_aim : # Don't clear if IDLE is re-evaluating a pending aim
		if current_state != State.IDLE and pending_take_aim: # Clear if leaving a state that might have initiated it
			pass # Let the new state decide if it wants to start a new pending_take_aim
	
	# More robust reset for pending_take_aim
	if new_state != State.IDLE and not (new_state == State.TAKE_AIM and current_state == State.IDLE and pending_take_aim):
		pending_take_aim = false
		los_confirmation_timer = 0.0

	var old_state = current_state
	current_state = new_state
	state_timer = 0.0 # Reset generic state timer by default

	match current_state:
		State.IDLE:
			if crosshair_sprite: crosshair_sprite.visible = false
			play_animation("idle")
		State.WALK:
			if crosshair_sprite: crosshair_sprite.visible = false
			pending_take_aim = false # Definitely not aiming if walking
			los_confirmation_timer = 0.0
			play_animation("walk")
		State.TAKE_AIM:
			pending_take_aim = false # Successfully entered aiming state
			los_confirmation_timer = 0.0
			state_timer = take_aim_duration
			play_animation("take_aim")
			if crosshair_sprite: crosshair_sprite.visible = true
			if player_ref: # Initial aim on state entry
				update_facing_direction_towards_point(player_ref.global_position)
				if crosshair_sprite: crosshair_sprite.global_position = player_ref.global_position
				player_last_known_position = player_ref.global_position
		State.PREPARE_SHOT:
			state_timer = prepare_shot_duration
			play_animation("prepare_shot")
			# player_last_known_position should be set by TAKE_AIM before this transition
			if player_last_known_position == Vector2.ZERO and player_ref: # Fallback
				player_last_known_position = player_ref.global_position
			
			if player_last_known_position == Vector2.ZERO:
				printerr(DEBUG_PREFIX % _debug_name, "Error: Entering PREPARE_SHOT with no aim position!")
				change_state(State.IDLE) # Recurse safely to IDLE
				return

			update_facing_direction_towards_point(player_last_known_position) # Face static point
			if crosshair_sprite:
				crosshair_sprite.visible = true
				crosshair_sprite.global_position = player_last_known_position # Aim at static point
				crosshair_sprite.self_modulate = Color.RED # Indicate locked
		State.FIRE:
			state_timer = fire_animation_duration
			play_animation("fire")
			if hitscan_weapon and hitscan_weapon.has_method("fire"):
				if player_last_known_position != Vector2.ZERO:
					var fire_target_global_pos = player_last_known_position
					# Position hitscan weapon at gun muzzle if it's a separate node
					# For this example, assuming hitscan_weapon is positioned at enemy's origin or a child that moves with it.
					# If hitscan_weapon is child of a rotating pivot:
					# $GunPivot.look_at(fire_target_global_pos)
					# hitscan_weapon.target_position = Vector2(SOME_LARGE_RANGE, 0) # Local forward
					# Else, if hitscan_weapon itself is the RayCast2D at enemy origin:
					if hitscan_weapon is RayCast2D: # Type check for safety
						hitscan_weapon.global_position = global_position # Or muzzle position
						hitscan_weapon.target_position = hitscan_weapon.to_local(fire_target_global_pos)

					hitscan_weapon.force_raycast_update()
					hitscan_weapon.fire()
				else:
					print(DEBUG_PREFIX % _debug_name, "FIRE: No player_last_known_position to fire at.")
			# else: print errors already in _ready
		State.COOLDOWN:
			state_timer = attack_cooldown_duration
			if crosshair_sprite:
				crosshair_sprite.visible = false
				crosshair_sprite.self_modulate = Color.WHITE # Reset color
			play_animation("idle")

# --- Player Detection & Line of Sight ---
func scan_for_player_and_los():
	var previous_player_ref = player_ref
	var previous_has_los = has_line_of_sight
	player_ref = null
	has_line_of_sight = false
	
	var players_in_scene = get_tree().get_nodes_in_group("player")
	var closest_player: Node2D = null
	var min_dist_sq = detection_range * detection_range

	for p_node in players_in_scene:
		if p_node is Node2D:
			var dist_sq = global_position.distance_squared_to(p_node.global_position)
			if dist_sq < min_dist_sq:
				min_dist_sq = dist_sq
				closest_player = p_node

	if closest_player:
		player_ref = closest_player
		# Don't update player_last_known_position here directly if PREPARE_SHOT has locked it.
		# Only update if not in PREPARE_SHOT or if LoS is active for TAKE_AIM.
		if current_state != State.PREPARE_SHOT:
			player_last_known_position = player_ref.global_position

		if los_ray:
			los_ray.global_position = global_position # Or gun-barrel origin
			los_ray.target_position = los_ray.to_local(player_ref.global_position)
			los_ray.force_raycast_update()

			if los_ray.is_colliding():
				var collider = los_ray.get_collider()
				if collider == player_ref:
					has_line_of_sight = true
			
			if not has_line_of_sight and previous_has_los and player_ref == previous_player_ref:
				print(DEBUG_PREFIX % _debug_name, "Lost LoS to player: %s" % player_ref.name)
			elif has_line_of_sight and not previous_has_los and player_ref:
				print(DEBUG_PREFIX % _debug_name, "Gained LoS to player: %s" % player_ref.name)
	
	# If player_ref was lost, but was previously valid, keep last_known_pos for a bit
	if not player_ref and previous_player_ref and current_state != State.PREPARE_SHOT:
		player_last_known_position = previous_player_ref.global_position 
	# If LoS is lost, but player_ref still exists (e.g. player went behind temporary thin cover)
	# And not in PREPARE_SHOT where aim is locked
	elif player_ref and not has_line_of_sight and current_state != State.PREPARE_SHOT:
		player_last_known_position = player_ref.global_position # Keep tracking last seen spot


# --- Animation & Facing ---
func play_animation(anim_name: String):
	# if get_node_or_null("AnimationPlayer") and get_node_or_null("AnimationPlayer").has_animation(anim_name): # If using AnimationPlayer
		# if get_node_or_null("AnimationPlayer").current_animation != anim_name:
			# get_node_or_null("AnimationPlayer").play(anim_name)
	if animated_sprite and animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation(anim_name):
		if animated_sprite.animation != anim_name:
			animated_sprite.play(anim_name)
	else:
		print(DEBUG_PREFIX % _debug_name, "Animation not found or AnimatedSprite not ready: '%s'" % anim_name)


func update_facing_direction(move_direction_x: float):
	# Assuming sprite faces right by default: flip_h = true means facing LEFT
	if move_direction_x > 0.01: # Moving right
		animated_sprite.flip_h = true
	elif move_direction_x < -0.01: # Moving left
		animated_sprite.flip_h = false
	# Hitscan weapon scale/rotation should be handled by its parent pivot or look_at logic

func update_facing_direction_towards_point(target_global_pos: Vector2):
	var direction_x = (target_global_pos - global_position).x
	if direction_x > 0.01: # Target is to the right
		animated_sprite.flip_h = true
	elif direction_x < -0.01: # Target is to the left
		animated_sprite.flip_h = false

# --- Hitscan Signal Callback Example ---
func _on_hitscan_action_applied(hurt_box: HurtBox2D):
	print(DEBUG_PREFIX % _debug_name, "Hitscan confirmed action applied to HurtBox: %s" % hurt_box.name)
	# e.g. play a hit confirmation sound

# --- Death ---
func _on_died(entity):
	velocity.x = 0
	velocity.y = 0
	$AnimatedSprite2D.self_modulate = Color.RED
	$AnimatedSprite2D.play("idle")
	print(DEBUG_PREFIX % _debug_name, "Died.")
	set_physics_process(false) # Stop processing
	if is_instance_valid(crosshair_sprite): crosshair_sprite.queue_free()
	if is_instance_valid(los_ray): los_ray.queue_free() # Clean up manually added node
	# play_animation("death") # If you have one
	# await get_node("AnimationPlayer").animation_finished # if death anim controlled by AnimPlayer
	await get_tree().create_timer(1.0).timeout
	queue_free()


func _on_health_component_damaged(entity: Node, type: HealthActionType.Enum, amount: int, incrementer: int, multiplier: float, applied: int) -> void:
	$ProgressBar.value = $HealthComponent.percent()
