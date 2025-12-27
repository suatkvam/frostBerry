extends CharacterBody2D


enum State { PATROL, CHASE, ATTACK }


# Constants
const SPEED = 200.0
const PATROL_RANGE = 150.0
const DETECTION_RADIUS = 200.0
const CHASE_EXTENSION = 200.0  # Extra distance to chase beyond patrol boundary
const ATTACK_DAMAGE = 1
const ATTACK_COOLDOWN = 1.0


# State
var current_state: State = State.PATROL
var spawn_position: Vector2
var chase_start_position: Vector2
var patrol_direction: int = 1
var attack_timer: float = 0.0
var player: CharacterBody2D = null
var returning_home: bool = false  # True when returning to spawn after long chase
var collision_damage_cooldown: float = 0.0  # Cooldown for collision damage


@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var detection_area: Area2D = $DetectionArea


func _ready() -> void:
	spawn_position = global_position
	detection_area.body_entered.connect(_on_detection_area_body_entered)
	detection_area.body_exited.connect(_on_detection_area_body_exited)
	animated_sprite.play("walk+run")
	print("Enemy spawned at: ", spawn_position)


func _physics_process(delta: float) -> void:
	# Apply gravity
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Update attack timer
	if attack_timer > 0:
		attack_timer -= delta

	# Update collision damage cooldown
	if collision_damage_cooldown > 0:
		collision_damage_cooldown -= delta

	# State-based behavior
	match current_state:
		State.PATROL:
			patrol_behavior(delta)
		State.CHASE:
			chase_behavior(delta)
		State.ATTACK:
			attack_behavior(delta)

	# Debug output
	if current_state != State.PATROL:
		print("State: ", State.keys()[current_state], " | Velocity.x: ", velocity.x, " | Player: ", player != null)

	move_and_slide()

	# Check for collision damage with player
	check_collision_damage()


func patrol_behavior(delta: float) -> void:
	# Move in patrol direction
	velocity.x = patrol_direction * SPEED

	# Check boundaries (150px left/right from spawn)
	var offset_from_spawn = global_position.x - spawn_position.x

	# If returning home, check if we're close enough to reset flag
	if returning_home:
		var distance_from_spawn_abs = abs(offset_from_spawn)
		if distance_from_spawn_abs < PATROL_RANGE:
			# Back in patrol zone, can detect player again
			print("PATROL: Back home, resuming normal patrol")
			returning_home = false

	# Turn around only if moving away from spawn and at boundary
	if patrol_direction > 0 and offset_from_spawn >= PATROL_RANGE:
		# Moving right and too far right, turn left
		patrol_direction = -1
		flip_sprite()
	elif patrol_direction < 0 and offset_from_spawn <= -PATROL_RANGE:
		# Moving left and too far left, turn right
		patrol_direction = 1
		flip_sprite()

	# Check if player detected (only if NOT returning home)
	if player != null and not returning_home:
		var distance_to_player = global_position.distance_to(player.global_position)

		# Start chase if player is in detection range
		if distance_to_player <= DETECTION_RADIUS:
			change_state(State.CHASE)


func chase_behavior(delta: float) -> void:
	if player == null:
		print("CHASE: Player is null, returning to patrol")
		change_state(State.PATROL)
		return

	# Check if too far from patrol zone (X-axis only)
	var offset_from_spawn = global_position.x - spawn_position.x
	var max_chase_distance = PATROL_RANGE + CHASE_EXTENSION  # 150 + 100 = 250px

	if offset_from_spawn > max_chase_distance:
		# Too far right from spawn
		print("CHASE: Too far right (", offset_from_spawn, "px), returning home")
		returning_home = true
		change_state(State.PATROL)
		return
	elif offset_from_spawn < -max_chase_distance:
		# Too far left from spawn
		print("CHASE: Too far left (", offset_from_spawn, "px), returning home")
		returning_home = true
		change_state(State.PATROL)
		return

	# Check if player still in detection range
	var distance_to_player = global_position.distance_to(player.global_position)
	if distance_to_player > DETECTION_RADIUS:
		print("CHASE: Player out of detection range, returning to patrol")
		change_state(State.PATROL)
		return

	# Move towards player
	var direction_to_player = player.global_position.x - global_position.x
	print("CHASE: direction_to_player = ", direction_to_player, " | abs = ", abs(direction_to_player))

	# Always move towards player if they're to the side
	if abs(direction_to_player) > 3.0:
		var direction = sign(direction_to_player)
		velocity.x = direction * SPEED
		print("CHASE: Moving with velocity.x = ", velocity.x)

		# Only flip sprite if direction is clear (prevents rapid flipping)
		if abs(direction_to_player) > 15.0:
			animated_sprite.flip_h = direction < 0
	else:
		velocity.x = 0
		print("CHASE: Too close, stopping")

	# Check if close enough to attack (20px threshold to enter attack)
	var distance_to_player_horiz = abs(direction_to_player)
	if distance_to_player_horiz < 20.0:
		print("CHASE: Close enough, switching to ATTACK")
		change_state(State.ATTACK)


func attack_behavior(delta: float) -> void:
	if player == null:
		change_state(State.PATROL)
		return

	# Stop moving while attacking
	velocity.x = 0

	# Check if player moved away (30px threshold to exit attack - hysteresis)
	var distance_to_player_horiz = abs(player.global_position.x - global_position.x)
	if distance_to_player_horiz > 30.0:
		change_state(State.CHASE)
		return

	# Attack when cooldown ready and player is close
	if attack_timer <= 0.0 and distance_to_player_horiz < 25.0:
		damage_player()
		attack_timer = ATTACK_COOLDOWN

	# Keep sprite facing player (only flip if far enough to avoid jitter)
	if distance_to_player_horiz > 8.0:
		var direction_to_player = player.global_position.x - global_position.x
		animated_sprite.flip_h = direction_to_player < 0


func change_state(new_state: State) -> void:
	if current_state == new_state:
		return

	print("STATE CHANGE: ", State.keys()[current_state], " -> ", State.keys()[new_state])
	current_state = new_state

	# State entry logic
	match current_state:
		State.PATROL:
			# Return to spawn direction
			var direction_to_spawn = sign(spawn_position.x - global_position.x)
			if direction_to_spawn != 0:
				patrol_direction = direction_to_spawn
				flip_sprite()
		State.CHASE:
			# Save position where chase started
			chase_start_position = global_position
			print("Entering CHASE state at: ", chase_start_position)
		State.ATTACK:
			print("Entering ATTACK state")


func is_touching_player() -> bool:
	if player == null:
		return false

	# Check if player is very close (within collision range)
	var distance = global_position.distance_to(player.global_position)
	return distance < 20.0  # Adjust this value based on collision size


func damage_player() -> void:
	if player != null and player.has_method("take_damage"):
		player.take_damage(ATTACK_DAMAGE)


func flip_sprite() -> void:
	animated_sprite.flip_h = patrol_direction < 0


func _on_detection_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") or body.name == "Character":
		player = body


func _on_detection_area_body_exited(body: Node2D) -> void:
	if body == player:
		player = null
		if current_state == State.CHASE or current_state == State.ATTACK:
			change_state(State.PATROL)


func check_collision_damage() -> void:
	# Check if enemy collided with player
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()

		# Check if it's the player
		if collider and (collider.name == "Character" or collider.is_in_group("player")):
			# Deal damage if cooldown is ready
			if collision_damage_cooldown <= 0.0:
				if collider.has_method("take_damage"):
					collider.take_damage(ATTACK_DAMAGE)
					collision_damage_cooldown = ATTACK_COOLDOWN
					print("ENEMY: Collision damage! Player hit by physical contact")
