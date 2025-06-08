extends CombatState

@export_custom(PROPERTY_HINT_NONE, "suffix:s") var parry_time: float = 0.1875

@export var empty_state: StateMachineState = null
@export var holding_sword_state: StateMachineState = null

var _current_time = 0.0

func _enter_state():
	print("starting parry")

func _process(delta: float) -> void:
	_current_time += delta
	if _current_time >= parry_time:
		_current_time = 0.0
		if character.is_holding_sword:
			print("set state to hold")
			get_state_machine().current_state = holding_sword_state
		else:
			print("set state to empty")
			get_state_machine().current_state = empty_state
