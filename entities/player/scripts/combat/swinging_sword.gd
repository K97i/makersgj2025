extends CombatState

@export_custom(PROPERTY_HINT_NONE, "suffix:s") var attack_time: float = 0.5

@export var holding_sword_state: StateMachineState = null
var _current_time: float = 0.0

func _enter_state():
	print("swinging")

func _process(delta: float) -> void:
	_current_time += delta
	if _current_time >= attack_time:
		_current_time = 0.0
		get_state_machine().current_state = holding_sword_state
