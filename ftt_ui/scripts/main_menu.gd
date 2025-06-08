extends Node2D
var button_type = null

func _ready():
	$Fade_transition.show()
	$Fade_transition/AnimationPlayer.play("fade_out")
	$"Main Theme".play()

	
func _on_start_pressed() -> void:
	button_type = "start"
	$Fade_transition.show()
	$Fade_transition/Fade_timer.start()
	$Fade_transition/AnimationPlayer.play("fade_in")
	pass # put intro scene here
	
func _on_quit_pressed() -> void:
	$Fade_transition.show()
	$Fade_transition/Fade_timer.start()
	$Fade_transition/AnimationPlayer.play("fade_in")
	get_tree().quit()

func _on_fade_timer_timeout() -> void:
	if button_type == "start":
		pass  # put intro scene here
