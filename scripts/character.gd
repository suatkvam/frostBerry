extends CharacterBody2D

const SPEED = 170.0
const JUMP_VELOCITY = -250.0

@onready var animated_sprite = $AnimatedSprite2D

func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta
	
	# Handle jump.
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY
	
	# Get the input direction and handle the movement/deceleration.
	var direction := Input.get_axis("move_left", "move_right")
	if direction:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
	
	move_and_slide()
	
	# Animasyon kontrolü
	update_animation(direction)

func update_animation(direction: float) -> void:
	# Havadaysa jump animasyonu
	if not is_on_floor():
		animated_sprite.play("jump")
	# Hareket ediyorsa run animasyonu
	elif direction != 0:
		animated_sprite.play("run")
		# Karakteri hareket yönüne çevir
		animated_sprite.flip_h = direction < 0
	# Duruyorsa idle animasyonu
	else:
		animated_sprite.play("idle")
