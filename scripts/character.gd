extends CharacterBody2D


const SPEED = 300.0
const JUMP_VELOCITY = -400.0


@onready var health_component: HealthComponent = $HealthComponent
@onready var jump_sound: AudioStreamPlayer2D = $JumpSound
@onready var landing_sound: AudioStreamPlayer2D = $LandingSound
@onready var hurt_sound: AudioStreamPlayer2D = $HurtSound
@onready var death_sound: AudioStreamPlayer2D = $DeathSound

var was_on_floor: bool = false


func _ready() -> void:
	health_component.died.connect(_on_death)
	health_component.health_changed.connect(_on_health_changed)


func _physics_process(delta: float) -> void:
	# Check landing
	if is_on_floor() and not was_on_floor:
		landing_sound.play()

	was_on_floor = is_on_floor()

	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY
		jump_sound.play()

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var direction := Input.get_axis("ui_left", "ui_right")
	if direction:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	move_and_slide()


func take_damage(amount: int) -> void:
	health_component.take_damage(amount)


func _on_health_changed(current_health: int, max_health: int) -> void:
	hurt_sound.play()


func _on_death() -> void:
	set_physics_process(false)
	death_sound.play()
	# TODO: Add death animation or game over screen
