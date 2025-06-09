@tool
class_name ParryHitBox2D extends BasicHitBox2D
## [ParryHitBox2D] extends [BasicHitBox2D] to interact with [ParryHurtBox2D].
## Its actions can be negated if it collides with a [ParryHurtBox2D] in a parry state.

## Emitted when this hitbox's action is successfully parried by a [ParryHurtBox2D].
## The [param hurt_box] is the [ParryHurtBox2D] that performed the parry.
signal attack_parried(hurt_box: HurtBox2D)

## If [color=orange]false[/color], this hitbox's actions cannot be parried.
@export var is_parryable: bool = true


# Override the collision detection to include parry logic.
func _on_area_entered(area: Area2D) -> void:
	if ignore_collisions:
		return

	# Handle collision with another HitBox (e.g., projectile clashing)
	if area is HitBox2D: # This also covers ParryHitBox2D
		hit_box_entered.emit(area)
		return

	# Handle collision with something that isn't a HurtBox
	if not area is HurtBox2D: # This also covers BasicHurtBox2D and ParryHurtBox2D
		unknown_area_entered.emit(area)
		return

	# At this point, 'area' is confirmed to be some kind of HurtBox2D.
	var hurt_box := area as HurtBox2D

	# --- Parry Logic ---
	if is_parryable and hurt_box is ParryHurtBox2D:
		var parry_hurt_box := hurt_box as ParryHurtBox2D
		if parry_hurt_box.can_parry and parry_hurt_box.is_parrying_internal: # Access internal directly for check
			# Parry successful!
			#printerr("%s attack PARRIED by %s" % [(get_parent().name if get_parent() else name), (parry_hurt_box.get_parent().name if parry_hurt_box.get_parent() else parry_hurt_box.name)]) # For debugging
			
			hurt_box_entered.emit(parry_hurt_box) # Still emit that contact was made
			attack_parried.emit(parry_hurt_box)
			parry_hurt_box._on_parry_success(self) # Notify the hurtbox
			
			# IMPORTANT: Do not apply actions. Do not emit action_applied.
			return # Exit early, parry handled.

	# --- Standard Hit Logic (if not parried or not a parryable interaction) ---
	#printerr("%s attack HIT %s" % [(get_parent().name if get_parent() else name), (hurt_box.get_parent().name if hurt_box.get_parent() else hurt_box.name)]) # For debugging
	
	hurt_box_entered.emit(hurt_box)
	var cloned_actions := _clone_actions() # From HitBox2D
	hurt_box.apply_all_actions(cloned_actions)
	action_applied.emit(hurt_box)

# Note: _ready() is inherited from BasicHitBox2D, which calls super() for HitBox2D's _ready().
# _clone_actions() is inherited from HitBox2D.
# affect, amount, and actions setup are inherited from BasicHitBox2D.
