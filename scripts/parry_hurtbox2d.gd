@tool
class_name ParryHurtBox2D extends BasicHurtBox2D
## [ParryHurtBox2D] extends [BasicHurtBox2D] to enable a parry state,
## allowing it to negate incoming parryable attacks from [ParryHitBox2D].

## Emitted when this hurtbox successfully parries an incoming [ParryHitBox2D].
## The [param hit_box] is the [ParryHitBox2D] that was parried.
signal parry_successful(hit_box: HitBox2D)

## If [color=orange]false[/color], this hurtbox cannot enter a parry state.
@export var can_parry: bool = true

## The duration (in seconds) the parry state remains active after [method start_parry] is called.
## If [color=orange]0.0[/color] or less, parry remains active until [method stop_parry] is called.
@export var parry_active_duration: float = 0.2

## [color=green]true[/color] if this hurtbox is currently in a parry state.
@onready var is_parrying: bool = false:
	get:
		return is_parrying_internal # Use internal to avoid recursion if setter is added later
	# No direct setter from inspector, managed by start_parry/stop_parry

# Internal state, to avoid issues if a setter is added to is_parrying
var is_parrying_internal: bool = false

var _parry_timer: Timer


func _ready() -> void:
	super._ready() # Call BasicHurtBox2D's ready
	if not Engine.is_editor_hint():
		_parry_timer = Timer.new()
		_parry_timer.one_shot = true
		_parry_timer.timeout.connect(stop_parry)
		add_child(_parry_timer)


## Activates the parry state.
## If [param duration_override] is positive, it overrides [member parry_active_duration] for this activation.
func start_parry(duration_override: float = -1.0) -> void:
	if not can_parry or is_parrying_internal:
		return

	is_parrying_internal = true
	#printerr("%s started parrying" % get_parent().name if get_parent() else name) # For debugging

	var active_duration: float = duration_override if duration_override > 0.0 else parry_active_duration
	if active_duration > 0.0:
		if _parry_timer: # Check if timer exists (not in editor hint)
			_parry_timer.start(active_duration)
	# If active_duration is <= 0, parry stays active indefinitely until stop_parry() is called.


## Deactivates the parry state.
func stop_parry() -> void:
	if not is_parrying_internal:
		return

	is_parrying_internal = false
	if _parry_timer and not _parry_timer.is_stopped(): # Check if timer exists and is running
		_parry_timer.stop()
	#printerr("%s stopped parrying" % get_parent().name if get_parent() else name) # For debugging


## Called by ParryHitBox2D when a parry is successful.
func _on_parry_success(hit_box: HitBox2D) -> void:
	parry_successful.emit(hit_box)
	# Optionally, could stop parrying immediately after a successful parry
	stop_parry()
