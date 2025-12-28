extends Node

var menu_scene = preload("res://scene/main_menu.tscn")
var menu_instance = null

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS

func _input(event):
	if event.is_action_pressed("ui_cancel"):
		if get_tree().paused:
			# This is handled by the menu itself now
			pass
		else:
			get_tree().paused = true
			
			# Create a CanvasLayer to ensure the menu stays fixed on screen
			var canvas_layer = CanvasLayer.new()
			canvas_layer.layer = 100 # Ensure it's on top of everything
			
			menu_instance = menu_scene.instantiate()
			canvas_layer.add_child(menu_instance)
			
			# Add the CanvasLayer to the scene
			get_tree().current_scene.add_child(canvas_layer)
			
			# Clean up the CanvasLayer when the menu is destroyed
			menu_instance.tree_exited.connect(canvas_layer.queue_free)
			
			get_viewport().set_input_as_handled()

func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		get_tree().quit()
