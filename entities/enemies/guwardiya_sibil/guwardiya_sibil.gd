extends CharacterBody2D

# --- Signals ---
# (No custom signals defined directly in this script, uses signals from components)

# --- Enums ---
enum State { IDLE, FOLLOW, RUSH, ATTACK, STUNNED, DEAD }

# --- Constants ---
const FLOOR_NORMAL = Vector2.UP

# --- Exports ---
@export var move_speed: float = 60.0
@export var rush_speed_multiplier: float = 1.8
@export var gravity: float = 800.0 # ProjectSettings.physics.2d.default_gravity
@export var follow_to_rush_delay: float = 3.0 # Time in FOLLOW before RUSHING
@export var attack_cooldown: float = 1.5 # Time after attack before attacking again
@export var stun_duration: float = 2.0
@export var pushback_force: float = 200.0

# --- Onready Variables ---
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var character_hitbox: Area2D = $BasicHitBox2D # Assumed always on
@onready var weapon_hitbox: Area2D = $WeaponHitBox2D
@onready var detection_area: Area2D = $DetectionArea
@onready var attack_range_area: Area2D = $AttackRangeArea
@onready var health_component # Type hint this if you have a custom script e.g. : Health = $Health

# --- State Variables ---
var current_state: State = State.IDLE
var player_ref: Node2D = null # Store reference to the player
var player_in_detection_range: bool = false
var player_in_attack_range: bool = false

# --- Timers (use SceneTreeTimers or Timer nodes) ---
var follow_timer: float = 0.0
var attack_cooldown_timer: float = 0.0
var stun_timer: float = 0.0

# --- Movement ---
var current_movement_speed: float = move_speed

# --- Initialization ---
func _ready():
	# Attempt to get health component if not already typed strongly and failed
	if not health_component:
		health_component = $Health # Make sure $Health path is correct

	# Ensure weapon hitbox is off initially, AnimationPlayer will control it
	deactivate_weapon_hitbox()
	if character_hitbox:
		character_hitbox.monitoring = true # Or set in editor

	# Connect signals from components
	#if health_component:
		#if health_component.has_signal("damaged"):
			#health_component.connect("damaged", Callable(self, "_on_health_damaged"))
		#
		#if health_component.has_signal("died"):
			#health_component.connect("died", Callable(self, "_on_health_died"))
	#
	#if detection_area:
		#detection_area.connect("body_entered", Callable(self, "_on_detection_area_body_entered"))
		#detection_area.connect("body_exited", Callable(self, "_on_detection_area_body_exited"))
	#
	#if attack_range_area:
		#attack_range_area.connect("body_entered", Callable(self, "_on_attack_range_area_body_entered"))
		#attack_range_area.connect("body_exited", Callable(self, "_on_attack_range_area_body_exited"))
	#
	#if weapon_hitbox:
		#if weapon_hitbox.has_signal("parried"): # Assuming your WeaponHitbox script emits this
			#weapon_hitbox.connect("attack_parried", Callable(self, "_on_weapon_parried"))
	#
	#if animation_player:
		#animation_player.connect("animation_finished", Callable(self, "_on_animation_finished"))

	change_state(State.IDLE)


# --- Physics Processing ---
func _physics_process(delta: float):
	if current_state == State.DEAD:
		velocity.y += gravity * delta
		move_and_slide()
		return

	# Apply gravity
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		velocity.y = min(velocity.y, 5)

	# Update timers
	if attack_cooldown_timer > 0:
		attack_cooldown_timer -= delta
	if stun_timer > 0:
		stun_timer -= delta
		if stun_timer <= 0:
			if player_in_detection_range:
				change_state(State.FOLLOW)
			else:
				change_state(State.IDLE)
	if current_state == State.FOLLOW:
		follow_timer += delta

	# State machine logic
	match current_state:
		State.IDLE:
			velocity.x = 0
			if player_in_attack_range and attack_cooldown_timer <= 0:
				change_state(State.ATTACK)
			elif player_in_detection_range:
				change_state(State.FOLLOW)

		State.FOLLOW:
			current_movement_speed = move_speed
			move_towards_player(delta)
			if player_in_attack_range and attack_cooldown_timer <= 0:
				change_state(State.ATTACK)
			elif not player_in_detection_range:
				change_state(State.IDLE)
			elif follow_timer >= follow_to_rush_delay and not player_in_attack_range:
				change_state(State.RUSH)

		State.RUSH:
			current_movement_speed = move_speed * rush_speed_multiplier
			move_towards_player(delta)
			if player_in_attack_range and attack_cooldown_timer <= 0:
				change_state(State.ATTACK)
			elif not player_in_detection_range:
				change_state(State.IDLE)

		State.ATTACK:
			velocity.x = 0

		State.STUNNED:
			pass

	if current_state != State.STUNNED and current_state != State.ATTACK:
		move_and_slide()
		update_facing_direction()
	elif current_state == State.STUNNED:
		move_and_slide()


# --- State Management ---
func change_state(new_state: State):
	if current_state == new_state:
		return

	current_state = new_state

	match current_state:
		State.IDLE:
			play_animation("idle")
			follow_timer = 0.0
		State.FOLLOW:
			play_animation("chase") # Or "run"
			follow_timer = 0.0 # Reset when entering follow
		State.RUSH:
			play_animation("chase") # Or a faster "run"
		State.ATTACK:
			play_animation("attack", false)
			attack_cooldown_timer = attack_cooldown
		State.STUNNED:
			play_animation("idle") # Or "hurt" - User had "idle"
			deactivate_weapon_hitbox()
			stun_timer = stun_duration
			velocity.x = 0
			if player_ref:
				var push_direction = (global_position - player_ref.global_position).normalized()
				if push_direction == Vector2.ZERO:
					push_direction = Vector2.LEFT if animated_sprite.flip_h else Vector2.RIGHT
				velocity = push_direction * pushback_force
			else:
				velocity.x = pushback_force * (-1 if animated_sprite.flip_h else 1)
			if is_on_floor():
				velocity.y = -pushback_force * 0.3
		State.DEAD:
			play_animation("idle", false) # Or "death" - User had "idle"
			set_physics_process(true)
			if character_hitbox: character_hitbox.monitoring = false
			if weapon_hitbox: deactivate_weapon_hitbox()
			for i in range(get_child_count()):
				var child = get_child(i)
				if child is CollisionShape2D and child.owner == self:
					child.disabled = true
					break


# --- Movement and Animation ---
func move_towards_player(delta: float):
	if not player_ref:
		velocity.x = 0
		return

	var direction_to_player = (player_ref.global_position - global_position).normalized()
	velocity.x = direction_to_player.x * current_movement_speed

func update_facing_direction():
	if velocity.x > 0.1:
		animated_sprite.flip_h = true
	elif velocity.x < -0.1:
		animated_sprite.flip_h = false
	# --- Flip Weapon Hitbox Area2D ---
		if weapon_hitbox:
			# If flip_h is true (facing left), scale.x becomes -1. Otherwise, it's 1.
			weapon_hitbox.scale.x = -1.0 if animated_sprite.flip_h else 1.0


func play_animation(anim_name: String, loop: bool = true):
	if animation_player and animation_player.has_animation(anim_name):
		if animation_player.current_animation != anim_name:
			animation_player.play(anim_name)
	elif animated_sprite and animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation(anim_name):
		if animated_sprite.animation != anim_name:
			animated_sprite.play(anim_name)
		animated_sprite.sprite_frames.set_animation_loop(anim_name, loop)


# --- Hitbox Control (Called by AnimationPlayer) ---
func activate_weapon_hitbox():
	if weapon_hitbox:
		$WeaponHitBox2D/WeaponShape2D.disabled = false
		weapon_hitbox.monitoring = true
		weapon_hitbox.monitorable = true


func deactivate_weapon_hitbox():
	if weapon_hitbox:
		$WeaponHitBox2D/WeaponShape2D.disabled = true
		weapon_hitbox.monitoring = false
		weapon_hitbox.monitorable = false


# --- Signal Callbacks ---
func _on_detection_area_body_entered(body):
	if body.is_in_group("player"):
		player_ref = body
		player_in_detection_range = true

func _on_detection_area_body_exited(body):
	if body == player_ref:
		player_in_detection_range = false
		if not player_in_attack_range:
			player_ref = null

func _on_attack_range_area_body_entered(body):
	if body.is_in_group("player"):
		player_ref = body
		player_in_attack_range = true
		if current_state == State.IDLE and attack_cooldown_timer <= 0:
			change_state(State.ATTACK)

func _on_attack_range_area_body_exited(body):
	if body == player_ref:
		player_in_attack_range = false

func _on_weapon_parried(hurt_box: HurtBox2D):
	if current_state == State.ATTACK:
		if animation_player: animation_player.stop()
		change_state(State.STUNNED)


func _on_animation_finished(anim_name: String):
	if anim_name == "attack":
		if player_in_detection_range:
			if player_in_attack_range and attack_cooldown_timer <= 0:
				change_state(State.ATTACK)
			else:
				change_state(State.FOLLOW)
		else:
			change_state(State.IDLE)
	elif anim_name == "death" or (current_state == State.DEAD and anim_name == "idle"): # Catching user's "idle" for death
		# Shader effect (from original script, slightly adjusted for clarity)
		if animated_sprite and animated_sprite.material and animated_sprite.material.has_shader_parameter("flash_color"):
			animated_sprite.material.set_shader_parameter("flash_modifier", 1.0)
			animated_sprite.material.set_shader_parameter("flash_color", Color.RED)
			var tween = create_tween()
			tween.tween_property(animated_sprite.material, "shader_parameter/flash_modifier", 0.0, 0.3).set_delay(0.1)
			await tween.finished
		queue_free()


func _on_health_damaged(amount: int):
	if current_state == State.DEAD:
		return

	if animation_player and animation_player.has_animation("hurt") and current_state != State.ATTACK and current_state != State.STUNNED :
		animation_player.play("hurt")
	else:
		if animated_sprite and animated_sprite.material and animated_sprite.material.has_shader_parameter("flash_modifier"):
			animated_sprite.material.set_shader_parameter("flash_modifier", 0.7)
			var tween = create_tween()
			tween.tween_property(animated_sprite.material, "shader_parameter/flash_modifier", 0.0, 0.2)


func _on_health_died(entity: Node): # If your HealthComponent.died signal passes the entity
# func _on_health_died(): # If your HealthComponent.died signal passes no arguments
	# Ensure this function signature matches the signal from your HealthComponent.
	if current_state != State.DEAD:
		change_state(State.DEAD)
