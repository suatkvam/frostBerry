extends AnimatableBody2D


@export var move_distance: float = 200.0  # Total distance to move (left and right)
@export var speed: float = 100.0  # Pixels per second
@export var wait_time: float = 1.0  # Seconds to wait at boundaries

var start_position: Vector2
var direction: int = 1  # 1 for right, -1 for left
var wait_timer: float = 0.0  # Timer for waiting at boundaries


func _ready() -> void:
	start_position = position


func _physics_process(delta: float) -> void:
	# If waiting, decrease timer and don't move
	if wait_timer > 0:
		wait_timer -= delta
		return

	# Move in current direction
	position.x += direction * speed * delta

	# Check boundaries and reverse direction
	var offset = position.x - start_position.x

	if direction > 0 and offset >= move_distance / 2:
		# Reached right boundary, wait then go left
		direction = -1
		wait_timer = wait_time
	elif direction < 0 and offset <= -move_distance / 2:
		# Reached left boundary, wait then go right
		direction = 1
		wait_timer = wait_time
