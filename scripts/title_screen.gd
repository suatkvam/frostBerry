extends Control

func _ready():
	# Ensure the cursor is visible and game is not paused when in the main menu
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().paused = false

func _on_new_game_button_pressed():
	print("New Game button pressed. Loading level2_beta.tscn...")
	get_tree().change_scene_to_file("res://scene/level2_beta.tscn")

func _on_exit_button_pressed():
	get_tree().quit()
