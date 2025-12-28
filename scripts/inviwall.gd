extends StaticBody2D

func _ready():
	# Oyun başladığında görseli gizle
	if has_node("EditorVisual"):
		$EditorVisual.visible = false
