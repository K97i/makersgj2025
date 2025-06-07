class_name IdleState
extends MovementState

@export var running_state: StateMachineState = null
@export var jumping_state: StateMachineState = null
@export var falling_state: StateMachineState = null
@export var dashing_state: StateMachineState = null

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if not character.is_on_floor(): # the player somehow got moved while idle
		get_state_machine().current_state = falling_state


func _unhandled_input(event: InputEvent) -> void:
	super._unhandled_input(event)
	if event.is_action_just_pressed("jump"):
		get_state_machine().current_state = jumping_state
	elif event.is_action_just_pressed("dash"):
		get_state_machine().current_state = dashing_state
	elif event.is_action_pressed("move_left") or event.is_action_pressed("move_right"):
		get_state_machine().current_state = running_state
