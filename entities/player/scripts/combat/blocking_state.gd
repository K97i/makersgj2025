extends CombatState

@export var empty_state: StateMachineState = null
@export var holding_sword_state: StateMachineState = null
@export var swinging_sword_state: StateMachineState = null

func _enter_state():
	character.speed_multiplier = 0.5
	character.is_blocking = true
	print("blocking")
	
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_released("defend"):
		if character.is_holding_sword:
			print("switching to hold")
			get_state_machine().current_state = holding_sword_state
		else:
			print("switching to nothing")

			get_state_machine().current_state = empty_state
	elif event.is_action_pressed("sword_swing"):
		character.is_holding_sword = true
		get_state_machine().current_state = swinging_sword_state

func _exit_state():
	character.is_blocking = false
