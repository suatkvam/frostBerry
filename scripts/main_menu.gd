extends Control

var resume_button
var quit_button

func _ready():
	# Ensure the menu processes even when the game is paused
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	print("MainMenu _ready called.")
	
	# Try to find nodes using unique names first (fastest)
	resume_button = get_node_or_null("%ResumeButton")
	quit_button = get_node_or_null("%QuitButton")
	
	# Fallback: Find by name recursively if unique access fails
	if not resume_button:
		print("WARNING: %ResumeButton not found. Searching children recursively...")
		resume_button = find_child("ResumeButton", true, false)
	
	if not quit_button:
		print("WARNING: %QuitButton not found. Searching children recursively...")
		quit_button = find_child("QuitButton", true, false)
		
	# Connect signals if found, else dump tree
	if resume_button and quit_button:
		resume_button.pressed.connect(_on_resume_button_pressed)
		quit_button.pressed.connect(_on_quit_button_pressed)
		print("MainMenu initialized successfully.")
	else:
		print("ERROR: One or more buttons missing. Dumping tree:")
		print_tree_pretty()

	# The game is already paused by the time this menu is shown.

func _unhandled_input(event):
	if event.is_action_pressed("ui_cancel"):
		_resume_game()
		get_viewport().set_input_as_handled()

func _resume_game():
	get_tree().paused = false
	queue_free()

func _on_resume_button_pressed():
	_resume_game()

func _on_quit_button_pressed():
	# Unpause before leaving the scene, otherwise the new scene might start paused
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scene/title_screen.tscn")
