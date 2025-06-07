extends Node2D

var button_type = null

func _ready():
	$BGPlayer.play()
	$MainTheme.play()

func _on_start_pressed() -> void:
	button_type = "start"
	$"Fade Transition".show()
	$"Fade Transition/fade_timer".start()
	$"Fade Transition/AnimationPlayer".play("fade_in")

func _on_options_pressed() -> void:
	button_type = "options"
	$"Fade Transition".show()
	$"Fade Transition/fade_timer".start()
	$"Fade Transition/AnimationPlayer".play("fade_in")

func _on_quit_pressed() -> void:
	get_tree().quit()

func _on_fade_timer_timeout() -> void:
	if button_type == "start":
		get_tree().change_scene_to_file("res://scenes/game.tscn")
	elif button_type == "options":
		get_tree().change_scene_to_file("res://scenes/options.tscn")
