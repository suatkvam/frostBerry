extends CharacterBody2D

enum State { PATROL, CHASE, ATTACK }

# Constants
const SPEED = 200.0
const PATROL_RANGE = 150.0
const DETECTION_RADIUS = 200.0
const CHASE_EXTENSION = 200.0
const ATTACK_DAMAGE = 1
const ATTACK_COOLDOWN = 1.0

# State
var current_state: State = State.PATROL
var spawn_position: Vector2
var chase_start_position: Vector2
var patrol_direction: int = 1
var attack_timer: float = 0.0
var player: CharacterBody2D = null
var returning_home: bool = false
var collision_damage_cooldown: float = 0.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var detection_area: Area2D = $DetectionArea
@onready var health_component: HealthComponent = $HealthComponent

func _ready() -> void:
	spawn_position = global_position
	detection_area.body_entered.connect(_on_detection_area_body_entered)
	detection_area.body_exited.connect(_on_detection_area_body_exited)
	animated_sprite.play("walk+run")
	print("Enemy spawned at: ", spawn_position)
	
	# HealthComponent sinyalini bağla
	if health_component:
		health_component.died.connect(_on_health_component_died)
		health_component.damage_taken.connect(_on_damage_taken)

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

	move_and_slide()

	# Check for collision damage with player
	check_collision_damage()

func patrol_behavior(delta: float) -> void:
	velocity.x = patrol_direction * SPEED
	var offset_from_spawn = global_position.x - spawn_position.x

	if returning_home:
		var distance_from_spawn_abs = abs(offset_from_spawn)
		if distance_from_spawn_abs < PATROL_RANGE:
			returning_home = false

	if patrol_direction > 0 and offset_from_spawn >= PATROL_RANGE:
		patrol_direction = -1
		flip_sprite()
	elif patrol_direction < 0 and offset_from_spawn <= -PATROL_RANGE:
		patrol_direction = 1
		flip_sprite()

	if player != null and not returning_home:
		var distance_to_player = global_position.distance_to(player.global_position)
		if distance_to_player <= DETECTION_RADIUS:
			change_state(State.CHASE)

func chase_behavior(delta: float) -> void:
	if player == null:
		change_state(State.PATROL)
		return

	var offset_from_spawn = global_position.x - spawn_position.x
	var max_chase_distance = PATROL_RANGE + CHASE_EXTENSION

	if abs(offset_from_spawn) > max_chase_distance:
		returning_home = true
		change_state(State.PATROL)
		return

	var distance_to_player = global_position.distance_to(player.global_position)
	if distance_to_player > DETECTION_RADIUS:
		change_state(State.PATROL)
		return

	var direction_to_player = player.global_position.x - global_position.x
	
	if abs(direction_to_player) > 3.0:
		var direction = sign(direction_to_player)
		velocity.x = direction * SPEED
		
		if abs(direction_to_player) > 15.0:
			animated_sprite.flip_h = direction < 0
	else:
		velocity.x = 0

	var distance_to_player_horiz = abs(direction_to_player)
	if distance_to_player_horiz < 20.0:
		change_state(State.ATTACK)

func attack_behavior(delta: float) -> void:
	if player == null:
		change_state(State.PATROL)
		return

	velocity.x = 0

	var distance_to_player_horiz = abs(player.global_position.x - global_position.x)
	if distance_to_player_horiz > 30.0:
		change_state(State.CHASE)
		return

	if distance_to_player_horiz > 8.0:
		var direction_to_player = player.global_position.x - global_position.x
		animated_sprite.flip_h = direction_to_player < 0

func change_state(new_state: State) -> void:
	if current_state == new_state:
		return

	current_state = new_state

	match current_state:
		State.PATROL:
			var direction_to_spawn = sign(spawn_position.x - global_position.x)
			if direction_to_spawn != 0:
				patrol_direction = direction_to_spawn
				flip_sprite()
		State.CHASE:
			chase_start_position = global_position

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
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()

		if collider and (collider.name == "Character" or collider.is_in_group("player")):
			if collision_damage_cooldown <= 0.0:
				if collider.has_method("take_damage"):
					collider.take_damage(ATTACK_DAMAGE)
					collision_damage_cooldown = ATTACK_COOLDOWN

# HASAR SİSTEMİ - Player'dan gelen hasarlar için
func take_damage(amount: int) -> void:
	if health_component:
		health_component.take_damage(amount)

func _on_damage_taken(amount: int) -> void:
	# Hasar görsel efekti
	animated_sprite.modulate = Color(1, 0.3, 0.3)
	await get_tree().create_timer(0.1).timeout
	animated_sprite.modulate = Color.WHITE

func _on_health_component_died() -> void:
	print("Enemy öldü!")
	# Ölüm animasyonu varsa
	# animated_sprite.play("death")
	# await animated_sprite.animation_finished
	queue_free()
