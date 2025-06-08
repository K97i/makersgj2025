extends CombatState

@export var block_threshold = 0.2
@export var holding_sword_state: StateMachineState = null
@export var blocking_state: StateMachineState = null
@export var parrying_state: StateMachineState = null
@export var throwing_state: StateMachineState = null

var hold_time = 0.0
var is_parry_candidate = false

func _enter_state():
	print("empty")
	hold_time = 0.0
	is_parry_candidate = false
	character.is_holding_sword = false

func _process(delta):
	if Input.is_action_pressed("defend") and is_parry_candidate:
		hold_time += delta
		if hold_time >= block_threshold:
			is_parry_candidate = false
			get_state_machine().current_state = blocking_state
			
func _unhandled_input(event: InputEvent) -> void:
	#super._unhandled_input(event)
	if event.is_action_pressed("sword_bringup"):
		get_state_machine().current_state = holding_sword_state
	elif event.is_action_pressed("defend"):
		is_parry_candidate = true
		hold_time = 0.0
	elif event.is_action_released("defend"):
		if is_parry_candidate:
			is_parry_candidate = false
			get_state_machine().current_state = parrying_state
	elif event.is_action_pressed("throw_dagger"):
		get_state_machine().current_state = throwing_state
