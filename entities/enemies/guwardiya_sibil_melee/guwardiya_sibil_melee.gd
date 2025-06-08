extends CharacterBody2D

# this is so hacked together lol, but it's just for testing the parrying.
# TODO: move the enemy back a bit when they get parried.

func _ready():
	$AnimationPlayer.play("attack")

var noobed = false
func _on_weapon_hitbox_2d_attack_parried(hurt_box: HurtBox2D) -> void:
	print("enemy: parried, noob!")
	noobed = true
	await get_tree().create_timer(3.0).timeout
	noobed = false
	$AnimationPlayer.play("attack")

func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	if not noobed:
		$AnimationPlayer.play("attack")
