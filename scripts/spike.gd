extends Area2D


@onready var spike_sound: AudioStreamPlayer2D = $SpikeSound


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	# Check if it's the player
	if body.name == "Character" or body.is_in_group("player"):
		# Instant kill
		if body.has_method("take_damage"):
			# Deal massive damage (instant death)
			if spike_sound:
				spike_sound.play()
			body.take_damage(999)
			print("SPIKE: Player touched spike - instant death!")
